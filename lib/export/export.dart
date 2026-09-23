import 'dart:convert';

import 'package:flutter/services.dart';

import '../editor/recipe.dart';
import '../editor/preview.dart';
import 'jpeg.dart';

/// Renders [original] at full resolution with [recipe] (native renderer, D-17) and returns a
/// JPEG carrying the [original]'s EXIF and the recipe as XMP — with [hdr] as Ultra HDR.
Future<Uint8List> exportJpeg(
  Recipe recipe,
  Uint8List original,
  String originalSha1, {
  required bool hdr,
}) async {
  final encoded = await rendererChannel.invokeMethod<Uint8List>('export', {
    'original': original,
    'recipe': jsonEncode(recipe.toJson()),
    'quality': 95,
    'hdr': hdr,
  });
  final exif = exifFrom(original);
  if (exif != null) normalizeOrientation(exif);
  return assemble(
    encoded!,
    exif: exif,
    recipe: recipe.toJson(),
    originalSha1: originalSha1,
  );
}
