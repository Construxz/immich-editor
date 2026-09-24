import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'recipe.dart';

/// Channel to the native renderer (D-17): preview and export are computed there.
const rendererChannel = MethodChannel('immich_editor/renderer');

/// Hands the original (or, for now, Immich's preview image) to the renderer, together with
/// [recipe]. Returns whether it carries a gain map, and the size as the image is seen (after
/// EXIF orientation).
Future<({bool hasGainmap, double width, double height})> loadOriginal(
  Uint8List original, {
  required bool hdr,
  required Recipe recipe,
}) async {
  final result = await rendererChannel.invokeMapMethod<String, Object>('load', {
    'original': original,
    'hdr': hdr,
    'recipe': jsonEncode(recipe.toJson()),
  });
  return (
    hasGainmap: result!['hasGainmap'] == true,
    width: (result['width'] as int).toDouble(),
    height: (result['height'] as int).toDouble(),
  );
}

Future<void> showRecipe(Recipe recipe) => rendererChannel.invokeMethod(
  'recipe',
  {'recipe': jsonEncode(recipe.toJson())},
);

/// Small JPEGs of the loaded photo with each filter in [ids], in that order.
Future<List<Uint8List>> filterThumbs(List<String> ids) async =>
    (await rendererChannel.invokeListMethod<Uint8List>('filterThumbs', {
      'ids': ids,
    }))!;

Future<void> showHdr(bool on) =>
    rendererChannel.invokeMethod('hdr', {'on': on});

/// SHA-1 (Base64) — as Immich computes its `checksum`; computed by Android.
Future<String> sha1(Uint8List bytes) async =>
    (await rendererChannel.invokeMethod<String>('sha1', {'bytes': bytes}))!;

/// EXIF fields, read by Android's `ExifInterface`: texts (Make, Model, LensModel), numbers
/// (FNumber, ExposureTime in s, PhotographicSensitivity, FocalLength), lat/lon.
Future<Map<String, Object?>> readExif(Uint8List bytes) async =>
    (await rendererChannel.invokeMapMethod<String, Object?>('exif', {
      'bytes': bytes,
    }))!;

/// Version of this app, e.g. "0.0.1 build.1".
Future<String> appVersion() async =>
    (await rendererChannel.invokeMethod<String>('appVersion'))!;

/// Opens [url] in the app that understands it — in [package], or Android asks; false if there
/// is none.
Future<bool> openUrl(String url, {String? package}) async =>
    (await rendererChannel.invokeMethod<bool>('openUrl', {
      'url': url,
      'package': package,
    }))!;

/// The apps that open [url]: package and name.
Future<List<({String package, String label})>> urlHandlers(String url) async =>
    [
      for (final a in (await rendererChannel.invokeListMethod<Map>(
        'urlHandlers',
        {'url': url},
      ))!)
        (package: a['package'] as String, label: a['label'] as String),
    ];

/// Does the connection currently cost data (mobile, hotspot)? Android decides.
Future<bool> isMetered() async =>
    (await rendererChannel.invokeMethod<bool>('isMetered'))!;

Future<void> endSession() => rendererChannel.invokeMethod('end');

/// The native image surface. Hybrid composition, so it is a real Android view —
/// only then does Android draw the gain map in HDR.
class Preview extends StatelessWidget {
  const Preview({super.key});

  static const _type = 'immich_editor/preview';

  @override
  Widget build(BuildContext context) => PlatformViewLink(
    viewType: _type,
    surfaceFactory: (context, controller) => AndroidViewSurface(
      controller: controller as AndroidViewController,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
    ),
    onCreatePlatformView: (params) =>
        PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: _type,
            layoutDirection: TextDirection.ltr,
            creationParamsCodec: const StandardMessageCodec(),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create(),
  );
}

/// Whether device photo [id] is Ultra HDR (carries a gain map); decoded small, a few ms.
Future<bool> hasGainmap(String id) async =>
    await rendererChannel.invokeMethod<bool>('hasGainmap', {'id': id}) == true;

/// A device photo drawn by Android, so its gain map shows in HDR — the viewer lays it over its
/// Flutter image while not zoomed (D-54). Gestures pass through to Flutter.
class HdrImage extends StatelessWidget {
  const HdrImage({super.key, required this.id});

  /// The photo's ID on the device (MediaStore).
  final String id;

  static const _type = 'immich_editor/hdr';

  @override
  Widget build(BuildContext context) => PlatformViewLink(
    viewType: _type,
    surfaceFactory: (context, controller) => AndroidViewSurface(
      controller: controller as AndroidViewController,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    ),
    onCreatePlatformView: (params) =>
        PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: _type,
            layoutDirection: TextDirection.ltr,
            creationParams: {'id': id, 'hdr': true},
            creationParamsCodec: const StandardMessageCodec(),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create(),
  );
}
