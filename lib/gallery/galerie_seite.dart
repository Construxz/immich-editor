import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../einstellungen.dart';
import '../foto.dart';
import '../main.dart' show speicher;
import '../server/immich.dart';
import '../stapeln/stapeln.dart';
import 'abgleich.dart';
import 'betrachter.dart';
import 'bibliothek.dart';
import 'geraet.dart';
import 'kacheln.dart';

const _monatsnamen = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', //
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Ein Monat der gemeinsamen Zeitleiste: [schluessel] „2026-05", [beginn] der Server-Monat
/// (null, wenn dort nichts liegt), [anzahl] geschätzt (der Server zählt Videos mit),
/// [lokal] die Fotos, die nur auf dem Gerät liegen.
typedef _Monat = ({
  String schluessel,
  String? beginn,
  int anzahl,
  List<AssetEntity> lokal,
});

/// Eine Kachel der gemeinsamen Zeitleiste.
typedef _Eintrag = ({
  Eintrag e,
  DateTime zeit,
  int stapel,
  Ablage ablage,
  AssetEntity? lokal,
});

String _schluessel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Die Galerie wie in der Immich-App (D-36): „Fotos" ist eine Zeitleiste über Gerät und Server,
/// über die Prüfsumme zusammengeführt, mit Wolken für den Stand; „Bibliothek" zeigt die
/// Geräteordner. In den Einstellungen lässt sich Gerät und Server getrennt zeigen.
class GalerieSeite extends StatefulWidget {
  const GalerieSeite({
    super.key,
    required this.immich,
    required this.onAbmelden,
  });

  final Immich immich;
  final VoidCallback onAbmelden;

  @override
  State<GalerieSeite> createState() => _GalerieSeiteState();
}

class _GalerieSeiteState extends State<GalerieSeite> {
  late Future<List<Monat>> _monate = widget.immich.monate();
  final _geladen = <String, Future<List<Kachel>>>{};
  final _zGeladen = <String, Future<List<_Eintrag>>>{};
  final _auswahl = <String>{};
  var _reiter = 0;
  var _getrennt = false;
  Abgleich _stand = leererAbgleich;
  (int, int)? _fortschritt; // Prüfsummen: fertig, gesamt
  late Future<int?> _geraet = _geraetZaehlen();
  final _geraetSeiten = <int, Future<List<AssetEntity>>>{};

  @override
  void initState() {
    super.initState();
    _einstellungenLesen();
    _abgleichen();
    _stapeln();
  }

  Future<void> _einstellungenLesen() async {
    final getrennt = await speicher.read(key: 'zusammen') == 'getrennt';
    if (mounted && getrennt != _getrennt) {
      setState(() {
        _getrennt = getrennt;
        _reiter = 0;
      });
    }
  }

  /// Welche Gerätefotos schon gesichert sind; das erste Mal rechnet es alle Prüfsummen.
  Future<void> _abgleichen() async {
    try {
      final stand = await abgleich(
        widget.immich,
        fortschritt: (f, g) {
          if (mounted) setState(() => _fortschritt = (f, g));
        },
      );
      if (!mounted) return;
      setState(() {
        _stand = stand;
        _fortschritt = null;
        _zGeladen.clear();
      });
    } catch (e) {
      debugPrint('Abgleich später: $e'); // etwa ohne Netz
      if (mounted) setState(() => _fortschritt = null);
    }
  }

  /// Auf dem Gerät gespeicherte Kopien stapeln, sobald die Immich-App sie gesichert hat.
  Future<void> _stapeln() async {
    try {
      await ausstehendeStapeln(widget.immich);
    } catch (e) {
      debugPrint('Stapeln später: $e');
    }
  }

  /// Anzahl der Gerätefotos, oder null ohne Berechtigung.
  static Future<int?> _geraetZaehlen() async =>
      await geraetErlaubt() ? await geraetAnzahl() : null;

  Future<void> _neuLaden() async {
    setState(() {
      _geladen.clear();
      _zGeladen.clear();
      _monate = widget.immich.monate();
      _geraetSeiten.clear();
      _geraet = _geraetZaehlen();
    });
    await Future.wait([
      _monate,
      _geraet,
      _stapeln(),
      _abgleichen(),
      _einstellungenLesen(),
    ]);
  }

  Future<List<Kachel>> _monat(String beginn) =>
      _geladen[beginn] ??= widget.immich.monat(beginn);

  static const _seite = 120; // Gerätefotos je Abruf

  Future<List<AssetEntity>> _geraetSeite(int i) =>
      _geraetSeiten[i ~/ _seite] ??= geraetFotos(
        i ~/ _seite * _seite,
        (i ~/ _seite + 1) * _seite,
      );

