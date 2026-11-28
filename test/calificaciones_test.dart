import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/widgets/insignias_item.dart';

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

  const luis = Autor(uid: 'u1', nombre: 'Luis Almazán');

  Future<MemoriaListaRepository> abrirPeliculas(WidgetTester tester) async {
    final repo = MemoriaListaRepository(
      autorActual: luis,
      reloj: () => DateTime(2026, 11, 25),
    );
    await repo.add(TipoLista.peliculas, (
      titulo: 'Shrek 2',
      categoria: 'DreamWorks',
      nota: '',
    ));
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pump();
    await tester.tap(find.text('Películas'));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('Al marcar pide calificación y la guarda', (tester) async {
    final repo = await abrirPeliculas(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué tal estuvo?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('huellita-4')));
    await tester.enterText(
      find.byKey(const Key('campo-comentario')),
      '¡Muy chistosa!',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué tal estuvo?'), findsNothing);

    final item = (await repo.watch(TipoLista.peliculas).first).single;
    expect(item.hecho, isTrue);
    expect(item.hechoPor?.uid, 'u1');
    final c = item.calificaciones['u1']!;
    expect(c.huellitas, 4);
    expect(c.comentario, '¡Muy chistosa!');
  });

  testWidgets('"Omitir" no guarda calificación', (tester) async {
    final repo = await abrirPeliculas(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué tal estuvo?'), findsNothing);

    final item = (await repo.watch(TipoLista.peliculas).first).single;
    expect(item.hecho, isTrue);
    expect(item.calificaciones, isEmpty);
  });

  testWidgets('El detalle muestra calificaciones y quién lo hizo', (
    tester,
  ) async {
    final repo = await abrirPeliculas(tester);
    final id = (await repo.watch(TipoLista.peliculas).first).single.id;
    await repo.setHecho(TipoLista.peliculas, id, true);
    await repo.calificar(
      TipoLista.peliculas,
      id,
      const Calificacion(
        autor: Autor(uid: 'u2', nombre: 'Frijolita Pérez'),
        huellitas: 5,
        comentario: 'La mejor',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vistas 1'));
    await tester.pumpAndSettle();

    // Insignias en la tarjeta: promedio.
    expect(
      find.descendant(
        of: find.byType(InsigniasItem),
        matching: find.text('\uFFFC 5', findRichText: true),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Shrek 2'));
    await tester.pumpAndSettle();

    expect(find.text('Calificaciones'), findsOneWidget);
    expect(find.text('Frijolita'), findsOneWidget);
    expect(find.text('La mejor'), findsOneWidget);
    expect(find.text('Agregado por Luis el 25/11/2026'), findsOneWidget);
    expect(find.text('Vista por Luis el 25/11/2026'), findsOneWidget);

    // Calificar desde el detalle.
    await tester.tap(find.text('Calificar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('huellita-4')));
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Cambiar mi calificación'), findsOneWidget);
    expect(find.text('\uFFFC 4.5 de 5', findRichText: true), findsOneWidget);
    final item = (await repo.watch(TipoLista.peliculas).first).single;
    expect(item.calificaciones['u1']?.huellitas, 4);
  });

  testWidgets('Las insignias no muestran nada sin datos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InsigniasItem(
            item: ItemLista(
              id: '1',
              titulo: 'Picnic',
              categoria: 'Citas',
              creadoEn: DateTime(2026),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
}
