import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/editor/recipe.dart';

void main() {
  test('neutral: only the version in the JSON', () {
    expect(const Recipe().toJson(), {'v': 1});
    expect(const Recipe().isNeutral, isTrue);
  });

  test('adjustments: only changed ones go into the JSON', () {
    final r = const Recipe().withValue('contrast', 0.3).withValue('warmth', 0);
    expect(r.toJson(), {'v': 1, 'contrast': 0.3});
    expect(r.isNeutral, isFalse);
  });

  test('geometry in the JSON, as the renderer reads it', () {
    final r = const Recipe().copyWith(quarterTurns: 1, angle: -2.5);
    expect(r.isNeutral, isFalse);
    expect(r.toJson()['geometry'], {
      'quarterTurns': 1,
      'flip': false,
      'angle': -2.5,
      'crop': [0, 0, 1, 1],
    });
  });

  test('crop by aspect ratio: largest centered', () {
    // portrait 3000×4000, square: full width, 3/4 of the height
    expect(cropFor(1, 3000, 4000), [0, 0.125, 1, 0.75]);
    // landscape 4000×3000, 16:9: full width
    final c = cropFor(16 / 9, 4000, 3000);
    expect(c[2], 1);
    expect(c[3] * 3000, closeTo(4000 * 9 / 16, 1e-9));
    expect(cropFor(null, 1, 1), [0, 0, 1, 1]);
  });

  test('fromJson reads what toJson writes', () {
    final r = const Recipe()
        .withValue('contrast', 0.3)
        .withValue('vignette', -0.5)
        .copyWith(
          quarterTurns: 3,
          flip: true,
          angle: 7.8,
          crop: [0.1, 0.2, 0.5, 0.6],
        );
    final back = Recipe.fromJson(jsonDecode(jsonEncode(r.toJson())));
    expect(back.sameAs(r), isTrue);
    expect(Recipe.fromJson({'v': 1}).isNeutral, isTrue);
  });

  test('"Optimieren" sets its adjustments from 0 and keeps the rest', () {
    final r = const Recipe()
        .withValue('brightness', 0.5)
        .withValue('contrast', 0.3)
        .copyWith(angle: 4);
    final o = withOptimized(r, {'whitePoint': 0.2});
    expect(o.adjustments, {
      'brightness': 0.0,
      'contrast': 0.3,
      'blackPoint': 0.0,
      'whitePoint': 0.2,
      'warmth': 0.0,
      'tint': 0.0,
      'saturation': 0.0,
    });
    expect(o.angle, 4);
  });

  test('filter: ID and strength in the JSON, strength 0 = none', () {
    final r = const Recipe().withFilter((id: 'warm@1', strength: 0.7));
    expect(r.toJson()['filter'], {'id': 'warm@1', 'strength': 0.7});
    expect(
      Recipe.fromJson(jsonDecode(jsonEncode(r.toJson()))).sameAs(r),
      isTrue,
    );
    expect(r.copyWith(angle: 2).filter, r.filter);
    final off = r.withFilter((id: 'warm@1', strength: 0));
    expect(off.isNeutral, isTrue);
    expect(off.toJson().containsKey('filter'), isFalse);
  });
}
