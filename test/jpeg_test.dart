import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/export/jpeg.dart';

/// Orientierungs-Tag aus IFD0 einer EXIF-Nutzlast.
int orientierung(Uint8List exif) {
  final d = ByteData.sublistView(exif);
  final e = exif[6] == 0x49 ? Endian.little : Endian.big;
  final ifd0 = 6 + d.getUint32(10, e);
  for (var n = 0; n < d.getUint16(ifd0, e); n++) {
    final eintrag = ifd0 + 2 + n * 12;
    if (d.getUint16(eintrag, e) == 0x0112) return d.getUint16(eintrag + 8, e);
  }
  return -1;
}

/// Segmente mit Kennung, etwa 'Exif' oder 'http://ns.adobe.com/xap'.
List<Uint8List> segmente(Uint8List jpeg, String kennung) => [
  for (final s in zerlegen(jpeg).$1)
    if (latin1.decode(s.daten.take(kennung.length).toList()) == kennung)
      s.daten,
];

/// (Größe des Hauptbilds, absoluter Offset der Gain-Map) aus dem MPF-Verzeichnis
/// (MM-TIFF, wie im Fixture).
(int, int) mpf(Uint8List jpeg) {
  var i = 2;
  while (!(jpeg[i + 1] == 0xE2 &&
      latin1.decode(jpeg.sublist(i + 4, i + 8)) == 'MPF\x00')) {
    i += 2 + ((jpeg[i + 2] << 8) | jpeg[i + 3]);
  }
  final tiff = i + 8;
  final d = ByteData.sublistView(jpeg);
  final eintraege = tiff + d.getUint32(tiff + 8 + 2 + 2 * 12 + 8);
  return (d.getUint32(eintraege + 4), tiff + d.getUint32(eintraege + 16 + 8));
}

Future<ui.Image> dekodieren(Uint8List jpeg) async =>
    (await (await ui.instantiateImageCodec(jpeg)).getNextFrame()).image;

void main() {
  // 4×2 Pixel gespeichert, EXIF-Orientierung 6 (90° im Uhrzeigersinn).
  final gedreht = File('test/fixtures/orient6.jpg').readAsBytesSync();
  // Aufbau wie Androids Ultra-HDR-Ausgabe; erzeugt von ultrahdr_klein.py.
  final ultraHdr = File('test/fixtures/ultrahdr_klein.jpg').readAsBytesSync();

  test('EXIF lesen und Orientierung auf 1 setzen', () {
    final exif = exifAus(gedreht)!;
    expect(latin1.decode(exif.sublist(0, 6)), 'Exif\x00\x00');
    expect(orientierung(exif), 6);
    orientierungNormal(exif);
    expect(orientierung(exif), 1);
  });

  test('kein EXIF: null', () {
    expect(exifAus(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDA, 0, 2])), isNull);
  });

  testWidgets('ohne XMP: neues Paket, EXIF ersetzt, dekodierbar', (t) async {
    final exif = exifAus(gedreht)!;
    orientierungNormal(exif);
    final neu = zusammensetzen(
      gedreht,
      exif: exif,
      rezept: {'v': 1, 'brightness': 0.25},
      originalSha1: 'ab+/c=',
    );
    expect(segmente(neu, 'Exif'), [exif]);
    final xmp = segmente(neu, 'http://ns.adobe.com/xap');
    expect(xmp, hasLength(1));
    final text = utf8.decode(xmp.single);
    expect(text, contains('xmlns:ife="$rezeptNamensraum"'));
    expect(text, contains('ife:originalSha1="ab+/c="'));
    expect(
      text,
      contains('ife:recipe="{&quot;v&quot;:1,&quot;brightness&quot;:0.25}"'),
    );
    // Orientierung jetzt 1: die gespeicherten 4×2 Pixel bleiben 4×2.
    final bild = (await t.runAsync(() => dekodieren(neu)))!;
    expect([bild.width, bild.height], [4, 2]);
  });

  testWidgets('Ultra HDR: ein EXIF, ein XMP, MPF zeigt auf die Gain-Map', (
    t,
  ) async {
    final (_, gainMapAlt) = mpf(ultraHdr);
    final gainMap = ultraHdr.sublist(gainMapAlt);
    final exif = exifAus(gedreht)!;
    orientierungNormal(exif);

    final neu = zusammensetzen(
      ultraHdr,
      exif: exif,
      rezept: {'v': 1},
      originalSha1: 'x',
    );

    expect(segmente(neu, 'Exif'), [exif]); // das des Kodierers ist ersetzt
    final xmp = utf8.decode(segmente(neu, 'http://ns.adobe.com/xap').single);
    expect(xmp, contains('hdrgm:Version="1.0"'));
    expect(xmp, contains('Item:Semantic="GainMap"'));
    expect(xmp, contains('ife:recipe='));

    final (primaer, gainMapNeu) = mpf(neu);
    expect(gainMapNeu, primaer); // Gain-Map direkt hinter dem Hauptbild
    expect(neu.sublist(gainMapNeu), gainMap); // unverändert, am Ende
    expect(neu.sublist(primaer - 2, primaer), [0xFF, 0xD9]); // EOI davor
    final bild = (await t.runAsync(() => dekodieren(neu)))!;
    expect([bild.width, bild.height], [8, 4]);
  });

  test('rezeptAus liest Rezept und Prüfsumme zurück', () {
    final kopie = zusammensetzen(
      ultraHdr,
      rezept: {
        'v': 1,
        'contrast': 0.25,
        'geometry': {'angle': -2.5},
      },
      originalSha1: 'ab+/c=',
    );
    final r = rezeptAus(kopie)!;
    expect(r.originalSha1, 'ab+/c=');
    expect(r.rezept, {
      'v': 1,
      'contrast': 0.25,
      'geometry': {'angle': -2.5},
    });
    expect(rezeptAus(gedreht), isNull); // kein Rezept
  });
}
