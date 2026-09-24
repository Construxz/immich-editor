import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../l10n/app_localizations.dart';
import '../main.dart' show storage;
import 'checksums.dart' show lastListed;
import 'device.dart';

/// Which device folders show under "Fotos" — by default the camera, like Google Photos (D-48) —
/// and how the library shows them: pinned first, then the user's order, then the rest by newest
/// photo or by name; hidden ones not at all (D-59). Folders are their relative path, e.g.
/// "DCIM/Camera/".
const _photosKey = 'photoFolders'; // persisted: do not rename
const _hiddenKey = 'hiddenFolders'; // persisted: do not rename
const _pinnedKey = 'pinnedFolders'; // persisted: do not rename
const _orderKey = 'folderOrder'; // persisted: do not rename
const _sortKey = 'folderSort'; // persisted: do not rename ('name' or newest)
const defaultPhotoFolders = {'DCIM/Camera/'};

Future<List<String>> _readList(String key, List<String> fallback) async {
  final v = await storage.read(key: key);
  return v == null
      ? [...fallback]
      : [for (final f in jsonDecode(v)) f as String];
}

Future<Set<String>> _read(String key, Set<String> fallback) async =>
    (await _readList(key, [...fallback])).toSet();

Future<void> _write(String key, Iterable<String> folders) =>
    storage.write(key: key, value: jsonEncode([...folders]));

Future<Set<String>> photoFolders() => _read(_photosKey, defaultPhotoFolders);
Future<Set<String>> hiddenFolders() => _read(_hiddenKey, const {});

/// The library's order (D-59): pinned first, then the arranged ones — both as in [order] —,
/// then the rest [byName] or as in [newestFirst] (all paths, the newest photo first).
List<String> arrangeFolders(
  List<String> newestFirst,
  Map<String, String> names, {
  List<String> order = const [],
  Set<String> pinned = const {},
  bool byName = false,
}) {
  final known = newestFirst.toSet();
  final arranged = [
    for (final p in order)
      if (known.contains(p)) p,
  ];
  final rest = [
    for (final p in newestFirst)
      if (!arranged.contains(p)) p,
  ];
  if (byName) {
    rest.sort(
      (a, b) => (names[a] ?? a).toLowerCase().compareTo(
        (names[b] ?? b).toLowerCase(),
      ),
    );
  }
  final all = [...arranged, ...rest];
  return [
    ...all.where(pinned.contains),
    ...all.where((p) => !pinned.contains(p)),
  ];
}

/// The arranged part after moving [from] to [to] in [shown] (the list as displayed): everything
/// down to the moved folder — and down to anything in [keep] (arranged or pinned) — keeps its
/// place.
List<String> orderAfterMove(
  List<String> shown,
  int from,
  int to,
  Set<String> keep,
) {
  final moved = [...shown];
  final p = moved.removeAt(from);
  moved.insert(to, p);
  var last = to;
  for (final (i, q) in moved.indexed) {
    if (keep.contains(q) && i > last) last = i;
  }
  return moved.take(last + 1).toList();
}

