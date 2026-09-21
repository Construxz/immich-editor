import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/export/jpeg.dart';

/// Orientierungs-Tag aus IFD0 eines APP1-Exif-Segments.
int orientierung(Uint8List segment) {
  final d = ByteData.sublistView(segment);
  final e = segment[10] == 0x49 ? Endian.little : Endian.big;
  final ifd0 = 10 + d.getUint32(14, e);
  for (var n = 0; n < d.getUint16(ifd0, e); n++) {
    final eintrag = ifd0 + 2 + n * 12;
    if (d.getUint16(eintrag, e) == 0x0112) return d.getUint16(eintrag + 8, e);
  }
  return -1;
}

Future<ui.Image> dekodieren(Uint8List jpeg) async =>
    (await (await ui.instantiateImageCodec(jpeg)).getNextFrame()).image;

void main() {
  // 4×2 Pixel gespeichert, EXIF-Orientierung 6 (90° im Uhrzeigersinn).
  final gedreht = File('test/fixtures/orient6.jpg').readAsBytesSync();

  test('EXIF finden und Orientierung auf 1 setzen', () {
    final exif = exifSegment(gedreht)!;
    expect(latin1.decode(exif.sublist(4, 10)), 'Exif\x00\x00');
    expect(orientierung(exif), 6);
    orientierungNormal(exif);
    expect(orientierung(exif), 1);
  });

  test('kein EXIF: null', () {
    final ohne = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDA, 0, 2]);
    expect(exifSegment(ohne), isNull);
  });

  testWidgets('Flutter wendet die Orientierung beim Dekodieren an', (t) async {
    // Die Annahme hinter orientierungNormal: Pixel kommen schon gedreht an.
    final bild = (await t.runAsync(() => dekodieren(gedreht)))!;
    expect([bild.width, bild.height], [2, 4]);
  });

  test('XMP trägt Rezept und Prüfsumme, Länge stimmt', () {
    final xmp = xmpSegment({'v': 1, 'brightness': 0.25}, 'ab+/c=');
    expect(xmp.sublist(0, 2), [0xFF, 0xE1]);
    expect((xmp[2] << 8) | xmp[3], xmp.length - 2);
    final text = utf8.decode(xmp.sublist(4), allowMalformed: true);
    expect(text, startsWith('http://ns.adobe.com/xap/1.0/\x00'));
    expect(text, contains('xmlns:ife="$rezeptNamensraum"'));
    expect(text, contains('ife:originalSha1="ab+/c="'));
    expect(
      text,
      contains('ife:recipe="{&quot;v&quot;:1,&quot;brightness&quot;:0.25}"'),
    );
  });

  testWidgets('eingesetzte Segmente: Datei bleibt dekodierbar', (t) async {
    final exif = exifSegment(gedreht)!;
    final lage = String.fromCharCodes(gedreht)
        .indexOf(String.fromCharCodes(exif));
    final ohneExif = Uint8List.fromList([
      ...gedreht.sublist(0, lage),
      ...gedreht.sublist(lage + exif.length),
    ]);
    orientierungNormal(exif);
    final neu = einsetzen(ohneExif, [
      exif,
      xmpSegment({'v': 1}, 'x'),
    ]);
    expect(exifSegment(neu), exif);
    // Orientierung jetzt 1: die gespeicherten 4×2 Pixel bleiben 4×2.
    final bild = (await t.runAsync(() => dekodieren(neu)))!;
    expect([bild.width, bild.height], [4, 2]);
  });
}
