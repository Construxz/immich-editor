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

/// Eine Seite: oben Datum und Version, das Foto, darunter die Miniaturen des Stapels, unten die
/// Knöpfe — wie Google Fotos bei Langzeitbelichtungen (D-34).
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
  late Future<Stapel> _stapel = _laden();
  late String _gezeigt = widget.eintrag.id;
  AssetEntity? _geraetFoto;
  Future<Uint8List?>? _geraetBild;

  Future<Stapel> _laden() => widget.eintrag.geraet
      ? Future.value((id: null, vorn: widget.eintrag.id, fotos: const <Foto>[]))
      : widget.immich.stapelMit(
          _gezeigt,
        ); // nach „Rest löschen" vom behaltenen aus

  @override
  void initState() {
    super.initState();
    if (widget.eintrag.geraet) {
      _geraetBild = AssetEntity.fromId(widget.eintrag.id).then((a) {
        if (mounted) setState(() => _geraetFoto = a);
        return a?.thumbnailDataWithSize(const ThumbnailSize.square(1440));
      });
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
      _eintrag.geraet
          ? geraetInfo(_gezeigt, widget.immich.ortVon)
          : widget.immich.info(_gezeigt),
    ),
  );

  Future<bool> _sicher(String titel, String text, String ja) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(titel),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(ja),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _aktion(Stapel s, String was, String name) async {
    final meldung = ScaffoldMessenger.of(context);
    try {
      if (was == 'vorn') {
        await widget.immich.vornSetzen(s.id!, _gezeigt);
      } else {
        final rest = [
          for (final f in s.fotos)
            if (f.id != _gezeigt) f.id,
        ];
        if (!await _sicher(
          '$name behalten?',
          'Die anderen ${rest.length} Fotos des Stapels gehen in Immichs '
              'Papierkorb — dort lassen sie sich wiederherstellen.',
          'Rest löschen',
        )) {
          return;
        }
        await widget.immich.papierkorb(rest);
        await widget.immich.stapelAufloesen(s.id!);
      }
      setState(() {
        _stapel = _laden();
      });
    } catch (e) {
      meldung.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
    return FutureBuilder(
      future: _stapel,
      builder: (context, s) {
        final stapel = s.data;
        final fotos = stapel == null
            ? const <(Foto, String)>[]
            : _versionen(stapel);
        final gezeigt = fotos.where((f) => f.$1.id == _gezeigt).firstOrNull;
        final zeit = widget.eintrag.geraet
            ? _geraetFoto?.createDateTime
            : gezeigt?.$1.ortszeit;
        return SafeArea(
          child: Column(
            children: [
              // Kopf: zurück, Datum und Uhrzeit, darunter die Version
              Row(
                children: [
                  const BackButton(),
                  Expanded(
                    child: Column(
                      children: [
                        if (zeit != null) ...[
                          Text(_tag(zeit), style: text.titleMedium),
                          Text(_uhrzeit(zeit), style: text.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              if (fotos.length > 1 && gezeigt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chip(
                    avatar: Icon(
                      gezeigt.$1.id == stapel!.vorn
                          ? Icons.star
                          : Icons.filter_none,
                      size: 18,
                    ),
                    label: Text(gezeigt.$2),
                  ),
                ),
              Expanded(
                child: InteractiveViewer(
                  transformationController: _zoom,
                  maxScale: 8,
                  panEnabled: _zoom.value.getMaxScaleOnAxis() > 1.01,
                  // Nach oben wischen zeigt die Infos, wie bei Google Fotos. Der Zoom fängt
                  // die Geste ab, deshalb hier statt in einem GestureDetector.
                  onInteractionEnd: (d) {
                    if (_zoom.value.getMaxScaleOnAxis() <= 1.01 &&
                        d.velocity.pixelsPerSecond.dy < -300) {
                      _info();
                    }
                  },
                  child: SizedBox.expand(child: bild),
                ),
              ),
              if (fotos.length > 1) _miniaturen(stapel!, fotos),
              Padding(
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
            ],
          ),
        );
      },
    );
  }

  /// Die Miniaturen des Stapels; die gewählte trägt ⋮ mit den Stapel-Aktionen.
  Widget _miniaturen(Stapel stapel, List<(Foto, String)> fotos) => SizedBox(
    height: 76,
    child: Center(
      child: ListView(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final (f, name) in fotos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                label: name,
                selected: f.id == _gezeigt,
                button: true,
                child: GestureDetector(
                  onTap: () => setState(() => _gezeigt = f.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: f.id == _gezeigt ? 96 : 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: f.id == _gezeigt
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
                          widget.immich.miniatur(f.id).toString(),
                          headers: widget.immich.kopf,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                        if (f.id == stapel.vorn)
                          const Positioned(
                            left: 4,
                            top: 4,
                            child: Icon(Icons.star, size: 16),
                          ),
                        if (f.id == _gezeigt)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: PopupMenuButton<String>(
                              tooltip: 'Stapel',
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (w) => _aktion(stapel, w, name),
                              itemBuilder: (_) => [
                                if (f.id != stapel.vorn)
                                  const PopupMenuItem(
                                    value: 'vorn',
                                    child: Text('Als Hauptfoto festlegen'),
                                  ),
                                const PopupMenuItem(
                                  value: 'behalten',
                                  child: Text(
                                    'Dieses Foto behalten, den Rest löschen',
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

/// Der Stapel in fester Reihenfolge: das Original, dann die Kopien in der Reihenfolge ihres
/// Entstehens als V1, V2 … Kopien dieser App erkennt man am Namen (`.edit`, s. Speicherweg).
// ponytail: am Namen erkannt; das Rezept-XMP wäre sicherer, kostet aber je Mitglied einen Abruf.
List<(Foto, String)> _versionen(Stapel stapel) {
  final originale = [
    for (final f in stapel.fotos)
      if (!f.dateiname.contains('.edit')) f,
  ];
  final kopien = [
    for (final f in stapel.fotos)
      if (f.dateiname.contains('.edit')) f,
  ]..sort((a, b) => (a.angelegt ?? '').compareTo(b.angelegt ?? ''));
  return [
    for (final f in originale) (f, 'Original'),
    for (final (i, f) in kopien.indexed) (f, 'V${i + 1}'),
  ];
}

const _wochentage = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
const _monate = [
  'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', //
  'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.',
];

String _tag(DateTime d) => '${d.day}. ${_monate[d.month - 1]} ${d.year}';

String _uhrzeit(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _datum(DateTime d) =>
    '${_wochentage[d.weekday - 1]} ${_tag(d)} · ${_uhrzeit(d)}';

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
