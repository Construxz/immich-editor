import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/server/immich.dart';

void main() {
  test('address: HTTPS unless a scheme is typed (D-78)', () {
    expect(
      Immich.address(' photos.example.com/ '),
      'https://photos.example.com',
    );
    expect(
      Immich.address('http://192.168.1.5:2283//'),
      'http://192.168.1.5:2283',
    );
  });

  test(
    'plain HTTP only stays private at home, on the device, in Tailscale',
    () {
      bool private(String s) => Immich.isPrivate(Uri.parse(s));
      for (final s in [
        'http://192.168.1.5:2283',
        'http://10.0.2.2',
        'http://172.16.0.1',
        'http://172.31.255.1',
        'http://127.0.0.1',
        'http://localhost:2283',
        'http://nas.local',
        'http://immich.lan',
        'http://100.101.102.103',
        'http://nas.tail1234.ts.net',
        'http://[fd12::1]',
        'http://[fe80::1]',
      ]) {
        expect(private(s), isTrue, reason: s);
      }
      for (final s in [
        'http://photos.example.com',
        'http://172.32.0.1',
        'http://100.128.0.1',
        'http://8.8.8.8',
        'http://[2001:db8::1]',
        'http://local.example.com',
      ]) {
        expect(private(s), isFalse, reason: s);
      }
    },
  );
}
