import 'package:flutter_test/flutter_test.dart';
import 'package:telefono_app/main.dart';

void main() {
  testWidgets('TelefonoApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TelefonoApp());
    expect(find.text('Monitor Actividad'), findsWidgets);
  });
}
