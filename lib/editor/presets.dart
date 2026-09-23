import 'dart:convert';
import 'dart:io';

import 'rezept.dart';
import 'vorschau.dart' show rendererKanal;

/// Ein Preset ist ein Rezept ohne Geometrie und ohne Masken (Spec, *Presets*): nur die Regler.
typedef Preset = ({String name, Map<String, double> regler});

/// [rezept] mit den Reglern des [preset]s; Zuschnitt und Drehung bleiben.
Rezept mitPreset(Rezept rezept, Preset preset) =>
    rezept.kopie(regler: preset.regler);

/// Die Regler von [rezept] als Preset namens [name].
Preset presetAus(String name, Rezept rezept) => (
  name: name,
  regler: {
    for (final MapEntry(:key, :value) in rezept.regler.entries)
      if (value != 0) key: value,
  },
);

/// Im App-Ordner, nicht in `speicher`: das leert sich beim Abmelden.
// ponytail: nur auf dem Gerät; auf dem Server ablegen (Spec), wenn Presets mitreisen sollen.
Future<File> _datei() async =>
    File('${await rendererKanal.invokeMethod<String>('dateien')}/presets.json');

Future<List<Preset>> presetsLesen() async {
  try {
    return [
      for (final p in jsonDecode(await (await _datei()).readAsString()))
        (
          name: p['name'] as String,
          regler: Rezept.fromJson(p['rezept']).regler,
        ),
    ];
  } catch (_) {
    return []; // noch keine
  }
}

Future<void> presetsSchreiben(List<Preset> presets) async =>
    (await _datei()).writeAsString(
      jsonEncode([
        for (final p in presets)
          {'name': p.name, 'rezept': Rezept(regler: p.regler).toJson()},
      ]),
    );
