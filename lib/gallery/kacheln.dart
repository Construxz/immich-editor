import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../foto.dart';

/// Miniatur eines Server-Fotos. Eine frisch hochgeladene Kopie hat noch keine — Immich rechnet
/// sie erst Sekunden später; bis dahin neu versuchen statt schwarz zu bleiben.
class ServerMiniatur extends StatefulWidget {
  const ServerMiniatur(this.url, this.kopf, {super.key});

  final String url;
  final Map<String, String> kopf;

  @override
  State<ServerMiniatur> createState() => _ServerMiniaturState();
}

class _ServerMiniaturState extends State<ServerMiniatur> {
  var _versuch = 0;
  var _wartet = false;

  @override
  Widget build(BuildContext context) => Image.network(
    widget.url,
    key: ValueKey(_versuch),
    headers: widget.kopf,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    errorBuilder: (context, fehler, stapel) {
      if (!_wartet && _versuch < 10) {
        _wartet = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          PaintingBinding.instance.imageCache.evict(NetworkImage(widget.url));
          setState(() {
            _wartet = false;
            _versuch++;
          });
        });
      }
      return const SizedBox();
    },
  );
}

/// Miniatur eines Gerätefotos; lädt einmal, solange die Kachel lebt.
class GeraetMiniatur extends StatefulWidget {
  const GeraetMiniatur(this.foto, {super.key});

  final AssetEntity foto;

  @override
  State<GeraetMiniatur> createState() => _GeraetMiniaturState();
}

class _GeraetMiniaturState extends State<GeraetMiniatur> {
  late final Future<Uint8List?> _bytes = widget.foto.thumbnailDataWithSize(
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

/// Symbole auf der Kachel wie Immichs `_TileOverlayIcon`: weiß, mit Schatten.
class _Symbol extends StatelessWidget {
  const _Symbol(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: 16,
    color: Colors.white,
    shadows: const [Shadow(blurRadius: 5, color: Color.fromARGB(80, 0, 0, 0))],
  );
}

/// Eine Kachel der Galerie: Bild, Stapel-Zeichen, Auswahl und — wie in der Immich-App — unten
/// rechts, wo das Foto liegt (Wolke durchgestrichen: nur Gerät; Wolke: nur Server; Wolke mit
/// Haken: beides).
class FotoKachel extends StatelessWidget {
  const FotoKachel({
    super.key,
    required this.bild,
    required this.stapel,
    required this.gewaehlt,
    required this.waehlt,
    required this.onTap,
    required this.onLongPress,
    this.ablage,
  });

  final Widget bild;
  final int stapel;
  final Ablage? ablage;
  final bool gewaehlt, waehlt;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final farbe = Theme.of(context).colorScheme;
    return Semantics(
      label: [
        stapel > 1 ? 'Foto, Stapel mit $stapel' : 'Foto',
        switch (ablage) {
          Ablage.geraet => 'nur auf dem Gerät',
          Ablage.server => 'nur auf dem Server',
          Ablage.beide => 'gesichert',
          null => null,
        },
      ].nonNulls.join(', '),
      selected: gewaehlt,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              padding: EdgeInsets.all(gewaehlt ? 10 : 0),
              child: bild,
            ),
            if (stapel > 1)
              const Positioned(
                right: 6,
                top: 6,
                child: _Symbol(Icons.filter_none),
              ),
            if (ablage != null)
              Positioned(
                right: 6,
                bottom: 4,
                child: _Symbol(switch (ablage!) {
                  Ablage.geraet => Icons.cloud_off_outlined,
                  Ablage.server => Icons.cloud_outlined,
                  Ablage.beide => Icons.cloud_done_outlined,
                }),
              ),
            if (waehlt)
              Positioned(
                left: 4,
                top: 4,
                child: Icon(
                  gewaehlt ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: gewaehlt ? farbe.primary : Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Raster wie in der Immich-App: vier Spalten, schmale Fugen.
const kachelRaster = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 4,
  mainAxisSpacing: 2,
  crossAxisSpacing: 2,
);
