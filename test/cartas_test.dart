import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/app/app.dart';
import 'package:movil_app/features/cartas/data/memoria_cartas_repository.dart';
import 'package:movil_app/features/cartas/domain/cartas_repository.dart';
import 'package:movil_app/features/cartas/presentation/cartas_page.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/config_scope.dart';

const luis = Autor(uid: 'u1', nombre: 'Luis Pérez');
const ana = Autor(uid: 'u2', nombre: 'Ana López');

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

  /// Repositorio compartido donde se puede cambiar quién usa la app y la hora.
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

  group('Repositorio en memoria', () {
    test('La carta está cerrada para el otro hasta la fecha', () async {
      final r = crearRepo(DateTime(2027, 2, 1, 10));
      await r.repo.crear(
        titulo: 'Feliz San Valentín',
        texto: 'Te quiero mucho',
        abrirEn: DateTime(2027, 2, 14),
      );
      final carta = (await r.repo.watch().first).single;
      expect(carta.de.uid, luis.uid);

      // Quien la escribió la puede leer cuando quiera.
      expect(await r.repo.leer(carta), 'Te quiero mucho');

      // La otra persona no, hasta el 14 de febrero.
      r.como(ana);
      expect(() => r.repo.leer(carta), throwsA(isA<CartaError>()));
      await r.repo.marcarAbierta(carta);
      expect((await r.repo.watch().first).single.abierta, isFalse);
      expect(() => r.repo.borrar(carta), throwsA(isA<CartaError>()));

      r.hora(DateTime(2027, 2, 14, 0, 1));
      expect(await r.repo.leer(carta), 'Te quiero mucho');
      await r.repo.marcarAbierta(carta);
      final abierta = (await r.repo.watch().first).single;
      expect(abierta.abiertaEn, DateTime(2027, 2, 14, 0, 1));
      expect(abierta.abiertaPor?.uid, ana.uid);

      // Solo la autora puede borrarla.
      r.como(luis);
      await r.repo.borrar(abierta);
      expect(await r.repo.watch().first, isEmpty);
    });

    test('Valida título, texto y fecha futura', () async {
      final r = crearRepo(DateTime(2027, 1, 1));
      Future<void> crear(String t, String x, DateTime f) =>
          r.repo.crear(titulo: t, texto: x, abrirEn: f);
      expect(
        () => crear(' ', 'hola', DateTime(2027, 2)),
        throwsA(isA<CartaError>()),
      );
      expect(
        () => crear('Hola', 'hola', DateTime(2026, 12)),
        throwsA(isA<CartaError>()),
      );
      expect(
        () => crear('Hola', 'x' * 5001, DateTime(2027, 2)),
        throwsA(isA<CartaError>()),
      );
      await crear('Uno', 'a', DateTime(2027, 3));
      await crear('Dos', 'b', DateTime(2027, 2));
      expect((await r.repo.watch().first).map((c) => c.titulo), ['Dos', 'Uno']);
    });
  });

  group('Pantallas', () {
    testWidgets('Como la otra persona: cerrada antes y abierta después', (
      tester,
    ) async {
      final r = crearRepo(DateTime(2027, 2, 2, 10));
      await r.repo.crear(
        titulo: 'Feliz San Valentín',
        texto: 'Te quiero mucho',
        abrirEn: DateTime(2027, 2, 14),
      );

      // Luis ve su carta marcada como suya.
      await tester.pumpWidget(
        MaterialApp(
          home: CartasPage(key: UniqueKey(), cartas: r.repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Escrita por ti'), findsOneWidget);

      // Ana la ve cerrada con cuenta regresiva.
      r.como(ana);
      await tester.pumpWidget(
        MaterialApp(
          home: CartasPage(key: UniqueKey(), cartas: r.repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('De Luis'), findsOneWidget);
      expect(find.text('🔒'), findsOneWidget);
      expect(
        find.text('Se abre el 14/02/2027 · faltan 11 días'),
        findsOneWidget,
      );
      await tester.tap(find.text('Feliz San Valentín'));
      await tester.pumpAndSettle();
      expect(find.text('Te quiero mucho'), findsNothing);
      expect(find.textContaining('🔒 Se abre el 14/02/2027'), findsOneWidget);

      // Llega el día.
      r.hora(DateTime(2027, 2, 14, 8));
      await tester.pumpWidget(
        MaterialApp(
          home: CartasPage(key: UniqueKey(), cartas: r.repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('¡Ya puedes abrirla!'), findsOneWidget);
      await tester.tap(find.text('Feliz San Valentín'));
      await tester.pumpAndSettle();
      expect(find.text('Te quiero mucho'), findsOneWidget);
      expect((await r.repo.watch().first).single.abierta, isTrue);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Abierta el 14/02/2027'), findsOneWidget);
    });

    testWidgets('Escribir una carta desde el formulario', (tester) async {
      final r = crearRepo(DateTime(2027, 5, 1, 12));
      await tester.pumpWidget(MaterialApp(home: CartasPage(cartas: r.repo)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Aún no hay cartas'), findsOneWidget);

      await tester.tap(find.text('Escribir carta'));
      await tester.pumpAndSettle();
      // Por defecto, mañana.
      expect(find.text('02/05/2027'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título'),
        'Para mañana',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Carta'),
        'Hola, frijolito',
      );
      await tester.tap(find.text('Guardar carta'));
      await tester.pumpAndSettle();

      expect(find.text('Para mañana'), findsOneWidget);
      expect(find.text('Escrita por ti'), findsOneWidget);

      // Borrar la propia carta desde el menú.
      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await tester.pumpAndSettle();
      expect(find.text('Para mañana'), findsNothing);
    });

    testWidgets('La tarjeta del inicio respeta la bandera', (tester) async {
      await tester.pumpWidget(
        ClubDelFrijolApp(repository: MemoriaListaRepository(autorActual: luis)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Cartas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Escríbele una carta'), findsOneWidget);
      await tester.tap(find.text('Cartas'));
      await tester.pumpAndSettle();
      expect(find.text('Escribir carta'), findsOneWidget);

      await tester.pumpWidget(
        ClubDelFrijolApp(
          key: UniqueKey(),
          repository: MemoriaListaRepository(
            autorActual: luis,
            config: const ConfigClub(cartas: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Hasta el final del inicio, para que se construya todo.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(find.text('Cartas'), findsNothing);
      expect(find.text('Escríbele una carta'), findsNothing);
    });

    testWidgets('Con la bandera apagada la página lo avisa', (tester) async {
      final r = crearRepo(DateTime(2027));
      await tester.pumpWidget(
        MaterialApp(
          home: ConfigClubScope(
            config: const ConfigClub(cartas: false),
            child: CartasPage(cartas: r.repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Las cartas están desactivadas'), findsOneWidget);
    });
  });
}
