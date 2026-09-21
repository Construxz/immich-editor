import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../export/export.dart';
import '../foto.dart';
import '../main.dart' show speicher;
import '../server/immich.dart';
import 'rezept.dart';
import 'vorschau.dart';

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
  var _rezept = const Rezept();
  var _speichert = false;

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

  void _aendern(Rezept r) {
    setState(() => _rezept = r);
    zeigeRezept(r);
  }

  /// Zuschnitt fürs gewählte Seitenverhältnis im aktuell gedrehten Rahmen.
  List<double> _zuschnitt(double? verhaeltnis, int viertel) => viertel.isOdd
      ? zuschnittFuer(verhaeltnis, _masse.height, _masse.width)
      : zuschnittFuer(verhaeltnis, _masse.width, _masse.height);

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
    final geladen = _original != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.foto.dateiname),
        actions: [
          if (_hatGainmap)
            IconButton(
              icon: Icon(_hdr ? Icons.hdr_on : Icons.hdr_off),
              tooltip: _hdr ? 'HDR an' : 'HDR aus',
              onPressed: _speichert
                  ? null
                  : () {
                      setState(() => _hdr = !_hdr);
                      zeigeHdr(_hdr);
                      speicher.write(key: 'hdr', value: _hdr ? 'an' : 'aus');
                    },
            ),
          TextButton(
            onPressed: !geladen || _speichert || _rezept.istNeutral
                ? null
                : _speichern,
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: _fehler != null
          ? Center(child: Text('$_fehler'))
          : !geladen
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const Vorschau(),
                      if (_speichert)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
                // ponytail: vorläufige Knöpfe; Anfasser und Bedienung nach Google Fotos folgen.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.rotate_90_degrees_cw),
                      tooltip: 'Drehen',
                      onPressed: () {
                        final v = (_rezept.viertel + 1) % 4;
                        // Seitenverhältnis dreht mit
                        final alt = _verhaeltnis;
                        _verhaeltnis = alt == null ? null : 1 / alt;
                        _aendern(
                          _rezept.kopie(
                            viertel: v,
                            zuschnitt: _zuschnitt(_verhaeltnis, v),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip),
                      tooltip: 'Spiegeln',
                      onPressed: () =>
                          _aendern(_rezept.kopie(spiegeln: !_rezept.spiegeln)),
                    ),
                    PopupMenuButton<double>(
                      icon: const Icon(Icons.aspect_ratio),
                      tooltip: 'Seitenverhältnis',
                      onSelected: (v) {
                        _verhaeltnis = v == 0 ? null : v;
                        _aendern(
                          _rezept.kopie(
                            zuschnitt: _zuschnitt(
                              _verhaeltnis,
                              _rezept.viertel,
                            ),
                          ),
                        );
                      },
                      itemBuilder: (_) => [
                        for (final (name, v) in [
                          ('Frei', 0.0),
                          (
                            'Original',
                            _rezept.viertel.isOdd
                                ? _masse.height / _masse.width
                                : _masse.width / _masse.height,
                          ),
                          ('Quadrat', 1.0),
                          ('4:3', 4 / 3),
                          ('3:2', 3 / 2),
                          ('16:9', 16 / 9),
                          ('3:4', 3 / 4),
                          ('2:3', 2 / 3),
                          ('9:16', 9 / 16),
                        ])
                          PopupMenuItem(value: v, child: Text(name)),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten),
                      Expanded(
                        child: Slider(
                          value: _rezept.winkel,
                          min: -45,
                          max: 45,
                          onChanged: _speichert
                              ? null
                              : (v) => _aendern(_rezept.kopie(winkel: v)),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.brightness_6),
                      Expanded(
                        child: Slider(
                          value: _rezept.helligkeit,
                          min: -1,
                          max: 1,
                          onChanged: _speichert
                              ? null
                              : (v) => _aendern(_rezept.kopie(helligkeit: v)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
