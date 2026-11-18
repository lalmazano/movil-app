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

  testWidgets('Inicio muestra el club y sus tres listas', (tester) async {
    await tester.pumpWidget(
      ClubDelFrijolApp(repository: MemoriaListaRepository()),
    );
    await tester.pump();
    expect(find.text('🫘 El Club del Frijol'), findsOneWidget);
    expect(find.text('Películas'), findsOneWidget);
    expect(find.text('Deseos'), findsOneWidget);
    expect(find.text('Hacer juntos'), findsOneWidget);
    expect(find.textContaining('Modo local'), findsOneWidget);
  });

  testWidgets('Agregar y marcar una película como vista', (tester) async {
    final repo = MemoriaListaRepository();
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pump();

    await tester.tap(find.text('Películas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no hay películas'), findsOneWidget);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-titulo')), 'Shrek 2');
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton-guardar-item')));
    await tester.pumpAndSettle();

    expect(find.text('Shrek 2'), findsOneWidget);
    expect(find.text('0 de 1 vistas'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1 vistas'), findsOneWidget);

    final items = await repo.watch(TipoLista.peliculas).first;
    expect(items.single.hecho, isTrue);
    expect(items.single.hechoEn, isNotNull);
  });

  testWidgets('Cargar la lista Disney agrega películas', (tester) async {
    final repo = MemoriaListaRepository();
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pump();
    await tester.tap(find.text('Películas'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cargar lista Disney'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();

    final items = await repo.watch(TipoLista.peliculas).first;
    expect(items.length, greaterThan(80));
    expect(find.text('Princesas'), findsWidgets);
  });

  testWidgets('Las listas ocultas en la configuración no aparecen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ClubDelFrijolApp(
        repository: MemoriaListaRepository(
          config: const ConfigClub(deseos: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Películas'), findsOneWidget);
    expect(find.text('Deseos'), findsNothing);
    expect(find.text('Hacer juntos'), findsOneWidget);
  });
}
