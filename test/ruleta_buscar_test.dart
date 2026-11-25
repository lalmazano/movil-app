import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/item_detalle_page.dart';
import 'package:movil_app/features/listas/presentation/widgets/campo_busqueda.dart';
import 'package:movil_app/features/listas/presentation/widgets/ruleta_sheet.dart';

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

  Future<MemoriaListaRepository> repoConPeliculas() async {
    final repo = MemoriaListaRepository();
    await repo.addMany(TipoLista.peliculas, [
      (titulo: 'La Bella y la Bestia', categoria: 'Princesas', nota: ''),
      (titulo: 'Aladdín', categoria: 'Disney', nota: ''),
      (titulo: 'Shrek', categoria: 'DreamWorks', nota: 'La del ogro'),
      (titulo: 'Coco', categoria: 'Pixar', nota: ''),
    ]);
    return repo;
  }

  Future<void> abrirLista(WidgetTester tester, String lista) async {
    await tester.tap(find.text(lista));
    await tester.pumpAndSettle();
  }

  test('La búsqueda ignora mayúsculas y acentos', () {
    final item = ItemLista(
      id: '1',
      titulo: 'Aladdín',
      categoria: 'Disney',
      nota: 'Con el Genio y Jazmín',
      creadoEn: DateTime(2024),
    );
    expect(normalizarBusqueda('  ÁÉÍÓÚ Ñandú '), 'aeiou nandu');
    expect(coincideBusqueda(item, 'aladdin'), isTrue);
    expect(coincideBusqueda(item, 'JAZMIN'), isTrue);
    expect(coincideBusqueda(item, ''), isTrue);
    expect(coincideBusqueda(item, 'shrek'), isFalse);
  });

  testWidgets('Buscar filtra por título y nota, sin acentos', (tester) async {
    final repo = await repoConPeliculas();
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pump();
    await abrirLista(tester, 'Películas');

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('campo-busqueda')), 'bella');
    await tester.pump();
    expect(find.text('La Bella y la Bestia'), findsOneWidget);
    expect(find.text('Aladdín'), findsNothing);
    expect(find.text('Shrek'), findsNothing);

    await tester.enterText(find.byKey(const Key('campo-busqueda')), 'aladdin');
    await tester.pump();
    expect(find.text('Aladdín'), findsOneWidget);
    expect(find.text('La Bella y la Bestia'), findsNothing);

    // También busca en la nota.
    await tester.enterText(find.byKey(const Key('campo-busqueda')), 'OGRO');
    await tester.pump();
    expect(find.text('Shrek'), findsOneWidget);
    expect(find.text('Coco'), findsNothing);

    await tester.enterText(find.byKey(const Key('campo-busqueda')), 'nemo');
    await tester.pump();
    expect(find.text('Nada coincide con «nemo»'), findsOneWidget);

    // Borrar la búsqueda muestra todo otra vez.
    await tester.tap(find.byTooltip('Borrar búsqueda'));
    await tester.pump();
    expect(find.text('Coco'), findsOneWidget);
    expect(find.text('Aladdín'), findsOneWidget);

    // Cerrar el buscador lo limpia y deja la lista completa.
    await tester.enterText(find.byKey(const Key('campo-busqueda')), 'coco');
    await tester.pump();
    expect(find.text('Shrek'), findsNothing);
    await tester.tap(find.byTooltip('Cerrar búsqueda'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campo-busqueda')), findsNothing);
    expect(find.text('Shrek'), findsOneWidget);
    expect(find.text('🎬 Películas'), findsOneWidget);
    expect(find.byTooltip('Cargar lista Disney'), findsOneWidget);
  });

  testWidgets('La búsqueda se combina con el filtro de pendientes', (
    tester,
  ) async {
    final repo = await repoConPeliculas();
    final coco = (await repo.watch(TipoLista.peliculas).first).last;
    await repo.setHecho(TipoLista.peliculas, coco.id, true);
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pump();
    await abrirLista(tester, 'Películas');

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-busqueda')), 'coco');
    await tester.pump();
    // Coco ya está vista: en Pendientes no aparece.
    expect(find.text('Coco'), findsNothing);
    expect(find.text('Nada coincide con «coco»'), findsOneWidget);

    await tester.tap(find.textContaining('Todo'));
    await tester.pumpAndSettle();
    expect(find.text('Coco'), findsOneWidget);
  });

  testWidgets('La ruleta elige un pendiente y "Ver" abre el detalle', (
    tester,
  ) async {
    final repo = await repoConPeliculas();
    final items = await repo.watch(TipoLista.peliculas).first;
    // Solo Shrek queda pendiente, así la elección es segura.
    for (final i in items.where((i) => i.titulo != 'Shrek')) {
      await repo.setHecho(TipoLista.peliculas, i.id, true);
    }
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pump();
    await abrirLista(tester, 'Películas');

    await tester.tap(find.byTooltip('¿Qué vemos hoy?'));
    await tester.pumpAndSettle();
    expect(find.text('🎲 ¿Qué vemos hoy?'), findsOneWidget);

    await tester.tap(find.text('Girar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('ruleta-girando')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(find.byKey(const Key('ruleta-elegido')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('ruleta-elegido')),
        matching: find.text('Shrek'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetallePage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ItemDetallePage),
        matching: find.text('Shrek'),
      ),
      findsWidgets,
    );
  });

  testWidgets('La ruleta avisa cuando no hay pendientes', (tester) async {
    final repo = MemoriaListaRepository();
    await repo.add(TipoLista.planes, (
      titulo: 'Picnic',
      categoria: 'Citas',
      nota: '',
    ));
    final picnic = (await repo.watch(TipoLista.planes).first).single;
    await repo.setHecho(TipoLista.planes, picnic.id, true);
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pump();
    await abrirLista(tester, 'Hacer juntos');

    await tester.tap(find.byTooltip('¿Qué hacemos hoy?'));
    await tester.pumpAndSettle();
    expect(find.text('No hay pendientes 🎉'), findsOneWidget);
    expect(find.text('Girar'), findsNothing);
  });

  testWidgets('La ruleta respeta la categoría y el azar inyectado', (
    tester,
  ) async {
    final items = [
      for (final (i, (t, c)) in const [
        ('Paris', 'Viajes'),
        ('Tokio', 'Viajes'),
        ('Tacos', 'Comida'),
        ('Sushi', 'Comida'),
      ].indexed)
        ItemLista(id: '$i', titulo: t, categoria: c, creadoEn: DateTime(2024)),
      ItemLista(
        id: 'x',
        titulo: 'Ramen',
        categoria: 'Comida',
        hecho: true,
        creadoEn: DateTime(2024),
      ),
    ];
    ItemLista? elegido;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => elegido = await mostrarRuleta(
              context,
              tipo: TipoLista.deseos,
              items: items,
              categorias: const ['Viajes', 'Comida'],
              random: Random(7),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('🎲 ¿Qué hacemos hoy?'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Todas'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Viajes'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.pump();
    expect(find.text('2 pendientes en la ruleta'), findsOneWidget);

    for (var vuelta = 0; vuelta < 5; vuelta++) {
      await tester.tap(find.text(vuelta == 0 ? 'Girar' : 'Otra vez'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      final textos = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('ruleta-elegido')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data);
      // Nunca elige algo de otra categoría ni algo ya cumplido.
      expect(textos.contains('Tacos') || textos.contains('Sushi'), isTrue);
      expect(textos, isNot(contains('Ramen')));
    }

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(elegido?.categoria, 'Comida');
    expect(find.byType(RuletaSheet), findsNothing);
  });
}
