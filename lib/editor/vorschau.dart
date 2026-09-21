import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'rezept.dart';

/// Kanal zum nativen Renderer (D-17): Vorschau und Export rechnen dort.
const rendererKanal = MethodChannel('immich_editor/renderer');

/// Übergibt das Original an den Renderer. Liefert, ob es eine Gain-Map trägt, und die Größe,
/// wie man das Bild sieht (nach EXIF-Orientierung).
Future<({bool hatGainmap, double breite, double hoehe})> ladeOriginal(
  Uint8List original, {
  required bool hdr,
}) async {
  final antwort = await rendererKanal.invokeMapMethod<String, Object>('laden', {
    'original': original,
    'hdr': hdr,
  });
  return (
    hatGainmap: antwort!['hatGainmap'] == true,
    breite: (antwort['breite'] as int).toDouble(),
    hoehe: (antwort['hoehe'] as int).toDouble(),
  );
}

Future<void> zeigeRezept(Rezept rezept) => rendererKanal.invokeMethod(
  'rezept',
  {'rezept': jsonEncode(rezept.toJson())},
);

Future<void> zeigeHdr(bool an) => rendererKanal.invokeMethod('hdr', {'an': an});

Future<void> beendeSitzung() => rendererKanal.invokeMethod('beenden');

/// Die native Bildfläche. Hybrid Composition, damit sie eine echte Android-Ansicht ist —
/// nur dann zeichnet Android die Gain-Map in HDR.
class Vorschau extends StatelessWidget {
  const Vorschau({super.key});

  static const _typ = 'immich_editor/vorschau';

  @override
  Widget build(BuildContext context) => PlatformViewLink(
    viewType: _typ,
    surfaceFactory: (context, controller) => AndroidViewSurface(
      controller: controller as AndroidViewController,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
    ),
    onCreatePlatformView: (params) =>
        PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: _typ,
            layoutDirection: TextDirection.ltr,
            creationParamsCodec: const StandardMessageCodec(),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create(),
  );
}
