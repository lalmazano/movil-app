import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movil_app/features/cartas/data/memoria_cartas_repository.dart';
import 'package:movil_app/features/cartas/domain/cartas_repository.dart';
import 'package:movil_app/features/cartas/presentation/cartas_page.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/config_scope.dart';
import 'package:movil_app/features/musica/data/itunes_client.dart';
import 'package:movil_app/features/musica/domain/cancion.dart';
import 'package:movil_app/features/musica/presentation/reproductor.dart';

const luis = Autor(uid: 'u1', nombre: 'Luis Pérez');
const ana = Autor(uid: 'u2', nombre: 'Ana López');

const perfect = Cancion(
  itunesId: 1,
  titulo: 'Perfect',
  artista: 'Ed Sheeran',
  previewUrl: 'https://example.com/perfect.m4a',
);

/// Respuesta falsa de iTunes con una canción.
final _respuestaItunes = jsonEncode({
  'resultCount': 1,
  'results': [
    {
      'trackId': 7,
      'trackName': 'Contigo',
      'artistName': 'Sin Bandera',
      'previewUrl': 'https://example.com/contigo.m4a',
    },
  ],
});

void main() {
  late ReproductorFalso reproductor;
  late Reproductor reproductorOriginal;
  late ItunesClient Function() fabricaOriginal;
  final consultas = <Uri>[];

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 2.5;
    reproductorOriginal = Reproductor.instancia;
    reproductor = ReproductorFalso();
    Reproductor.instancia = reproductor;
    fabricaOriginal = ItunesClient.fabrica;
    consultas.clear();
    ItunesClient.fabrica = () => ItunesClient(
      client: MockClient((req) async {
        consultas.add(req.url);
        return http.Response(
          _respuestaItunes,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    Reproductor.instancia = reproductorOriginal;
    ItunesClient.fabrica = fabricaOriginal;
  });

  ({
    MemoriaCartasRepository repo,
    void Function(Autor) como,
    void Function(DateTime) hora,
  })
  crearRepo(DateTime inicio) {
    Autor actual = luis;
    var ahora = inicio;
    final repo = MemoriaCartasRepository(
      autor: () => actual,
      reloj: () => ahora,
    );
    return (repo: repo, como: (a) => actual = a, hora: (h) => ahora = h);
  }

  Widget app(CartasRepository repo, {ConfigClub config = const ConfigClub()}) =>
      MaterialApp(
        key: UniqueKey(),
        // La bandera debe llegar también a las páginas que se abren encima.
        builder: (context, child) =>
            ConfigClubScope(config: config, child: child!),
        home: CartasPage(cartas: repo),
      );

  test('La canción va en el contenido y respeta el candado', () async {
    final r = crearRepo(DateTime(2027, 2, 1, 10));
    await r.repo.crear(
      titulo: 'San Valentín',
      texto: 'Te quiero',
      abrirEn: DateTime(2027, 2, 14),
      cancion: perfect,
    );
    final carta = (await r.repo.watch().first).single;

    final mio = await r.repo.leerContenido(carta);
    expect(mio.texto, 'Te quiero');
    expect(mio.cancion, perfect);

    r.como(ana);
    expect(() => r.repo.leerContenido(carta), throwsA(isA<CartaError>()));

    r.hora(DateTime(2027, 2, 14, 9));
    final suyo = await r.repo.leerContenido(carta);
    expect(suyo.texto, 'Te quiero');
    expect(suyo.cancion?.titulo, 'Perfect');

    // El mapa guardado lleva la canción junto al texto.
    final mapa = suyo.toMap();
    expect(mapa['texto'], 'Te quiero');
    expect(ContenidoCarta.fromMap(mapa).cancion, perfect);
    expect(ContenidoCarta.fromMap(const {'texto': 'Hola'}).cancion, isNull);
  });

  testWidgets('Antes de la fecha no se ve ni suena; después sí', (
    tester,
  ) async {
    final r = crearRepo(DateTime(2027, 2, 2, 10));
    await r.repo.crear(
      titulo: 'San Valentín',
      texto: 'Te quiero mucho',
      abrirEn: DateTime(2027, 2, 14),
      cancion: perfect,
    );

    r.como(ana);
    await tester.pumpWidget(app(r.repo));
    await tester.pumpAndSettle();
    // Ni una pista de la canción en el sobre cerrado.
    expect(find.textContaining('🎵'), findsNothing);
    expect(find.textContaining('Perfect'), findsNothing);
    await tester.tap(find.text('San Valentín'));
    await tester.pumpAndSettle();
    expect(find.text('Te quiero mucho'), findsNothing);
    expect(find.text('Perfect'), findsNothing);
    expect(reproductor.reproducidas, isEmpty);

    r.hora(DateTime(2027, 2, 14, 8));
    await tester.pumpWidget(app(r.repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('San Valentín'));
    await tester.pumpAndSettle();
    expect(find.text('Te quiero mucho'), findsOneWidget);
    expect(find.text('Perfect'), findsOneWidget);
    expect(find.text('Ed Sheeran'), findsOneWidget);
    expect(find.text('Escuchar completa'), findsOneWidget);
    expect(find.text('🎵 Luis te dedicó una canción'), findsOneWidget);
    // Sonó sola una vez.
    expect(reproductor.reproducidas, [perfect]);
    expect(reproductor.actual, perfect);

    await tester.tap(find.text('Escuchar completa'));
    await tester.pumpAndSettle();
    expect(find.text('Escuchar en Spotify'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Al salir se detiene.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(reproductor.actual, isNull);
    expect(reproductor.reproducidas, [perfect]);
  });

  testWidgets('Elegir una canción al escribir (iTunes simulado)', (
    tester,
  ) async {
    final r = crearRepo(DateTime(2027, 5, 1, 12));
    await tester.pumpWidget(app(r.repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escribir carta'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'Para mañana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Carta'),
      'Hola, frijolito',
    );
    await tester.tap(find.text('Agregar una canción'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-buscar-cancion')),
      'contigo',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(consultas.single.queryParameters['term'], 'contigo');
    await tester.tap(find.byKey(const ValueKey('resultado-7')));
    await tester.pumpAndSettle();

    expect(find.text('Agregar una canción'), findsNothing);
    expect(find.text('Contigo'), findsOneWidget);
    expect(find.text('Sin Bandera'), findsOneWidget);

    // Se puede quitar y volver a elegir.
    await tester.tap(find.byTooltip('Quitar canción'));
    await tester.pumpAndSettle();
    expect(find.text('Contigo'), findsNothing);
    await tester.tap(find.text('Agregar una canción'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-buscar-cancion')),
      'contigo',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resultado-7')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar carta'));
    await tester.pumpAndSettle();
    expect(find.text('Para mañana'), findsOneWidget);
    // El sobre no la delata.
    expect(find.textContaining('Contigo'), findsNothing);

    final carta = (await r.repo.watch().first).single;
    final contenido = await r.repo.leerContenido(carta);
    expect(contenido.texto, 'Hola, frijolito');
    expect(contenido.cancion?.itunesId, 7);
  });

  testWidgets('Con cartasMusica apagada no hay canción ni autoplay', (
    tester,
  ) async {
    const sinMusica = ConfigClub(cartasMusica: false);
    final r = crearRepo(DateTime(2027, 2, 2, 10));
    await r.repo.crear(
      titulo: 'San Valentín',
      texto: 'Te quiero mucho',
      abrirEn: DateTime(2027, 2, 14),
      cancion: perfect,
    );

    // Al escribir no aparece la fila de canción.
    await tester.pumpWidget(app(r.repo, config: sinMusica));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escribir carta'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar una canción'), findsNothing);
    expect(find.text('Guardar carta'), findsOneWidget);

    // Al leer solo se ve el texto y no suena nada.
    r.como(ana);
    r.hora(DateTime(2027, 2, 14, 8));
    await tester.pumpWidget(app(r.repo, config: sinMusica));
    await tester.pumpAndSettle();
    await tester.tap(find.text('San Valentín'));
    await tester.pumpAndSettle();
    expect(find.text('Te quiero mucho'), findsOneWidget);
    expect(find.text('Perfect'), findsNothing);
    expect(find.text('Escuchar completa'), findsNothing);
    expect(reproductor.reproducidas, isEmpty);
    expect(consultas, isEmpty);
  });
}
