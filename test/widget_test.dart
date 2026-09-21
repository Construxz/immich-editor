import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/main.dart';

void main() {
  testWidgets('App startet', (tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.text('Editor for Immich'), findsOneWidget);
  });
}
