import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movil_app/core/tmdb/tmdb_client.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/config_scope.dart';
import 'package:movil_app/features/listas/presentation/item_detalle_page.dart';
import 'package:movil_app/features/sugerencias/domain/sugerencias.dart';

/// TMDB responde en UTF-8.
http.Response _json(Object datos) =>
    http.Response.bytes(utf8.encode(jsonEncode(datos)), 200);

Map<String, Object?> _peli(
  int id,
  String titulo, {
  double? popularidad,
  double? votos,
}) => {
  'id': id,
  'title': titulo,
  'release_date': '2010-01-01',
  'poster_path': null,
  'overview': '',
  'popularity': ?popularidad,
  'vote_average': ?votos,
};

/// Respuestas falsas de TMDB (sin pósters para no cargar imágenes).
http.Response _respuestaFalsa(http.Request req) => switch (req.url.path) {
  '/3/movie/809/recommendations' => _json({
    'results': [
      _peli(810, 'Shrek Tercero', popularidad: 50),
      _peli(9502, 'Kung Fu Panda', popularidad: 80),
      _peli(12, 'buscando a nemo', popularidad: 99),
    ],
  }),
  '/3/movie/100/recommendations' => _json({'results': <Object>[]}),
  '/3/movie/100/similar' => _json({
    'results': [_peli(9502, 'Kung Fu Panda', popularidad: 80)],
  }),
  _ => http.Response('{}', 404),
};

ItemLista _item(
  String id,
  String titulo, {
  int? tmdbId,
  List<int> huellitas = const [],
  bool hecho = false,
  DateTime? hechoEn,
}) => ItemLista(
  id: id,
  titulo: titulo,
  categoria: 'Otras',
  creadoEn: DateTime(2024, 1, int.parse(id) + 1),
  hecho: hecho,
  hechoEn: hechoEn,
  pelicula: tmdbId == null ? null : InfoPelicula(tmdbId: tmdbId),
  calificaciones: {
    for (final (i, h) in huellitas.indexed)
      'u$i': Calificacion(
        autor: Autor(uid: 'u$i'),
        huellitas: h,
      ),
  },
);

ResultadoTmdb _r(int id, String titulo, {double? pop, double? votos}) =>
    ResultadoTmdb(id: id, titulo: titulo, popularidad: pop, votos: votos);

