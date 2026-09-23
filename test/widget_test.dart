import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/language.dart';
import 'package:immich_editor/main.dart';

void main() {
  testWidgets('no session: login, in the device language, switchable', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget); // test device: en_US

    await setLanguage(const Locale('de'));
    await tester.pumpAndSettle();
    expect(find.text('Anmelden'), findsOneWidget);
    await setLanguage(null);
  });

  test('other device languages get English', () {
    expect(resolveLocale(const Locale('fr')), const Locale('en'));
    expect(resolveLocale(const Locale('de', 'AT')), const Locale('de'));
  });
}
