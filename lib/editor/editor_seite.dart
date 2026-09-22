import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../export/export.dart';
import '../export/jpeg.dart' show rezeptAus;
import '../foto.dart';
import '../gallery/geraet.dart';
import '../main.dart' show speicher;
import '../server/immich.dart';
import '../stapeln/stapeln.dart';
import 'lineal.dart';
import 'rezept.dart';
import 'vorschau.dart';
import 'zuschnitt.dart';

enum _Bereich { zuschneiden, anpassen }

/// Der Editor im Aufbau von Google Fotos (Spec, *Bedienung*): oben Schließen, Rückgängig,
/// Speichern; in der Mitte das Bild; unten Werkzeuge und Bereiche.
class EditorSeite extends StatefulWidget {
  const EditorSeite({
    super.key,
    required this.immich,
    required this.id,
    this.geraet = false,
  });

  final Immich immich;
  final String id;

  /// [id] ist ein Gerätefoto: bearbeiten ohne Server, Kopie in die Gerätegalerie (D-24).
  final bool geraet;

  @override
  State<EditorSeite> createState() => _EditorSeiteState();
}

class _EditorSeiteState extends State<EditorSeite> {
  Foto? _foto;

  /// Beim erneuten Bearbeiten: die bisherige Kopie; sie geht nach dem Speichern in den
  /// Papierkorb (Spec, *Speicherweg* 5).
  Foto? _alteKopie;
  var _bereit =
      false; // Bild im Editor, zunächst womöglich Immichs Vorschaubild

  /// Das Original, sobald geladen und im Renderer; bei Online-Fotos kommt es im Hintergrund.
  Uint8List? _original;
  Future<Uint8List>?
  _originalFertig; // null: wartet aufs WLAN oder auf eine Rückfrage

  /// Einstellung „Mobile Daten" aus (D-24): Originale und Uploads nur ohne getaktete Verbindung.
  var _nurWlan = false;
  var _hdr = true;
  var _aufsGeraet =
      true; // Kopie in die Gerätegalerie statt direkt auf den Server
  var _hatGainmap = false;
  var _masse = const Size(1, 1); // wie man das Original sieht
  double? _verhaeltnis; // gewähltes Seitenverhältnis, null = frei
  Object? _fehler;
  var _speichert = false;
  var _schritt = ''; // was beim Speichern gerade passiert
  var _bereich = _Bereich.anpassen;
  String? _werkzeug; // gewählter Regler im Bereich Anpassen

  // Rückgängig/Wiederholen: der Verlauf und die Stelle darin
  var _verlauf = <Rezept>[const Rezept()];
  var _stelle = 0;
  var _rezept = const Rezept();

