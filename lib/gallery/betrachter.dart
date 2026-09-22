import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../editor/editor_seite.dart';
import '../foto.dart';
import '../server/immich.dart';
import 'geraet.dart';

/// Ein Foto groß: wischen zum nächsten, zoomen, im Stapel wechseln, nach oben wischen für die
/// Infos; „Bearbeiten" öffnet den Editor, danach steht hier das Ergebnis (ROADMAP, Betrachter).
/// Teilen, Alben, Papierkorb bleiben bei der Immich-App.
class BetrachterSeite extends StatefulWidget {
  const BetrachterSeite({
    super.key,
    required this.immich,
    required this.anzahl,
    required this.eintragBei,
    required this.start,
  });

  final Immich immich;
  final int anzahl;
  final Future<Eintrag> Function(int) eintragBei;
  final int start;

  @override
  State<BetrachterSeite> createState() => _BetrachterSeiteState();
}

class _BetrachterSeiteState extends State<BetrachterSeite> {
  late final _seiten = PageController(initialPage: widget.start);
  final _eintraege = <int, Future<Eintrag>>{};
  var _gezoomt = false;

  @override
  void dispose() {
    _seiten.dispose();
    super.dispose();
  }

  Future<void> _bearbeiten(int i, Eintrag e) async {
    final ergebnis = await Navigator.of(context).push<Eintrag>(
      MaterialPageRoute(
        builder: (_) =>
            EditorSeite(immich: widget.immich, id: e.id, geraet: e.geraet),
      ),
    );
    // Zurück zum Ergebnis: die neue Kopie an dieser Stelle.
    if (ergebnis != null && mounted) {
      setState(() {
        _eintraege[i] = Future.value(ergebnis);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.black38),
      body: PageView.builder(
        controller: _seiten,
        physics: _gezoomt ? const NeverScrollableScrollPhysics() : null,
        itemCount: widget.anzahl,
        itemBuilder: (context, i) => FutureBuilder(
          future: _eintraege[i] ??= widget.eintragBei(i),
          builder: (context, s) {
            final e = s.data;
            if (e == null) return const SizedBox();
            return _Seite(
              key: ValueKey(e),
              immich: widget.immich,
              eintrag: e,
              onZoom: (z) {
                if (z != _gezoomt) setState(() => _gezoomt = z);
              },
              onBearbeiten: (gezeigt) => _bearbeiten(i, gezeigt),
            );
          },
        ),
      ),
    ),
  );
}

/// Eine Seite: das Foto, bei einem Server-Stapel die Wahl des Mitglieds, unten die Knöpfe.
class _Seite extends StatefulWidget {
  const _Seite({
    super.key,
    required this.immich,
    required this.eintrag,
    required this.onZoom,
    required this.onBearbeiten,
  });

  final Immich immich;
  final Eintrag eintrag;
  final ValueChanged<bool> onZoom;
  final ValueChanged<Eintrag> onBearbeiten;

  @override
  State<_Seite> createState() => _SeiteState();
}

class _SeiteState extends State<_Seite> {
  final _zoom = TransformationController();
  late final Future<List<Foto>> _stapel = widget.eintrag.geraet
      ? Future.value(const [])
      : widget.immich.stapelMit(widget.eintrag.id);
  late String _gezeigt = widget.eintrag.id;
  Future<Uint8List?>? _geraetBild;

