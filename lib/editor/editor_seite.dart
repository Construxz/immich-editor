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
        final hatGainmap = await ladeOriginal(original, hdr: hdr);
        if (!mounted) return;
        setState(() {
          _original = original;
          _hdr = hdr;
          _hatGainmap = hatGainmap;
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
            onPressed: !geladen || _speichert || _rezept.helligkeit == 0
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
                              : (v) {
                                  setState(
                                    () => _rezept = Rezept(helligkeit: v),
                                  );
                                  zeigeRezept(_rezept);
                                },
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
