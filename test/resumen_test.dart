import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/core/routes/app_router.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/config_scope.dart';
import 'package:movil_app/features/resumen/domain/resumen_anual.dart';
import 'package:movil_app/features/resumen/presentation/resumen_page.dart';
import 'package:movil_app/features/resumen/presentation/tarjeta_resumen.dart';

const luis = Autor(uid: 'u1', nombre: 'Luis Almazán');
const ana = Autor(uid: 'u2', nombre: 'Ana López');

int _id = 0;

ItemLista item(
  String titulo, {
  String categoria = 'Otros',
  DateTime? hechoEn,
  Autor? hechoPor,
  List<int> huellitas = const [],
  int fotos = 0,
  bool repetible = false,
  int veces = 0,
  DateTime? ultimaVez,
}) => ItemLista(
  id: '${_id++}',
  titulo: titulo,
  categoria: categoria,
  creadoEn: DateTime(2020),
  hecho: hechoEn != null,
  hechoEn: hechoEn,
  hechoPor: hechoPor,
  calificaciones: {
    for (final (i, h) in huellitas.indexed)
      'u$i': Calificacion(
        autor: Autor(uid: 'u$i'),
        huellitas: h,
      ),
  },
  fotos: fotos,
  repetible: repetible,
  veces: veces,
  ultimaVez: ultimaVez,
);

