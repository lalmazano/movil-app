import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/michis/domain/michi.dart';
import 'package:movil_app/features/peso/domain/registro_peso.dart';
import 'package:movil_app/features/peso/presentation/peso_page.dart';

import 'peso_logros_fakes.dart';

Future<void> _abrir(
  WidgetTester tester, {
  required MichiRepository michis,
  required PesoRepository pesos,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: PesoPage(
        michis: michis,
        pesos: pesos,
        ahora: () => DateTime(2026, 11, 10, 15),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin michis muestra cómo crear uno', (tester) async {
    await _abrir(tester, michis: MichisEnMemoria(), pesos: PesosEnMemoria());
    expect(find.textContaining('Mis michis'), findsOneWidget);
    expect(find.text('Registrar peso'), findsNothing);
  });

  testWidgets('registrar pesos, ver gráfica y cambio, y borrar', (
    tester,
  ) async {
    final pesos = PesosEnMemoria([
      RegistroPeso(
        id: 'viejo',
        michiId: 'tom',
        fecha: DateTime(2026, 1, 1),
        kg: 6,
      ),
    ]);
    await _abrir(
      tester,
      michis: MichisEnMemoria(const [
        Michi(id: 'pelusa', nombre: 'Pelusa', emoji: '😺'),
        Michi(id: 'tom', nombre: 'Tom'),
      ]),
      pesos: pesos,
    );
    expect(find.text('😺 Pelusa'), findsOneWidget);
    expect(find.textContaining('Sin pesajes todavía'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);

    // Primer pesaje con validación.
    await tester.tap(find.text('Registrar peso'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_kg')), '45');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('entre 0.1 y 30 kg'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo_kg')), '4,2');
    await tester.enterText(find.byKey(const Key('campo_nota')), 'En ayunas');
    expect(find.text('10/11/2026'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(pesos.datos.last.kg, 4.2);
    expect(pesos.datos.last.michiId, 'pelusa');
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('4.20 kg'), findsWidgets);
    expect(find.text('10/11/2026 · En ayunas'), findsOneWidget);

    // Segundo pesaje con fecha elegida en el calendario: anterior al primero.
    await tester.tap(find.text('Registrar peso'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo_kg')), '4.5');
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('03/11/2026'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Último (10/11) 4.20 vs anterior (03/11) 4.50 → bajó.
    expect(find.text('↓ 0.30 kg 🏃 vs. anterior'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots.map((s) => s.y), [4.5, 4.2]);

    // Cambiar de michi muestra sus registros.
    await tester.tap(find.text('🐱 Tom'));
    await tester.pumpAndSettle();
    expect(find.text('6.00 kg'), findsWidgets);
    expect(find.textContaining('vs. anterior'), findsNothing);

    // Borrar.
    await tester.tap(find.byTooltip('Borrar registro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin pesajes todavía'), findsOneWidget);
    expect(pesos.datos.where((r) => r.michiId == 'tom'), isEmpty);
  });
}
