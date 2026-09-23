import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../l10n/app_localizations.dart';
import '../photo.dart' show Presence;
import '../server/immich.dart';
import 'backup_state.dart';
import 'device.dart';
import 'tiles.dart';
import 'viewer.dart';

/// The "Bibliothek" tab as in the Immich app: "Auf diesem Gerät" with all folders — including
/// those the Immich app does not back up (D-36).
class LibraryView extends StatefulWidget {
  const LibraryView({super.key, required this.immich, required this.backup});

  final Immich immich;
  final BackupState backup;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  late Future<List<AssetPathEntity>> _folders = deviceFolders();

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      setState(() {
        _folders = deviceFolders();
      });
      await _folders;
    },
    child: FutureBuilder(
      future: _folders,
      builder: (context, s) {
        final folders = s.data;
        if (folders == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                AppLocalizations.of(context).libraryOnDevice,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final o in folders)
              _FolderRow(
                key: ValueKey(o.id),
                folder: o,
                immich: widget.immich,
                backup: widget.backup,
              ),
          ],
        );
      },
    ),
  );
}

/// One folder: first photo, name, count and how much of it is backed up.
class _FolderRow extends StatefulWidget {
  const _FolderRow({
    super.key,
    required this.folder,
    required this.immich,
    required this.backup,
  });

  final AssetPathEntity folder;
  final Immich immich;
  final BackupState backup;

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  late final Future<List<AssetEntity>> _photos = widget.folder.assetCountAsync
      .then(
        (n) => n == 0 ? [] : widget.folder.getAssetListRange(start: 0, end: n),
      );
  late final Future<Uint8List?> _cover = _photos.then(
    (f) => f.isEmpty
        ? null
        : f.first.thumbnailDataWithSize(const ThumbnailSize.square(160)),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _photos,
    builder: (context, s) {
      final photos = s.data ?? const [];
      final backedUp = photos
          .where((a) => widget.backup.deviceBackedUp.contains(a.id))
          .length;
      return ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: 56,
            child: FutureBuilder(
              future: _cover,
              builder: (context, b) => b.data == null
                  ? ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                    )
                  : Image.memory(b.data!, fit: BoxFit.cover),
            ),
          ),
        ),
        title: Text(widget.folder.name),
        subtitle: s.data == null
            ? null
            : Text(
                backedUp == 0
                    ? AppLocalizations.of(context)
                          .libraryNotInImmich(photos.length)
                    : backedUp == photos.length
                    ? AppLocalizations.of(context)
                          .libraryBackedUp(photos.length)
                    : AppLocalizations.of(context)
                          .libraryPartlyBackedUp(photos.length, backedUp),
              ),
        trailing: Icon(
          backedUp == 0 ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
          size: 20,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FolderPage(
              folder: widget.folder,
              immich: widget.immich,
              backup: widget.backup,
            ),
          ),
        ),
      );
    },
  );
}

/// The photos of a device folder; tapping opens the viewer.
class FolderPage extends StatefulWidget {
  const FolderPage({
    super.key,
    required this.folder,
    required this.immich,
    required this.backup,
  });

  final AssetPathEntity folder;
  final Immich immich;
  final BackupState backup;

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  late Future<List<AssetEntity>> _photos = _load();

  Future<List<AssetEntity>> _load() async {
    final n = await widget.folder.fetchPathProperties().then(
      (p) => (p ?? widget.folder).assetCountAsync,
    );
    return n == 0 ? [] : widget.folder.getAssetListRange(start: 0, end: n);
  }

  Future<void> _open(List<AssetEntity> photos, int i) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerPage(
          immich: widget.immich,
          count: photos.length,
          entryAt: (j) async => (id: photos[j].id, onDevice: true),
          start: i,
        ),
      ),
    );
    // A copy may have been added.
    if (mounted) {
      setState(() {
        _photos = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(centerTitle: false, title: Text(widget.folder.name)),
    body: FutureBuilder(
      future: _photos,
      builder: (context, s) {
        final photos = s.data;
        if (photos == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return GridView.builder(
          gridDelegate: tileGrid,
          itemCount: photos.length,
          itemBuilder: (context, i) => PhotoTile(
            key: ValueKey(photos[i].id),
            image: DeviceThumbnail(photos[i]),
            stackSize: 1,
            presence: widget.backup.deviceBackedUp.contains(photos[i].id)
                ? Presence.both
                : Presence.device,
            selected: false,
            selecting: false,
            onTap: () => _open(photos, i),
            onLongPress: () {},
          ),
        );
      },
    ),
  );
}
