import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/recordatorios/domain/recordatorio.dart';
import 'package:movil_app/features/recordatorios/domain/servicio_recordatorios.dart';
import 'package:movil_app/features/salud/domain/entrada_salud.dart';
import 'package:movil_app/features/salud/presentation/salud_page.dart';

import 'cuidados_fakes.dart';

void main() {
  final ahora = DateTime(2026, 11, 10, 9);

  testWidgets('anotar, filtrar, editar, recordar y borrar', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final michis = MichisEnMemoria([pelusa, garfield]);
    final repo = SaludEnMemoria()
      ..datos.add(
        EntradaSalud(
          id: 'g1',
          tipo: TipoSalud.sintoma,
          fecha: DateTime(2026, 9, 1),
          titulo: 'Estornudos',
          michiId: 'g',
        ),
      );
    final recordatorios = RecordatoriosEnMemoria();
    final notificador = NotificadorFalso();
    final servicio = ServicioRecordatorios(
      repository: recordatorios,
      notificador: notificador,
      michis: michis,
      reloj: () => ahora,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SaludPage(
          repository: repo,
          michis: michis,
          recordatorios: servicio,
          reloj: () => ahora,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estornudos'), findsOneWidget);

    // Nueva vacuna para Pelusa con costo.
    await tester.tap(find.text('Anotar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('💉 Vacuna'));
    await tester.pump();
    await tester.tap(find.text('🐾 Sin michi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😺 Pelusa').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('salud_titulo')),
      'Triple felina',
    );
    await tester.enterText(
      find.byKey(const ValueKey('salud_notas')),
      'Se portó bien',
    );
    await tester.enterText(find.byKey(const ValueKey('salud_costo')), '25,5');
    // Las vacunas ofrecen crear un recordatorio de refuerzo.
    expect(find.text('Crear recordatorio'), findsOneWidget);
    await tester.ensureVisible(find.text('Guardar entrada'));
    await tester.tap(find.text('Guardar entrada'));
    await tester.pumpAndSettle();

    final vacuna = repo.datos.firstWhere((e) => e.id != 'g1');
    expect(vacuna.tipo, TipoSalud.vacuna);
    expect(vacuna.michiId, 'p');
    expect(vacuna.costo, 25.5);
    expect(vacuna.fecha, DateTime(2026, 11, 10));
    expect(find.text('Triple felina'), findsOneWidget);
    expect(find.text('💰 25.50'), findsOneWidget);
    expect(find.textContaining('2 entradas · gasto 25.50'), findsOneWidget);

    // Filtrar por tipo.
    await tester.tap(find.text('📝 Síntoma / nota'));
    await tester.pumpAndSettle();
    expect(find.text('Triple felina'), findsNothing);
    expect(find.text('Estornudos'), findsOneWidget);
    await tester.tap(find.text('📝 Síntoma / nota'));
    await tester.pumpAndSettle();

    // Filtrar por michi.
    await tester.tap(find.text('🐾 Todos los michis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😺 Pelusa').last);
    await tester.pumpAndSettle();
    expect(find.text('Triple felina'), findsOneWidget);
    expect(find.text('Estornudos'), findsNothing);

    // Editar y crear recordatorio desde la vacuna.
    await tester.tap(find.text('Triple felina'));
    await tester.pumpAndSettle();
    expect(find.text('Editar entrada'), findsOneWidget);
    await tester.ensureVisible(find.text('Crear recordatorio'));
    await tester.tap(find.text('Crear recordatorio'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo recordatorio'), findsOneWidget);
    expect(find.text('Refuerzo: Triple felina'), findsOneWidget);
    await tester.ensureVisible(find.text('Guardar recordatorio'));
    await tester.tap(find.text('Guardar recordatorio'));
    await tester.pumpAndSettle();

    final r = recordatorios.datos.single;
    expect(r.tipo, TipoRecordatorio.vacuna);
    expect(r.michiId, 'p');
    expect(r.fecha, DateTime(2027, 11, 10, 10));
    expect(
      notificador.programadas[r.idNotificacion]!.titulo,
      '💉 ¡Toca vacuna para Pelusa!',
    );
    expect(
      find.textContaining('Recordatorio de vacuna creado'),
      findsOneWidget,
    );

    // Cambiar el título y guardar.
    await tester.enterText(
      find.byKey(const ValueKey('salud_titulo')),
      'Triple felina (1ª dosis)',
    );
    await tester.ensureVisible(find.text('Guardar entrada'));
    await tester.tap(find.text('Guardar entrada'));
    await tester.pumpAndSettle();
    expect(find.text('Triple felina (1ª dosis)'), findsOneWidget);

    // Borrar.
    await tester.tap(find.text('Triple felina (1ª dosis)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(repo.datos.map((e) => e.id), ['g1']);
    expect(find.textContaining('Nada con ese filtro'), findsOneWidget);
  });
}
