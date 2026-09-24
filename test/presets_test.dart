import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/editor/presets.dart';
import 'package:immich_editor/editor/recipe.dart';

void main() {
  test('a preset takes only the changed adjustments, no geometry', () {
    final r = const Recipe(
      quarterTurns: 1,
      angle: 3,
    ).withValue('contrast', 0.4).withValue('warmth', 0);
    final p = presetFrom('Kräftig', r);
    expect(p.adjustments, {'contrast': 0.4});
  });

  test('applying replaces the adjustments and keeps crop and rotation', () {
    final copy = const Recipe(
      quarterTurns: 2,
      crop: [0.1, 0.1, 0.8, 0.8],
    ).withValue('brightness', 0.5);
    final result = withPreset(copy, (
      name: 'P',
      adjustments: {'saturation': -0.3},
      filter: null,
    ));
    expect(result.adjustments, {'saturation': -0.3});
    expect(result.quarterTurns, 2);
    expect(result.crop, [0.1, 0.1, 0.8, 0.8]);
  });

  test('a preset takes the filter along and replaces the one in the photo', () {
    final r = const Recipe().withFilter((id: 'film@1', strength: 0.6));
    final p = presetFrom('Film', r);
    expect(p.filter, (id: 'film@1', strength: 0.6));
    final other = const Recipe().withFilter((id: 'bw@1', strength: 1));
    expect(withPreset(other, p).filter, (id: 'film@1', strength: 0.6));
    final none = (name: 'Ohne', adjustments: <String, double>{}, filter: null);
    expect(withPreset(other, none).filter, isNull);
  });
}
