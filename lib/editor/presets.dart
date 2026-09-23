import 'dart:convert';
import 'dart:io';

import 'recipe.dart';
import 'preview.dart' show rendererChannel;

/// A preset is a recipe without geometry and without masks (spec, *Presets*): adjustments only.
typedef Preset = ({String name, Map<String, double> adjustments});

/// [recipe] with the adjustments of [preset]; crop and rotation stay.
Recipe withPreset(Recipe recipe, Preset preset) =>
    recipe.copyWith(adjustments: preset.adjustments);

/// The adjustments of [recipe] as a preset named [name].
Preset presetFrom(String name, Recipe recipe) => (
  name: name,
  adjustments: {
    for (final MapEntry(:key, :value) in recipe.adjustments.entries)
      if (value != 0) key: value,
  },
);

/// In the app folder, not in `storage`: that is cleared on logout.
// ponytail: device only; store on the server (spec) when presets should travel along.
Future<File> _file() async => File(
  '${await rendererChannel.invokeMethod<String>('filesDir')}/presets.json',
);

Future<List<Preset>> readPresets() async {
  try {
    return [
      for (final p in jsonDecode(await (await _file()).readAsString()))
        (
          name: p['name'] as String,
          adjustments: Recipe.fromJson(p['recipe']).adjustments,
        ),
    ];
  } catch (_) {
    return []; // none yet
  }
}

Future<void> writePresets(List<Preset> presets) async =>
    (await _file()).writeAsString(
      jsonEncode([
        for (final p in presets)
          {
            'name': p.name,
            'recipe': Recipe(adjustments: p.adjustments).toJson(),
          },
      ]),
    );