  /// Womit der Editor anfing — beim erneuten Bearbeiten das Rezept der Kopie.
  Rezept get _start => _verlauf.first;
  bool get _geaendert => !_rezept.gleich(_start);

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final hdr = await speicher.read(key: 'hdr') != 'aus';
        // Online-Fotos nach Einstellung, Vorgabe Gerät (D-25).
        final aufsGeraet =
            widget.geraet || await speicher.read(key: 'online') != 'server';
        final immich = widget.immich;
        // Gerätefotos ganz; vom Server erst Details und Anfang (EXIF, XMP) — das Original
        // (Megabytes) lädt im Hintergrund, der Editor startet mit Immichs Vorschaubild (D-24).
        Future<(Foto, Uint8List)> laden(String id) async => widget.geraet
            ? await geraetOriginal(id)
            : (await immich.foto(id), await immich.anfang(id));
        var (foto, bytes) = await laden(widget.id);
        // Eine Kopie dieser App? Dann das Original mit ihrem Rezept öffnen.
        Foto? alteKopie;
        var start = const Rezept();
        final aus = rezeptAus(bytes);
        final originalId = aus == null
            ? null
            : widget.geraet
            ? await geraetPerPruefsumme(aus.originalSha1, foto.aufgenommen)
            : await immich.perPruefsumme(aus.originalSha1);
        if (aus != null && originalId != null) {
          alteKopie = foto;
          start = Rezept.fromJson(aus.rezept);
          (foto, bytes) = await laden(originalId);
        }
        final original = widget.geraet ? bytes : null;
        final nurWlan = await speicher.read(key: 'mobil') == 'aus';
        final geladen = await ladeOriginal(
          original ?? await immich.vorschau(foto.id),
          hdr: hdr,
          rezept: start,
        );
        if (!mounted) return;
        setState(() {
          _foto = foto;
          _alteKopie = alteKopie;
          _verlauf = [start];
          _rezept = start;
          _original = original;
          _bereit = true;
          _hdr = hdr;
          _aufsGeraet = aufsGeraet;
          _hatGainmap = geladen.hatGainmap;
          _masse = Size(geladen.breite, geladen.hoehe);
          _nurWlan = nurWlan;
        });
        if (original != null) {
          _originalFertig = Future.value(original);
        } else if (!nurWlan || !await getaktet()) {
          _originalFertig = _originalNachladen(foto.id)
            ..ignore(); // ein Fehler zeigt sich erst beim Speichern
        }
      } catch (e) {
        if (mounted) setState(() => _fehler = e);
      }
    }();
  }

  /// Holt das Original vom Server und tauscht es im Renderer gegen das Vorschaubild — erst jetzt
  /// gibt es HDR und volle Auflösung. Speichern wartet darauf.
  Future<Uint8List> _originalNachladen(String id) async {
    final original = await widget.immich.original(id);
    if (!mounted) return original;
    final geladen = await ladeOriginal(original, hdr: _hdr, rezept: _gezeigt);
    if (mounted) {
      setState(() {
        _original = original;
        _hatGainmap = geladen.hatGainmap;
      });
    }
    return original;
  }

  @override
  void dispose() {
    beendeSitzung();
    super.dispose();
  }

  /// Beim Zuschneiden zeigt die Vorschau das ganze Bild; der Rahmen liegt darüber.
  Rezept get _gezeigt => _bereich == _Bereich.zuschneiden
      ? _rezept.kopie(zuschnitt: const [0, 0, 1, 1])
      : _rezept;

  void _zeigen() => zeigeRezept(_gezeigt);

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
    if (!_geaendert || _speichert) return Navigator.of(context).pop();
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

  /// Kopie rendern, hochladen, vor das Original stapeln, in dessen Alben legen — oder in die
  /// Gerätegalerie legen und zum Stapeln vormerken (D-24, D-25).
  /// Aufnahmezeit und Ort reisen im übernommenen EXIF mit.
  Future<void> _speichern() async {
    // Eine Kopie bearbeitet: sie ersetzen (die alte geht in den Papierkorb) oder daneben legen.
    var ersetzen = false;
    if (_alteKopie != null) {
      final wahl = await showDialog<bool>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Speichern'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, true),
              child: const ListTile(
                leading: Icon(Icons.save),
                title: Text('Kopie ersetzen'),
                subtitle: Text(
                  'Die bisherige Bearbeitung geht in den Papierkorb',
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, false),
              child: const ListTile(
                leading: Icon(Icons.library_add),
                title: Text('Als weitere Kopie speichern'),
                subtitle: Text('Beide Bearbeitungen liegen im Stapel'),
              ),
            ),
          ],
        ),
      );
      if (wahl == null || !mounted) return;
      ersetzen = wahl;
    }
    // Muss etwas übers Netz, das die Einstellung „Mobile Daten" nur im WLAN erlaubt?
    final netz = _originalFertig == null || !_aufsGeraet;
    if (_nurWlan && netz && await getaktet()) {
      if (!mounted) return;
      final trotzdem = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Mobile Daten verwenden?'),
          content: const Text(
            'Zum Speichern muss das Original geladen oder die Kopie hochgeladen '
            'werden — laut Einstellung nur im WLAN.',
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
    _originalFertig ??= _originalNachladen(_foto!.id);
    setState(() {
      _speichert = true;
      _schritt = 'Wird gerendert …';
    });
    final navigator = Navigator.of(context);
    final meldung = ScaffoldMessenger.of(context);
    final immich = widget.immich;
    final foto = _foto!;
    try {
      if (_original == null) {
        setState(() => _schritt = 'Original wird geladen …');
      }
      final original = await _originalFertig!;
      setState(() => _schritt = 'Wird gerendert …');
      final kopie = await exportieren(
        _rezept,
        original,
        foto.pruefsumme,
        hdr: _hdr,
      );
      if (_aufsGeraet) {
        final lokal = await geraetSpeichern(kopie, foto);
        await vormerken((
          kopie: await sha1(kopie),
          original: foto.pruefsumme,
          alt: ersetzen ? _alteKopie?.pruefsumme : null,
          entfernen: widget.geraet ? null : lokal,
        ));
        // Eine alte Kopie auf dem Gerät geht in dessen Papierkorb; eine auf dem Server erst
        // beim Stapeln (alt).
        final alt = _alteKopie;
        if (alt != null && ersetzen && widget.geraet) {
          await geraetPapierkorb([alt.id]);
        }
        meldung.showSnackBar(
          const SnackBar(
            content: Text(
              'Auf dem Gerät gespeichert — gestapelt wird nach dem Backup',
            ),
          ),
        );
        navigator.pop((id: lokal, geraet: true));
        return;
      }
      setState(() => _schritt = 'Wird hochgeladen …');
      final id = await immich.hochladen(
        kopie,
        foto.dateiname.replaceFirst(RegExp(r'(\.[^.]*)?$'), '.edit.jpg'),
        foto.aufgenommen,
      );
      // Erst stapeln, wenn der Server genau die Bytes hat, die wir geschickt haben:
      // Immich berechnet die SHA-1 beim Empfang — sie muss unserer gleichen.
      setState(() => _schritt = 'Wird geprüft …');
      final serverSha1 = (await immich.foto(id)).pruefsumme;
      if (serverSha1 != await sha1(kopie)) {
        throw Exception('Kopie auf dem Server weicht ab ($id)');
      }
      setState(() => _schritt = 'Wird gestapelt …');
      await vorOriginal(
        immich,
        id,
        foto,
        alteKopie: ersetzen ? _alteKopie?.id : null,
      );

      meldung.showSnackBar(
        const SnackBar(content: Text('Gespeichert und geprüft')),
      );
      navigator.pop((id: id, geraet: false));
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
        canPop: !_geaendert || _speichert,
        onPopInvokedWithResult: (hatGepoppt, _) {
          if (!hatGepoppt) _schliessen();
        },
        child: Scaffold(
          body: SafeArea(
            child: _fehler != null
                ? Center(child: Text('$_fehler'))
                : !_bereit
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
          onPressed: _speichert || !_geaendert || _rezept.istNeutral
              ? null
              : _speichern,
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
            if (w == 'bearbeitung') _aendern(_start);
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
            if (_alteKopie != null)
              const PopupMenuItem(
                value: 'bearbeitung',
                child: Text('Zur gespeicherten Bearbeitung'),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _bildflaeche() => Stack(
    fit: StackFit.expand,
    children: [
      Semantics(label: _foto?.dateiname, child: const Vorschau()),
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
      if (_speichert)
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_schritt),
                ],
              ),
            ),
          ),
        ),
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
          stufe: 0.1,
          fang: 0.5,
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
