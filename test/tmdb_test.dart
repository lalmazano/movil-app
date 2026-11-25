import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/core/tmdb/tmdb_client.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';

/// Respuestas falsas de TMDB (sin pósters para no cargar imágenes en pruebas).
http.Response _respuestaFalsa(http.Request req) {
  if (req.url.path == '/3/search/movie') {
    return _json({
      'results': [
        {
          'id': 809,
          'title': 'Shrek 2',
          'release_date': '2004-05-19',
          'poster_path': null,
          'overview': 'Shrek y Fiona visitan a los papás.',
        },
        {'id': 1, 'title': 'Sin fecha', 'release_date': ''},
      ],
    });
  }
  if (req.url.path == '/3/movie/809') {
    return _json({
      'id': 809,
      'title': 'Shrek 2',
      'release_date': '2004-05-19',
      'runtime': 93,
      'poster_path': null,
      'overview': 'Shrek y Fiona visitan a los papás.',
    });
  }
  return http.Response('{}', 404);
}

/// TMDB responde en UTF-8.
http.Response _json(Object datos) =>
    http.Response.bytes(utf8.encode(jsonEncode(datos)), 200);

void main() {
  group('TmdbClient', () {
    test('busca y convierte los resultados', () async {
      late http.Request pedido;
      final cliente = TmdbClient(
        'abc',
        client: MockClient((req) async {
          pedido = req;
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 10,
                  'title': 'El Gato con Botas',
                  'release_date': '2011-10-28',
                  'poster_path': '/gato.jpg',
                  'overview': '',
                },
              ],
            }),
            200,
          );
        }),
      );
      final r = await cliente.buscar('gato con botas');
      expect(r.single.id, 10);
      expect(r.single.titulo, 'El Gato con Botas');
      expect(r.single.anio, 2011);
      expect(r.single.posterUrl, 'https://image.tmdb.org/t/p/w342/gato.jpg');
      expect(r.single.resumen, isNull);

      expect(pedido.url.host, 'api.themoviedb.org');
      expect(pedido.url.path, '/3/search/movie');
      expect(pedido.url.queryParameters['query'], 'gato con botas');
      expect(pedido.url.queryParameters['language'], 'es-MX');
      expect(pedido.url.queryParameters['include_adult'], 'false');
    });

    test('detalle trae duración; sin póster queda null', () async {
      final cliente = TmdbClient(
        'abc',
        client: MockClient((req) async => _respuestaFalsa(req)),
      );
      final info = await cliente.detalle(809);
      expect(info.tmdbId, 809);
      expect(info.anio, 2004);
      expect(info.duracionMin, 93);
      expect(info.posterUrl, isNull);
      expect(formatearDuracion(93), '1 h 33 min');
      expect(formatearDuracion(100), '1 h 40 min');
      expect(formatearDuracion(45), '45 min');
      expect(formatearDuracion(120), '2 h');
    });

    test('clave v3 va como api_key; token v4 como Bearer', () async {
      final pedidos = <http.Request>[];
      final mock = MockClient((req) async {
        pedidos.add(req);
        return http.Response('{"results": []}', 200);
      });
      await TmdbClient('abc123', client: mock).buscar('x');
      final token = 'eyJ${'a' * 120}';
      await TmdbClient(token, client: mock).buscar('x');

      expect(pedidos[0].url.queryParameters['api_key'], 'abc123');
      expect(pedidos[0].headers.containsKey('Authorization'), isFalse);
      expect(pedidos[1].url.queryParameters.containsKey('api_key'), isFalse);
      expect(pedidos[1].headers['Authorization'], 'Bearer $token');
    });

    test('errores y tiempos de espera lanzan TmdbException', () async {
      final noAutorizado = TmdbClient(
        'mala',
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      expect(noAutorizado.buscar('x'), throwsA(isA<TmdbException>()));

      final caido = TmdbClient(
        'abc',
        client: MockClient((_) async => throw http.ClientException('sin red')),
      );
      expect(caido.buscar('x'), throwsA(isA<TmdbException>()));

      final lento = TmdbClient(
        'abc',
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) => Completer<http.Response>().future),
      );
      expect(lento.detalle(1), throwsA(isA<TmdbException>()));

      expect(await noAutorizado.buscar('   '), isEmpty);
    });
  });

  group('Formulario con TMDB', () {
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

    testWidgets('Vincular un resultado guarda los datos de la película', (
      tester,
    ) async {
      final repo = MemoriaListaRepository(apiKeyTmdb: 'abc');
      await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
      await tester.pump();
      await tester.tap(find.text('Películas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('boton-buscar-tmdb')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('campo-buscar-tmdb')),
        'shrek',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('2004'), findsOneWidget);

      await tester.tap(find.text('Shrek 2'));
      await tester.pumpAndSettle();

      // El título estaba vacío: se llena con el de TMDB.
      expect(find.byKey(const Key('chip-tmdb')), findsOneWidget);
      expect(find.text('🎞️ Shrek 2 (2004)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('boton-guardar-item')));
      await tester.pumpAndSettle();

      final item = (await repo.watch(TipoLista.peliculas).first).single;
      expect(item.titulo, 'Shrek 2');
      expect(item.pelicula?.tmdbId, 809);
      expect(item.pelicula?.duracionMin, 93);
      expect(item.pelicula?.anio, 2004);
    });

    testWidgets('Sin clave no aparece la búsqueda en TMDB', (tester) async {
      await tester.pumpWidget(
        ClubDelFrijolApp(repository: MemoriaListaRepository()),
      );
      await tester.pump();
      await tester.tap(find.text('Películas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('boton-buscar-tmdb')), findsNothing);
    });
  });
}
