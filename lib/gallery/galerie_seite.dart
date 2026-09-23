import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../editor/presets.dart';
import '../editor/speichern.dart' show presetAnwenden;
import '../editor/vorschau.dart' show getaktet;
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
import 'pruefsummen.dart' show abgleichStand;

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
  final _auswahl = <Eintrag>{};
  var _reiter = 0;
  var _getrennt = false;
  Abgleich _stand = leererAbgleich;
  late Future<int?> _geraet = _geraetZaehlen();
  final _geraetSeiten = <int, Future<List<AssetEntity>>>{};

  @override
  void initState() {
    super.initState();
    _einstellungenLesen();
    abgleichStand.addListener(_erklaeren);
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

  @override
  void dispose() {
    abgleichStand.removeListener(_erklaeren);
    super.dispose();
  }

  /// Beginnt der Bildabgleich, erklärt ihn ein Fenster — einmal je Installation.
  Future<void> _erklaeren() async {
    if (abgleichStand.value == null) return;
    abgleichStand.removeListener(_erklaeren);
    if (await speicher.read(key: 'abgleichErklaert') == 'ja' || !mounted) {
      return;
    }
    await speicher.write(key: 'abgleichErklaert', value: 'ja');
    if (mounted) await abgleichErklaeren(context);
  }

  /// Welche Gerätefotos schon gesichert sind; das erste Mal rechnet es alle Prüfsummen.
  Future<void> _abgleichen() async {
    try {
      final stand = await abgleich(widget.immich);
      if (!mounted) return;
      setState(() {
        _stand = stand;
        _zGeladen.clear();
      });
    } catch (e) {
      debugPrint('Abgleich später: $e'); // etwa ohne Netz
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

  void _waehlen(Eintrag e) => setState(
    () => _auswahl.contains(e) ? _auswahl.remove(e) : _auswahl.add(e),
  );

  /// Ein Preset wählen und auf die Auswahl anwenden; jedes Foto bekommt eine Kopie wie aus dem
  /// Editor (Spec, *Presets*).
  Future<void> _presetAnwenden() async {
    final meldung = ScaffoldMessenger.of(context);
    final presets = await presetsLesen();
    if (!mounted) return;
    if (presets.isEmpty) {
      meldung.showSnackBar(
        const SnackBar(
          content: Text(
            'Noch keine Presets — im Editor unter „Presets" sichern',
          ),
        ),
      );
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
                'Preset auf ${_auswahl.length} Fotos anwenden',
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
    // Originale vom Server laden: nach der Einstellung „Mobile Daten" nur im WLAN (D-30).
    if (_auswahl.any((e) => !e.geraet) &&
        await speicher.read(key: 'mobil') == 'aus' &&
        await getaktet()) {
      if (!mounted) return;
      final trotzdem = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Mobile Daten verwenden?'),
          content: const Text(
            'Die Originale der Online-Fotos werden geladen — laut Einstellung '
            'nur im WLAN.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Trotzdem'),
            ),
          ],
        ),
      );
      if (trotzdem != true) return;
    }
    if (!mounted) return;
    final fotos = _auswahl.toList();
    final fertig = ValueNotifier(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('„${preset.name}" wird angewendet'),
          content: ValueListenableBuilder(
            valueListenable: fertig,
            builder: (c, n, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                LinearProgressIndicator(value: n / fotos.length),
                Text('$n von ${fotos.length} Fotos'),
              ],
            ),
          ),
        ),
      ),
    );
    final fehler = await presetAnwenden(
      widget.immich,
      fotos,
      preset,
      fertig: (n) => fertig.value = n,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    setState(_auswahl.clear);
    final gut = fotos.length - fehler.length;
    meldung.showSnackBar(
      SnackBar(
        content: Text(
          fehler.isEmpty
              ? '$gut Kopien gespeichert'
              : '$gut Kopien gespeichert, ${fehler.length} fehlgeschlagen: ${fehler.first}',
        ),
      ),
    );
    await _neuLaden();
  }

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
    return AppBar(
      centerTitle:
          false, // wie Immichs Zeitleiste: Name links, Profilbild rechts
      title: const Text('Editor for Immich'),
      actions: [
        // Den Bildabgleich zeigen Profilbild (Ring) und Konto-Fenster.
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
    actions: [
      IconButton(
        icon: const Icon(Icons.auto_awesome),
        tooltip: 'Preset anwenden',
        onPressed: _presetAnwenden,
      ),
    ],
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
                      gewaehlt: _auswahl.contains(z.e),
                      waehlt: _auswahl.isNotEmpty,
                      onTap: () => _auswahl.isEmpty
                          ? _oeffnen(
                              eintraege.length,
                              (j) async => eintraege[j].e,
                              i,
                            )
                          : _waehlen(z.e),
                      onLongPress: () => _waehlen(z.e),
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
                gewaehlt: _auswahl.contains((id: a.id, geraet: true)),
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
                    : _waehlen((id: a.id, geraet: true)),
                onLongPress: () => _waehlen((id: a.id, geraet: true)),
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
                      gewaehlt: _auswahl.contains((id: k.id, geraet: false)),
                      waehlt: _auswahl.isNotEmpty,
                      onTap: () => _auswahl.isEmpty
                          ? _oeffnen(
                              kacheln.length,
                              (j) async => (id: kacheln[j].id, geraet: false),
                              i,
                            )
                          : _waehlen((id: k.id, geraet: false)),
                      onLongPress: () => _waehlen((id: k.id, geraet: false)),
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
