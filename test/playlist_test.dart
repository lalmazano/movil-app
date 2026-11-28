import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/config_scope.dart';
import 'package:movil_app/features/musica/data/itunes_client.dart';
import 'package:movil_app/features/musica/domain/musica_repository.dart';
import 'package:movil_app/features/musica/presentation/playlist_page.dart';
import 'package:movil_app/features/musica/presentation/reproductor.dart';

const luis = Autor(uid: 'u1', nombre: 'Luis Pérez');

const bonita = Cancion(
  itunesId: 1,
  titulo: 'Bonita',
  artista: 'Juanes',
  previewUrl: 'https://example.com/1.m4a',
);
const amor = Cancion(
  itunesId: 2,
  titulo: 'Amor Eterno',
  artista: 'Rocío Dúrcal',
  previewUrl: 'https://example.com/2.m4a',
);

/// Respuesta falsa de iTunes con dos canciones.
String get _jsonItunes => jsonEncode({
  'resultCount': 2,
  'results': [
    {
      'trackId': 1,
      'trackName': 'Bonita',
      'artistName': 'Juanes',
      'previewUrl': 'https://example.com/1.m4a',
    },
    {
      'trackId': 2,
      'trackName': 'Amor Eterno',
      'artistName': 'Rocío Dúrcal',
      'previewUrl': 'https://example.com/2.m4a',
    },
  ],
});

