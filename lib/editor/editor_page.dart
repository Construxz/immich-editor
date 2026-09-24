import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../photo.dart';
import '../gallery/backup_state.dart' show folderBackedUp;
import '../l10n/app_localizations.dart';
import '../hdr.dart';
import '../main.dart' show storage;
import '../server/immich.dart';
import '../theme.dart';
import 'ruler.dart';
import 'presets.dart';
import 'recipe.dart';
import 'save.dart';
import 'preview.dart';
import 'crop.dart';

enum _Section { presets, crop, adjust, filter }

/// The editor laid out like Google Photos (spec, *Bedienung*): close, undo, save at the
/// top; the image in the middle; tools and sections at the bottom.
class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.immich,
    required this.id,
    this.onDevice = false,
  });

  final Immich immich;
  final String id;

  /// [id] is a device photo: edit without a server, copy into the device gallery (D-24).
  final bool onDevice;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  Photo? _photo;

  /// When re-editing: the previous copy; it goes to the trash after saving
  /// (spec, *Speicherweg* 5).
  Photo? _oldCopy;
  var _ready =
      false; // image in the editor, at first possibly Immich's preview image

  /// The original, once loaded and in the renderer; for online photos it arrives in the background.
  Uint8List? _original;
  Future<Uint8List>?
  _originalReady; // null: waiting for Wi-Fi or for a confirmation

  /// Setting "Mobile Daten" off (D-24): originals and uploads only without a metered connection.
  var _wifiOnly = false;
  var _toDevice =
      true; // copy into the device gallery instead of straight to the server
  var _hasGainmap = false;
  var _dimensions = const Size(1, 1); // as the original is seen
  double? _ratio; // chosen aspect ratio, null = free
  Object? _error;
  var _saving = false;
  var _step = ''; // what is happening while saving
  var _section = _Section.adjust;
  String? _tool; // selected adjustment in the adjust section
  var _presets = <Preset>[];

  /// The adjustments "Optimieren" may set; a second tap starts from 0 for them, not on top.
  Future<Map<String, double>>?
  _optimizedValues; // "Optimieren" for this photo, once
  Map<String, double>? _optimizedNow; // its result, once known

  /// "Optimieren" is on: the adjustments it sets hold exactly its values.
  bool get _isOptimized {
    final v = _optimizedNow;
    return v != null &&
        v.isNotEmpty &&
        optimizedKeys.every((k) => _recipe.value(k) == (v[k] ?? 0));
  }

  List<Uint8List>? _thumbs; // filter thumbnails, in the order of [filters]

  // Undo/redo: the history and the position in it
  var _history = <Recipe>[const Recipe()];
  var _position = 0;
  var _recipe = const Recipe();

  /// What the editor started with — when re-editing, the copy's recipe.
  Recipe get _start => _history.first;
  bool get _changed => !_recipe.sameAs(_start);

  @override
  void initState() {
    super.initState();
    hdrOn.addListener(_hdrChanged);
    final clock = Stopwatch()..start(); // measured as in D-29
    () async {
      try {
        final immich = widget.immich;
        // From the server details, head and Immich's preview image — the original loads in the
        // background (D-29). A copy opens its original with its recipe. Settings meanwhile.
        // Settings and presets load meanwhile; small, local, they never fail.
        final settings = Future.wait([
          for (final k in ['online', 'mobil']) storage.read(key: k),
        ]);
        final presetsRead = readPresets();
        final (:photo, :original, :preview, :oldCopy, :start) = await loadPhoto(
          immich,
          widget.id,
          onDevice: widget.onDevice,
          preview: true,
        );
        // persisted: do not rename
        final [online, mobile] = await settings;
        final presets = await presetsRead;
        final hdr = hdrOn.value;
        // Online photos per setting, default device (D-25).
        // A local original (also a server photo that lives here, D-24) saves to the device.
        final toDevice = original != null || online != 'server';
        final wifiOnly = mobile == 'aus';
        final loaded = await loadOriginal(
          original ?? preview!,
          hdr: hdr,
          recipe: start,
        );
        if (!mounted) return;
        if (kDebugMode) {
          debugPrint('editor: image after ${clock.elapsedMilliseconds} ms');
        }
        setState(() {
          _photo = photo;
          _oldCopy = oldCopy;
          _history = [start];
          _recipe = start;
          _original = original;
          _ready = true;
          _toDevice = toDevice;
          _hasGainmap = loaded.hasGainmap;
          _dimensions = Size(loaded.width, loaded.height);
          _wifiOnly = wifiOnly;
          _presets = presets;
        });
        if (original != null) {
          _originalReady = Future.value(original);
        } else if (!wifiOnly || !await isMetered()) {
          _originalReady = _fetchOriginal(photo.id)
            ..ignore(); // an error only shows when saving
        }
      } catch (e) {
        if (mounted) setState(() => _error = e);
      }
    }();
  }

  /// Fetches the original from the server and swaps it for the preview image in the renderer —
  /// only now is there HDR and full resolution. Saving waits for it.
  Future<Uint8List> _fetchOriginal(String id) async {
    final original = await widget.immich.original(id);
    if (!mounted) return original;
    final loaded = await loadOriginal(
      original,
      hdr: hdrOn.value,
      recipe: _shown,
    );
    if (mounted) {
      setState(() {
        _original = original;
        _hasGainmap = loaded.hasGainmap;
      });
    }
    return original;
  }

  @override
  void dispose() {
    hdrOn.removeListener(_hdrChanged);
    endSession();
    super.dispose();
  }

  /// While cropping, the preview shows the whole image; the frame lies on top.
  Recipe get _shown => _section == _Section.crop
      ? _recipe.copyWith(crop: const [0, 0, 1, 1])
      : _recipe;

  void _show() => showRecipe(_shown);

  /// New state; with [remember] as an undo step.
  void _change(Recipe r, {bool remember = true}) {
    setState(() => _recipe = r);
    _show();
    if (remember) _remember();
  }

  void _remember() {
    if (_history[_position] == _recipe) return;
    _history
      ..removeRange(_position + 1, _history.length)
      ..add(_recipe);
    setState(() => _position = _history.length - 1);
  }

  void _jump(int position) {
    setState(() {
      _position = position;
      _recipe = _history[position];
    });
    _show();
  }

  void _switchSection(_Section s) {
    setState(() {
      _section = s;
      _tool = null;
    });
    _show();
    if (s == _Section.filter && _thumbs == null) {
      final clock = Stopwatch()..start();
      filterThumbs(filters).then((t) {
        if (kDebugMode) {
          debugPrint('editor: filters after ${clock.elapsedMilliseconds} ms');
        }
        if (mounted) setState(() => _thumbs = t);
      });
    }
  }

  /// HDR switched here, in the gallery or the viewer (D-58).
  void _hdrChanged() {
    if (!mounted) return;
    setState(() {});
    showHdr(hdrOn.value);
  }

  /// Aspect ratio of the rotated frame (width/height).
  double get _frame => _recipe.quarterTurns.isOdd
      ? _dimensions.height / _dimensions.width
      : _dimensions.width / _dimensions.height;

  List<double> _crop(double? ratio, int quarterTurns) => quarterTurns.isOdd
      ? cropFor(ratio, _dimensions.height, _dimensions.width)
      : cropFor(ratio, _dimensions.width, _dimensions.height);

  Future<void> _close() async {
    if (!_changed || _saving) return Navigator.of(context).pop();
    final l = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.editorDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.editorDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  /// Render the copy, upload it, stack it on top of the original, put it in its albums — or
  /// put it in the device gallery and queue it for stacking (D-24, D-25).
  /// Capture time and place travel along in the carried-over EXIF.
  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    // Editing a copy: replace it (the old one goes to the trash) or put the new one beside it.
    var replace = false;
    if (_oldCopy != null) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(l.save),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, true),
              child: ListTile(
                leading: const Icon(Icons.save),
                title: Text(l.saveReplaceCopy),
                subtitle: Text(l.saveReplaceCopyHint),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, false),
              child: ListTile(
                leading: const Icon(Icons.library_add),
                title: Text(l.saveAsAnotherCopy),
                subtitle: Text(l.saveAsAnotherCopyHint),
              ),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      replace = choice;
    }
    // Does something have to go over the network that the "Mobile Daten" setting allows only on Wi-Fi?
    final network = _originalReady == null || !_toDevice;
    if (_wifiOnly && network && await isMetered()) {
      if (!mounted) return;
      final anyway = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.useMobileDataTitle),
          content: Text(l.saveMobileDataBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.anyway),
            ),
          ],
        ),
      );
      if (anyway != true) return;
    }
    if (!mounted) return;
    _originalReady ??= _fetchOriginal(_photo!.id);
    setState(() {
      _saving = true;
      _step = l.stepRendering;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final immich = widget.immich;
    final photo = _photo!;
    try {
      if (_original == null) {
        setState(() => _step = l.editorLoadingOriginal);
      }
      final (:entry, :copy) = await saveCopy(
        immich,
        photo: photo,
        original: await _originalReady!,
        recipe: _recipe,
        hdr: hdrOn.value,
        toDevice: _toDevice,
        oldCopy: _oldCopy,
        replace: replace,
        onStep: (s) => setState(() => _step = s),
      );
      if (!entry.onDevice) {
        messenger.showSnackBar(SnackBar(content: Text(l.saveDoneChecked)));
        navigator.pop(entry);
        return;
      }
      // A folder the Immich app does not back up: on request upload archived and open in
      // the Immich app (D-36).
      if (photo.folder != null) {
        setState(() => _step = l.stepChecking);
        final backedUp = await folderBackedUp(
          immich,
          photo.folder!,
        ).catchError((_) => true); // don't ask without network
        if (!backedUp && mounted && await _askOpenInImmich(photo.folder!)) {
          await _openInImmich(copy, photo, messenger, l);
          navigator.pop(entry);
          return;
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(l.saveDoneOnDevice)));
      navigator.pop(entry);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed('$e'))));
      setState(() => _saving = false);
    }
  }

  /// Name of the album that edits from folders without backup go into.
  static const _album = 'Editor for Immich';

  Future<bool> _askOpenInImmich(String folder) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(AppLocalizations.of(c).saveOpenInImmichTitle),
          content: Text(
            AppLocalizations.of(c).saveOpenInImmichBody(
              folder.replaceAll(RegExp(r'/$'), ''),
              _album,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(AppLocalizations.of(c).saveDeviceOnly),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(AppLocalizations.of(c).saveOpenInImmich),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _openInImmich(
    Uint8List copy,
    Photo photo,
    ScaffoldMessengerState messenger,
    AppLocalizations l,
  ) async {
    final immich = widget.immich;
    setState(() => _step = l.stepUploading);
    final id = await immich.upload(
      copy,
      photo.fileName.replaceFirst(RegExp(r'(\.[^.]*)?$'), '.edit.jpg'),
      photo.takenAt,
      archived: true,
    );
    if ((await immich.photo(id)).checksum != await sha1(copy)) {
      throw Exception(l.saveCopyMismatch(id));
    }
    await immich.addToAlbum(await immich.album(_album), [id]);
    final opened = await openUrl(
      'immich://asset?id=$id',
      package: await storage.read(key: 'openWith'), // null: Android asks
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          opened ? l.saveArchived(_album) : l.saveArchivedNoApp(_album),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Black as in Google Photos: stays black on OLED, even when HDR turns the panel up.
    final l = AppLocalizations.of(context);
    final dark = darkTheme.copyWith(scaffoldBackgroundColor: Colors.black);
    return Theme(
      data: dark,
      child: PopScope(
        canPop: !_changed || _saving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Scaffold(
          body: SafeArea(
            child: _error != null
                ? Center(child: Text('$_error'))
                : !_ready
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _topBar(l),
                      if (_section == _Section.crop) _cropButtons(l),
                      Expanded(child: _imageArea()),
                      _tools(l),
                      _tabs(l),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l.close,
          onPressed: _saving ? null : _close,
        ),
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: l.editorUndo,
          onPressed: _position > 0 && !_saving
              ? () => _jump(_position - 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          tooltip: l.editorRedo,
          onPressed: _position < _history.length - 1 && !_saving
              ? () => _jump(_position + 1)
              : null,
        ),
        const Spacer(),
        if (_hasGainmap) HdrButton(enabled: !_saving),
        FilledButton(
          onPressed: _saving || !_changed || _recipe.isNeutral ? null : _save,
          child: Text(l.save),
        ),
        PopupMenuButton<String>(
          tooltip: l.editorMore,
          enabled: !_saving,
          onSelected: (v) {
            if (v == 'hdr') setHdr(!hdrOn.value);
            if (v == 'reset') {
              _ratio = null;
              _change(const Recipe());
            }
            if (v == 'saved') _change(_start);
          },
          itemBuilder: (_) => [
            if (_hasGainmap && hdrButton.value)
              CheckedPopupMenuItem(
                value: 'hdr',
                checked: hdrOn.value,
                child: const Text('HDR'),
              ),
            PopupMenuItem(value: 'reset', child: Text(l.editorResetAll)),
            if (_oldCopy != null)
              PopupMenuItem(value: 'saved', child: Text(l.editorBackToSaved)),
          ],
        ),
      ],
    ),
  );

  Widget _imageArea() => Stack(
    fit: StackFit.expand,
    children: [
      Semantics(label: _photo?.fileName, child: const Preview()),
      if (_section == _Section.crop)
        CropFrame(
          aspectRatio: _frame,
          crop: _recipe.crop,
          ratio: _ratio,
          onChanged: (c) => setState(() => _recipe = _recipe.copyWith(crop: c)),
          onEnd: _remember,
        )
      else
        // Long press shows the original.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (_) => showRecipe(const Recipe()),
          onLongPressEnd: (_) => _show(),
        ),
      if (_saving)
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_step),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _cropButtons(AppLocalizations l) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      PopupMenuButton<double>(
        icon: const Icon(Icons.aspect_ratio),
        tooltip: l.editorAspectRatio,
        onSelected: (v) {
          _ratio = v == 0 ? null : v;
          _change(_recipe.copyWith(crop: _crop(_ratio, _recipe.quarterTurns)));
        },
        itemBuilder: (_) => [
          for (final (name, v) in [
            (l.editorRatioFree, 0.0),
            (l.original, _frame),
            (l.editorRatioSquare, 1.0),
            ('5:4', 5 / 4),
            ('4:3', 4 / 3),
            ('3:2', 3 / 2),
            ('16:9', 16 / 9),
            ('4:5', 4 / 5),
            ('3:4', 3 / 4),
            ('2:3', 2 / 3),
            ('9:16', 9 / 16),
          ])
            PopupMenuItem(value: v, child: Text(name)),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.flip),
        tooltip: l.editorFlip,
        onPressed: () => _change(_recipe.copyWith(flip: !_recipe.flip)),
      ),
      IconButton(
        icon: const Icon(Icons.rotate_90_degrees_ccw),
        tooltip: l.editorRotate,
        onPressed: () {
          // Google rotates counterclockwise; the aspect ratio rotates along.
          final q = (_recipe.quarterTurns + 3) % 4;
          final old = _ratio;
          _ratio = old == null ? null : 1 / old;
          _change(_recipe.copyWith(quarterTurns: q, crop: _crop(_ratio, q)));
        },
      ),
    ],
  );

  /// Save the adjustments as a preset, under a name the user enters.
  Future<void> _savePreset() async {
    final field = TextEditingController();
    final l = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.presetSaveTitle),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: InputDecoration(labelText: l.presetName),
          onSubmitted: (t) => Navigator.pop(c, t),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(c, field.text),
            child: Text(l.presetSave),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final presets = [
      for (final p in _presets)
        if (p.name != name.trim()) p,
      presetFrom(name.trim(), _recipe),
    ];
    await writePresets(presets);
    if (mounted) setState(() => _presets = presets);
  }

  Future<void> _deletePreset(Preset preset) async {
    final l = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.presetDeleteTitle(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.presetDelete),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final presets = [
      for (final p in _presets)
        if (p != preset) p,
    ];
    await writePresets(presets);
    if (mounted) setState(() => _presets = presets);
  }

  Widget _tools(AppLocalizations l) {
    if (_section == _Section.presets) {
      // ponytail: names instead of thumbnails (spec); the renderer computes those only one at a time.
      final own = presetFrom('', _recipe);
      return SizedBox(
        height: 96,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            // First, as "Automatisch" in Google Photos: read the photo, set the adjustments
            // (D-70). Adjustments it does not touch stay as they are.
            // A switch: selected while the adjustments hold its values; tapped again, they go
            // back to 0 (D-71). Computed once per photo.
            _ToolButton(
              label: l.presetOptimize,
              icon: Icons.auto_fix_high,
              selected: _isOptimized,
              changed: false,
              onTap: () async {
                final on = !_isOptimized;
                final values = on
                    ? _optimizedNow = await (_optimizedValues ??= optimize())
                    : const <String, double>{};
                if (!mounted) return;
                _change(withOptimized(_recipe, values));
                if (on && values.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.presetOptimizeNothing)),
                  );
                }
              },
            ),
            _ToolButton(
              label: l.presetSave,
              icon: Icons.add,
              selected: false,
              changed: false,
              onTap: own.adjustments.isEmpty && own.filter == null
                  ? null
                  : _savePreset,
            ),
            // Own presets apart from the two actions (D-71).
            if (_presets.isNotEmpty)
              const VerticalDivider(width: 17, indent: 22, endIndent: 40),
            for (final p in _presets)
              _ToolButton(
                label: p.name,
                icon: Icons.auto_awesome,
                selected:
                    mapEquals(p.adjustments, own.adjustments) &&
                    p.filter == own.filter,
                changed: false,
                onTap: () => _change(withPreset(_recipe, p)),
                onLongPress: () => _deletePreset(p),
              ),
          ],
        ),
      );
    }
    if (_section == _Section.filter) return _filterTools(l);
    if (_section == _Section.crop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Ruler(
          value: _recipe.angle,
          min: -45,
          max: 45,
          scale: 1,
          unit: '°',
          tick: 1,
          step: 0.1,
          snapRange: 0.5,
          onChanged: (v) =>
              _change(_recipe.copyWith(angle: v), remember: false),
          onEnd: _remember,
        ),
      );
    }
    final active = _tool;
    return Column(
      children: [
        if (active != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Ruler(
              value: _recipe.value(active),
              min: -1,
              max: 1,
              onChanged: (v) =>
                  _change(_recipe.withValue(active, v), remember: false),
              onEnd: _remember,
            ),
          ),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final t in tools)
                _ToolButton(
                  label: toolName(l, t.key),
                  icon: t.icon,
                  selected: t.key == active,
                  changed: _recipe.value(t.key) != 0,
                  onTap: () =>
                      setState(() => _tool = t.key == active ? null : t.key),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Strength ruler for the chosen filter, below it the filters as thumbnails.
  Widget _filterTools(AppLocalizations l) {
    final chosen = _recipe.filter;
    final thumbs = _thumbs;
    return Column(
      children: [
        if (chosen != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Ruler(
              value: chosen.strength,
              min: 0,
              max: 1,
              onChanged: (v) => _change(
                _recipe.withFilter((id: chosen.id, strength: v)),
                remember: false,
              ),
              onEnd: _remember,
            ),
          ),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _ToolButton(
                label: l.filterNone,
                icon: Icons.block,
                selected: chosen == null,
                changed: false,
                onTap: () => _change(_recipe.withFilter(null)),
              ),
              for (final (i, id) in filters.indexed)
                _ToolButton(
                  label: filterName(l, id),
                  icon: Icons.filter,
                  image: thumbs == null || i >= thumbs.length
                      ? null
                      : thumbs[i],
                  selected: chosen?.id == id,
                  changed: false,
                  onTap: chosen?.id == id
                      ? null
                      : () =>
                            _change(_recipe.withFilter((id: id, strength: 1))),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabs(AppLocalizations l) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (s, name) in [
          (_Section.presets, l.editorTabPresets),
          (_Section.crop, l.editorTabCrop),
          (_Section.adjust, l.editorTabAdjust),
          (_Section.filter, l.editorTabFilter),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(name),
              selected: _section == s,
              showCheckmark: false,
              shape: const StadiumBorder(),
              onSelected: _saving ? null : (_) => _switchSection(s),
            ),
          ),
      ],
    ),
  );
}

/// Round labeled button as in Google Photos; a dot marks a changed adjustment.
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.changed,
    required this.onTap,
    this.onLongPress,
    this.image,
  });

  final String label;
  final IconData icon;

  /// A thumbnail instead of the icon (filters).
  final Uint8List? image;
  final bool selected, changed;
  final VoidCallback? onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // A thumbnail covers the fill, so a ring marks the choice.
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: CircleBorder(
                        side: selected && image != null
                            ? BorderSide(color: colors.primary, width: 3)
                            : BorderSide.none,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: selected
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      foregroundColor: selected
                          ? colors.onPrimary
                          : colors.onSurface,
                      foregroundImage: image == null
                          ? null
                          : MemoryImage(image!),
                      child: Icon(icon),
                    ),
                  ),
                  if (changed)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: colors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
