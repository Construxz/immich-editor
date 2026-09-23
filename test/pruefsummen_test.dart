import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/gallery/pruefsummen.dart';

void main() {
  test('gespeicherte Summe gilt nur, solange das Foto unverändert ist', () {
    final r = abgleichen(
      {'1': 100, '2': 200, '3': 300},
      {'1': (100, 'a'), '2': (199, 'b'), '9': (900, 'z')},
    );
    expect(r.gueltig, {'1': 'a'});
    expect(r.offen, ['2', '3']);
  });
}
