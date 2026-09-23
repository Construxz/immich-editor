import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/stacking/stacking.dart';

void main() {
  test('a replaced copy that is still waiting drops out of the queue', () {
    const a = (copy: 'k1', original: 'o', old: null, removeLocal: null);
    const b = (copy: 'x', original: 'p', old: null, removeLocal: '7');
    const added = (copy: 'k2', original: 'o', old: 'k1', removeLocal: null);
    expect(enqueueIn([a, b], added), [b, added]);
    expect(enqueueIn([b], a), [b, a]);
  });
}