void main() {
  late Reproductor reproductorAntes;
  late ItunesClient Function() fabricaAntes;
  late ReproductorFalso reproductor;

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 2.5;
    reproductorAntes = Reproductor.instancia;
    fabricaAntes = ItunesClient.fabrica;
    Reproductor.instancia = reproductor = ReproductorFalso();
    ItunesClient.fabrica = () => ItunesClient(
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(_jsonItunes), 200),
      ),
    );
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    Reproductor.instancia = reproductorAntes;
    ItunesClient.fabrica = fabricaAntes;
  });

  Future<void> abrirPagina(
    WidgetTester tester,
    MemoriaListaRepository repo, {
    ConfigClub config = const ConfigClub(),
    Random? azar,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigClubScope(
          config: config,
          child: PlaylistPage(musica: repo.musica, azar: azar),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Agrega desde el buscador la canción [titulo].
  Future<void> agregarDesdeBuscador(WidgetTester tester, String titulo) async {
    await tester.tap(find.text('Agregar canción'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-buscar-cancion')), 'x');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text(titulo).last);
    await tester.pumpAndSettle();
  }

  test('Ordena por recientes o por ❤️', () {
    final a = CancionPlaylist(
      id: '1',
      cancion: bonita,
      agregadaEn: DateTime(2026, 1, 1),
      corazones: const {'u1', 'u2'},
    );
    final b = CancionPlaylist(
      id: '2',
      cancion: amor,
      agregadaEn: DateTime(2026, 2, 1),
    );
    expect(ordenarPlaylist([a, b], OrdenPlaylist.recientes), [b, a]);
    expect(ordenarPlaylist([b, a], OrdenPlaylist.corazones), [a, b]);
    expect(fechaPlaylist(DateTime(2026, 3, 7)), '07/03/2026');
  });

  testWidgets('La tarjeta del inicio respeta la bandera', (tester) async {
    await tester.pumpWidget(
      ClubDelFrijolApp(repository: MemoriaListaRepository(autorActual: luis)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nuestras canciones'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Agreguen su primera canción 🎶'), findsOneWidget);
    await tester.tap(find.text('Nuestras canciones'));
    await tester.pumpAndSettle();
    expect(find.text('📀 Nuestras canciones'), findsOneWidget);
    expect(find.text('Agregar canción'), findsOneWidget);

    await tester.pumpWidget(
      ClubDelFrijolApp(
        key: UniqueKey(),
        repository: MemoriaListaRepository(
          autorActual: luis,
          config: const ConfigClub(playlist: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.text('Nuestras canciones'), findsNothing);
    expect(find.text('Agreguen su primera canción 🎶'), findsNothing);
  });

  testWidgets('La tarjeta muestra cuántas canciones hay', (tester) async {
    final repo = MemoriaListaRepository(autorActual: luis);
    await repo.musica.agregar(bonita);
    await repo.musica.agregar(amor);
    await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2 canciones'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2 canciones'), findsOneWidget);
  });

  testWidgets('Con la bandera apagada la página lo avisa', (tester) async {
    await abrirPagina(
      tester,
      MemoriaListaRepository(autorActual: luis),
      config: const ConfigClub(playlist: false),
    );
    expect(find.text('La playlist está desactivada'), findsOneWidget);
  });

  testWidgets('Agregar desde el buscador; repetida avisa', (tester) async {
    final repo = MemoriaListaRepository(autorActual: luis);
    await abrirPagina(tester, repo);
    expect(find.textContaining('Todavía no hay canciones'), findsOneWidget);

    await agregarDesdeBuscador(tester, 'Amor Eterno');
    expect(find.text('¡Agregada! 🎶'), findsOneWidget);
    expect(find.text('Amor Eterno'), findsOneWidget);
    expect(find.text('Rocío Dúrcal'), findsOneWidget);
    expect(find.textContaining('Agregada por Luis ·'), findsOneWidget);
    expect((await repo.musica.watchPlaylist().first).single.cancion, amor);

    await agregarDesdeBuscador(tester, 'Amor Eterno');
    expect(find.text('Ya está en la playlist'), findsOneWidget);
    expect(await repo.musica.watchPlaylist().first, hasLength(1));
  });

  testWidgets('❤️ suma y resta; ▶ usa el reproductor', (tester) async {
    final repo = MemoriaListaRepository(autorActual: luis);
    await repo.musica.agregar(bonita);
    await abrirPagina(tester, repo);

    Text contador() =>
        tester.widget<Text>(find.byKey(const ValueKey('corazones-1')));
    expect(contador().data, '0');
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('corazon-1')));
    await tester.pumpAndSettle();
    expect(contador().data, '1');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('corazon-1')),
        matching: find.byIcon(Icons.favorite),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('corazon-1')));
    await tester.pumpAndSettle();
    expect(contador().data, '0');

    await tester.tap(find.byKey(const ValueKey('preview-1')));
    await tester.pumpAndSettle();
    expect(reproductor.reproducidas, [bonita]);
    expect(reproductor.actual, bonita);

    // Al salir de la página se detiene la muestra.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(reproductor.actual, isNull);
  });

  testWidgets('Ordenar por más ❤️', (tester) async {
    final repo = MemoriaListaRepository(autorActual: luis);
    await tester.runAsync(() async {
      await repo.musica.agregar(bonita);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.musica.agregar(amor);
    });
    await repo.musica.alternarCorazon('1');
    await abrirPagina(tester, repo);

    double y(String titulo) => tester.getTopLeft(find.text(titulo)).dy;
    // Más recientes: "Amor Eterno" (la última) arriba.
    expect(y('Amor Eterno'), lessThan(y('Bonita')));

    await tester.tap(find.byTooltip('Ordenar por más ❤️'));
    await tester.pumpAndSettle();
    expect(y('Bonita'), lessThan(y('Amor Eterno')));

    await tester.tap(find.byTooltip('Ordenar por más recientes'));
    await tester.pumpAndSettle();
    expect(y('Amor Eterno'), lessThan(y('Bonita')));
  });

  testWidgets('Quitar una canción propia pide confirmación', (tester) async {
    final repo = MemoriaListaRepository(autorActual: luis);
    await repo.musica.agregar(bonita);
    await abrirPagina(tester, repo);

    await tester.longPress(find.text('Bonita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de la playlist'));
    await tester.pumpAndSettle();
    expect(find.text('¿Quitar de la playlist?'), findsOneWidget);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(find.text('Bonita'), findsNothing);
    expect(await repo.musica.watchPlaylist().first, isEmpty);
  });

  testWidgets('🎲 ¿Qué escuchamos? abre una canción al azar', (tester) async {
    final repo = MemoriaListaRepository(autorActual: luis);
    await repo.musica.agregar(bonita);
    await abrirPagina(tester, repo, azar: Random(1));
    await tester.tap(find.byKey(const Key('playlist-azar')));
    await tester.pumpAndSettle();
    expect(find.text('Escuchar en Spotify'), findsOneWidget);
  });
}
