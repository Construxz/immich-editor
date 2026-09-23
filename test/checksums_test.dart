import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/gallery/checksums.dart';

void main() {
  test('a stored checksum is valid only while the photo is unchanged', () {
    final r = reconcile(
      {'1': 100, '2': 200, '3': 300},
      {'1': (100, 'a'), '2': (199, 'b'), '9': (900, 'z')},
    );
    expect(r.valid, {'1': 'a'});
    expect(r.pending, ['2', '3']);
  });
}
