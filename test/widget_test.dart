import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';

void main() {
  testWidgets('La pantalla de inicio muestra el mensaje de bienvenida', (
    tester,
  ) async {
    await tester.pumpWidget(const MovilApp());
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Movil App'), findsOneWidget);
  });
}