/// The device folders with their paths, newest photo first (as the Immich app sorts "on this
/// device", `SortLocalAlbumsBy.newestAsset`, v3.2.2, D-52). Newest from the list of all photos
/// (newest first, as the timeline has it); a folder's first photo from photo_manager is not
/// reliably its newest, but it gives the path.
Future<List<(AssetPathEntity, String)>> _byNewest() async {
  final all = lastListed.isNotEmpty
      ? lastListed
      : await devicePhotos(0, await deviceCount());
  final newest = <String, int>{};
  for (final (i, a) in all.indexed) {
    newest.putIfAbsent(a.relativePath ?? '', () => i);
  }
  final found = <(AssetPathEntity, String)>[];
  for (final f in await deviceFolders()) {
    final path = (await f.getAssetListRange(
      start: 0,
      end: 1,
    )).firstOrNull?.relativePath;
    if (path != null) found.add((f, path));
  }
  int rank((AssetPathEntity, String) f) => newest[f.$2] ?? all.length;
  return found..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// The device folders in the library's order, with their paths (hidden ones included).
Future<List<(AssetPathEntity, String)>> foldersWithPaths() async {
  final found = await _byNewest();
  final byPath = {for (final (f, p) in found) p: f};
  final order = arrangeFolders(
    [for (final (_, p) in found) p],
    {for (final (f, p) in found) p: f.name},
    order: await _readList(_orderKey, const []),
    pinned: await _read(_pinnedKey, const {}),
    byName: await storage.read(key: _sortKey) == 'name',
  );
  return [for (final p in order) (byPath[p]!, p)];
}

/// Settings → device folders: which ones show under "Fotos"; for the library a list to hide,
/// pin and drag into order, and how the rest is sorted (D-59).
class FolderSettings extends StatefulWidget {
  const FolderSettings({super.key});

  @override
  State<FolderSettings> createState() => _FolderSettingsState();
}

class _FolderSettingsState extends State<FolderSettings> {
  List<(AssetPathEntity, String)>? _folders;
  var _inPhotos = <String>{}, _hidden = <String>{}, _pinned = <String>{};
  var _order = <String>[];
  var _byName = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folders = await foldersWithPaths();
    final inPhotos = await photoFolders();
    final hidden = await hiddenFolders();
    final pinned = await _read(_pinnedKey, const {});
    final order = await _readList(_orderKey, const []);
    final byName = await storage.read(key: _sortKey) == 'name';
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _inPhotos = inPhotos;
      _hidden = hidden;
      _pinned = pinned;
      _order = order;
      _byName = byName;
    });
  }

  Future<void> _reorder(int from, int to) async {
    final shown = [for (final (_, p) in _folders!) p];
    final order = orderAfterMove(shown, from, to, {..._order, ..._pinned});
    await _write(_orderKey, order);
    _order = order;
    await _load();
  }

  Future<void> _togglePin(String path) async {
    _pinned.contains(path) ? _pinned.remove(path) : _pinned.add(path);
    await _write(_pinnedKey, _pinned);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final folders = _folders;
    if (folders == null) {
      return const Center(child: CircularProgressIndicator());
    }
    Widget header(String title, String hint) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(title, style: text.titleSmall),
          Text(hint, style: text.bodyMedium),
        ],
      ),
    );
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: header(l.foldersInPhotos, l.foldersInPhotosHint),
        ),
        SliverList.list(
          children: [
            for (final (f, p) in folders)
              CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(f.name),
                subtitle: Text(p),
                value: _inPhotos.contains(p),
                onChanged: (on) {
                  setState(() {
                    on == true ? _inPhotos.add(p) : _inPhotos.remove(p);
                  });
                  _write(_photosKey, _inPhotos);
                },
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: header(l.foldersLibrary, l.foldersLibraryHint),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.foldersRestNewest)),
                ButtonSegment(value: true, label: Text(l.foldersRestName)),
              ],
              selected: {_byName},
              onSelectionChanged: (s) async {
                await storage.write(
                  key: _sortKey,
                  value: s.first ? 'name' : 'newest',
                );
                await _load();
              },
            ),
          ),
        ),
        SliverReorderableList(
          itemCount: folders.length,
          onReorderItem: _reorder,
          // Where it lands: the gap in the list; the dragged row carries a frame in the accent
          // colour.
          proxyDecorator: (child, _, _) => Material(
            elevation: 4,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: colors.primary, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
          itemBuilder: (context, i) {
            final (f, p) = folders[i];
            final hidden = _hidden.contains(p);
            final pinned = _pinned.contains(p);
            return Material(
              key: ValueKey(p),
              color: Colors.transparent,
              child: Opacity(
                opacity: hidden ? 0.4 : 1,
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 8, right: 4),
                  leading: IconButton(
                    tooltip: hidden ? l.foldersShow : l.foldersHide,
                    icon: Icon(
                      hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        hidden ? _hidden.remove(p) : _hidden.add(p);
                      });
                      _write(_hiddenKey, _hidden);
                    },
                  ),
                  title: Text(f.name),
                  subtitle: Text(p),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: pinned ? l.foldersUnpin : l.foldersPin,
                        isSelected: pinned,
                        icon: const Icon(Icons.push_pin_outlined),
                        selectedIcon: Icon(
                          Icons.push_pin,
                          color: colors.primary,
                        ),
                        onPressed: () => _togglePin(p),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.drag_handle,
                            semanticLabel: l.foldersMove,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}
