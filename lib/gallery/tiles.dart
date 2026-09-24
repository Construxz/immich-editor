import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../editor/preview.dart' show rendererChannel;
import '../l10n/app_localizations.dart';
import '../photo.dart' show Presence;
import '../server/immich.dart';

/// Thumbnail of a server photo. A freshly uploaded copy has none yet — Immich computes it only
/// seconds later; retry until then instead of staying black.
class ServerThumbnail extends StatefulWidget {
  const ServerThumbnail(this.immich, this.id, {super.key});

  final Immich immich;
  final String id;

  @override
  State<ServerThumbnail> createState() => _ServerThumbnailState();
}

/// Server thumbnails on disk, in the app's cache folder (Android may clear it): scrolling back
/// or opening the app again doesn't load them anew (D-55). The newest thousand also stay in
/// memory, so Flutter's image cache recognises them.
// ponytail: never evicted on disk except by Android; add a size limit if the cache grows too big.
final _dir = rendererChannel
    .invokeMethod<String>('cacheDir')
    .then((d) => Directory('$d/thumbnails')..createSync(recursive: true));
final _memory = <String, Future<Uint8List>>{};

Future<Uint8List> serverThumbnail(Immich immich, String id) {
  final known = _memory.remove(id);
  if (known != null) return _memory[id] = known; // now the newest
  if (_memory.length >= 1000) _memory.remove(_memory.keys.first);
  final loaded = () async {
    final file = File('${(await _dir).path}/$id');
    if (await file.exists()) return file.readAsBytes();
    final bytes = await immich.thumbnail(id);
    await file.writeAsBytes(bytes);
    return bytes;
  }();
  // A failure is not kept: next time it tries again.
  loaded.then(
    (_) {},
    onError: (_) {
      _memory.remove(id);
    },
  );
  return _memory[id] = loaded;
}

class _ServerThumbnailState extends State<ServerThumbnail> {
  late var _bytes = serverThumbnail(widget.immich, widget.id);
  var _attempt = 0;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, s) {
      if (s.hasError && _attempt < 10) {
        // A new copy's thumbnail comes a few seconds after the upload.
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _attempt++;
            _bytes = serverThumbnail(widget.immich, widget.id);
          });
        });
      }
      final bytes = s.data;
      return bytes == null
          ? const SizedBox()
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            );
    },
  );
}

/// Thumbnail of a device photo; loads once while the tile lives.
class DeviceThumbnail extends StatefulWidget {
  const DeviceThumbnail(this.asset, {super.key});

  final AssetEntity asset;

  @override
  State<DeviceThumbnail> createState() => _DeviceThumbnailState();
}

class _DeviceThumbnailState extends State<DeviceThumbnail> {
  late final Future<Uint8List?> _bytes = widget.asset.thumbnailDataWithSize(
    const ThumbnailSize.square(256),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _bytes,
    builder: (context, s) => s.data == null
        ? const SizedBox()
        : Image.memory(
            s.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
          ),
  );
}

/// Icons on the tile like Immich's `_TileOverlayIcon`: white, with a shadow.
class _OverlayIcon extends StatelessWidget {
  const _OverlayIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: 16,
    color: Colors.white,
    shadows: const [Shadow(blurRadius: 5, color: Color.fromARGB(80, 0, 0, 0))],
  );
}

/// A gallery tile: image, stack badge, selection and — as in the Immich app — bottom right,
/// where the photo lives (crossed-out cloud: device only; cloud: server only; cloud with
/// check: both).
class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.image,
    required this.stackSize,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    this.presence,
  });

  final Widget image;
  final int stackSize;
  final Presence? presence;
  final bool selected, selecting;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Semantics(
      label: [
        stackSize > 1 ? l.tilePhotoStack(stackSize) : l.tilePhoto,
        switch (presence) {
          Presence.device => l.tileDeviceOnly,
          Presence.server => l.tileServerOnly,
          Presence.both => l.tileBackedUp,
          null => null,
        },
      ].nonNulls.join(', '),
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              padding: EdgeInsets.all(selected ? 10 : 0),
              child: image,
            ),
            if (stackSize > 1)
              const Positioned(
                right: 6,
                top: 6,
                child: _OverlayIcon(Icons.filter_none),
              ),
            if (presence != null)
              Positioned(
                right: 6,
                bottom: 4,
                child: _OverlayIcon(switch (presence!) {
                  Presence.device => Icons.cloud_off_outlined,
                  Presence.server => Icons.cloud_outlined,
                  Presence.both => Icons.cloud_done_outlined,
                }),
              ),
            if (selecting)
              Positioned(
                left: 4,
                top: 4,
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? colors.primary : Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grid as in the Immich app: four columns, narrow gaps.
const tileGrid = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 4,
  mainAxisSpacing: 2,
  crossAxisSpacing: 2,
);
