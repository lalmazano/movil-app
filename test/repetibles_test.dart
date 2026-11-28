import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 2.5;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> abrirPlanes(
    WidgetTester tester,
    MemoriaListaRepository repo,
  ) async {
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hacer juntos'));
    await tester.pumpAndSettle();
  }

  Future<void> otraVez(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('boton-otra-vez')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar-otra-vez')));
    await tester.pumpAndSettle();
  }

  testWidgets('Crear un repetible y sumarlo dos veces: sigue pendiente', (
    tester,
  ) async {
    final repo = MemoriaListaRepository(reloj: () => DateTime(2026, 11, 12));
    await abrirPlanes(tester, repo);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-titulo')),
      'Desayunar juntos',
    );
    await tester.tap(find.byKey(const Key('switch-repetible')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton-guardar-item')));
    await tester.pumpAndSettle();

    // En lugar del círculo hay un botón +1.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byKey(const Key('boton-otra-vez')), findsOneWidget);
    expect(find.text('Hechos 0'), findsOneWidget);

    await otraVez(tester);
    expect(
      find.text('¡Otra vez! Ya van 1 \uFFFC', findRichText: true),
      findsOneWidget,
    );
    await otraVez(tester);
    expect(
      find.text('¡Otra vez! Ya van 2 \uFFFC', findRichText: true),
      findsOneWidget,
    );

    final item = (await repo.watch(TipoLista.planes).first).single;
    expect(item.repetible, isTrue);
    expect(item.veces, 2);
    expect(item.hecho, isFalse);

    // Sigue en pendientes y ahora también en hechos.
    expect(find.text('Pendientes 1'), findsOneWidget);
    expect(find.text('Hechos 1'), findsOneWidget);
    expect(
      find.textContaining('🔁 ×2 · última vez 12/11/2026'),
      findsOneWidget,
    );

    await tester.tap(find.text('Hechos 1'));
    await tester.pumpAndSettle();
    expect(find.text('Desayunar juntos'), findsOneWidget);

    // El detalle muestra el contador.
    await tester.tap(find.text('Desayunar juntos'));
    await tester.pumpAndSettle();
    expect(
      find.text('🔁 Hecho 2 veces · última vez 12/11/2026'),
      findsOneWidget,
    );
  });

  testWidgets('Un repetible sin hacer no aparece en hechos', (tester) async {
    final repo = MemoriaListaRepository();
    await repo.add(TipoLista.planes, (
      titulo: 'Ir al cine',
      categoria: 'Citas',
      nota: '',
    ), repetible: true);
    await abrirPlanes(tester, repo);

    expect(find.text('Pendientes 1'), findsOneWidget);
    expect(find.text('Hechos 0'), findsOneWidget);
    await tester.tap(find.text('Hechos 0'));
    await tester.pumpAndSettle();
    expect(find.text('Ir al cine'), findsNothing);
  });

  testWidgets('Con sesión, después de +1 pide calificación', (tester) async {
    final repo = MemoriaListaRepository(
      autorActual: const Autor(uid: 'u1', nombre: 'Luis'),
    );
    await repo.add(TipoLista.planes, (
      titulo: 'Ir al cine',
      categoria: 'Citas',
      nota: '',
    ), repetible: true);
    await abrirPlanes(tester, repo);

    await otraVez(tester);
    expect(find.text('¿Qué tal estuvo?'), findsOneWidget);
  });

  testWidgets('Con la bandera apagada se comporta como uno normal', (
    tester,
  ) async {
    final repo = MemoriaListaRepository(
      config: const ConfigClub(repetibles: false),
    );
    await repo.add(TipoLista.planes, (
      titulo: 'Ir al cine',
      categoria: 'Citas',
      nota: '',
    ), repetible: true);
    await abrirPlanes(tester, repo);

    expect(find.byKey(const Key('boton-otra-vez')), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('🔁'), findsNothing);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campo-titulo')), findsOneWidget);
    expect(find.byKey(const Key('switch-repetible')), findsNothing);
  });
}
