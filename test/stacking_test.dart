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

  test(
    'pending entries whose copy or original is gone everywhere are dropped',
    () {
      const waits = (copy: 'k1', original: 'o1', old: null, removeLocal: null);
      const noBackup = (
        copy: 'k2',
        original: 'o2',
        old: null,
        removeLocal: null,
      );
      const copyGone = (
        copy: 'k3',
        original: 'o3',
        old: null,
        removeLocal: null,
      );
      const originalGone = (
        copy: 'k4',
        original: 'o4',
        old: null,
        removeLocal: null,
      );
      expect(
        unreachable(
          [waits, noBackup, copyGone, originalGone],
          {'o1', 'o3'}, // server
          {'k1', 'k2', 'o2', 'k4'}, // device
        ),
        [copyGone, originalGone],
      );
    },
  );
}
