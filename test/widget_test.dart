import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/home/presentation/home_page.dart';

import 'support/michis_fakes.dart';

void main() {
  testWidgets('Muestra la bienvenida michi', (tester) async {
    await tester.pumpWidget(const MovilApp());
    expect(find.text('¡Miau! Bienvenido'), findsOneWidget);
    expect(find.text('Toca al michi para acariciarlo'), findsOneWidget);
  });

  testWidgets('Acariciar al michi suma caricias', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(michiRepository: MichiRepoEnMemoria()),
      ),
    );
    await tester.tap(find.byKey(const Key('michi-interactivo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Caricias: 1'), findsOneWidget);
  });

  testWidgets('Pedir un dato muestra un dato michi', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(michiRepository: MichiRepoEnMemoria()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Otro dato'));
    await tester.tap(find.text('Otro dato'));
    await tester.pump();
    expect(find.text('Pide un dato curioso sobre gatos.'), findsNothing);
  });
}
