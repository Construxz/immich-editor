import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/editor/rezept.dart';

void main() {
  test('neutral: nur Helligkeit im JSON', () {
    expect(const Rezept().toJson(), {'v': 1, 'brightness': 0.0});
    expect(const Rezept().istNeutral, isTrue);
  });

  test('Geometrie im JSON, wie der Renderer sie liest', () {
    final r = const Rezept().kopie(viertel: 1, winkel: -2.5);
    expect(r.istNeutral, isFalse);
    expect(r.toJson()['geometry'], {
      'quarterTurns': 1,
      'flip': false,
      'angle': -2.5,
      'crop': [0, 0, 1, 1],
    });
  });

  test('Zuschnitt nach Seitenverhältnis: größter mittiger', () {
    // Hochformat 3000×4000, Quadrat: ganze Breite, 3/4 der Höhe
    expect(zuschnittFuer(1, 3000, 4000), [0, 0.125, 1, 0.75]);
    // Querformat 4000×3000, 16:9: ganze Breite
    final z = zuschnittFuer(16 / 9, 4000, 3000);
    expect(z[2], 1);
    expect(z[3] * 3000, closeTo(4000 * 9 / 16, 1e-9));
    expect(zuschnittFuer(null, 1, 1), [0, 0, 1, 1]);
  });
}
