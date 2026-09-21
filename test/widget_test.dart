import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/main.dart';

void main() {
  testWidgets('ohne Sitzung: Anmeldung', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    expect(find.text('Anmelden'), findsOneWidget);
  });
}