void main() {
  setUp(limpiarCacheSugerencias);

  group('TmdbClient.recomendaciones', () {
    test('pide recomendaciones en es-MX y convierte los resultados', () async {
      late http.Request pedido;
      final cliente = TmdbClient(
        'abc',
        client: MockClient((req) async {
          pedido = req;
          return _respuestaFalsa(req);
        }),
      );
      final r = await cliente.recomendaciones(809);
      expect(pedido.url.path, '/3/movie/809/recommendations');
      expect(pedido.url.queryParameters['language'], 'es-MX');
      expect(pedido.url.queryParameters['api_key'], 'abc');
      expect(r.map((e) => e.id), [810, 9502, 12]);
      expect(r.first.titulo, 'Shrek Tercero');
      expect(r.first.anio, 2010);
      expect(r.first.posterUrl, isNull);
      expect(r.first.popularidad, 50);
    });

    test('si no hay recomendaciones usa las similares', () async {
      final rutas = <String>[];
      final cliente = TmdbClient(
        'abc',
        client: MockClient((req) async {
          rutas.add(req.url.path);
          return _respuestaFalsa(req);
        }),
      );
      final r = await cliente.recomendaciones(100);
      expect(rutas, ['/3/movie/100/recommendations', '/3/movie/100/similar']);
      expect(r.single.titulo, 'Kung Fu Panda');
    });

    test('errores lanzan TmdbException', () {
      final cliente = TmdbClient(
        'abc',
        client: MockClient((_) async => http.Response('{}', 500)),
      );
      expect(cliente.recomendaciones(1), throwsA(isA<TmdbException>()));
    });
  });

  group('Lógica de sugerencias', () {
    test('yaEnLista compara id de TMDB o título sin mayúsculas', () {
      final items = [
        _item('0', 'Shrek 2', tmdbId: 809),
        _item('1', 'Buscando a Nemo'),
      ];
      expect(yaEnLista(_r(809, 'Otro nombre'), items), isTrue);
      expect(yaEnLista(_r(12, ' BUSCANDO A NEMO '), items), isTrue);
      expect(yaEnLista(_r(13, 'Cars'), items), isFalse);
    });

    test('semillas: las mejor calificadas (≥ 4), máximo 5', () {
      final items = [
        for (var i = 0; i < 7; i++)
          _item('$i', 'P$i', tmdbId: i, huellitas: [4 + i % 2]),
        _item('7', 'Regular', tmdbId: 7, huellitas: [3, 4]),
        _item('8', 'Sin vincular', huellitas: [5]),
      ];
      final semillas = semillasSugerencias(items);
      expect(semillas, hasLength(5));
      // Primero las de 5 huellitas (las más recientes primero).
      expect(semillas.map((s) => s.titulo), ['P5', 'P3', 'P1', 'P6', 'P4']);
    });

    test('semillas: sin calificaciones, las vistas más recientes', () {
      final items = [
        _item('0', 'Vieja', tmdbId: 1, hecho: true, hechoEn: DateTime(2024)),
        _item('1', 'Nueva', tmdbId: 2, hecho: true, hechoEn: DateTime(2025)),
        _item('2', 'Pendiente', tmdbId: 3),
        _item('3', 'Mala', tmdbId: 4, huellitas: [2]),
      ];
      expect(semillasSugerencias(items).map((s) => s.titulo), [
        'Nueva',
        'Vieja',
      ]);
      expect(semillasSugerencias([_item('0', 'Sin vincular')]), isEmpty);
    });

    test('combinar: ordena por semillas, popularidad y votos; excluye', () {
      final items = [_item('0', 'Shrek 2', tmdbId: 809), _item('1', 'Cars')];
      final r = combinarSugerencias([
        [
          _r(1, 'Uno', pop: 10),
          _r(2, 'Dos', pop: 90),
          _r(809, 'Shrek 2'),
          _r(1, 'Uno', pop: 10), // repetida en la misma semilla
        ],
        [_r(1, 'Uno', pop: 10), _r(3, 'cars'), _r(4, 'Cuatro', votos: 8)],
        [_r(5, 'Cinco', pop: 90, votos: 9)],
      ], items);
      expect(r.map((s) => s.resultado.titulo), [
        'Uno',
        'Cinco',
        'Dos',
        'Cuatro',
      ]);
      expect(r.first.veces, 2);
    });

    test('Para ustedes: usa las favoritas y guarda en caché', () async {
      final rutas = <String>[];
      final cliente = TmdbClient(
        'abc',
        client: MockClient((req) async {
          rutas.add(req.url.path);
          return _respuestaFalsa(req);
        }),
      );
      final items = [
        _item('0', 'Shrek 2', tmdbId: 809, huellitas: [5]),
        _item('1', 'Otra', tmdbId: 100, huellitas: [4, 4]),
        _item('2', 'Regular', tmdbId: 300, huellitas: [2]),
        _item('3', 'Buscando a Nemo'),
      ];
      final r = await sugerenciasParaUstedes(cliente, items);
      expect(r.map((s) => s.resultado.titulo), [
        'Kung Fu Panda',
        'Shrek Tercero',
      ]);
      expect(r.first.veces, 2);
      expect(rutas, isNot(contains('/3/movie/300/recommendations')));

      rutas.clear();
      await sugerenciasParaUstedes(cliente, items);
      expect(rutas, isEmpty);
    });
  });

  group('Sección de sugerencias', () {
    late TmdbClient Function(String) fabricaOriginal;

    setUp(() {
      fabricaOriginal = TmdbClient.fabrica;
      TmdbClient.fabrica = (clave) => TmdbClient(
        clave,
        client: MockClient((req) async => _respuestaFalsa(req)),
      );
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1080, 2400);
      view.devicePixelRatio = 2.5;
    });

    tearDown(() {
      TmdbClient.fabrica = fabricaOriginal;
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    /// Repositorio con "Shrek 2" (vinculada, id '0') y "Buscando a Nemo".
    Future<MemoriaListaRepository> repoConPeliculas({
      String? clave = 'abc',
      bool vincular = true,
    }) async {
      final repo = MemoriaListaRepository(apiKeyTmdb: clave);
      await repo.add(TipoLista.peliculas, (
        titulo: 'Shrek 2',
        categoria: 'DreamWorks',
        nota: '',
      ), pelicula: vincular ? const InfoPelicula(tmdbId: 809) : null);
      await repo.add(TipoLista.peliculas, (
        titulo: 'Buscando a Nemo',
        categoria: 'Pixar',
        nota: '',
      ));
      return repo;
    }

    Future<void> abrir(
      WidgetTester tester,
      ListaRepository repo, {
      ConfigClub config = const ConfigClub(),
      TipoLista tipo = TipoLista.peliculas,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConfigClubScope(
            config: config,
            child: ItemDetallePage(
              key: ObjectKey(repo),
              tipo: tipo,
              itemId: '0',
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra sugerencias y agrega una con sus datos de TMDB', (
      tester,
    ) async {
      final repo = await repoConPeliculas();
      await abrir(tester, repo);

      expect(find.text('Si les gustó Shrek 2…'), findsOneWidget);
      expect(find.text('Shrek Tercero'), findsOneWidget);
      expect(find.text('Kung Fu Panda'), findsOneWidget);
      // "buscando a nemo" ya está (mismo título).
      expect(find.text('✓ En la lista'), findsOneWidget);
      expect(find.byKey(const Key('agregar-sugerencia-12')), findsNothing);

      await tester.tap(find.byKey(const Key('agregar-sugerencia-810')));
      await tester.pumpAndSettle();
      expect(find.text('Agregar "Shrek Tercero"'), findsOneWidget);
      await tester.tap(find.byKey(const Key('boton-confirmar-sugerencia')));
      await tester.pumpAndSettle();

      final nueva = (await repo.watch(TipoLista.peliculas).first).last;
      expect(nueva.titulo, 'Shrek Tercero');
      expect(nueva.categoria, 'DreamWorks');
      expect(nueva.pelicula?.tmdbId, 810);
      expect(nueva.pelicula?.anio, 2010);
      expect(find.text('✓ En la lista'), findsNWidgets(2));
      expect(find.byKey(const Key('agregar-sugerencia-810')), findsNothing);
    });

    testWidgets('se puede elegir otra categoría', (tester) async {
      final repo = await repoConPeliculas();
      await abrir(tester, repo);
      await tester.tap(find.byKey(const Key('agregar-sugerencia-9502')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Aventura'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('boton-confirmar-sugerencia')));
      await tester.pumpAndSettle();
      final nueva = (await repo.watch(TipoLista.peliculas).first).last;
      expect(nueva.titulo, 'Kung Fu Panda');
      expect(nueva.categoria, 'Aventura');
    });

    testWidgets('"Más sugerencias" abre Para ustedes sin las que ya están', (
      tester,
    ) async {
      final repo = await repoConPeliculas();
      await abrir(tester, repo);
      await tester.tap(find.byKey(const Key('boton-mas-sugerencias')));
      await tester.pumpAndSettle();

      expect(find.text('🎬 Para ustedes'), findsOneWidget);
      expect(find.text('Shrek Tercero'), findsOneWidget);
      expect(find.text('Kung Fu Panda'), findsOneWidget);
      expect(find.text('buscando a nemo'), findsNothing);

      await tester.tap(find.byKey(const Key('agregar-sugerencia-9502')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('boton-confirmar-sugerencia')));
      await tester.pumpAndSettle();
      final nueva = (await repo.watch(TipoLista.peliculas).first).last;
      expect(nueva.pelicula?.tmdbId, 9502);
      expect(nueva.categoria, 'DreamWorks');
      expect(find.text('✓ En la lista'), findsOneWidget);
    });

    testWidgets('error de TMDB se muestra compacto', (tester) async {
      TmdbClient.fabrica = (clave) => TmdbClient(
        clave,
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      await abrir(tester, await repoConPeliculas());
      expect(find.text('La clave de TMDB no es válida'), findsOneWidget);
      expect(find.byTooltip('Reintentar'), findsOneWidget);
    });

    testWidgets(
      'se oculta sin bandera, sin pósters, sin clave o sin vincular',
      (tester) async {
        final seccion = find.byKey(const Key('seccion-sugerencias'));

        await abrir(
          tester,
          await repoConPeliculas(),
          config: const ConfigClub(sugerencias: false),
        );
        expect(seccion, findsNothing);

        await abrir(
          tester,
          await repoConPeliculas(),
          config: const ConfigClub(posters: false),
        );
        expect(seccion, findsNothing);

        await abrir(tester, await repoConPeliculas(clave: null));
        expect(seccion, findsNothing);

        await abrir(tester, await repoConPeliculas(vincular: false));
        expect(seccion, findsNothing);

        await abrir(tester, await repoConPeliculas());
        expect(seccion, findsOneWidget);
      },
    );
  });
}
