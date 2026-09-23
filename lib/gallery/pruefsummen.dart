import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../editor/vorschau.dart' show rendererKanal;
import 'geraet.dart';

/// Prüfsummen (SHA-1, Base64) aller Gerätefotos, wie Immich sie als `checksum` führt — daran
/// erkennt die Galerie, was schon gesichert ist (D-36). Einmal gerechnet, danach aus dem
/// Zwischenspeicher; neu nur, was neu ist oder sich geändert hat.

/// Welche gespeicherten Summen noch gelten und welche Fotos zu rechnen sind. [fotos]: ID →
/// Zeitpunkt der letzten Änderung; [gespeichert]: ID → (Änderung beim Rechnen, Summe).
({Map<String, String> gueltig, List<String> offen}) abgleichen(
  Map<String, int> fotos,
  Map<String, (int, String)> gespeichert,
) {
  final gueltig = <String, String>{};
  final offen = <String>[];
  fotos.forEach((id, geaendert) {
    final g = gespeichert[id];
    if (g != null && g.$1 == geaendert) {
      gueltig[id] = g.$2;
    } else {
      offen.add(id);
    }
  });
  return (gueltig: gueltig, offen: offen);
}

Future<File> _datei() async => File(
  '${await rendererKanal.invokeMethod<String>('dateien')}/pruefsummen.json',
);

Future<Map<String, (int, String)>> _lesen() async {
  try {
    final j = jsonDecode(await (await _datei()).readAsString()) as Map;
    return {
      for (final e in j.entries)
        e.key as String: ((e.value as List)[0] as int, e.value[1] as String),
    };
  } catch (_) {
    return {}; // noch nie gerechnet oder kaputt: neu rechnen
  }
}

Future<void> _schreiben(
  Map<String, int> fotos,
  Map<String, String> summen,
) async => (await _datei()).writeAsString(
  jsonEncode({
    for (final e in summen.entries) e.key: [fotos[e.key], e.value],
  }),
);

/// Stand des Bildabgleichs, solange Prüfsummen gerechnet werden, sonst null — für Fenster,
/// Profilbild und Konto-Fenster zugleich.
typedef AbgleichStand = ({int fertig, int gesamt, DateTime beginn});

final abgleichStand = ValueNotifier<AbgleichStand?>(null);

Future<Map<String, String>>? _laeuft;

/// ID → Prüfsumme aller Fotos auf dem Gerät; den Fortschritt zeigt [abgleichStand]. Läuft
/// höchstens einmal gleichzeitig.
Future<Map<String, String>> geraetPruefsummen() =>
    _laeuft ??= _rechnen().whenComplete(() {
      _laeuft = null;
      abgleichStand.value = null;
    });

Future<Map<String, String>> _rechnen() async {
  final anzahl = await geraetAnzahl();
  final fotos = {
    for (final a in anzahl == 0 ? const [] : await geraetFotos(0, anzahl))
      a.id as String: a.modifiedDateSecond as int? ?? 0,
  };
  final (:gueltig, :offen) = abgleichen(fotos, await _lesen());
  const buendel = 40;
  final beginn = DateTime.now();
  if (offen.isNotEmpty) {
    abgleichStand.value = (fertig: 0, gesamt: offen.length, beginn: beginn);
  }
  for (var i = 0; i < offen.length; i += buendel) {
    final ids = offen.sublist(i, (i + buendel).clamp(0, offen.length));
    final summen = await rendererKanal.invokeMapMethod<String, String>(
      'pruefsummen',
      {'ids': ids},
    );
    gueltig.addAll(summen!);
    abgleichStand.value = (
      fertig: i + ids.length,
      gesamt: offen.length,
      beginn: beginn,
    );
    // Zwischendurch sichern: bricht die App ab, beginnt sie nicht von vorn.
    if ((i ~/ buendel) % 25 == 24) await _schreiben(fotos, gueltig);
  }
  if (offen.isNotEmpty || gueltig.length != fotos.length) {
    await _schreiben(fotos, gueltig);
  }
  return gueltig;
}
