import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'rezept.dart';

/// Kanal zum nativen Renderer (D-17): Vorschau und Export rechnen dort.
const rendererKanal = MethodChannel('immich_editor/renderer');

/// Übergibt das Original (oder vorerst Immichs Vorschaubild) an den Renderer, gleich mit
/// [rezept]. Liefert, ob es eine Gain-Map trägt, und die Größe, wie man das Bild sieht (nach
/// EXIF-Orientierung).
Future<({bool hatGainmap, double breite, double hoehe})> ladeOriginal(
  Uint8List original, {
  required bool hdr,
  required Rezept rezept,
}) async {
  final antwort = await rendererKanal.invokeMapMethod<String, Object>('laden', {
    'original': original,
    'hdr': hdr,
    'rezept': jsonEncode(rezept.toJson()),
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

/// SHA-1 (Base64) — wie Immich seine `checksum` berechnet; gerechnet von Android.
Future<String> sha1(Uint8List bytes) async =>
    (await rendererKanal.invokeMethod<String>('sha1', {'bytes': bytes}))!;

/// Kostet die Verbindung gerade Datenvolumen (Mobilfunk, Hotspot)? Android entscheidet.
Future<bool> getaktet() async =>
    (await rendererKanal.invokeMethod<bool>('getaktet'))!;

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
