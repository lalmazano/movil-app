import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/config_scope.dart';
import 'package:movil_app/features/musica/data/memoria_musica_repository.dart';
import 'package:movil_app/features/musica/domain/adivina_juego.dart';
import 'package:movil_app/features/musica/domain/musica_repository.dart';
import 'package:movil_app/features/musica/presentation/adivina_page.dart';
import 'package:movil_app/features/musica/presentation/reproductor.dart';

const _luis = Autor(uid: 'u1', nombre: 'Luis Pérez');
const _ana = Autor(uid: 'u2', nombre: 'Ana López');

Cancion _cancion(int id, {bool preview = true, String? titulo}) => Cancion(
  itunesId: id,
  titulo: titulo ?? 'Canción $id',
  artista: 'Artista $id',
  previewUrl: preview ? 'https://x/$id.m4a' : null,
);

void main() {
  late ReproductorFalso reproductor;
  late Reproductor original;

  setUp(() {
    original = Reproductor.instancia;
    reproductor = ReproductorFalso();
    Reproductor.instancia = reproductor;
  });

  tearDown(() => Reproductor.instancia = original);

  group('rondas', () {
    final playlist = [for (var i = 1; i <= 8; i++) _cancion(i)];

    test('5 rondas sin repetir, con 4 opciones distintas de la playlist', () {
      for (var semilla = 0; semilla < 30; semilla++) {
        final rondas = AdivinaJuego.crearRondas(
          playlist,
          random: Random(semilla),
        );
        expect(rondas, hasLength(5));
        final respuestas = rondas.map((r) => r.cancion.itunesId).toSet();
        expect(respuestas, hasLength(5));
        final titulos = playlist.map((c) => c.titulo).toSet();
        for (final r in rondas) {
          expect(r.opciones, hasLength(4));
          expect(r.opciones.toSet(), hasLength(4));
          expect(r.opciones, contains(r.cancion.titulo));
          expect(titulos.containsAll(r.opciones), isTrue);
          expect(r.opciones[r.indiceCorrecto], r.respuesta);
          expect(r.inicio.inSeconds, inInclusiveRange(0, 15));
          expect(r.fin - r.inicio, const Duration(seconds: 10));
        }
      }
    });

    test('es determinista con la misma semilla y baraja las opciones', () {
      String firma(int s) => AdivinaJuego.crearRondas(
        playlist,
        random: Random(s),
      ).map((r) => '${r.cancion.itunesId}:${r.opciones}:${r.inicio}').join();
      expect(firma(7), firma(7));
      final posiciones = <int>{};
      for (var s = 0; s < 20; s++) {
        for (final r in AdivinaJuego.crearRondas(playlist, random: Random(s))) {
          posiciones.add(r.indiceCorrecto);
        }
      }
      expect(posiciones, {0, 1, 2, 3});
    });

    test('con playlist chica hay menos rondas', () {
      final cuatro = playlist.take(4).toList();
      expect(AdivinaJuego.rondasPosibles(cuatro), 4);
      final rondas = AdivinaJuego.crearRondas(cuatro, random: Random(1));
      expect(rondas, hasLength(4));
      expect(rondas.map((r) => r.cancion).toSet(), hasLength(4));
    });

    test('sin al menos 4 canciones con muestra no se puede jugar', () {
      final pocas = [
        _cancion(1),
        _cancion(2),
        _cancion(3),
        _cancion(4, preview: false),
        _cancion(5, titulo: 'canción 1 '), // título repetido
        _cancion(1), // misma canción
      ];
      expect(AdivinaJuego.jugables(pocas), hasLength(3));
      expect(AdivinaJuego.sePuedeJugar(pocas), isFalse);
      expect(AdivinaJuego.rondasPosibles(pocas), 0);
      expect(AdivinaJuego.crearRondas(pocas), isEmpty);
      expect(AdivinaJuego.crearRondas(const []), isEmpty);
    });
  });

  group('puntaje y récord', () {
    test('1 punto por acierto y 1 extra si es rápido', () {
      final rondas = AdivinaJuego.crearRondas([
        for (var i = 1; i <= 5; i++) _cancion(i),
      ], random: Random(3));
      final partida = PartidaAdivina(rondas);
      expect(
        partida.responder(rondas[0].respuesta, tiempo: Duration(seconds: 2)),
        isTrue,
      );
      expect(
        partida.responder(rondas[1].respuesta, tiempo: Duration(seconds: 8)),
        isTrue,
      );
      final mala = rondas[2].opciones.firstWhere(
        (o) => !rondas[2].esCorrecta(o),
      );
      expect(partida.responder(mala), isFalse);
      partida.responder(rondas[3].respuesta, tiempo: Duration(seconds: 9));
      expect(partida.terminada, isFalse);
      partida.responder(rondas[4].respuesta, tiempo: Duration(seconds: 6));
      expect(partida.terminada, isTrue);
      expect(partida.aciertos, 4);
      expect(partida.rapidas, 1);
      expect(partida.puntos, 5);
      expect(() => partida.responder('x'), throwsStateError);

      expect(AdivinaJuego.esNuevoRecord(1, null), isTrue);
      expect(AdivinaJuego.esNuevoRecord(0, null), isFalse);
      expect(AdivinaJuego.esNuevoRecord(4, 4), isFalse);
      expect(AdivinaJuego.esNuevoRecord(5, 4), isTrue);
    });

    test('el récord se guarda en el repositorio en memoria', () async {
      Autor? yo = _luis;
      final repo = MemoriaMusicaRepository(autor: () => yo);
      await repo.guardarPartida(3);
      await repo.guardarPartida(2);
      yo = _ana;
      await repo.guardarPartida(4);
      final records = await repo.watchRecords().first;
      expect(records.map((r) => r.autor.uid), ['u2', 'u1']);
      expect(records.last.mejor, 3);
      expect(records.last.partidas, 2);
    });
  });

  group('pantallas', () {
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1080, 3200);
      view.devicePixelRatio = 2.5;
    });

    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    MemoriaListaRepository nuevoRepo({
      ConfigClub config = const ConfigClub(),
    }) => MemoriaListaRepository(config: config, autorActual: _luis);

    Future<void> agregar(ListaRepository repo, int n) async {
      for (var i = 1; i <= n; i++) {
        await repo.musica.agregar(_cancion(i));
      }
    }

    Future<void> abrirApp(WidgetTester tester, ListaRepository repo) async {
      await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
      await tester.pumpAndSettle();
    }

    Finder tarjeta() => find.byKey(const Key('tarjeta-adivina'));

    testWidgets('la tarjeta se oculta con la bandera adivina en false', (
      tester,
    ) async {
      await abrirApp(
        tester,
        nuevoRepo(config: const ConfigClub(adivina: false)),
      );
      expect(find.text('Películas'), findsOneWidget);
      expect(tarjeta(), findsNothing);
    });

    testWidgets('la tarjeta pide al menos 4 canciones y luego el récord', (
      tester,
    ) async {
      final repo = nuevoRepo();
      await agregar(repo, 3);
      await abrirApp(tester, repo);
      expect(tarjeta(), findsOneWidget);
      expect(find.text('Adivina la canción'), findsOneWidget);
      expect(
        find.text('Necesitan al menos 4 canciones en la playlist'),
        findsOneWidget,
      );

      await repo.musica.agregar(_cancion(4));
      await repo.musica.agregar(_cancion(5));
      await repo.musica.guardarPartida(4);
      await tester.pumpAndSettle();
      expect(find.text('Tu récord: 4/5'), findsOneWidget);

      // Al tocarla se abre el juego.
      await tester.tap(tarjeta());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adivina-jugar')), findsOneWidget);
      expect(find.text('🏆 Récords'), findsOneWidget);
      expect(find.text('Luis'), findsOneWidget);
    });

    testWidgets('juega una partida completa y guarda el récord', (
      tester,
    ) async {
      final repo = nuevoRepo();
      await agregar(repo, 4);
      final musica = repo.musica;
      await musica.guardarPartida(1);
      await tester.pumpWidget(
        MaterialApp(
          home: AdivinaPage(musica: musica, random: Random(5)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1/4'), findsOneWidget);

      await tester.tap(find.byKey(const Key('adivina-jugar')));
      await tester.pump();
      for (var ronda = 1; ronda <= 4; ronda++) {
        await tester.pump();
        expect(find.text('Ronda $ronda de 4'), findsOneWidget);
        expect(find.text('🎧'), findsOneWidget);
        expect(reproductor.reproducidas, hasLength(ronda));
        final sonando = reproductor.actual!;

        if (ronda == 1) {
          // Volver a escuchar repite el mismo fragmento.
          await tester.tap(find.byKey(const Key('adivina-repetir')));
          await tester.pump();
          expect(reproductor.actual, sonando);
          reproductor.reproducidas.removeLast();
        }

        // Acierta todas menos la última.
        if (ronda < 4) {
          await tester.tap(find.text(sonando.titulo));
        } else {
          // Elige una opción equivocada.
          for (var i = 0; i < 4; i++) {
            final boton = find.byKey(ValueKey('opcion-$i'));
            final correcta = find.descendant(
              of: boton,
              matching: find.text(sonando.titulo),
            );
            if (correcta.evaluate().isEmpty) {
              await tester.tap(boton);
              break;
            }
          }
        }
        await tester.pump();
        expect(
          find.textContaining(ronda < 4 ? '✅ ¡Correcto!' : '❌ Nop'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('adivina-titulo')), findsOneWidget);
        expect(find.text(sonando.artista), findsOneWidget);
        await tester.tap(find.byKey(const Key('adivina-siguiente')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('3 de 4'), findsOneWidget);
      expect(find.text('¡Nuevo récord! 🎉'), findsOneWidget);
      expect(reproductor.actual, isNull);
      // Las 4 canciones sonaron, sin repetirse.
      expect(reproductor.reproducidas.toSet(), hasLength(4));
      final records = await musica.watchRecords().first;
      expect(records.single.mejor, 3);
      expect(records.single.partidas, 2);

      // Jugar otra vez empieza de nuevo.
      await tester.tap(find.byKey(const Key('adivina-otra-vez')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Ronda 1 de 4'), findsOneWidget);
      expect(reproductor.actual, isNotNull);

      // Al salir se detiene el audio.
      await tester.pumpWidget(const SizedBox());
      expect(reproductor.actual, isNull);
    });

    testWidgets('avisa si el juego está desactivado', (tester) async {
      final repo = nuevoRepo();
      await agregar(repo, 4);
      await tester.pumpWidget(
        MaterialApp(
          home: ConfigClubScope(
            config: const ConfigClub(adivina: false),
            child: AdivinaPage(musica: repo.musica),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('El juego está desactivado 💤'), findsOneWidget);
      expect(find.byKey(const Key('adivina-jugar')), findsNothing);
    });
  });
}
