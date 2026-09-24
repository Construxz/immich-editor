import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../editor/presets.dart';
import '../editor/preview.dart' show isMetered;
import '../editor/save.dart' show applyPreset;
import '../l10n/app_localizations.dart';
import '../hdr.dart';
import '../main.dart' show storage;
import '../photo.dart';
import '../server/immich.dart';
import '../settings.dart';
import '../stacking/stacking.dart';
import 'backup_state.dart';
import 'checksums.dart' show checksumProgress;
import 'device.dart';
import 'folders.dart';
import 'library_view.dart';
import 'tiles.dart';
import 'viewer.dart';

/// A month of the merged timeline: [key] "2026-05", [start] the server month (null if nothing
/// is there), [count] estimated (the server counts videos too), [local] the photos that live
/// only on the device.
typedef _Month = ({
  String key,
  String? start,
  int count,
  List<AssetEntity> local,
});

/// A tile of the merged timeline.
typedef _Item = ({
  Entry e,
  DateTime time,
  int stackSize,
  Presence presence,
  AssetEntity? local,
});

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// The gallery as in the Immich app (D-36): "Fotos" is one timeline across device and server,
/// merged by checksum, with clouds for the backup state; "Bibliothek" shows the device
/// folders. Settings can show device and server separately.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, required this.immich, required this.onLogout});

  final Immich immich;
  final VoidCallback onLogout;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late Future<List<Month>> _months = widget.immich.months();
  final _loaded = <String, Future<List<Tile>>>{};
  final _mergedLoaded = <String, Future<List<_Item>>>{};
  final _selection = <Entry>{};
  var _tab = 0;
  var _separate = false;
  var _photoFolders = defaultPhotoFolders;
  BackupState _backup = emptyBackupState;
  late Future<int?> _deviceCount = _countDevice();
  final _devicePages = <int, Future<List<AssetEntity>>>{};

  @override
  void initState() {
    super.initState();
    _readSettings();
    checksumProgress.addListener(_explain);
    _showStored();
    _checkBackup();
    _stackPending();
  }

  Future<void> _readSettings() async {
    // persisted: do not rename
    final separate = await storage.read(key: 'zusammen') == 'getrennt';
    final folders = await photoFolders();
    if (!mounted) return;
    if (separate != _separate) {
      setState(() {
        _separate = separate;
        _tab = 0;
      });
    }
    if (!setEquals(folders, _photoFolders)) {
      setState(() {
        _photoFolders = folders;
        _mergedLoaded.clear();
      });
    }
  }

  @override
  void dispose() {
    checksumProgress.removeListener(_explain);
    super.dispose();
  }

  /// When the checksum pass starts, a dialog explains it — once per installation.
  Future<void> _explain() async {
    if (checksumProgress.value == null) return;
    checksumProgress.removeListener(_explain);
    if (await storage.read(key: 'checksumsExplained') == 'yes' || !mounted) {
      return;
    }
    await storage.write(key: 'checksumsExplained', value: 'yes');
    if (mounted) await explainChecksums(context);
  }

  /// Which device photos are already backed up; the first time this computes all checksums.
  /// The last check's device photos at once; the fresh check replaces them (D-51).
  Future<void> _showStored() async {
    final stored = await storedBackup();
    if (!mounted || !identical(_backup, emptyBackupState)) return;
    setState(() {
      _backup = stored;
      _mergedLoaded.clear();
    });
  }

  Future<void> _checkBackup() async {
    try {
      final backup = await checkBackup(widget.immich);
      if (!mounted) return;
      setState(() {
        _backup = backup;
        _mergedLoaded.clear();
      });
    } catch (e) {
      debugPrint('Backup check later: $e'); // e.g. offline
    }
  }

  /// Stack copies saved on the device as soon as the Immich app has backed them up.
  Future<void> _stackPending() async {
    try {
      await stackPending(widget.immich);
    } catch (e) {
      debugPrint('Stacking later: $e');
    }
  }

  /// Number of device photos, or null without permission.
  static Future<int?> _countDevice() async =>
      await devicePermitted() ? await deviceCount() : null;

  Future<void> _reload() async {
    setState(() {
      _loaded.clear();
      _mergedLoaded.clear();
      _months = widget.immich.months();
      _devicePages.clear();
      _deviceCount = _countDevice();
    });
    await Future.wait([
      _months,
      _deviceCount,
      _stackPending(),
      _checkBackup(),
      _readSettings(),
    ]);
  }

  Future<List<Tile>> _month(String start) =>
      _loaded[start] ??= widget.immich.month(start);

  static const _pageSize = 120; // device photos per request

  Future<List<AssetEntity>> _devicePage(int i) =>
      _devicePages[i ~/ _pageSize] ??= devicePhotos(
        i ~/ _pageSize * _pageSize,
        (i ~/ _pageSize + 1) * _pageSize,
      );

  /// Opens the viewer at [start]; reload afterwards, there may be something new.
  // ponytail: server photos only within their month; swipe across months if that is missed.
  Future<void> _open(
    int count,
    Future<Entry> Function(int) entryAt,
    int start, {
    Future<int> Function(bool older)? more,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerPage(
          immich: widget.immich,
          count: count,
          entryAt: entryAt,
          start: start,
          more: more,
        ),
      ),
    );
    await _reload();
  }

  /// Opens the viewer at [start] in [first], the photos of month [month] of [months] (newest
  /// first); swiping past an end loads the neighbouring month through [monthAt].
  Future<void> _openAcross(
    List<Entry> first,
    int start,
    int month,
    int months,
    Future<List<Entry>> Function(int month) monthAt,
  ) {
    final all = [...first];
    var newest = month, oldest = month;
    Future<int> more(bool older) async {
      while (true) {
        final next = older ? oldest + 1 : newest - 1;
        if (next < 0 || next >= months) return 0;
        final got = await monthAt(next);
        if (older) {
          oldest = next;
          all.addAll(got);
        } else {
          newest = next;
          all.insertAll(0, got);
        }
        // A month of only videos: on to the next.
        if (got.isNotEmpty) return got.length;
      }
    }

    return _open(all.length, (j) async => all[j], start, more: more);
  }

  void _toggle(Entry e) => setState(
    () => _selection.contains(e) ? _selection.remove(e) : _selection.add(e),
  );

  /// Pick a preset and apply it to the selection; every photo gets a copy as from the editor
  /// (spec, *Presets*).
  Future<void> _applyPreset() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final presets = await readPresets();
    if (!mounted) return;
    if (presets.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.galleryNoPresets)));
      return;
    }
    final preset = await showModalBottomSheet<Preset>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                l.galleryApplyPresetTo(_selection.length),
                style: Theme.of(c).textTheme.titleMedium,
              ),
            ),
            for (final p in presets)
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(p.name),
                onTap: () => Navigator.pop(c, p),
              ),
          ],
        ),
      ),
    );
    if (preset == null || !mounted) return;
    // Load originals from the server: per the "Mobile Daten" setting only on Wi-Fi (D-30).
    if (_selection.any((e) => !e.onDevice) &&
        await storage.read(key: 'mobil') == 'aus' && // persisted: do not rename
        await isMetered()) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.useMobileDataTitle),
          content: Text(l.galleryMobileDataOriginals),
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
      if (proceed != true) return;
    }
    if (!mounted) return;
    final photos = _selection.toList();
    final progress = ValueNotifier(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l.galleryApplyingPreset(preset.name)),
          content: ValueListenableBuilder(
            valueListenable: progress,
            builder: (c, n, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                LinearProgressIndicator(value: n / photos.length),
                Text(l.galleryProgress(n, photos.length)),
              ],
            ),
          ),
        ),
      ),
    );
    final errors = await applyPreset(
      widget.immich,
      photos,
      preset,
      onDone: (n) => progress.value = n,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    setState(_selection.clear);
    final ok = photos.length - errors.length;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          errors.isEmpty
              ? l.galleryCopiesSaved(ok)
              : l.galleryCopiesSavedFailed(
                  ok,
                  errors.length,
                  '${errors.first}',
                ),
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final selecting = _selection.isNotEmpty;
    final l = AppLocalizations.of(context);
    final tabs = _separate
        ? [
            (Icons.phone_android, l.galleryTabDevice, _deviceView),
            (Icons.cloud_outlined, 'Immich', _serverView),
            (Icons.photo_library_outlined, l.galleryTabLibrary, _library),
          ]
        : [
            (Icons.photo_outlined, l.galleryTabPhotos, _mergedView),
            (Icons.photo_library_outlined, l.galleryTabLibrary, _library),
          ];
    final active = _tab.clamp(0, tabs.length - 1);
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selection.clear);
      },
      child: Scaffold(
        appBar: selecting ? _selectionBar() : _appBar(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: active,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            for (final (icon, name, _) in tabs)
              NavigationDestination(icon: Icon(icon), label: name),
          ],
        ),
        body: tabs[active].$3(),
      ),
    );
  }

  Widget _library() => LibraryView(immich: widget.immich, backup: _backup);

  AppBar _appBar() {
    return AppBar(
      centerTitle: false, // like Immich's timeline: name left, avatar right
      title: const Text('Editor for Immich'),
      actions: [
        const HdrButton(),
        // The checksum pass is shown by the avatar (ring) and the account dialog.
        AccountButton(
          immich: widget.immich,
          onLogout: widget.onLogout,
          onSettings: _reload,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  AppBar _selectionBar() {
    final l = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l.galleryEndSelection,
        onPressed: () => setState(_selection.clear),
      ),
      title: Text(l.gallerySelected(_selection.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_awesome),
          tooltip: l.galleryApplyPreset,
          onPressed: _applyPreset,
        ),
      ],
    );
  }

  Widget _monthHeader(DateTime date) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        DateFormat.yMMMM(AppLocalizations.of(context).localeName).format(date),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
  );

  // — Merged timeline —

  List<_Month> _mergedMonths(List<Month> server) {
    final local = <String, List<AssetEntity>>{};
    // From the device only the chosen folders, like the camera in Google Photos (D-48).
    for (final a in _backup.deviceOnly.where(
      (a) => _photoFolders.contains(a.relativePath),
    )) {
      (local[_monthKey(a.createDateTime)] ??= []).add(a);
    }
    final months = <String, _Month>{
      for (final m in server)
        m.start.substring(0, 7): (
          key: m.start.substring(0, 7),
          start: m.start,
          count: m.count,
          local: const [],
        ),
    };
    local.forEach((k, photos) {
      final m = months[k];
      months[k] = (
        key: k,
        start: m?.start,
        count: (m?.count ?? 0) + photos.length,
        local: photos,
      );
    });
    return months.values.toList()..sort((a, b) => b.key.compareTo(a.key));
  }

  Future<List<_Item>> _mergedMonth(_Month m) =>
      _mergedLoaded[m.key] ??= () async {
        final server = m.start == null
            ? const <Tile>[]
            : await _month(m.start!);
        return <_Item>[
          for (final k in server)
            (
              e: (id: k.id, onDevice: false),
              time: k.time,
              stackSize: k.stackSize,
              presence: _backup.serverOnDevice.contains(k.id)
                  ? Presence.both
                  : Presence.server,
              local: null,
            ),
          for (final a in m.local)
            (
              e: (id: a.id, onDevice: true),
              time: a.createDateTime,
              stackSize: 1,
              presence: Presence.device,
              local: a,
            ),
        ]..sort((a, b) => b.time.compareTo(a.time));
      }();

  Widget _mergedView() => FutureBuilder(
    future: _months,
    builder: (context, s) {
      if (s.hasError) return _ErrorView('${s.error}', _reload);
      final server = s.data;
      if (server == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final months = _mergedMonths(server);
      if (months.isEmpty) {
        return Center(
          child: Text(AppLocalizations.of(context).galleryNoPhotos),
        );
      }
      return RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            for (final (k, m) in months.indexed) ...[
              _monthHeader(DateTime.parse('${m.key}-01')),
              SliverGrid.builder(
                gridDelegate: tileGrid,
                itemCount: m.count,
                itemBuilder: (context, i) => FutureBuilder(
                  future: _mergedMonth(m),
                  builder: (context, s) {
                    final items = s.data;
                    if (items == null) {
                      return ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      );
                    }
                    // The server counts videos in the month, they are not shown
                    if (i >= items.length) return const SizedBox();
                    final z = items[i];
                    return PhotoTile(
                      key: ValueKey(z.e),
                      image: z.local != null
                          ? DeviceThumbnail(z.local!)
                          : ServerThumbnail(widget.immich, z.e.id),
                      stackSize: z.stackSize,
                      presence: z.presence,
                      selected: _selection.contains(z.e),
                      selecting: _selection.isNotEmpty,
                      onTap: () => _selection.isEmpty
                          ? _openAcross(
                              [for (final z in items) z.e],
                              i,
                              k,
                              months.length,
                              (n) async => [
                                for (final z in await _mergedMonth(months[n]))
                                  z.e,
                              ],
                            )
                          : _toggle(z.e),
                      onLongPress: () => _toggle(z.e),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  // — Separate view (setting) —

  Widget _deviceView() => FutureBuilder(
    future: _deviceCount,
    builder: (context, s) {
      if (s.hasError) return _ErrorView('${s.error}', _reload);
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final count = s.data;
      if (count == null) {
        return _ErrorView(
          AppLocalizations.of(context).galleryNoDevicePermission,
          () async {
            await PhotoManager.openSetting();
            await _reload();
          },
        );
      }
      if (count == 0) {
        return Center(
          child: Text(AppLocalizations.of(context).galleryNoDevicePhotos),
        );
      }
      return RefreshIndicator(
        onRefresh: _reload,
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: tileGrid,
          itemCount: count,
          itemBuilder: (context, i) => FutureBuilder(
            future: _devicePage(i),
            builder: (context, s) {
              final photos = s.data;
              if (photos == null || i % _pageSize >= photos.length) {
                return ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                );
              }
              final a = photos[i % _pageSize];
              return PhotoTile(
                key: ValueKey(a.id),
                image: DeviceThumbnail(a),
                stackSize: 1,
                presence: _backup.deviceBackedUp.contains(a.id)
                    ? Presence.both
                    : Presence.device,
                selected: _selection.contains((id: a.id, onDevice: true)),
                selecting: _selection.isNotEmpty,
                onTap: () => _selection.isEmpty
                    ? _open(
                        count,
                        (j) async => (
                          id: (await _devicePage(j))[j % _pageSize].id,
                          onDevice: true,
                        ),
                        i,
                      )
                    : _toggle((id: a.id, onDevice: true)),
                onLongPress: () => _toggle((id: a.id, onDevice: true)),
              );
            },
          ),
        ),
      );
    },
  );

  Widget _serverView() => FutureBuilder(
    future: _months,
    builder: (context, s) {
      if (s.hasError) return _ErrorView('${s.error}', _reload);
      final months = s.data;
      if (months == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (months.isEmpty) {
        return Center(
          child: Text(AppLocalizations.of(context).galleryNoServerPhotos),
        );
      }
      return RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            for (final (month, m) in months.indexed) ...[
              _monthHeader(DateTime.parse(m.start)),
              SliverGrid.builder(
                gridDelegate: tileGrid,
                itemCount: m.count,
                itemBuilder: (context, i) => FutureBuilder(
                  future: _month(m.start),
                  builder: (context, s) {
                    final tiles = s.data;
                    if (tiles == null) {
                      return ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      );
                    }
                    if (i >= tiles.length) return const SizedBox();
                    final k = tiles[i];
                    return PhotoTile(
                      image: ServerThumbnail(widget.immich, k.id),
                      stackSize: k.stackSize,
                      presence: _backup.serverOnDevice.contains(k.id)
                          ? Presence.both
                          : Presence.server,
                      selected: _selection.contains((
                        id: k.id,
                        onDevice: false,
                      )),
                      selecting: _selection.isNotEmpty,
                      onTap: () => _selection.isEmpty
                          ? _openAcross(
                              [
                                for (final t in tiles)
                                  (id: t.id, onDevice: false),
                              ],
                              i,
                              month,
                              months.length,
                              (n) async => [
                                for (final t in await _month(months[n].start))
                                  (id: t.id, onDevice: false),
                              ],
                            )
                          : _toggle((id: k.id, onDevice: false)),
                      onLongPress: () => _toggle((id: k.id, onDevice: false)),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView(this.text, this.onRetry);

  final String text;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).galleryRetry),
          ),
        ],
      ),
    ),
  );
}
