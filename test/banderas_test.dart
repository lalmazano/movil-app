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

  Future<void> abrirPelicula(WidgetTester tester, ConfigClub config) async {
    final repo = MemoriaListaRepository(
      config: config,
      autorActual: const Autor(uid: 'u1', nombre: 'Luis'),
    );
    await repo.add(TipoLista.peliculas, (
      titulo: 'Shrek',
      categoria: 'DreamWorks',
      nota: '',
    ));
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Películas'));
    await tester.pumpAndSettle();
  }

  testWidgets('Con todo activado se ven ruleta, búsqueda y fotos', (
    tester,
  ) async {
    await abrirPelicula(tester, const ConfigClub());
    expect(find.byTooltip('Buscar'), findsOneWidget);
    expect(find.byTooltip('¿Qué vemos hoy?'), findsOneWidget);
    await tester.tap(find.text('Shrek'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recuerdos'), findsOneWidget);
    expect(find.text('Calificaciones'), findsOneWidget);
  });

  testWidgets('Las banderas en false ocultan cada función', (tester) async {
    await abrirPelicula(
      tester,
      const ConfigClub(
        ruleta: false,
        buscar: false,
        fotos: false,
        calificaciones: false,
        autores: false,
      ),
    );
    expect(find.byTooltip('Buscar'), findsNothing);
    expect(find.byTooltip('¿Qué vemos hoy?'), findsNothing);

    // Al marcar no se pide calificación.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué tal estuvo?'), findsNothing);

    await tester.tap(find.text('Todo 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shrek'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recuerdos'), findsNothing);
    expect(find.text('Calificaciones'), findsNothing);
    expect(find.text('Historial'), findsNothing);
  });
}
