import 'dart:convert';
import 'dart:typed_data';

/// Namensraum des Rezepts im XMP.
const rezeptNamensraum = 'https://github.com/Construxz/immich-editor/ns/1.0/';

const _exifKennung = 'Exif\x00\x00';
const _xmpKennung = 'http://ns.adobe.com/xap/1.0/\x00';
const _mpfKennung = 'MPF\x00';

/// Ein Segment im Kopf eines JPEG: Marker (etwa 0xE1) und Nutzlast ohne Längenfeld.
typedef Segment = ({int marker, Uint8List daten});

/// Zerlegt [jpeg] in die Segmente vor den Bilddaten und den Rest ab SOS. Verträgt auch den
/// Anfang einer Datei (Teilabruf): ein abgeschnittenes Segment endet die Liste.
(List<Segment>, Uint8List) zerlegen(Uint8List jpeg) {
  final segmente = <Segment>[];
  var i = 2;
  while (i + 4 <= jpeg.length && jpeg[i] == 0xFF && jpeg[i + 1] != 0xDA) {
    final laenge = (jpeg[i + 2] << 8) | jpeg[i + 3];
    if (i + 2 + laenge > jpeg.length) break;
    segmente.add((
      marker: jpeg[i + 1],
      daten: Uint8List.sublistView(jpeg, i + 4, i + 2 + laenge),
    ));
    i += 2 + laenge;
  }
  return (segmente, Uint8List.sublistView(jpeg, i));
}

bool _ist(Segment s, int marker, String kennung) =>
    s.marker == marker &&
    s.daten.length >= kennung.length &&
    latin1.decode(s.daten.sublist(0, kennung.length)) == kennung;

/// Die EXIF-Nutzlast (`Exif\0\0` + TIFF) aus [jpeg], oder null.
Uint8List? exifAus(Uint8List jpeg) {
  for (final s in zerlegen(jpeg).$1) {
    if (_ist(s, 0xE1, _exifKennung)) return Uint8List.fromList(s.daten);
  }
  return null;
}

/// Rezept (JSON) und Prüfsumme des Originals aus dem XMP einer Kopie, die diese App
/// geschrieben hat — oder null, wenn [jpeg] keine solche Kopie ist.
({Map<String, dynamic> rezept, String originalSha1})? rezeptAus(
  Uint8List jpeg,
) {
  for (final s in zerlegen(jpeg).$1) {
    if (!_ist(s, 0xE1, _xmpKennung)) continue;
    final xml = utf8.decode(
      s.daten.sublist(_xmpKennung.length),
      allowMalformed: true,
    );
    if (!xml.contains(rezeptNamensraum)) return null;
    String? wert(String name) =>
        RegExp('ife:$name="([^"]*)"')
            .firstMatch(xml)
            ?.group(1)
            ?.replaceAll('&quot;', '"')
            .replaceAll('&lt;', '<')
            .replaceAll('&amp;', '&');
    final rezept = wert('recipe'), sha1 = wert('originalSha1');
    if (rezept == null || sha1 == null) return null;
    return (
      rezept: jsonDecode(rezept) as Map<String, dynamic>,
      originalSha1: sha1,
    );
  }
  return null;
}

/// Setzt die Orientierung in der EXIF-Nutzlast [exif] auf 1 („normal"): Der
/// Renderer hat das Bild bereits aufgerichtet (`Geometrie.nachExif`).
void orientierungNormal(Uint8List exif) {
  const tiff = 6; // nach "Exif\0\0"
  final d = ByteData.sublistView(exif);
  final e = exif[tiff] == 0x49 ? Endian.little : Endian.big; // II / MM
  final ifd0 = tiff + d.getUint32(tiff + 4, e);
  for (var n = 0; n < d.getUint16(ifd0, e); n++) {
    final eintrag = ifd0 + 2 + n * 12;
    if (d.getUint16(eintrag, e) == 0x0112) {
      d.setUint16(eintrag + 8, 1, e);
      return;
    }
  }
}

