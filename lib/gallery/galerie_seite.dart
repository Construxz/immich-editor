import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../editor/editor_seite.dart';
import '../foto.dart';
import '../main.dart' show speicher;
import '../server/immich.dart';
import '../stapeln/stapeln.dart';
import 'geraet.dart';

const _monatsnamen = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', //
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Die Galerie: Gerätefotos, und Server-Fotos nach Monaten, ein Stapel zählt einmal (vorn liegt
/// die Bearbeitung). Monate laden erst, wenn sie ins Bild kommen.
// ponytail: Gerät und Server getrennt; eine Zeitleiste über beide (über die Prüfsumme) folgt.
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
  final _auswahl = <String>{};
  var _hdr = true;
  var _onlineAufsGeraet = true;
  var _mobileDaten = true;
  var _aufGeraet = true;
  late Future<int?> _geraet = _geraetZaehlen();
  final _geraetSeiten = <int, Future<List<AssetEntity>>>{};

  @override
  void initState() {
    super.initState();
    speicher.read(key: 'hdr').then((w) => setState(() => _hdr = w != 'aus'));
    speicher
        .read(key: 'online')
        .then((w) => setState(() => _onlineAufsGeraet = w != 'server'));
    speicher
        .read(key: 'mobil')
        .then((w) => setState(() => _mobileDaten = w != 'aus'));
    _stapeln();
  }

  /// Auf dem Gerät gespeicherte Kopien stapeln, sobald die Immich-App sie gesichert hat.
  Future<void> _stapeln() async {
    try {
      await ausstehendeStapeln(widget.immich);
    } catch (e) {
      debugPrint('Stapeln später: $e'); // etwa ohne Netz
    }
  }

  /// Anzahl der Gerätefotos, oder null ohne Berechtigung.
  static Future<int?> _geraetZaehlen() async =>
      await geraetErlaubt() ? await geraetAnzahl() : null;

  Future<void> _neuLaden() async {
    setState(() {
      _geladen.clear();
      _monate = widget.immich.monate();
      _geraetSeiten.clear();
      _geraet = _geraetZaehlen();
    });
    await Future.wait([_monate, _geraet, _stapeln()]);
  }

  Future<List<Kachel>> _monat(String beginn) =>
      _geladen[beginn] ??= widget.immich.monat(beginn);

  Future<void> _oeffnen(String id, {bool geraet = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EditorSeite(immich: widget.immich, id: id, geraet: geraet),
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
    return PopScope(
      canPop: !waehlt,
      onPopInvokedWithResult: (gepoppt, _) {
        if (!gepoppt) setState(_auswahl.clear);
      },
      child: Scaffold(
        appBar: waehlt ? _auswahlLeiste() : _leiste(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aufGeraet ? 0 : 1,
          onDestinationSelected: (i) => setState(() => _aufGeraet = i == 0),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.phone_android),
              label: 'Gerät',
            ),
            NavigationDestination(icon: Icon(Icons.cloud), label: 'Immich'),
          ],
        ),
        body: _aufGeraet ? _geraetAnsicht() : _serverAnsicht(),
      ),
    );
  }

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
      const seite = 120;
      return RefreshIndicator(
        onRefresh: _neuLaden,
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: anzahl,
          itemBuilder: (context, i) => FutureBuilder(
            future: _geraetSeiten[i ~/ seite] ??= geraetFotos(
              i ~/ seite * seite,
              (i ~/ seite + 1) * seite,
            ),
            builder: (context, s) {
              final fotos = s.data;
              if (fotos == null || i % seite >= fotos.length) {
                return ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                );
              }
              final a = fotos[i % seite];
              return _Kachel(
                key: ValueKey(a.id),
                bild: _GeraetMiniatur(a),
                stapel: 1,
                gewaehlt: _auswahl.contains(a.id),
                waehlt: _auswahl.isNotEmpty,
                onTap: () => _auswahl.isEmpty
                    ? _oeffnen(a.id, geraet: true)
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
          slivers: [for (final m in monate) ..._monatsAbschnitt(m)],
        ),
      );
    },
  );

  AppBar _leiste() => AppBar(
    title: const Text('Editor for Immich'),
    actions: [
      PopupMenuButton<String>(
        tooltip: 'Mehr',
        onSelected: (w) {
          if (w == 'abmelden') widget.onAbmelden();
          if (w == 'hdr') {
            setState(() => _hdr = !_hdr);
            speicher.write(key: 'hdr', value: _hdr ? 'an' : 'aus');
          }
          if (w == 'mobil') {
            setState(() => _mobileDaten = !_mobileDaten);
            speicher.write(key: 'mobil', value: _mobileDaten ? 'an' : 'aus');
          }
          if (w == 'online') {
            setState(() => _onlineAufsGeraet = !_onlineAufsGeraet);
            speicher.write(
              key: 'online',
              value: _onlineAufsGeraet ? 'geraet' : 'server',
            );
          }
        },
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: 'hdr',
            checked: _hdr,
            child: const Text('HDR (Ultra HDR erhalten)'),
          ),
          CheckedPopupMenuItem(
            value: 'mobil',
            checked: _mobileDaten,
            child: const Text('Originale und Uploads über mobile Daten'),
          ),
          CheckedPopupMenuItem(
            value: 'online',
            checked: _onlineAufsGeraet,
            child: const Text(
              'Bearbeitungen von Online-Fotos übers Gerät sichern',
            ),
          ),
          const PopupMenuItem(value: 'abmelden', child: Text('Abmelden')),
        ],
      ),
    ],
  );

  AppBar _auswahlLeiste() => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close),
      tooltip: 'Auswahl beenden',
      onPressed: () => setState(_auswahl.clear),
    ),
    title: Text('${_auswahl.length} ausgewählt'),
  );

  List<Widget> _monatsAbschnitt(Monat m) {
    final datum = DateTime.parse(m.beginn);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            '${_monatsnamen[datum.month - 1]} ${datum.year}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: m.anzahl,
        itemBuilder: (context, i) => FutureBuilder(
          future: _monat(m.beginn),
          builder: (context, s) {
            final kacheln = s.data;
            // Videos zählen im Monat mit, zeigen wir aber nicht
            if (kacheln == null || i >= kacheln.length) {
              return ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              );
            }
            final k = kacheln[i];
            return _Kachel(
              bild: Image.network(
                widget.immich.miniatur(k.id).toString(),
                headers: widget.immich.kopf,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
              stapel: k.stapel,
              gewaehlt: _auswahl.contains(k.id),
              waehlt: _auswahl.isNotEmpty,
              onTap: () => _auswahl.isEmpty ? _oeffnen(k.id) : _waehlen(k.id),
              onLongPress: () => _waehlen(k.id),
            );
          },
        ),
      ),
    ];
  }
}

/// Miniatur eines Gerätefotos; lädt einmal, solange die Kachel lebt.
class _GeraetMiniatur extends StatefulWidget {
  const _GeraetMiniatur(this.foto);

  final AssetEntity foto;

  @override
  State<_GeraetMiniatur> createState() => _GeraetMiniaturState();
}

class _GeraetMiniaturState extends State<_GeraetMiniatur> {
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

class _Kachel extends StatelessWidget {
  const _Kachel({
    super.key,
    required this.bild,
    required this.stapel,
    required this.gewaehlt,
    required this.waehlt,
    required this.onTap,
    required this.onLongPress,
  });

  final Widget bild;
  final int stapel;
  final bool gewaehlt, waehlt;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final farbe = Theme.of(context).colorScheme;
    return Semantics(
      label: stapel > 1 ? 'Foto, Stapel mit $stapel' : 'Foto',
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
                right: 4,
                top: 4,
                child: Icon(Icons.filter_none, size: 16, color: Colors.white),
              ),
            if (waehlt)
              Positioned(
                left: 4,
                top: 4,
                child: Icon(
                  gewaehlt ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: gewaehlt ? farbe.primary : Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
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
