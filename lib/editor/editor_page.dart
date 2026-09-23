import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../photo.dart';
import '../gallery/backup_state.dart' show folderBackedUp;
import '../main.dart' show storage;
import '../server/immich.dart';
import '../theme.dart';
import 'ruler.dart';
import 'presets.dart';
import 'recipe.dart';
import 'save.dart';
import 'preview.dart';
import 'crop.dart';

enum _Section { presets, crop, adjust }

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
  var _hdr = true;
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
    () async {
      try {
        final hdr = await storage.read(key: 'hdr') != 'aus';
        // Online photos per setting, default device (D-25).
        final toDevice =
            widget.onDevice || await storage.read(key: 'online') != 'server';
        final immich = widget.immich;
        // From the server first details and head — the original loads in the background, the
        // editor starts with Immich's preview image (D-29). A copy opens its original with its recipe.
        final (:photo, :bytes, :oldCopy, :start) = await loadPhoto(
          immich,
          widget.id,
          onDevice: widget.onDevice,
        );
        final presets = await readPresets();
        final original = widget.onDevice ? bytes : null;
        final wifiOnly = await storage.read(key: 'mobil') == 'aus';
        final loaded = await loadOriginal(
          original ?? await immich.preview(photo.id),
          hdr: hdr,
          recipe: start,
        );
        if (!mounted) return;
        setState(() {
          _photo = photo;
          _oldCopy = oldCopy;
          _history = [start];
          _recipe = start;
          _original = original;
          _ready = true;
          _hdr = hdr;
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
    final loaded = await loadOriginal(original, hdr: _hdr, recipe: _shown);
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
  }

  void _toggleHdr() {
    setState(() => _hdr = !_hdr);
    showHdr(_hdr);
    // persisted: do not rename
    storage.write(key: 'hdr', value: _hdr ? 'an' : 'aus');
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
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Änderungen verwerfen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Verwerfen'),
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
    // Editing a copy: replace it (the old one goes to the trash) or put the new one beside it.
    var replace = false;
    if (_oldCopy != null) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Speichern'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, true),
              child: const ListTile(
                leading: Icon(Icons.save),
                title: Text('Kopie ersetzen'),
                subtitle: Text(
                  'Die bisherige Bearbeitung geht in den Papierkorb',
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, false),
              child: const ListTile(
                leading: Icon(Icons.library_add),
                title: Text('Als weitere Kopie speichern'),
                subtitle: Text('Beide Bearbeitungen liegen im Stapel'),
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
          title: const Text('Mobile Daten verwenden?'),
          content: const Text(
            'Zum Speichern muss das Original geladen oder die Kopie hochgeladen '
            'werden — laut Einstellung nur im WLAN.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Trotzdem'),
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
      _step = 'Wird gerendert …';
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final immich = widget.immich;
    final photo = _photo!;
    try {
      if (_original == null) {
        setState(() => _step = 'Original wird geladen …');
      }
      final (:entry, :copy) = await saveCopy(
        immich,
        photo: photo,
        original: await _originalReady!,
        recipe: _recipe,
        hdr: _hdr,
        toDevice: _toDevice,
        onDevice: widget.onDevice,
        oldCopy: _oldCopy,
        replace: replace,
        onStep: (s) => setState(() => _step = s),
      );
      if (!entry.onDevice) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Gespeichert und geprüft')),
        );
        navigator.pop(entry);
        return;
      }
      // A folder the Immich app does not back up: on request upload archived and open in
      // the Immich app (D-36).
      if (widget.onDevice && photo.folder != null) {
        setState(() => _step = 'Wird geprüft …');
        final backedUp = await folderBackedUp(
          immich,
          photo.folder!,
        ).catchError((_) => true); // don't ask without network
        if (!backedUp && mounted && await _askOpenInImmich(photo.folder!)) {
          await _openInImmich(copy, photo, messenger);
          navigator.pop(entry);
          return;
        }
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Auf dem Gerät gespeichert — gestapelt wird nach dem Backup',
          ),
        ),
      );
      navigator.pop(entry);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
      setState(() => _saving = false);
    }
  }

  /// Name of the album that edits from folders without backup go into.
  static const _album = 'Editor for Immich';

  Future<bool> _askOpenInImmich(String folder) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Bearbeitung in Immich öffnen?'),
          content: Text(
            'Der Ordner „${folder.replaceAll(RegExp(r'/$'), '')}" wird nicht in Immich '
            'gesichert. Die Bearbeitung archiviert hochladen — nicht in der '
            'Zeitleiste —, ins Album „$_album" legen und in der Immich-App öffnen? '
            'Dort kannst du sie in ein anderes Album legen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Nur auf dem Gerät'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('In Immich öffnen'),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _openInImmich(
    Uint8List copy,
    Photo photo,
    ScaffoldMessengerState messenger,
  ) async {
    final immich = widget.immich;
    setState(() => _step = 'Wird hochgeladen …');
    final id = await immich.upload(
      copy,
      photo.fileName.replaceFirst(RegExp(r'(\.[^.]*)?$'), '.edit.jpg'),
      photo.takenAt,
      archived: true,
    );
    if ((await immich.photo(id)).checksum != await sha1(copy)) {
      throw Exception('Kopie auf dem Server weicht ab ($id)');
    }
    await immich.addToAlbum(await immich.album(_album), [id]);
    final opened = await openUrl('immich://asset?id=$id');
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Archiviert in Immich, Album „$_album"'
              : 'Archiviert in Immich, Album „$_album" — die Immich-App fehlt',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Black as in Google Photos: stays black on OLED, even when HDR turns the panel up.
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
                      _topBar(),
                      if (_section == _Section.crop) _cropButtons(),
                      Expanded(child: _imageArea()),
                      _tools(),
                      _tabs(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Schließen',
          onPressed: _saving ? null : _close,
        ),
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Rückgängig',
          onPressed: _position > 0 && !_saving
              ? () => _jump(_position - 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          tooltip: 'Wiederholen',
          onPressed: _position < _history.length - 1 && !_saving
              ? () => _jump(_position + 1)
              : null,
        ),
        const Spacer(),
        if (_hasGainmap)
          IconButton(
            icon: Icon(_hdr ? Icons.hdr_on : Icons.hdr_off),
            tooltip: _hdr ? 'HDR an' : 'HDR aus',
            onPressed: _saving ? null : _toggleHdr,
          ),
        FilledButton(
          onPressed: _saving || !_changed || _recipe.isNeutral ? null : _save,
          child: const Text('Speichern'),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mehr',
          enabled: !_saving,
          onSelected: (v) {
            if (v == 'hdr') _toggleHdr();
            if (v == 'reset') {
              _ratio = null;
              _change(const Recipe());
            }
            if (v == 'saved') _change(_start);
          },
          itemBuilder: (_) => [
            if (_hasGainmap)
              CheckedPopupMenuItem(
                value: 'hdr',
                checked: _hdr,
                child: const Text('HDR'),
              ),
            const PopupMenuItem(
              value: 'reset',
              child: Text('Alles zurücksetzen'),
            ),
            if (_oldCopy != null)
              const PopupMenuItem(
                value: 'saved',
                child: Text('Zur gespeicherten Bearbeitung'),
              ),
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

  Widget _cropButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      PopupMenuButton<double>(
        icon: const Icon(Icons.aspect_ratio),
        tooltip: 'Seitenverhältnis',
        onSelected: (v) {
          _ratio = v == 0 ? null : v;
          _change(_recipe.copyWith(crop: _crop(_ratio, _recipe.quarterTurns)));
        },
        itemBuilder: (_) => [
          for (final (name, v) in [
            ('Frei', 0.0),
            ('Original', _frame),
            ('Quadrat', 1.0),
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
        tooltip: 'Spiegeln',
        onPressed: () => _change(_recipe.copyWith(flip: !_recipe.flip)),
      ),
      IconButton(
        icon: const Icon(Icons.rotate_90_degrees_ccw),
        tooltip: 'Drehen',
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
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Als Preset sichern'),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (t) => Navigator.pop(c, t),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, field.text),
            child: const Text('Sichern'),
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
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Preset „${preset.name}" löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Löschen'),
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

  Widget _tools() {
    if (_section == _Section.presets) {
      // ponytail: names instead of thumbnails (spec); the renderer computes those only one at a time.
      final own = presetFrom('', _recipe).adjustments;
      return SizedBox(
        height: 96,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            _ToolButton(
              tool: (key: '', name: 'Sichern', icon: Icons.add),
              selected: false,
              changed: false,
              onTap: own.isEmpty ? null : _savePreset,
            ),
            for (final p in _presets)
              _ToolButton(
                tool: (key: p.name, name: p.name, icon: Icons.auto_awesome),
                selected: mapEquals(p.adjustments, own),
                changed: false,
                onTap: () => _change(withPreset(_recipe, p)),
                onLongPress: () => _deletePreset(p),
              ),
          ],
        ),
      );
    }
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
                  tool: t,
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

  Widget _tabs() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (s, name) in [
          (_Section.presets, 'Presets'),
          (_Section.crop, 'Zuschneiden'),
          (_Section.adjust, 'Anpassen'),
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
    required this.tool,
    required this.selected,
    required this.changed,
    required this.onTap,
    this.onLongPress,
  });

  final Tool tool;
  final bool selected, changed;
  final VoidCallback? onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
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
                CircleAvatar(
                  radius: 26,
                  backgroundColor: selected
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  foregroundColor: selected
                      ? colors.onPrimary
                      : colors.onSurface,
                  child: Icon(tool.icon),
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
              tool.name,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
