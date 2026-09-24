import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/gallery/folders.dart';

void main() {
  const newest = ['Camera/', 'Screenshots/', 'WhatsApp/', 'Download/'];
  const names = {
    'Camera/': 'Camera',
    'Screenshots/': 'Screenshots',
    'WhatsApp/': 'WhatsApp',
    'Download/': 'Download',
  };

  test('pinned first, then the own order, then the rest by newest or name', () {
    expect(arrangeFolders(newest, names), newest);
    expect(
      arrangeFolders(
        newest,
        names,
        order: ['WhatsApp/'],
        pinned: {'Download/'},
      ),
      ['Download/', 'WhatsApp/', 'Camera/', 'Screenshots/'],
    );
    expect(arrangeFolders(newest, names, byName: true), [
      'Camera/',
      'Download/',
      'Screenshots/',
      'WhatsApp/',
    ]);
    // a folder that no longer exists drops out of the order
    expect(
      arrangeFolders(newest, names, order: ['Gone/', 'WhatsApp/']).first,
      'WhatsApp/',
    );
  });

  test('moving keeps everything arranged or pinned before in place', () {
    // WhatsApp dragged to the top: only it is arranged
    expect(orderAfterMove(newest, 2, 0, {}), ['WhatsApp/']);
    // Download dragged to position 1, WhatsApp was arranged below it: both stay
    expect(orderAfterMove(newest, 3, 1, {'WhatsApp/'}), [
      'Camera/',
      'Download/',
      'Screenshots/',
      'WhatsApp/',
    ]);
  });
}