/// Setzt die Kopie aus dem Ergebnis des Kodierers zusammen:
///
/// - das EXIF des Originals ([exif]) ersetzt das des Kodierers;
/// - das Rezept kommt ins XMP — in das vorhandene Paket, wenn der Kodierer eins
///   geschrieben hat (Ultra HDR: Gain-Map-Verzeichnis), sonst in ein neues;
/// - ein MPF-Verzeichnis (Ultra HDR) wird an die geänderten Längen angepasst,
///   damit es weiter auf die Gain-Map zeigt.
Uint8List zusammensetzen(
  Uint8List kodiert, {
  Uint8List? exif,
  required Map<String, Object> rezept,
  required String originalSha1,
}) {
  final (alt, rest) = zerlegen(kodiert);
  final attribute =
      ' xmlns:ife="$rezeptNamensraum"'
      ' ife:originalSha1="${_attr(originalSha1)}"'
      ' ife:recipe="${_attr(jsonEncode(rezept))}"';

  final neu = <Segment>[];
  var exifDa = false, xmpDa = false;
  for (final s in alt) {
    if (exif != null && _ist(s, 0xE1, _exifKennung)) {
      if (!exifDa) neu.add((marker: 0xE1, daten: exif));
      exifDa = true;
    } else if (!xmpDa && _ist(s, 0xE1, _xmpKennung)) {
      final xml = utf8.decode(s.daten.sublist(_xmpKennung.length));
      final i = xml.indexOf('<rdf:Description');
      if (i < 0) throw StateError('XMP des Kodierers ohne rdf:Description');
      final mitRezept = xml.replaceRange(i + 16, i + 16, attribute);
      neu.add((marker: 0xE1, daten: _xmpDaten(mitRezept)));
      xmpDa = true;
    } else {
      neu.add(s);
    }
  }
  var vorn = neu.isNotEmpty && neu.first.marker == 0xE0 ? 1 : 0; // hinter JFIF
  if (exif != null && !exifDa) neu.insert(vorn++, (marker: 0xE1, daten: exif));
  if (!xmpDa) {
    neu.insert(vorn, (
      marker: 0xE1,
      daten: _xmpDaten(
        '<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>'
        '<x:xmpmeta xmlns:x="adobe:ns:meta/">'
        '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
        '<rdf:Description rdf:about=""$attribute/>'
        '</rdf:RDF></x:xmpmeta><?xpacket end="w"?>',
      ),
    ));
  }
  _mpfAnpassen(alt, neu);

  return Uint8List.fromList([
    0xFF,
    0xD8,
    for (final s in neu) ..._segmentBytes(s),
    ...rest,
  ]);
}

/// Korrigiert das MPF-Verzeichnis in [neu]: Die Größe des Hauptbilds wächst um
/// alles, was im Kopf dazukam; Offsets weiterer Bilder zählen ab dem MPF-Kopf
/// und wachsen nur um das, was dahinter dazukam.
void _mpfAnpassen(List<Segment> alt, List<Segment> neu) {
  final iAlt = alt.indexWhere((s) => _ist(s, 0xE2, _mpfKennung));
  if (iAlt < 0) return;
  final iNeu = neu.indexWhere((s) => identical(s.daten, alt[iAlt].daten));
  int summe(Iterable<Segment> l) => l.fold(0, (n, s) => n + s.daten.length + 4);
  final gesamt = summe(neu) - summe(alt);
  final dahinter = summe(neu.skip(iNeu + 1)) - summe(alt.skip(iAlt + 1));

  final mpf = Uint8List.fromList(alt[iAlt].daten);
  const tiff = 4; // nach "MPF\0"
  final d = ByteData.sublistView(mpf);
  final e = mpf[tiff] == 0x49 ? Endian.little : Endian.big;
  final ifd = tiff + d.getUint32(tiff + 4, e);
  for (var n = 0; n < d.getUint16(ifd, e); n++) {
    final eintrag = ifd + 2 + n * 12;
    if (d.getUint16(eintrag, e) != 0xB002) continue; // MP Entry
    final anzahl = d.getUint32(eintrag + 4, e) ~/ 16;
    final start = tiff + d.getUint32(eintrag + 8, e);
    for (var j = 0; j < anzahl; j++) {
      final bild = start + j * 16;
      if (j == 0) {
        d.setUint32(bild + 4, d.getUint32(bild + 4, e) + gesamt, e);
      } else if (d.getUint32(bild + 8, e) != 0) {
        d.setUint32(bild + 8, d.getUint32(bild + 8, e) + dahinter, e);
      }
    }
  }
  neu[iNeu] = (marker: 0xE2, daten: mpf);
}

String _attr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;');

Uint8List _xmpDaten(String xml) =>
    Uint8List.fromList([...latin1.encode(_xmpKennung), ...utf8.encode(xml)]);

Uint8List _segmentBytes(Segment s) {
  // ponytail: ein Segment fasst höchstens 64 KB; für Masken (M4) Extended XMP.
  final laenge = s.daten.length + 2;
  if (laenge > 0xFFFF) throw StateError('Segment zu groß (${s.marker})');
  return Uint8List.fromList([
    0xFF,
    s.marker,
    laenge >> 8,
    laenge & 0xFF,
    ...s.daten,
  ]);
}
