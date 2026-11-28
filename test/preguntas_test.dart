import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/preguntas/data/memoria_preguntas_repository.dart';
import 'package:movil_app/features/preguntas/domain/banco_preguntas.dart';
import 'package:movil_app/features/preguntas/domain/preguntas_repository.dart';

const _luis = Autor(uid: 'u1', nombre: 'Luis Pérez');
const _ana = Autor(uid: 'u2', nombre: 'Ana López');

void main() {
  group('pregunta del día', () {
    test('el banco tiene al menos 120 preguntas distintas', () {
      expect(bancoPreguntas.length, greaterThanOrEqualTo(120));
      expect(bancoPreguntas.toSet().length, bancoPreguntas.length);
      for (final p in bancoPreguntas) {
        expect(p.length, lessThanOrEqualTo(300));
      }
    });

    test('es la misma para la misma fecha, sin importar la hora', () {
      expect(
        preguntaDelDia(DateTime(2026, 11, 28, 0, 5)),
        preguntaDelDia(DateTime(2026, 11, 28, 23, 59)),
      );
      expect(claveDia(DateTime(2026, 3, 7, 18)), '2026-03-07');
      expect(fechaDeClave('2026-03-07'), DateTime(2026, 3, 7));
    });

    test('días seguidos cambian y se recorre todo el banco', () {
      final inicio = DateTime(2026);
      final vistas = <String>{};
      String? anterior;
      for (var i = 0; i < bancoPreguntas.length; i++) {
        final p = preguntaDelDia(
          DateTime(inicio.year, inicio.month, inicio.day + i),
        );
        expect(p, isNot(anterior));
        anterior = p;
        vistas.add(p);
      }
      expect(vistas.length, bancoPreguntas.length);
    });
  });

  group('MemoriaPreguntasRepository', () {
    late Autor? yo;
    late DateTime ahora;
    late MemoriaPreguntasRepository repo;

    setUp(() {
      yo = _luis;
      ahora = DateTime(2026, 11, 28, 10);
      repo = MemoriaPreguntasRepository(autor: () => yo, reloj: () => ahora);
    });

    test('la respuesta del otro se ve solo después de responder', () async {
      final dia = repo.hoy;
      await repo.asegurarHoy();
      expect(await repo.watchPregunta(dia).first, preguntaDelDia(ahora));

      await repo.responder(dia, 'Playa, siempre 🏖️');

      // Ana aún no responde: no ve la mía.
      yo = _ana;
      expect(await repo.watchMiRespuesta(dia).first, isNull);
      expect(await repo.watchOtras(dia).first, isEmpty);
      var vista = await repo.watchDia(dia).first;
      expect(vista.respondi, isFalse);
      expect(vista.otras, isEmpty);

      await repo.responder(dia, 'Montaña con chocolate');
      vista = await repo.watchDia(dia).firstWhere((d) => d.otras.isNotEmpty);
      expect(vista.mia!.texto, 'Montaña con chocolate');
      expect(vista.otras.single.texto, 'Playa, siempre 🏖️');
      expect(vista.otras.single.autor.uid, 'u1');

      // Luis edita su respuesta y ve la de Ana.
      yo = _luis;
      await repo.responder(dia, '  Playa y montaña  ');
      expect(
        (await repo.watchMiRespuesta(dia).first)!.texto,
        'Playa y montaña',
      );
      expect((await repo.watchOtras(dia).first).single.autor.uid, 'u2');
      expect((await repo.pareja())!.uid, 'u2');
    });

    test('no deja respuestas vacías ni sin sesión', () async {
      expect(() => repo.responder(repo.hoy, '   '), throwsArgumentError);
      yo = null;
      expect(() => repo.responder(repo.hoy, 'Hola'), throwsStateError);
    });

    test('el historial trae días anteriores con lo visible', () async {
      await repo.asegurarHoy();
      await repo.responder(repo.hoy, 'Lunes de Luis');
      yo = _ana;
      await repo.responder(repo.hoy, 'Lunes de Ana');

      ahora = DateTime(2026, 11, 29, 9);
      await repo.asegurarHoy();
      await repo.responder(repo.hoy, 'Martes de Ana');

      ahora = DateTime(2026, 11, 30, 9);
      yo = _luis;
      final historial = await repo.watchHistorial().first;
      expect(historial.map((d) => d.dia), ['2026-11-29', '2026-11-28']);
      // El 29 Luis no respondió: la de Ana queda oculta.
      expect(historial.first.mia, isNull);
      expect(historial.first.otras, isEmpty);
      expect(historial.last.mia!.texto, 'Lunes de Luis');
      expect(historial.last.otras.single.texto, 'Lunes de Ana');
    });
  });

  group('tarjeta en el inicio', () {
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

    final hoy = DateTime(2026, 11, 28, 10);

    MemoriaListaRepository nuevoRepo({
      ConfigClub config = const ConfigClub(),
      Autor? autor = _luis,
    }) => MemoriaListaRepository(
      config: config,
      autorActual: autor,
      reloj: () => hoy,
    );

    Future<void> abrir(WidgetTester tester, ListaRepository repo) async {
      await tester.pumpWidget(ClubDelFrijolApp(repository: repo));
      await tester.pumpAndSettle();
    }

    Finder tarjeta() => find.byKey(const Key('tarjeta-pregunta'));

    testWidgets('pide responder, espera y luego muestra las dos', (
      tester,
    ) async {
      final repo = nuevoRepo();
      final preguntas = repo.preguntas;
      await abrir(tester, repo);

      expect(tarjeta(), findsOneWidget);
      expect(find.text('🎲 Pregunta del día'), findsOneWidget);
      expect(find.text(preguntaDelDia(hoy)), findsOneWidget);
      expect(
        find.text('✍️ Responde para ver la de tu frijolito'),
        findsOneWidget,
      );

      // Responder desde la página de la pregunta.
      await tester.tap(tarjeta());
      await tester.pumpAndSettle();
      expect(find.text('🔒 Responde para ver la de tu frijolito'), findsOne);
      expect(find.text('Días anteriores'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('campo-respuesta')),
        'Ver atardeceres contigo',
      );
      await tester.tap(find.text('Responder'));
      await tester.pumpAndSettle();
      expect(find.text('Ver atardeceres contigo'), findsOneWidget);
      expect(find.text('⏳ Esperando a tu frijolito…'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('⏳ Esperando a tu frijolito…'), findsOneWidget);

      // Ana responde desde "su teléfono" (mismos datos, otra identidad).
      await (preguntas as MemoriaPreguntasRepository).responderComo(
        _ana,
        preguntas.hoy,
        'Cocinar juntos',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Esperando'), findsNothing);
      expect(find.text('Ver atardeceres contigo'), findsOneWidget);
      expect(find.text('Cocinar juntos'), findsOneWidget);
    });

    testWidgets('se oculta con la bandera preguntas en false', (tester) async {
      await abrir(
        tester,
        nuevoRepo(config: const ConfigClub(preguntas: false)),
      );
      expect(find.text('Películas'), findsOneWidget);
      expect(tarjeta(), findsNothing);
    });

    testWidgets('se oculta en modo local sin autor', (tester) async {
      await abrir(tester, nuevoRepo(autor: null));
      expect(find.text('Películas'), findsOneWidget);
      expect(tarjeta(), findsNothing);
    });
  });
}
