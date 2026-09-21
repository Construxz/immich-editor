import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../editor/rezept.dart';
import 'jpeg.dart';

const _kanal = MethodChannel('immich_editor/jpeg');

/// Rendert [bild] in voller Auflösung mit [rezept] und gibt ein JPEG zurück,
/// das EXIF des [original]s und das Rezept als XMP trägt.
Future<Uint8List> exportieren(
  ui.Image bild,
  Rezept rezept,
  Uint8List original,
  String originalSha1,
) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
      .drawImage(bild, ui.Offset.zero, ui.Paint()..colorFilter = rezept.filter);
  final gerendert = await recorder.endRecording().toImage(
    bild.width,
    bild.height,
  );
  final rgba = await gerendert.toByteData(format: ui.ImageByteFormat.rawRgba);
  gerendert.dispose();

  final kodiert = await _kanal.invokeMethod<Uint8List>('encode', {
    'rgba': rgba!.buffer.asUint8List(),
    'width': bild.width,
    'height': bild.height,
    'quality': 95,
    'original': original,
  });

  final exif = exifAus(original);
  if (exif != null) orientierungNormal(exif);
  return zusammensetzen(
    kodiert!,
    exif: exif,
    rezept: rezept.toJson(),
    originalSha1: originalSha1,
  );
}
