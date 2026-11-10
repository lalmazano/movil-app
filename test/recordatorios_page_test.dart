import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/recordatorios/domain/recordatorio.dart';
import 'package:movil_app/features/recordatorios/domain/servicio_recordatorios.dart';
import 'package:movil_app/features/recordatorios/presentation/recordatorios_page.dart';

import 'cuidados_fakes.dart';

void main() {
  final ahora = DateTime(2026, 11, 10, 9);

  testWidgets('crear, listar, apagar y borrar recordatorios', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = RecordatoriosEnMemoria()
      ..datos.add(
        Recordatorio(
          id: 'viejo',
          tipo: TipoRecordatorio.vacuna,
          titulo: 'Vacuna antigua',
          fecha: DateTime(2026, 10, 1, 10),
        ),
      );
    final notificador = NotificadorFalso();
    final servicio = ServicioRecordatorios(
      repository: repo,
      notificador: notificador,
      michis: MichisEnMemoria([pelusa, garfield]),
      reloj: () => ahora,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RecordatoriosPage(servicio: servicio),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('🕰️ Pasados'), findsOneWidget);
    expect(find.text('⏰ Próximos'), findsNothing);
    expect(find.text('Vacuna antigua'), findsOneWidget);

    // Crear uno nuevo: comida diaria de Pelusa.
    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🍗 Comida'));
    await tester.enterText(find.byType(TextField), 'Croquetas');
    await tester.tap(find.text('🐾 Todos los michis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😺 Pelusa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cada día'));
    await tester.pump();
    await tester.tap(find.text('Guardar recordatorio'));
    await tester.pumpAndSettle();

    final nuevo = repo.datos.firstWhere((r) => r.id != 'viejo');
    expect(nuevo.tipo, TipoRecordatorio.comida);
    expect(nuevo.michiId, 'p');
    expect(nuevo.repeticion, Repeticion.diario);
    expect(nuevo.fecha, DateTime(2026, 11, 10, 10));
    final n = notificador.programadas[nuevo.idNotificacion]!;
    expect(n.titulo, '🐱 ¡Hora de la comida de Pelusa!');
    expect(n.cuerpo, 'Croquetas 🐾');

    expect(find.text('⏰ Próximos'), findsOneWidget);
    expect(find.text('Croquetas'), findsOneWidget);
    expect(find.textContaining('😺 Pelusa · Cada día'), findsOneWidget);

    // Apagar con el interruptor.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repo.datos.firstWhere((r) => r.id == nuevo.id).activo, isFalse);
    expect(notificador.programadas, isEmpty);

    // Encender de nuevo.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(notificador.programadas.keys, [nuevo.idNotificacion]);

    // Editar y borrar.
    await tester.tap(find.text('Croquetas'));
    await tester.pumpAndSettle();
    expect(find.text('Editar recordatorio'), findsOneWidget);
    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(repo.datos.map((r) => r.id), ['viejo']);
    expect(notificador.programadas, isEmpty);
    expect(find.text('Croquetas'), findsNothing);
  });

  testWidgets('no deja guardar uno de una vez en el pasado', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = RecordatoriosEnMemoria();
    final servicio = ServicioRecordatorios(
      repository: repo,
      notificador: NotificadorFalso(),
      michis: MichisEnMemoria([]),
      reloj: () => ahora,
    );
    await tester.pumpWidget(
      MaterialApp(home: RecordatoriosPage(servicio: servicio)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay recordatorios'), findsOneWidget);

    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    // Cambiar la hora a las 8:00 (ya pasó) con el selector.
    await tester.tap(find.text('Hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final campos = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(campos.at(0), '8');
    await tester.enterText(campos.at(1), '00');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Guardar recordatorio'));
    await tester.tap(find.text('Guardar recordatorio'));
    await tester.pump();
    expect(find.textContaining('Esa hora ya pasó'), findsOneWidget);
    expect(repo.datos, isEmpty);
  });
}
