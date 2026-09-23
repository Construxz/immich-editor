import 'package:flutter/foundation.dart';

import '../export/export.dart';
import '../export/jpeg.dart' show rezeptAus;
import '../foto.dart';
import '../gallery/geraet.dart';
import '../main.dart' show speicher;
import '../server/immich.dart';
import '../stapeln/stapeln.dart';
import 'presets.dart';
import 'rezept.dart';
import 'vorschau.dart' show sha1;

/// Ein Foto, bereit zum Bearbeiten: [bytes] sind bei Gerätefotos das Original, bei
/// Server-Fotos nur der Anfang (EXIF, XMP) — das Original (Megabytes) lädt, wer es braucht.
/// War [id] eine Kopie dieser App, ist [foto] ihr Original, [start] ihr Rezept und [alteKopie]
/// die Kopie selbst (Spec, *Speicherweg* 5).
typedef Geladen = ({Foto foto, Uint8List bytes, Foto? alteKopie, Rezept start});

Future<Geladen> fotoLaden(
  Immich immich,
  String id, {
  required bool geraet,
}) async {
  Future<(Foto, Uint8List)> laden(String id) async => geraet
      ? await geraetOriginal(id)
      : (await immich.foto(id), await immich.anfang(id));
  var (foto, bytes) = await laden(id);
  final aus = rezeptAus(bytes);
  final originalId = aus == null
      ? null
      : geraet
      ? await geraetPerPruefsumme(aus.originalSha1, foto.aufgenommen)
      : await immich.perPruefsumme(aus.originalSha1);
  if (aus == null || originalId == null) {
    return (foto: foto, bytes: bytes, alteKopie: null, start: const Rezept());
  }
  final kopie = foto;
  (foto, bytes) = await laden(originalId);
  return (
    foto: foto,
    bytes: bytes,
    alteKopie: kopie,
    start: Rezept.fromJson(aus.rezept),
  );
}

/// Rendert die Kopie von [foto] mit [rezept] und speichert sie: mit [aufsGeraet] in die
/// Gerätegalerie und vorgemerkt fürs Stapeln nach dem Backup (D-24, D-25), sonst hochgeladen,
/// gegengeprüft und vor das Original gestapelt. Mit [ersetzen] geht die [alteKopie] in den
/// Papierkorb (D-31). [geraet]: [foto] liegt auf dem Gerät. [schritt] meldet, was gerade passiert.
Future<({Eintrag e, Uint8List kopie})> kopieSpeichern(
  Immich immich, {
  required Foto foto,
  required Uint8List original,
  required Rezept rezept,
  required bool hdr,
  required bool aufsGeraet,
  required bool geraet,
  Foto? alteKopie,
  bool ersetzen = false,
  void Function(String)? schritt,
}) async {
  schritt?.call('Wird gerendert …');
  final kopie = await exportieren(rezept, original, foto.pruefsumme, hdr: hdr);
  if (aufsGeraet) {
    final lokal = await geraetSpeichern(kopie, foto);
    await vormerken((
      kopie: await sha1(kopie),
      original: foto.pruefsumme,
      alt: ersetzen ? alteKopie?.pruefsumme : null,
      entfernen: geraet ? null : lokal,
    ));
    // Eine alte Kopie auf dem Gerät geht in dessen Papierkorb; eine auf dem Server erst beim
    // Stapeln (alt).
    if (alteKopie != null && ersetzen && geraet) {
      await geraetPapierkorb([alteKopie.id]);
    }
    return (e: (id: lokal, geraet: true), kopie: kopie);
  }
  schritt?.call('Wird hochgeladen …');
  final id = await immich.hochladen(
    kopie,
    foto.dateiname.replaceFirst(RegExp(r'(\.[^.]*)?$'), '.edit.jpg'),
    foto.aufgenommen,
  );
  // Erst stapeln, wenn der Server genau die Bytes hat, die wir geschickt haben:
  // Immich berechnet die SHA-1 beim Empfang — sie muss unserer gleichen.
  schritt?.call('Wird geprüft …');
  if ((await immich.foto(id)).pruefsumme != await sha1(kopie)) {
    throw Exception('Kopie auf dem Server weicht ab ($id)');
  }
  schritt?.call('Wird gestapelt …');
  await vorOriginal(
    immich,
    id,
    foto,
    alteKopie: ersetzen ? alteKopie?.id : null,
  );
  return (e: (id: id, geraet: false), kopie: kopie);
}

/// Wendet [preset] auf [fotos] an, eines nach dem anderen, auf demselben Weg wie der Editor.
/// Eine Kopie dieser App wird ersetzt: ihr Original mit dem Zuschnitt der Kopie und den Reglern
/// des Presets (D-31). [fertig] meldet, wie viele durch sind. Gibt die Fehler zurück; ein Fehler
/// hält die übrigen nicht auf.
// ponytail: der Reihe nach, mit wartender Galerie; im Hintergrund, wenn große Auswahlen lästig werden.
Future<List<Object>> presetAnwenden(
  Immich immich,
  List<Eintrag> fotos,
  Preset preset, {
  void Function(int fertig)? fertig,
}) async {
  final hdr = await speicher.read(key: 'hdr') != 'aus';
  final online = await speicher.read(key: 'online') != 'server';
  final fehler = <Object>[];
  for (final (i, e) in fotos.indexed) {
    try {
      final g = await fotoLaden(immich, e.id, geraet: e.geraet);
      await kopieSpeichern(
        immich,
        foto: g.foto,
        original: e.geraet ? g.bytes : await immich.original(g.foto.id),
        rezept: mitPreset(g.start, preset),
        hdr: hdr,
        aufsGeraet: e.geraet || online,
        geraet: e.geraet,
        alteKopie: g.alteKopie,
        ersetzen: true,
      );
    } catch (x) {
      fehler.add(x);
    }
    fertig?.call(i + 1);
  }
  return fehler;
}
