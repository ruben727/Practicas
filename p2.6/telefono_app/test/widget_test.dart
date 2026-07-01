import 'package:flutter_test/flutter_test.dart';

import 'package:telefono_app/main.dart';

void main() {
  testWidgets('Muestra el botón Buscar wearable al inicio', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TelefonoApp());

    expect(find.text('Buscar wearable'), findsOneWidget);
  });
}
