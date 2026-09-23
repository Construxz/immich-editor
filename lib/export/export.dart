import 'dart:convert';

import 'package:flutter/services.dart';

import '../editor/rezept.dart';
import '../editor/vorschau.dart';
import 'jpeg.dart';

/// Rendert [original] in voller Auflösung mit [rezept] (nativer Renderer, D-17) und gibt ein
/// JPEG zurück, das EXIF des [original]s und das Rezept als XMP trägt — mit [hdr] als Ultra HDR.
Future<Uint8List> exportieren(
  Rezept rezept,
  Uint8List original,
  String originalSha1, {
  required bool hdr,
}) async {
  final kodiert = await rendererKanal.invokeMethod<Uint8List>('exportieren', {
    'original': original,
    'rezept': jsonEncode(rezept.toJson()),
    'quality': 95,
    'hdr': hdr,
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
