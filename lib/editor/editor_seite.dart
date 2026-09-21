import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../export/export.dart';
import '../foto.dart';
import '../main.dart' show speicher;
import '../server/immich.dart';
import 'lineal.dart';
import 'rezept.dart';
import 'vorschau.dart';
import 'zuschnitt.dart';

enum _Bereich { zuschneiden, anpassen }

/// Der Editor im Aufbau von Google Fotos (Spec, *Bedienung*): oben Schließen, Rückgängig,
/// Speichern; in der Mitte das Bild; unten Werkzeuge und Bereiche.
class EditorSeite extends StatefulWidget {
  const EditorSeite({super.key, required this.immich, required this.foto});

  final Immich immich;
  final Foto foto;

  @override
  State<EditorSeite> createState() => _EditorSeiteState();
}

class _EditorSeiteState extends State<EditorSeite> {
  Uint8List? _original;
  var _hdr = true;
  var _hatGainmap = false;
  var _masse = const Size(1, 1); // wie man das Original sieht
  double? _verhaeltnis; // gewähltes Seitenverhältnis, null = frei
  Object? _fehler;
  var _speichert = false;
  var _bereich = _Bereich.anpassen;
  String? _werkzeug; // gewählter Regler im Bereich Anpassen

  // Rückgängig/Wiederholen: der Verlauf und die Stelle darin
  final _verlauf = <Rezept>[const Rezept()];
  var _stelle = 0;
  var _rezept = const Rezept();

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final hdr = await speicher.read(key: 'hdr') != 'aus';
        final original = await widget.immich.original(widget.foto.id);
        final geladen = await ladeOriginal(original, hdr: hdr);
        if (!mounted) return;
        setState(() {
          _original = original;
          _hdr = hdr;
          _hatGainmap = geladen.hatGainmap;
          _masse = Size(geladen.breite, geladen.hoehe);
        });
      } catch (e) {
        if (mounted) setState(() => _fehler = e);
      }
    }();
  }

  @override
  void dispose() {
    beendeSitzung();
    super.dispose();
  }

  /// Beim Zuschneiden zeigt die Vorschau das ganze Bild; der Rahmen liegt darüber.
  void _zeigen() => zeigeRezept(
    _bereich == _Bereich.zuschneiden
        ? _rezept.kopie(zuschnitt: const [0, 0, 1, 1])
        : _rezept,
  );

  /// Neuer Stand; mit [merken] als Schritt fürs Rückgängigmachen.
  void _aendern(Rezept r, {bool merken = true}) {
    setState(() => _rezept = r);
    _zeigen();
    if (merken) _merken();
  }

  void _merken() {
    if (_verlauf[_stelle] == _rezept) return;
    _verlauf
      ..removeRange(_stelle + 1, _verlauf.length)
      ..add(_rezept);
    setState(() => _stelle = _verlauf.length - 1);
  }

  void _springen(int stelle) {
    setState(() {
      _stelle = stelle;
      _rezept = _verlauf[stelle];
    });
    _zeigen();
  }

  void _bereichWechseln(_Bereich b) {
    setState(() {
      _bereich = b;
      _werkzeug = null;
    });
    _zeigen();
  }

  void _hdrUmschalten() {
    setState(() => _hdr = !_hdr);
    zeigeHdr(_hdr);
    speicher.write(key: 'hdr', value: _hdr ? 'an' : 'aus');
  }

  /// Seitenverhältnis des gedrehten Rahmens (Breite/Höhe).
  double get _rahmen => _rezept.viertel.isOdd
      ? _masse.height / _masse.width
      : _masse.width / _masse.height;

  List<double> _zuschnitt(double? verhaeltnis, int viertel) => viertel.isOdd
      ? zuschnittFuer(verhaeltnis, _masse.height, _masse.width)
      : zuschnittFuer(verhaeltnis, _masse.width, _masse.height);

  Future<void> _schliessen() async {
    if (_rezept.istNeutral || _speichert) return Navigator.of(context).pop();
    final verwerfen = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Änderungen verwerfen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );
    if (verwerfen == true && mounted) Navigator.of(context).pop();
  }

  /// Kopie rendern, hochladen, vor das Original stapeln, in dessen Alben legen.
  /// Aufnahmezeit und Ort reisen im übernommenen EXIF mit.
  Future<void> _speichern() async {
    setState(() => _speichert = true);
    final navigator = Navigator.of(context);
    final meldung = ScaffoldMessenger.of(context);
    final immich = widget.immich;
    final foto = widget.foto;
    try {
      final kopie = await exportieren(
        _rezept,
        _original!,
        foto.pruefsumme,
        hdr: _hdr,
      );
      final id = await immich.hochladen(
        kopie,
        foto.dateiname.replaceFirst(RegExp(r'(\.[^.]*)?$'), '.edit.jpg'),
        foto.aufgenommen,
      );
      // Erst stapeln, wenn der Server genau die Bytes hat, die wir geschickt haben.
      if (!listEquals(await immich.original(id), kopie)) {
        throw Exception('Kopie auf dem Server weicht ab ($id)');
      }
      await immich.stapeln([id, foto.id]);
      for (final album in await immich.albenVon(foto.id)) {
        await immich.insAlbum(album, [id]);
      }
      meldung.showSnackBar(
        const SnackBar(content: Text('Gespeichert und geprüft')),
      );
      navigator.pop();
    } catch (e) {
      meldung.showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
      setState(() => _speichert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Schwarz wie bei Google Fotos: bleibt auf OLED schwarz, auch wenn HDR das Panel aufdreht.
    final dunkel = ThemeData(
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
    );
    return Theme(
      data: dunkel,
      child: PopScope(
        canPop: _rezept.istNeutral || _speichert,
        onPopInvokedWithResult: (hatGepoppt, _) {
          if (!hatGepoppt) _schliessen();
        },
        child: Scaffold(
          body: SafeArea(
            child: _fehler != null
                ? Center(child: Text('$_fehler'))
                : _original == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _obereLeiste(),
                      if (_bereich == _Bereich.zuschneiden) _zuschnittKnoepfe(),
                      Expanded(child: _bildflaeche()),
                      _werkzeuge(),
                      _reiter(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _obereLeiste() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Schließen',
          onPressed: _speichert ? null : _schliessen,
        ),
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Rückgängig',
          onPressed: _stelle > 0 && !_speichert
              ? () => _springen(_stelle - 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          tooltip: 'Wiederholen',
          onPressed: _stelle < _verlauf.length - 1 && !_speichert
              ? () => _springen(_stelle + 1)
              : null,
        ),
        const Spacer(),
        if (_hatGainmap)
          IconButton(
            icon: Icon(_hdr ? Icons.hdr_on : Icons.hdr_off),
            tooltip: _hdr ? 'HDR an' : 'HDR aus',
            onPressed: _speichert ? null : _hdrUmschalten,
          ),
        FilledButton(
          onPressed: _speichert || _rezept.istNeutral ? null : _speichern,
          child: const Text('Speichern'),
        ),
        PopupMenuButton<String>(
          tooltip: 'Mehr',
          enabled: !_speichert,
          onSelected: (w) {
            if (w == 'hdr') _hdrUmschalten();
            if (w == 'zurueck') {
              _verhaeltnis = null;
              _aendern(const Rezept());
            }
          },
          itemBuilder: (_) => [
            if (_hatGainmap)
              CheckedPopupMenuItem(
                value: 'hdr',
                checked: _hdr,
                child: const Text('HDR'),
              ),
            const PopupMenuItem(
              value: 'zurueck',
              child: Text('Alles zurücksetzen'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _bildflaeche() => Stack(
    fit: StackFit.expand,
    children: [
      Semantics(label: widget.foto.dateiname, child: const Vorschau()),
      if (_bereich == _Bereich.zuschneiden)
        ZuschnittRahmen(
          seitenverhaeltnis: _rahmen,
          zuschnitt: _rezept.zuschnitt,
          verhaeltnis: _verhaeltnis,
          onChanged: (z) =>
              setState(() => _rezept = _rezept.kopie(zuschnitt: z)),
          onEnde: _merken,
        )
      else
        // Gedrückt halten zeigt das Original.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (_) => zeigeRezept(const Rezept()),
          onLongPressEnd: (_) => _zeigen(),
        ),
      if (_speichert) const Center(child: CircularProgressIndicator()),
    ],
  );

  Widget _zuschnittKnoepfe() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      PopupMenuButton<double>(
        icon: const Icon(Icons.aspect_ratio),
        tooltip: 'Seitenverhältnis',
        onSelected: (v) {
          _verhaeltnis = v == 0 ? null : v;
          _aendern(
            _rezept.kopie(zuschnitt: _zuschnitt(_verhaeltnis, _rezept.viertel)),
          );
        },
        itemBuilder: (_) => [
          for (final (name, v) in [
            ('Frei', 0.0),
            ('Original', _rahmen),
            ('Quadrat', 1.0),
            ('5:4', 5 / 4),
            ('4:3', 4 / 3),
            ('3:2', 3 / 2),
            ('16:9', 16 / 9),
            ('4:5', 4 / 5),
            ('3:4', 3 / 4),
            ('2:3', 2 / 3),
            ('9:16', 9 / 16),
          ])
            PopupMenuItem(value: v, child: Text(name)),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.flip),
        tooltip: 'Spiegeln',
        onPressed: () => _aendern(_rezept.kopie(spiegeln: !_rezept.spiegeln)),
      ),
      IconButton(
        icon: const Icon(Icons.rotate_90_degrees_ccw),
        tooltip: 'Drehen',
        onPressed: () {
          // Google dreht gegen den Uhrzeigersinn; das Seitenverhältnis dreht mit.
          final v = (_rezept.viertel + 3) % 4;
          final alt = _verhaeltnis;
          _verhaeltnis = alt == null ? null : 1 / alt;
          _aendern(
            _rezept.kopie(viertel: v, zuschnitt: _zuschnitt(_verhaeltnis, v)),
          );
        },
      ),
    ],
  );

  Widget _werkzeuge() {
    if (_bereich == _Bereich.zuschneiden) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Lineal(
          wert: _rezept.winkel,
          min: -45,
          max: 45,
          anzeige: 1,
          einheit: '°',
          strich: 1,
          onChanged: (v) => _aendern(_rezept.kopie(winkel: v), merken: false),
          onEnde: _merken,
        ),
      );
    }
    final aktiv = _werkzeug;
    return Column(
      children: [
        if (aktiv != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Lineal(
              wert: _rezept.wert(aktiv),
              min: -1,
              max: 1,
              onChanged: (v) =>
                  _aendern(_rezept.mitWert(aktiv, v), merken: false),
              onEnde: _merken,
            ),
          ),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final w in werkzeuge)
                _WerkzeugKnopf(
                  werkzeug: w,
                  gewaehlt: w.schluessel == aktiv,
                  veraendert: _rezept.wert(w.schluessel) != 0,
                  onTap: () => setState(
                    () =>
                        _werkzeug = w.schluessel == aktiv ? null : w.schluessel,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reiter() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (b, name) in [
          (_Bereich.zuschneiden, 'Zuschneiden'),
          (_Bereich.anpassen, 'Anpassen'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(name),
              selected: _bereich == b,
              showCheckmark: false,
              shape: const StadiumBorder(),
              onSelected: _speichert ? null : (_) => _bereichWechseln(b),
            ),
          ),
      ],
    ),
  );
}

/// Runder Knopf mit Beschriftung wie in Google Fotos; ein Punkt zeigt einen veränderten Regler.
class _WerkzeugKnopf extends StatelessWidget {
  const _WerkzeugKnopf({
    required this.werkzeug,
    required this.gewaehlt,
    required this.veraendert,
    required this.onTap,
  });

  final Werkzeug werkzeug;
  final bool gewaehlt, veraendert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final farbe = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: gewaehlt
                      ? farbe.primary
                      : farbe.surfaceContainerHighest,
                  foregroundColor: gewaehlt ? farbe.onPrimary : farbe.onSurface,
                  child: Icon(werkzeug.symbol),
                ),
                if (veraendert)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: farbe.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              werkzeug.name,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
