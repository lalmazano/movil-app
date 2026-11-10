import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/routes/app_router.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/home/presentation/home_page.dart';
import 'package:movil_app/features/michis/domain/michi.dart';

import 'support/michis_fakes.dart';

void main() {
  final hoy = DateTime(2026, 11, 10);

  Future<void> abrir(WidgetTester tester, List<Michi> michis) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(michiRepository: MichiRepoEnMemoria(michis), hoy: hoy),
        onGenerateRoute: (s) => MaterialPageRoute(
          settings: s,
          builder: (_) => Scaffold(body: Text('ruta ${s.name}')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin michis invita a crear uno', (tester) async {
    await abrir(tester, []);
    expect(find.text('¡Miau! Bienvenido'), findsOneWidget);
    expect(
      find.textContaining('¿Aún no registras a tu michi?'),
      findsOneWidget,
    );
    // "Mis michis" es la primera sección del menú.
    final botones = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(Wrap).last,
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toList();
    expect(botones.first, 'Mis michis');

    await tester.tap(find.text('Crear su perfil'));
    await tester.pumpAndSettle();
    expect(find.text('ruta ${AppRoutes.michis}'), findsOneWidget);
  });

  testWidgets('saluda con el nombre del michi y su cumpleaños', (tester) async {
    await abrir(tester, [
      Michi(id: '1', nombre: 'Pelusa', nacimiento: DateTime(2023, 11, 10)),
    ]);
    expect(find.text('¡Miau, Pelusa te saluda!'), findsOneWidget);
    expect(find.text('¡Hoy es el cumpleaños de Pelusa!'), findsOneWidget);
    expect(find.text('Cumple 3 años 🎉'), findsOneWidget);
    expect(find.textContaining('¿Aún no registras'), findsNothing);
  });

  testWidgets('con varios michis saluda a todos, sin cumpleaños', (
    tester,
  ) async {
    await abrir(tester, [
      Michi(id: '1', nombre: 'Pelusa', nacimiento: DateTime(2023, 3, 1)),
      const Michi(id: '2', nombre: 'Tom', emoji: '🐯'),
    ]);
    expect(find.text('Tus 2 michis te saludan'), findsOneWidget);
    expect(find.textContaining('cumpleaños'), findsNothing);
    expect(find.text('🐯'), findsOneWidget);
  });
}
