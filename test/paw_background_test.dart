import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/widgets/paw_background.dart';

void main() {
  testWidgets('el contenido no queda debajo de la barra de navegación', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    // Barra de navegación del sistema de 48 px (modo edge-to-edge).
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PawBackground(
            child: ListView(
              // Padding explícito, como en el inicio: no aplica el de la barra.
              padding: const EdgeInsets.all(24),
              children: [
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 60, child: Text('$i')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final ultimo = tester.getRect(find.text('29'));
    expect(ultimo.bottom, lessThanOrEqualTo(800 - 48 - 24));
  });
}
