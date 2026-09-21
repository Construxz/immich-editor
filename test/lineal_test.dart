import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/editor/lineal.dart';

void main() {
  double regler(double roh) => rasten(roh, anzeige: 100, stufe: 1, fang: 2);
  double winkel(double roh) => rasten(roh, anzeige: 1, stufe: 0.1, fang: 0.5);

  test('nahe 0 rastet auf genau 0 ein', () {
    expect(regler(0.004), 0);
    expect(regler(-0.019), 0);
    expect(winkel(0.43), 0);
  });

  test('außerhalb des Fangs: auf die angezeigte Stufe gerundet', () {
    expect(regler(0.034), 0.03);
    expect(regler(-0.456), -0.46);
    expect(winkel(7.76), closeTo(7.8, 1e-9));
    expect(winkel(-0.6), closeTo(-0.6, 1e-9));
  });
}
