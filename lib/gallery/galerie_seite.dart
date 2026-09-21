import 'package:flutter/material.dart';

import '../editor/editor_seite.dart';
import '../foto.dart';
import '../main.dart' show speicher;
import '../server/immich.dart';

const _monatsnamen = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', //
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Die Galerie: Server-Fotos nach Monaten, ein Stapel zählt einmal (vorn liegt die
/// Bearbeitung). Monate laden erst, wenn sie ins Bild kommen.
// ponytail: nur Server-Fotos; Gerätefotos folgen (ROADMAP, M2).
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

  @override
  void initState() {
    super.initState();
    speicher.read(key: 'hdr').then((w) => setState(() => _hdr = w != 'aus'));
  }

  Future<void> _neuLaden() async {
    setState(() {
      _geladen.clear();
      _monate = widget.immich.monate();
    });
    await _monate;
  }

  Future<List<Kachel>> _monat(String beginn) =>
      _geladen[beginn] ??= widget.immich.monat(beginn);

  Future<void> _oeffnen(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorSeite(immich: widget.immich, id: id),
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
        body: FutureBuilder(
          future: _monate,
          builder: (context, s) {
            if (s.hasError) return _Fehler('${s.error}', _neuLaden);
            final monate = s.data;
            if (monate == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (monate.isEmpty) {
              return const Center(
                child: Text('Noch keine Fotos auf dem Server.'),
              );
            }
            return RefreshIndicator(
              onRefresh: _neuLaden,
              child: CustomScrollView(
                slivers: [for (final m in monate) ..._monatsAbschnitt(m)],
              ),
            );
          },
        ),
      ),
    );
  }

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
        },
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: 'hdr',
            checked: _hdr,
            child: const Text('HDR (Ultra HDR erhalten)'),
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
            return _KachelBild(
              kachel: k,
              immich: widget.immich,
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

class _KachelBild extends StatelessWidget {
  const _KachelBild({
    required this.kachel,
    required this.immich,
    required this.gewaehlt,
    required this.waehlt,
    required this.onTap,
    required this.onLongPress,
  });

  final Kachel kachel;
  final Immich immich;
  final bool gewaehlt, waehlt;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final farbe = Theme.of(context).colorScheme;
    return Semantics(
      label: kachel.stapel > 1 ? 'Foto, Stapel mit ${kachel.stapel}' : 'Foto',
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
              child: Image.network(
                immich.miniatur(kachel.id).toString(),
                headers: immich.kopf,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            if (kachel.stapel > 1)
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
