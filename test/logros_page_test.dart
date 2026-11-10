import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/logros/domain/logro.dart';
import 'package:movil_app/features/logros/presentation/logros_page.dart';
import 'package:movil_app/features/michis/domain/michi.dart';
import 'package:movil_app/features/recuerdos/domain/recuerdo.dart';

import 'peso_logros_fakes.dart';

void main() {
  testWidgets('muestra el resumen y las insignias', (tester) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final hoy = DateTime(2026, 11, 10);
    final michis = MichisEnMemoria(const [
      Michi(id: 'a', nombre: 'Pelusa'),
      Michi(id: 'b', nombre: 'Tom'),
    ]);
    final recuerdos = RecuerdosEnMemoria([
      Recuerdo(
        id: '1',
        imagePath: '/x.jpg',
        fecha: hoy,
        calificacion: 5,
        michiId: 'a',
      ),
    ]);
    final pesos = PesosEnMemoria([
      RegistroPeso(id: '1', michiId: 'a', fecha: hoy, kg: 4),
    ]);
    final esperados = calcularLogros(
      michis: michis.datos,
      recuerdos: recuerdos.datos,
      pesos: pesos.datos,
      hoy: hoy,
    );
    final hechos = esperados.where((l) => l.desbloqueado).length;
    expect(hechos, 3); // Primer recuerdo, ¡Purr-fecto!, Familia gatuna.

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LogrosPage(
          michis: michis,
          recuerdos: recuerdos,
          pesos: pesos,
          ahora: () => hoy,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 de ${esperados.length} logros 🏆'), findsOneWidget);
    expect(find.byType(InsigniaLogro), findsNWidgets(esperados.length));
    expect(find.text('¡Desbloqueado! ✨'), findsNWidgets(3));
    expect(find.text('Primer recuerdo'), findsOneWidget);
    // Bloqueado con progreso.
    expect(find.text('Báscula al día'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNWidgets(esperados.length - 3));
  });

  testWidgets('sin datos: 0 logros', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LogrosPage(
          michis: MichisEnMemoria(),
          recuerdos: RecuerdosEnMemoria(),
          pesos: PesosEnMemoria(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('0 de '), findsOneWidget);
    expect(find.text('¡Desbloqueado! ✨'), findsNothing);
  });
}