  @override
  void initState() {
    super.initState();
    if (widget.eintrag.geraet) {
      _geraetBild = AssetEntity.fromId(
        widget.eintrag.id,
      ).then((a) => a?.thumbnailDataWithSize(const ThumbnailSize.square(1440)));
    }
    _zoom.addListener(
      () => widget.onZoom(_zoom.value.getMaxScaleOnAxis() > 1.01),
    );
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  Eintrag get _eintrag => (id: _gezeigt, geraet: widget.eintrag.geraet);

  void _info() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _Info(
      _eintrag.geraet ? geraetInfo(_gezeigt) : widget.immich.info(_gezeigt),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bild = widget.eintrag.geraet
        ? FutureBuilder(
            future: _geraetBild,
            builder: (context, s) => s.data == null
                ? const Center(child: CircularProgressIndicator())
                : Image.memory(s.data!, fit: BoxFit.contain),
          )
        : Image.network(
            widget.immich.vorschauUri(_gezeigt).toString(),
            key: ValueKey(_gezeigt),
            headers: widget.immich.kopf,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            transformationController: _zoom,
            maxScale: 8,
            panEnabled: _zoom.value.getMaxScaleOnAxis() > 1.01,
            // Nach oben wischen zeigt die Infos, wie bei Google Fotos. Der Zoom fängt die
            // Geste ab, deshalb hier statt in einem GestureDetector.
            onInteractionEnd: (d) {
              if (_zoom.value.getMaxScaleOnAxis() <= 1.01 &&
                  d.velocity.pixelsPerSecond.dy < -300) {
                _info();
              }
            },
            child: SizedBox.expand(child: bild),
          ),
        ),
        FutureBuilder(
          future: _stapel,
          builder: (context, s) {
            final stapel = s.data ?? const [];
            if (stapel.length < 2) return const SizedBox();
            return SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final (f, name) in _namen(stapel))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: f.id == _gezeigt,
                        onSelected: (_) => setState(() => _gezeigt = f.id),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Infos',
                  onPressed: _info,
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('Bearbeiten'),
                  onPressed: () => widget.onBearbeiten(_eintrag),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// „Original", „Bearbeitung", „Bearbeitung 2" … in der Reihenfolge des Stapels (vorn zuerst).
/// Kopien dieser App erkennt man am Namen (`.edit`, s. Speicherweg).
// ponytail: am Namen erkannt; das Rezept-XMP wäre sicherer, kostet aber je Mitglied einen Abruf.
List<(Foto, String)> _namen(List<Foto> stapel) {
  var n = 0;
  return [
    for (final f in stapel)
      (
        f,
        !f.dateiname.contains('.edit')
            ? 'Original'
            : ++n == 1
            ? 'Bearbeitung'
            : 'Bearbeitung $n',
      ),
  ];
}

const _wochentage = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
const _monate = [
  'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', //
  'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.',
];

String _datum(DateTime d) =>
    '${_wochentage[d.weekday - 1]} ${d.day}. ${_monate[d.month - 1]} ${d.year} · '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _groesse(int bytes) => bytes >= 1 << 20
    ? '${(bytes / (1 << 20)).toStringAsFixed(1).replaceAll('.', ',')} MB'
    : '${(bytes / 1024).round()} KB';

/// Die Infos zum Foto, wie Google Fotos sie beim Hochwischen zeigt — ohne Karte.
class _Info extends StatelessWidget {
  const _Info(this.info);

  final Future<FotoInfo> info;

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
      final mp = i.breite == null || i.hoehe == null
          ? null
          : '${(i.breite! * i.hoehe! / 1e6).toStringAsFixed(1).replaceAll('.', ',')} MP'
                ' · ${i.breite} × ${i.hoehe}';
      final bild = [?mp, if (i.bytes != null) _groesse(i.bytes!)].join(' · ');
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i.aufgenommen != null)
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(_datum(i.aufgenommen!)),
                ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(i.name),
                subtitle: bild.isEmpty ? null : Text(bild),
              ),
              if (i.kamera != null || i.belichtung != null)
                ListTile(
                  leading: const Icon(Icons.camera_outlined),
                  title: Text(i.kamera ?? i.objektiv ?? ''),
                  subtitle: Text(
                    [
                      if (i.kamera != null) ?i.objektiv,
                      ?i.belichtung,
                    ].join('\n'),
                  ),
                ),
              if (i.ort != null)
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(i.ort!),
                ),
            ],
          ),
        ),
      );
    },
  );
}
