import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../photo.dart' show Presence;

/// Thumbnail of a server photo. A freshly uploaded copy has none yet — Immich computes it only
/// seconds later; retry until then instead of staying black.
class ServerThumbnail extends StatefulWidget {
  const ServerThumbnail(this.url, this.headers, {super.key});

  final String url;
  final Map<String, String> headers;

  @override
  State<ServerThumbnail> createState() => _ServerThumbnailState();
}

class _ServerThumbnailState extends State<ServerThumbnail> {
  var _attempt = 0;
  var _waiting = false;

  @override
  Widget build(BuildContext context) => Image.network(
    widget.url,
    key: ValueKey(_attempt),
    headers: widget.headers,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    errorBuilder: (context, error, stack) {
      if (!_waiting && _attempt < 10) {
        _waiting = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          PaintingBinding.instance.imageCache.evict(NetworkImage(widget.url));
          setState(() {
            _waiting = false;
            _attempt++;
          });
        });
      }
      return const SizedBox();
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
    return Semantics(
      label: [
        stackSize > 1 ? 'Foto, Stapel mit $stackSize' : 'Foto',
        switch (presence) {
          Presence.device => 'nur auf dem Gerät',
          Presence.server => 'nur auf dem Server',
          Presence.both => 'gesichert',
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