  /// Öffnet den Betrachter bei [start]; danach neu laden, es kann Neues geben.
  // ponytail: Server-Fotos nur innerhalb ihres Monats; über Monate wischen, wenn es fehlt.
  Future<void> _oeffnen(
    int anzahl,
    Future<Eintrag> Function(int) eintragBei,
    int start,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BetrachterSeite(
          immich: widget.immich,
          anzahl: anzahl,
          eintragBei: eintragBei,
          start: start,
        ),
      ),
    );
    await _neuLaden();
  }

  void _waehlen(String id) => setState(
    () => _auswahl.contains(id) ? _auswahl.remove(id) : _auswahl.add(id),
  );

  @override
  Widget build(BuildContext context) {
    final waehlt = _auswahl.isNotEmpty;
    final reiter = _getrennt
        ? [
            (Icons.phone_android, 'Gerät', _geraetAnsicht),
            (Icons.cloud_outlined, 'Immich', _serverAnsicht),
            (Icons.photo_library_outlined, 'Bibliothek', _bibliothek),
          ]
        : [
            (Icons.photo_outlined, 'Fotos', _zusammenAnsicht),
            (Icons.photo_library_outlined, 'Bibliothek', _bibliothek),
          ];
    final aktiv = _reiter.clamp(0, reiter.length - 1);
    return PopScope(
      canPop: !waehlt,
      onPopInvokedWithResult: (gepoppt, _) {
        if (!gepoppt) setState(_auswahl.clear);
      },
      child: Scaffold(
        appBar: waehlt ? _auswahlLeiste() : _leiste(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: aktiv,
          onDestinationSelected: (i) => setState(() => _reiter = i),
          destinations: [
            for (final (icon, name, _) in reiter)
              NavigationDestination(icon: Icon(icon), label: name),
          ],
        ),
        body: reiter[aktiv].$3(),
      ),
    );
  }

  Widget _bibliothek() => Bibliothek(immich: widget.immich, stand: _stand);

  AppBar _leiste() {
    final f = _fortschritt;
    return AppBar(
      centerTitle:
          false, // wie Immichs Zeitleiste: Name links, Profilbild rechts
      title: const Text('Editor for Immich'),
      actions: [
        // Wie Immichs Sync-Anzeige: solange Prüfsummen gerechnet werden
        if (f != null)
          Tooltip(
            message: 'Gerätefotos werden abgeglichen',
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: f.$2 == 0 ? null : f.$1 / f.$2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${f.$1}/${f.$2}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        KontoKnopf(
          immich: widget.immich,
          onAbmelden: widget.onAbmelden,
          onEinstellungen: _neuLaden,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  AppBar _auswahlLeiste() => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close),
      tooltip: 'Auswahl beenden',
      onPressed: () => setState(_auswahl.clear),
    ),
    title: Text('${_auswahl.length} ausgewählt'),
  );

  Widget _monatsKopf(DateTime datum) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        '${_monatsnamen[datum.month - 1]} ${datum.year}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
  );

  // — Gemeinsame Zeitleiste —

  List<_Monat> _zusammenMonate(List<Monat> server) {
    final lokal = <String, List<AssetEntity>>{};
    for (final a in _stand.nurGeraet) {
      (lokal[_schluessel(a.createDateTime)] ??= []).add(a);
    }
    final monate = <String, _Monat>{
      for (final m in server)
        m.beginn.substring(0, 7): (
          schluessel: m.beginn.substring(0, 7),
          beginn: m.beginn,
          anzahl: m.anzahl,
          lokal: const [],
        ),
    };
    lokal.forEach((k, fotos) {
      final m = monate[k];
      monate[k] = (
        schluessel: k,
        beginn: m?.beginn,
        anzahl: (m?.anzahl ?? 0) + fotos.length,
        lokal: fotos,
      );
    });
    return monate.values.toList()
      ..sort((a, b) => b.schluessel.compareTo(a.schluessel));
  }

  Future<List<_Eintrag>> _zusammenMonat(_Monat m) =>
      _zGeladen[m.schluessel] ??= () async {
        final server = m.beginn == null
            ? const <Kachel>[]
            : await _monat(m.beginn!);
        return <_Eintrag>[
          for (final k in server)
            (
              e: (id: k.id, geraet: false),
              zeit: k.zeit,
              stapel: k.stapel,
              ablage: _stand.serverAufGeraet.contains(k.id)
                  ? Ablage.beide
                  : Ablage.server,
              lokal: null,
            ),
          for (final a in m.lokal)
            (
              e: (id: a.id, geraet: true),
              zeit: a.createDateTime,
              stapel: 1,
              ablage: Ablage.geraet,
              lokal: a,
            ),
        ]..sort((a, b) => b.zeit.compareTo(a.zeit));
      }();

  Widget _zusammenAnsicht() => FutureBuilder(
    future: _monate,
    builder: (context, s) {
      if (s.hasError) return _Fehler('${s.error}', _neuLaden);
      final server = s.data;
      if (server == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final monate = _zusammenMonate(server);
      if (monate.isEmpty) {
        return const Center(child: Text('Noch keine Fotos.'));
      }
      return RefreshIndicator(
        onRefresh: _neuLaden,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            for (final m in monate) ...[
              _monatsKopf(DateTime.parse('${m.schluessel}-01')),
              SliverGrid.builder(
                gridDelegate: kachelRaster,
                itemCount: m.anzahl,
                itemBuilder: (context, i) => FutureBuilder(
                  future: _zusammenMonat(m),
                  builder: (context, s) {
                    final eintraege = s.data;
                    if (eintraege == null) {
                      return ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      );
                    }
                    // Videos zählt der Server im Monat mit, gezeigt werden sie nicht
                    if (i >= eintraege.length) return const SizedBox();
                    final z = eintraege[i];
                    return FotoKachel(
                      key: ValueKey(z.e),
                      bild: z.lokal != null
                          ? GeraetMiniatur(z.lokal!)
                          : ServerMiniatur(
                              widget.immich.miniatur(z.e.id).toString(),
                              widget.immich.kopf,
                            ),
                      stapel: z.stapel,
                      ablage: z.ablage,
                      gewaehlt: _auswahl.contains(z.e.id),
                      waehlt: _auswahl.isNotEmpty,
                      onTap: () => _auswahl.isEmpty
                          ? _oeffnen(
                              eintraege.length,
                              (j) async => eintraege[j].e,
                              i,
                            )
                          : _waehlen(z.e.id),
                      onLongPress: () => _waehlen(z.e.id),
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

  // — Getrennte Ansicht (Einstellung) —

  Widget _geraetAnsicht() => FutureBuilder(
    future: _geraet,
    builder: (context, s) {
      if (s.hasError) return _Fehler('${s.error}', _neuLaden);
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final anzahl = s.data;
      if (anzahl == null) {
        return _Fehler(
          'Die App darf die Fotos auf dem Gerät nicht sehen.',
          () async {
            await PhotoManager.openSetting();
            await _neuLaden();
          },
        );
      }
      if (anzahl == 0) {
        return const Center(child: Text('Keine Fotos auf dem Gerät.'));
      }
      return RefreshIndicator(
        onRefresh: _neuLaden,
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: kachelRaster,
          itemCount: anzahl,
          itemBuilder: (context, i) => FutureBuilder(
            future: _geraetSeite(i),
            builder: (context, s) {
              final fotos = s.data;
              if (fotos == null || i % _seite >= fotos.length) {
                return ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                );
              }
              final a = fotos[i % _seite];
              return FotoKachel(
                key: ValueKey(a.id),
                bild: GeraetMiniatur(a),
                stapel: 1,
                ablage: _stand.geraetGesichert.contains(a.id)
                    ? Ablage.beide
                    : Ablage.geraet,
                gewaehlt: _auswahl.contains(a.id),
                waehlt: _auswahl.isNotEmpty,
                onTap: () => _auswahl.isEmpty
                    ? _oeffnen(
                        anzahl,
                        (j) async => (
                          id: (await _geraetSeite(j))[j % _seite].id,
                          geraet: true,
                        ),
                        i,
                      )
                    : _waehlen(a.id),
                onLongPress: () => _waehlen(a.id),
              );
            },
          ),
        ),
      );
    },
  );

  Widget _serverAnsicht() => FutureBuilder(
    future: _monate,
    builder: (context, s) {
      if (s.hasError) return _Fehler('${s.error}', _neuLaden);
      final monate = s.data;
      if (monate == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (monate.isEmpty) {
        return const Center(child: Text('Noch keine Fotos auf dem Server.'));
      }
      return RefreshIndicator(
        onRefresh: _neuLaden,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            for (final m in monate) ...[
              _monatsKopf(DateTime.parse(m.beginn)),
              SliverGrid.builder(
                gridDelegate: kachelRaster,
                itemCount: m.anzahl,
                itemBuilder: (context, i) => FutureBuilder(
                  future: _monat(m.beginn),
                  builder: (context, s) {
                    final kacheln = s.data;
                    if (kacheln == null) {
                      return ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      );
                    }
                    if (i >= kacheln.length) return const SizedBox();
                    final k = kacheln[i];
                    return FotoKachel(
                      bild: ServerMiniatur(
                        widget.immich.miniatur(k.id).toString(),
                        widget.immich.kopf,
                      ),
                      stapel: k.stapel,
                      ablage: _stand.serverAufGeraet.contains(k.id)
                          ? Ablage.beide
                          : Ablage.server,
                      gewaehlt: _auswahl.contains(k.id),
                      waehlt: _auswahl.isNotEmpty,
                      onTap: () => _auswahl.isEmpty
                          ? _oeffnen(
                              kacheln.length,
                              (j) async => (id: kacheln[j].id, geraet: false),
                              i,
                            )
                          : _waehlen(k.id),
                      onLongPress: () => _waehlen(k.id),
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

class _Fehler extends StatelessWidget {
  const _Fehler(this.text, this.nochmal);

  final String text;
  final Future<void> Function() nochmal;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: nochmal, child: const Text('Nochmal')),
        ],
      ),
    ),
  );
}
