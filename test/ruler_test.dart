import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/editor/ruler.dart';

void main() {
  double adjustment(double raw) => snap(raw, scale: 100, step: 1, snapRange: 2);
  double angle(double raw) => snap(raw, scale: 1, step: 0.1, snapRange: 0.5);

  test('near 0 snaps to exactly 0', () {
    expect(adjustment(0.004), 0);
    expect(adjustment(-0.019), 0);
    expect(angle(0.43), 0);
  });

  test('outside the snap range: rounded to the displayed step', () {
    expect(adjustment(0.034), 0.03);
    expect(adjustment(-0.456), -0.46);
    expect(angle(7.76), closeTo(7.8, 1e-9));
    expect(angle(-0.6), closeTo(-0.6, 1e-9));
  });
}