void main() {
  group('calcularResumen', () {
    test('Un año vacío no falla', () {
      final r = calcularResumen(2026, const [], const [], const []);
      expect(r.vacio, isTrue);
      expect(r.total, 0);
      expect(r.totalDe(TipoLista.peliculas), 0);
      expect(r.mejores, isEmpty);
      expect(r.categoriaFavorita, isNull);
      expect(r.mesMasActivo, isNull);
      expect(r.primero, isNull);
      expect(r.ultimo, isNull);
      expect(r.quienMarcoMas, isNull);
      expect(r.fotos, 0);
      expect(r.totalCalificaciones, 0);
    });

    test('Solo cuenta lo hecho en el año pedido', () {
      final r = calcularResumen(
        2026,
        [
          item('Coco', hechoEn: DateTime(2026, 2, 1)),
          item('Shrek', hechoEn: DateTime(2025, 12, 31)),
          item('Pendiente'),
        ],
        [item('Playa', hechoEn: DateTime(2026, 7, 4))],
        [item('Picnic', hechoEn: DateTime(2027, 1, 1))],
      );
      expect(r.total, 2);
      expect(r.totalDe(TipoLista.peliculas), 1);
      expect(r.totalDe(TipoLista.deseos), 1);
      expect(r.totalDe(TipoLista.planes), 0);
      expect(r.primero!.item.titulo, 'Coco');
      expect(r.ultimo!.item.titulo, 'Playa');
      expect(r.ultimo!.tipo, TipoLista.deseos);
    });

    test('Mejores: por promedio, empates por fecha, máximo 3', () {
      final r = calcularResumen(
        2026,
        [
          item('B', hechoEn: DateTime(2026, 5), huellitas: [5]),
          item('A', hechoEn: DateTime(2026, 3), huellitas: [5, 5]),
          item('C', hechoEn: DateTime(2026, 1), huellitas: [4, 5]),
          item('D', hechoEn: DateTime(2026, 2), huellitas: [3]),
          item('Sin calificar', hechoEn: DateTime(2026, 2)),
        ],
        const [],
        const [],
      );
      expect(r.mejores.map((l) => l.item.titulo), ['A', 'B', 'C']);
      expect(r.totalCalificaciones, 6);
    });

    test('Categoría y mes favoritos, empates y quién marcó más', () {
      final r = calcularResumen(
        2026,
        [
          item(
            'Coco',
            categoria: 'Pixar',
            hechoEn: DateTime(2026, 3, 1),
            hechoPor: luis,
            fotos: 2,
          ),
          item(
            'Shrek',
            categoria: 'DreamWorks',
            hechoEn: DateTime(2026, 12, 1),
            hechoPor: ana,
          ),
          item(
            'Up',
            categoria: 'Pixar',
            hechoEn: DateTime(2026, 12, 2),
            hechoPor: luis,
            fotos: 1,
          ),
          item(
            'Madagascar',
            categoria: 'DreamWorks',
            hechoEn: DateTime(2026, 3, 5),
          ),
        ],
        const [],
        const [],
      );
      // Empate 2 a 2: DreamWorks llegó primero a 2.
      expect(r.categoriaFavorita, 'DreamWorks');
      expect(r.vecesCategoriaFavorita, 2);
      // Marzo y diciembre empatan: gana el primero.
      expect(r.mesMasActivo, 3);
      expect(r.vecesMesMasActivo, 2);
      expect(r.fotos, 3);
      expect(r.quienMarcoMas?.key, 'Luis');
      expect(r.quienMarcoMas?.value, 2);
      expect(r.empateMarcado, isFalse);
    });

    test('Empate al marcar', () {
      final r = calcularResumen(
        2026,
        [
          item('A', hechoEn: DateTime(2026, 1), hechoPor: luis),
          item('B', hechoEn: DateTime(2026, 2), hechoPor: ana),
        ],
        const [],
        const [],
      );
      expect(r.quienMarcoMas, isNull);
      expect(r.empateMarcado, isTrue);
    });

    test('Repetibles cuentan si su última vez fue en el año', () {
      final planes = [
        item(
          'Desayunar juntos',
          repetible: true,
          veces: 7,
          ultimaVez: DateTime(2026, 6, 1),
        ),
        item(
          'Bailar',
          repetible: true,
          veces: 3,
          ultimaVez: DateTime(2025, 6, 1),
        ),
        item('Nunca', repetible: true),
      ];
      final r = calcularResumen(2026, const [], const [], planes);
      expect(r.totalDe(TipoLista.planes), 1);
      expect(r.repeticiones, 7);
      expect(r.mesMasActivo, 6);
      expect(aniosConDatos(planes), [2026, 2025]);
    });
  });

  group('Pantallas', () {
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

    Future<MemoriaListaRepository> repoConDatos({
      ConfigClub config = const ConfigClub(),
    }) async {
      final repo = MemoriaListaRepository(
        reloj: () => DateTime(2026, 3, 10),
        config: config,
        autorActual: luis,
      );
      await repo.addMany(TipoLista.peliculas, [
        (titulo: 'Coco', categoria: 'Pixar', nota: ''),
        (titulo: 'Up', categoria: 'Pixar', nota: ''),
        (titulo: 'Shrek', categoria: 'DreamWorks', nota: ''),
      ]);
      await repo.add(TipoLista.deseos, (
        titulo: 'Ver la playa',
        categoria: 'Viajes',
        nota: '',
      ));
      final pelis = await repo.watch(TipoLista.peliculas).first;
      await repo.setHecho(TipoLista.peliculas, pelis[0].id, true);
      await repo.setHecho(TipoLista.peliculas, pelis[1].id, true);
      await repo.calificar(
        TipoLista.peliculas,
        pelis[0].id,
        const Calificacion(autor: luis, huellitas: 5),
      );
      final deseos = await repo.watch(TipoLista.deseos).first;
      await repo.setHecho(TipoLista.deseos, deseos.single.id, true);
      return repo;
    }

    Widget app(MemoriaListaRepository repo, {CompartirResumen? compartir}) =>
        MaterialApp(
          builder: (context, child) =>
              ConfigClubProvider(repository: repo, child: child!),
          onGenerateRoute: AppRouter(repo).onGenerateRoute,
          home: Scaffold(
            body: ListView(
              children: [
                TarjetaResumen(
                  repository: repo,
                  reloj: () => DateTime(2026, 11, 28),
                  compartir: compartir,
                ),
              ],
            ),
          ),
        );

    testWidgets('La tarjeta abre el resumen con los totales', (tester) async {
      final repo = await repoConDatos();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();

      expect(find.text('Su año 2026 en el club'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tarjeta-resumen')));
      await tester.pumpAndSettle();

      expect(find.text('Su 2026 en el club'), findsOneWidget);
      expect(find.text('Hicieron 3 cosas juntos 💛'), findsOneWidget);
      expect(find.text('🎬 2 películas vistas'), findsOneWidget);
      expect(find.text('🌠 1 deseo cumplido'), findsOneWidget);
      expect(find.text('🧺 0 planes hechos'), findsOneWidget);

      // Siguiente página: las películas.
      await tester.fling(find.byType(PageView), const Offset(0, -500), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Vieron 2 películas juntos'), findsOneWidget);
    });

    testWidgets('Las listas ocultas no aparecen en el resumen', (tester) async {
      final repo = await repoConDatos(config: const ConfigClub(deseos: false));
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tarjeta-resumen')));
      await tester.pumpAndSettle();

      expect(find.text('Hicieron 2 cosas juntos 💛'), findsOneWidget);
      expect(find.textContaining('deseo'), findsNothing);
    });

    testWidgets('Un año sin datos muestra un mensaje amable', (tester) async {
      final repo = MemoriaListaRepository();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tarjeta-resumen')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Aún no hay recuerdos'), findsOneWidget);
      expect(find.byKey(const Key('boton-compartir-resumen')), findsNothing);
    });

    testWidgets('Compartir captura la tarjeta final', (tester) async {
      final repo = await repoConDatos();
      Uint8List? png;
      String? texto;
      await tester.pumpWidget(
        app(
          repo,
          compartir: (bytes, t) async {
            png = bytes;
            texto = t;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tarjeta-resumen')));
      await tester.pumpAndSettle();

      final pagina = tester.widget<PageView>(find.byType(PageView));
      pagina.controller!.jumpToPage(100);
      await tester.pumpAndSettle();
      expect(find.byType(TarjetaFinalResumen), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('boton-compartir-resumen')));
        // Da tiempo a que se genere la imagen.
        for (var i = 0; i < 50 && png == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();
      expect(png, isNotNull);
      expect(png!.sublist(1, 4), 'PNG'.codeUnits);
      expect(texto, contains('2 películas vistas'));
    });

    testWidgets('Con la bandera en false la tarjeta no aparece', (
      tester,
    ) async {
      final repo = MemoriaListaRepository(
        config: const ConfigClub(resumen: false),
      );
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tarjeta-resumen')), findsNothing);
      expect(find.textContaining('en el club'), findsNothing);
    });

    testWidgets('La tarjeta aparece en el inicio', (tester) async {
      final repo = MemoriaListaRepository();
      await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('tarjeta-resumen')),
        200,
      );
      expect(find.byKey(const Key('tarjeta-resumen')), findsOneWidget);
    });
  });
}
