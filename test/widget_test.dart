import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';

void main() {
  testWidgets('Muestra la bienvenida michi', (tester) async {
    await tester.pumpWidget(const MovilApp());
    expect(find.text('¡Miau! Bienvenido'), findsOneWidget);
    expect(find.text('Toca al michi para acariciarlo'), findsOneWidget);
  });

  testWidgets('Acariciar al michi suma caricias', (tester) async {
    await tester.pumpWidget(const MovilApp());
    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    expect(find.textContaining('Caricias: 1'), findsOneWidget);
  });

  testWidgets('Pedir un dato muestra un dato michi', (tester) async {
    await tester.pumpWidget(const MovilApp());
    await tester.tap(find.text('Otro dato'));
    await tester.pump();
    expect(find.text('Pide un dato curioso sobre gatos.'), findsNothing);
  });
}
