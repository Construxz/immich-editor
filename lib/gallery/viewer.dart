import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../editor/editor_page.dart';
import '../editor/preview.dart' show HdrImage, hasGainmap;
import '../hdr.dart';
import 'checksums.dart' show deviceIdWithChecksum;
import '../l10n/app_localizations.dart';
import '../photo.dart';
import '../server/immich.dart';
import '../theme.dart';
import 'device.dart';

/// One photo large: swipe to the next, zoom, switch within the stack, swipe up for the info;
/// "Bearbeiten" opens the editor, afterwards the result shows here (ROADMAP, viewer).
/// Sharing, albums, trash stay with the Immich app.
class ViewerPage extends StatefulWidget {
  const ViewerPage({
    super.key,
    required this.immich,
    required this.count,
    required this.entryAt,
    required this.start,
    this.more,
  });

  final Immich immich;
  final int count;
  final Future<Entry> Function(int) entryAt;
  final int start;

  /// Loads the next month when swiping past an end: older ones are appended, newer ones
  /// prepended (then [entryAt] counts from the new first). Returns how many came, 0 at the end.
  final Future<int> Function(bool older)? more;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final _pages = PageController(initialPage: widget.start);
  var _entries = <int, Future<Entry>>{};
  var _zoomed = false;
  late var _count = widget.count;
  var _loading = false;
  late var _current = widget.start; // only this page shows HDR (D-54)
  Timer? _rest; // HDR only once a page has rested a moment — fast swiping creates no view (D-63)

