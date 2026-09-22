import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/stapeln/stapeln.dart';

void main() {
  test('eine ersetzte, noch wartende Kopie fällt aus der Warteschlange', () {
    const a = (kopie: 'k1', original: 'o', alt: null, entfernen: null);
    const b = (kopie: 'x', original: 'p', alt: null, entfernen: '7');
    const neu = (kopie: 'k2', original: 'o', alt: 'k1', entfernen: null);
    expect(vormerkenIn([a, b], neu), [b, neu]);
    expect(vormerkenIn([b], a), [b, a]);
  });
}
