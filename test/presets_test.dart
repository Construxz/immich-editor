import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/editor/presets.dart';
import 'package:immich_editor/editor/rezept.dart';

void main() {
  test('ein Preset nimmt nur die veränderten Regler, keine Geometrie', () {
    final r = const Rezept(
      viertel: 1,
      winkel: 3,
    ).mitWert('contrast', 0.4).mitWert('warmth', 0);
    final p = presetAus('Kräftig', r);
    expect(p.regler, {'contrast': 0.4});
  });

  test('anwenden ersetzt die Regler und behält Zuschnitt und Drehung', () {
    final kopie = const Rezept(
      viertel: 2,
      zuschnitt: [0.1, 0.1, 0.8, 0.8],
    ).mitWert('brightness', 0.5);
    final neu = mitPreset(kopie, (name: 'P', regler: {'saturation': -0.3}));
    expect(neu.regler, {'saturation': -0.3});
    expect(neu.viertel, 2);
    expect(neu.zuschnitt, [0.1, 0.1, 0.8, 0.8]);
  });
}
