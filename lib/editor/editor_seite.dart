import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../export/export.dart';
import '../foto.dart';
import '../server/immich.dart';
import 'rezept.dart';

class EditorSeite extends StatefulWidget {
  const EditorSeite({super.key, required this.immich, required this.foto});

  final Immich immich;
  final Foto foto;

  @override
  State<EditorSeite> createState() => _EditorSeiteState();
}

class _EditorSeiteState extends State<EditorSeite> {
  Uint8List? _original;
  ui.Image? _bild;
  Object? _fehler;
  var _rezept = const Rezept();
  var _speichert = false;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final original = await widget.immich.original(widget.foto.id);
        final codec = await ui.instantiateImageCodec(original);
        final bild = (await codec.getNextFrame()).image;
        if (!mounted) return bild.dispose();
        setState(() {
          _original = original;
          _bild = bild;
        });
      } catch (e) {
        if (mounted) setState(() => _fehler = e);
      }
    }();
  }

  @override
  void dispose() {
    _bild?.dispose();
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
        _bild!,
        _rezept,
        _original!,
        foto.pruefsumme,
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
    final bild = _bild;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.foto.dateiname),
        actions: [
          TextButton(
            onPressed: bild == null || _speichert || _rezept.helligkeit == 0
                ? null
                : _speichern,
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: _fehler != null
          ? Center(child: Text('$_fehler'))
          : bild == null || _speichert
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ColorFiltered(
                    colorFilter: _rezept.filter,
                    child: RawImage(image: bild, fit: BoxFit.contain),
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
                          onChanged: (v) =>
                              setState(() => _rezept = Rezept(helligkeit: v)),
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
