import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'rezept.dart';

/// Kanal zum nativen Renderer (D-17): Vorschau und Export rechnen dort.
const rendererKanal = MethodChannel('immich_editor/renderer');

/// Übergibt das Original an den Renderer. Liefert, ob es eine Gain-Map trägt.
Future<bool> ladeOriginal(Uint8List original, {required bool hdr}) async {
  final antwort = await rendererKanal.invokeMapMethod<String, Object>('laden', {
    'original': original,
    'hdr': hdr,
  });
  return antwort!['hatGainmap'] == true;
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
