import 'dart:convert';
import 'dart:typed_data';

/// Namensraum des Rezepts im XMP.
const rezeptNamensraum = 'https://github.com/Construxz/immich-editor/ns/1.0/';

const _exifKennung = 'Exif\x00\x00';
const _xmpKennung = 'http://ns.adobe.com/xap/1.0/\x00';

/// Das APP1-Exif-Segment (mit Marker und Länge) aus [jpeg], oder null.
Uint8List? exifSegment(Uint8List jpeg) {
  var i = 2;
  while (i + 4 <= jpeg.length && jpeg[i] == 0xFF) {
    final marker = jpeg[i + 1];
    if (marker == 0xDA) break; // Bilddaten beginnen
    final laenge = (jpeg[i + 2] << 8) | jpeg[i + 3];
    if (marker == 0xE1 &&
        latin1.decode(jpeg.sublist(i + 4, i + 10)) == _exifKennung) {
      return Uint8List.fromList(jpeg.sublist(i, i + 2 + laenge));
    }
    i += 2 + laenge;
  }
  return null;
}

/// Setzt die EXIF-Orientierung in [segment] auf 1 („normal"): Die Pixel der
/// Kopie sind bereits gedreht, weil Flutter die Orientierung beim Dekodieren
/// anwendet.
void orientierungNormal(Uint8List segment) {
  const tiff = 10; // FF E1, Länge, "Exif\0\0"
  final d = ByteData.sublistView(segment);
  final e = segment[tiff] == 0x49 ? Endian.little : Endian.big; // II / MM
  final ifd0 = tiff + d.getUint32(tiff + 4, e);
  final anzahl = d.getUint16(ifd0, e);
  for (var n = 0; n < anzahl; n++) {
    final eintrag = ifd0 + 2 + n * 12;
    if (d.getUint16(eintrag, e) == 0x0112) {
      d.setUint16(eintrag + 8, 1, e);
      return;
    }
  }
}

/// APP1-XMP-Segment mit dem Rezept und der Prüfsumme des Originals.
Uint8List xmpSegment(Map<String, Object> rezept, String originalSha1) {
  String attr(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;');
  final xml =
      '<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>'
      '<x:xmpmeta xmlns:x="adobe:ns:meta/">'
      '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
      '<rdf:Description rdf:about="" xmlns:ife="$rezeptNamensraum"'
      ' ife:originalSha1="${attr(originalSha1)}"'
      ' ife:recipe="${attr(jsonEncode(rezept))}"/>'
      '</rdf:RDF></x:xmpmeta><?xpacket end="w"?>';
  final nutzlast = [...latin1.encode(_xmpKennung), ...utf8.encode(xml)];
  // ponytail: ein Segment fasst höchstens 64 KB; für Masken (M4) Extended XMP.
  final laenge = nutzlast.length + 2;
  if (laenge > 0xFFFF) throw StateError('Rezept zu groß für ein XMP-Segment');
  return Uint8List.fromList([
    0xFF,
    0xE1,
    laenge >> 8,
    laenge & 0xFF,
    ...nutzlast,
  ]);
}

/// Setzt [segmente] direkt hinter den Dateianfang (SOI) von [kodiert].
Uint8List einsetzen(Uint8List kodiert, List<Uint8List> segmente) =>
    Uint8List.fromList([
      0xFF,
      0xD8,
      for (final s in segmente) ...s,
      ...kodiert.sublist(2),
    ]);