  /// Info below the photo, open across pages so photos can be compared (D-63).
  var _info = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nearEnd(widget.start));
  }

  /// Near an end, the neighbouring month comes in; newer ones shift the pages.
  Future<void> _nearEnd(int i) async {
    final more = widget.more;
    final older = i >= _count - 2;
    if (more == null || _loading || (!older && i > 1)) return;
    _loading = true;
    final n = await more(older);
    _loading = false;
    if (n == 0 || !mounted) return;
    setState(() {
      _count += n;
      if (!older) {
        _entries = {for (final e in _entries.entries) e.key + n: e.value};
      }
    });
    if (!older) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pages.jumpToPage(i + n),
      );
    }
  }

  @override
  void dispose() {
    _rest?.cancel();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _edit(int i, Entry e) async {
    final result = await Navigator.of(context).push<Entry>(
      MaterialPageRoute(
        builder: (_) =>
            EditorPage(immich: widget.immich, id: e.id, onDevice: e.onDevice),
      ),
    );
    // Back to the result: the new copy at this position.
    if (result != null && mounted) {
      setState(() {
        _entries[i] = Future.value(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: darkTheme,
    child: Scaffold(
      backgroundColor: Colors.black,
      // The HDR view (a real Android view) only while the pages rest: created mid-swipe it
      // stalls the page animation (D-54). -1: none while scrolling.
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth != 0) return false;
          if (n is ScrollStartNotification) {
            _rest?.cancel();
            if (_current != -1) setState(() => _current = -1);
          } else if (n is ScrollEndNotification) {
            _rest?.cancel();
            _rest = Timer(const Duration(milliseconds: 300), () {
              final page = _pages.page?.round();
              if (mounted && page != null && page != _current) {
                setState(() => _current = page);
              }
            });
          }
          return false;
        },
        child: PageView.builder(
          controller: _pages,
          physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
          itemCount: _count,
          onPageChanged: _nearEnd,
          itemBuilder: (context, i) => FutureBuilder(
            future: _entries[i] ??= widget.entryAt(i),
            builder: (context, s) {
              final e = s.data;
              if (e == null) return const SizedBox();
              return _Page(
                key: ValueKey(e),
                immich: widget.immich,
                entry: e,
                active: i == _current,
                info: _info,
                onInfo: (open) => setState(() => _info = open),
                onZoom: (z) {
                  if (z != _zoomed) setState(() => _zoomed = z);
                },
                onEdit: (shown) => _edit(i, shown),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// One page: date and version on top, the photo, below it the stack's thumbnails, the buttons
/// at the bottom — like Google Photos for long exposures (D-34).
class _Page extends StatefulWidget {
  const _Page({
    super.key,
    required this.immich,
    required this.entry,
    required this.active,
    required this.info,
    required this.onInfo,
    required this.onZoom,
    required this.onEdit,
  });

  final Immich immich;
  final Entry entry;

  /// The page on screen: only it lays the HDR image over (D-54).
  final bool active;

  /// Info open below the photo; [onInfo] opens or closes it for all pages.
  final bool info;
  final ValueChanged<bool> onInfo;
  final ValueChanged<bool> onZoom;
  final ValueChanged<Entry> onEdit;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final _zoom = TransformationController();
  late Future<PhotoStack> _stack = _load();
  late String _shown = widget.entry.id;
  AssetEntity? _deviceAsset;
  Future<Uint8List?>? _deviceImage;
  var _zoomed = false;

  final _hdrIds = <String, Future<String?>>{};

  /// The shown photo's ID on the device, if it lives here and carries a gain map — kept per
  /// photo so the native view isn't rebuilt. SDR photos get no native view (D-63).
  Future<String?> _hdrId(String? checksum) =>
      _hdrIds['$_shown/$checksum'] ??= () async {
        final id = widget.entry.onDevice
            ? _shown
            : checksum == null
            ? null
            : await deviceIdWithChecksum(checksum);
        return id != null && await hasGainmap(id) ? id : null;
      }();

  final _infos = <String, Future<PhotoInfo>>{};
  Future<PhotoInfo> get _photoInfo => _infos[_shown] ??= _entry.onDevice
      ? deviceInfo(_shown, widget.immich.placeAt)
      : widget.immich.info(_shown);

  Future<PhotoStack> _load() => widget.entry.onDevice
      ? Future.value((
          id: null,
          primary: widget.entry.id,
          photos: const <Photo>[],
        ))
      : widget.immich.stackOf(
          _shown,
        ); // after "Rest löschen" starting from the kept one

  @override
  void initState() {
    super.initState();
    if (widget.entry.onDevice) {
      _deviceImage = AssetEntity.fromId(widget.entry.id).then((a) {
        if (mounted) setState(() => _deviceAsset = a);
        return a?.thumbnailDataWithSize(const ThumbnailSize.square(1440));
      });
    }
    _zoom.addListener(() {
      final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
      widget.onZoom(zoomed);
      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  Entry get _entry => (id: _shown, onDevice: widget.entry.onDevice);

  Future<bool> _confirm(String title, String text, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(yes),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _act(PhotoStack s, String action, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      if (action == 'primary') {
        await widget.immich.setPrimary(s.id!, _shown);
      } else {
        final rest = [
          for (final f in s.photos)
            if (f.id != _shown) f.id,
        ];
        if (!await _confirm(
          l.viewerKeepTitle(name),
          l.viewerKeepText(rest.length),
          l.viewerDeleteRest,
        )) {
          return;
        }
        await widget.immich.trash(rest);
        await widget.immich.deleteStack(s.id!);
      }
      setState(() {
        _stack = _load();
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final image = widget.entry.onDevice
        ? FutureBuilder(
            future: _deviceImage,
            builder: (context, s) => s.data == null
                ? const Center(child: CircularProgressIndicator())
                : Image.memory(s.data!, fit: BoxFit.contain),
          )
        : Image.network(
            widget.immich.previewUri(_shown).toString(),
            key: ValueKey(_shown),
            headers: widget.immich.headers,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
    return FutureBuilder(
      future: _stack,
      builder: (context, s) {
        final stack = s.data;
        final photos = stack == null
            ? const <(Photo, String)>[]
            : _versions(stack, l.original);
        final shown = photos.where((f) => f.$1.id == _shown).firstOrNull;
        final time = widget.entry.onDevice
            ? _deviceAsset?.createDateTime
            : shown?.$1.localTime;
        return SafeArea(
          child: Column(
            children: [
              // Header: back, date and time, below it the version
              Row(
                children: [
                  const BackButton(),
                  Expanded(
                    child: Column(
                      children: [
                        if (time != null) ...[
                          Text(
                            DateFormat.yMMMd(l.localeName).format(time),
                            style: text.titleMedium,
                          ),
                          Text(
                            DateFormat.jm(l.localeName).format(time),
                            style: text.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              if (photos.length > 1 && shown != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chip(
                    avatar: Icon(
                      shown.$1.id == stack!.primary
                          ? Icons.star
                          : Icons.filter_none,
                      size: 18,
                    ),
                    label: Text(shown.$2),
                  ),
                ),
              Expanded(
                child: InteractiveViewer(
                  transformationController: _zoom,
                  maxScale: 8,
                  panEnabled: _zoom.value.getMaxScaleOnAxis() > 1.01,
                  // Swiping up shows the info, down hides it, as in Google Photos. The zoom
                  // catches the gesture, hence here instead of in a GestureDetector.
                  onInteractionEnd: (d) {
                    final dy = d.velocity.pixelsPerSecond.dy;
                    if (_zoom.value.getMaxScaleOnAxis() > 1.01) return;
                    if (dy < -300) widget.onInfo(true);
                    if (dy > 300) widget.onInfo(false);
                  },
                  child: SizedBox.expand(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image,
                        // HDR from the local original: device photos, or server photos that
                        // also live here (D-54). Server-only ones stay SDR — no download here.
                        if (widget.active && !_zoomed)
                          ValueListenableBuilder(
                            valueListenable: hdrOn,
                            builder: (context, on, _) => !on
                                ? const SizedBox()
                                : FutureBuilder(
                                    future: _hdrId(shown?.$1.checksum),
                                    builder: (context, s) => s.data == null
                                        ? const SizedBox()
                                        : HdrImage(
                                            key: ValueKey(s.data),
                                            id: s.data!,
                                          ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.info)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                  ),
                  child: SingleChildScrollView(child: _Info(_photoInfo)),
                ),
              if (photos.length > 1) _thumbnails(stack!, photos),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      tooltip: l.viewerInfo,
                      isSelected: widget.info,
                      onPressed: () => widget.onInfo(!widget.info),
                    ),
                    const HdrButton(),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.tune),
                      label: Text(l.viewerEdit),
                      onPressed: () => widget.onEdit(_entry),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The stack's thumbnails; the selected one carries ⋮ with the stack actions.
  Widget _thumbnails(PhotoStack stack, List<(Photo, String)> photos) =>
      SizedBox(
        height: 76,
        child: Center(
          child: ListView(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final (f, name) in photos)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Semantics(
                    label: name,
                    selected: f.id == _shown,
                    button: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _shown = f.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: f.id == _shown ? 96 : 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: f.id == _shown
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              widget.immich.thumbnailUri(f.id).toString(),
                              headers: widget.immich.headers,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                            ),
                            if (f.id == stack.primary)
                              const Positioned(
                                left: 4,
                                top: 4,
                                child: Icon(Icons.star, size: 16),
                              ),
                            if (f.id == _shown)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: PopupMenuButton<String>(
                                  tooltip: AppLocalizations.of(context)
                                      .viewerStack,
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (w) => _act(stack, w, name),
                                  itemBuilder: (_) => [
                                    if (f.id != stack.primary)
                                      PopupMenuItem(
                                        value: 'primary',
                                        child: Text(
                                          AppLocalizations.of(context)
                                              .viewerSetPrimary,
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 'keep',
                                      child: Text(
                                        AppLocalizations.of(context)
                                            .viewerKeepThis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// The stack in fixed order: the original, then the copies in order of creation as V1, V2 …
/// Copies from this app are recognized by name (`.edit`, see spec, *Speicherweg*).
// ponytail: recognized by name; the recipe XMP would be safer but costs one request per member.
List<(Photo, String)> _versions(PhotoStack stack, String original) {
  final originals = [
    for (final f in stack.photos)
      if (!f.fileName.contains('.edit')) f,
  ];
  final copies = [
    for (final f in stack.photos)
      if (f.fileName.contains('.edit')) f,
  ]..sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
  return [
    for (final f in originals) (f, original),
    for (final (i, f) in copies.indexed) (f, 'V${i + 1}'),
  ];
}

/// "Mo., 5. Mai 2026 · 14:03" in German.
String _date(DateTime d, String locale) =>
    '${DateFormat.yMMMEd(locale).format(d)} · ${DateFormat.jm(locale).format(d)}';

String _size(int bytes, String locale) => bytes >= 1 << 20
    ? '${NumberFormat('0.0', locale).format(bytes / (1 << 20))} MB'
    : '${(bytes / 1024).round()} KB';

/// The photo's info, as Google Photos shows it when swiping up — without a map.
class _Info extends StatelessWidget {
  const _Info(this.info);

  final Future<PhotoInfo> info;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: info,
    builder: (context, s) {
      if (s.hasError) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${s.error}'),
        );
      }
      final i = s.data;
      if (i == null) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final locale = AppLocalizations.of(context).localeName;
      final mp = i.width == null || i.height == null
          ? null
          : '${NumberFormat('0.0', locale).format(i.width! * i.height! / 1e6)} MP'
                ' · ${i.width} × ${i.height}';
      final details = [
        ?mp,
        if (i.bytes != null) _size(i.bytes!, locale),
      ].join(' · ');
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i.takenAt != null)
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(_date(i.takenAt!, locale)),
                ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(i.name),
                subtitle: details.isEmpty ? null : Text(details),
              ),
              if (i.camera != null || i.exposure != null)
                ListTile(
                  leading: const Icon(Icons.camera_outlined),
                  title: Text(i.camera ?? i.lens ?? ''),
                  subtitle: Text(
                    [if (i.camera != null) ?i.lens, ?i.exposure].join('\n'),
                  ),
                ),
              if (i.place != null)
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(i.place!),
                ),
            ],
          ),
        ),
      );
    },
  );
}
