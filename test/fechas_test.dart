import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/fechas/data/memoria_fechas_repository.dart';
import 'package:movil_app/features/fechas/domain/fechas_repository.dart';
import 'package:movil_app/features/fechas/presentation/fechas_page.dart';
import 'package:movil_app/features/fechas/presentation/tarjeta_fechas.dart';
import 'package:movil_app/features/home/data/widget_inicio.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';
import 'package:movil_app/features/listas/presentation/config_scope.dart';

void main() {
  final hoy = DateTime(2026, 11, 28, 18, 30);

  FechaImportante fecha(
    String titulo,
    DateTime f, {
    bool anual = false,
    bool contarAnios = false,
  }) => FechaImportante(
    id: titulo,
    titulo: titulo,
    fecha: f,
    anual: anual,
    contarAnios: contarAnios,
  );

  group('próxima ocurrencia', () {
    test('las anuales pasan al año siguiente si ya pasaron', () {
      expect(
        proximaOcurrencia(DateTime(1990, 3, 5), hoy, anual: true),
        DateTime.utc(2027, 3, 5),
      );
      expect(
        proximaOcurrencia(DateTime(1990, 12, 10), hoy, anual: true),
        DateTime.utc(2026, 12, 10),
      );
    });

    test('hoy cuenta como hoy (aunque sea tarde)', () {
      expect(
        proximaOcurrencia(DateTime(2000, 11, 28), hoy, anual: true),
        DateTime.utc(2026, 11, 28),
      );
      expect(
        fecha('x', DateTime(2000, 11, 28), anual: true).diasRestantes(hoy),
        0,
      );
    });

    test('29 de febrero pasa al 28 en años no bisiestos', () {
      expect(
        proximaOcurrencia(DateTime(2000, 2, 29), hoy, anual: true),
        DateTime.utc(2027, 2, 28),
      );
      expect(
        proximaOcurrencia(
          DateTime(2000, 2, 29),
          DateTime(2028, 1, 1),
          anual: true,
        ),
        DateTime.utc(2028, 2, 29),
      );
    });

    test('las de una vez no se mueven y pueden quedar en el pasado', () {
      final viaje = fecha('Viaje', DateTime(2026, 11, 20));
      expect(viaje.proxima(hoy), DateTime.utc(2026, 11, 20));
      expect(viaje.diasRestantes(hoy), -8);
      expect(viaje.cuentaRegresiva(hoy), 'Hace 8 días');
    });

    test('cruza el año nuevo', () {
      final f = fecha('Año nuevo', DateTime(2020, 1, 1), anual: true);
      expect(f.diasRestantes(DateTime(2026, 12, 31)), 1);
      expect(f.cuentaRegresiva(DateTime(2026, 12, 31)), 'Mañana');
    });
  });

  group('textos', () {
    test('cuenta regresiva', () {
      expect(textoCuentaRegresiva(0), '¡Hoy! 🎉');
      expect(textoCuentaRegresiva(1), 'Mañana');
      expect(textoCuentaRegresiva(12), 'Faltan 12 días');
      expect(textoCuentaRegresiva(59, hoy: hoy), 'Faltan 59 días');
      expect(textoCuentaRegresiva(92, hoy: DateTime(2026, 1, 1)), 'En 3 meses');
      expect(
        textoCuentaRegresiva(31 + 29, hoy: DateTime(2026, 1, 1)),
        'En 2 meses',
      );
      expect(textoCuentaRegresiva(365, hoy: DateTime(2026, 1, 1)), 'En 1 año');
      expect(textoCuentaRegresiva(800, hoy: DateTime(2026, 1, 1)), 'En 2 años');
      expect(textoCuentaRegresiva(-1), 'Fue ayer');
      expect(textoCuentaRegresiva(-3), 'Hace 3 días');
    });

    test('cumple N años solo con el año original', () {
      final cumple = fecha(
        'Cumpleaños de Ana',
        DateTime(1996, 12, 10),
        anual: true,
        contarAnios: true,
      );
      expect(cumple.cuentaRegresiva(hoy), 'Faltan 12 días · cumple 30 años');
      final sinAnio = fecha('Cumple', DateTime(1996, 12, 10), anual: true);
      expect(sinAnio.cuentaRegresiva(hoy), 'Faltan 12 días');
      final primero = fecha(
        'Aniversario',
        DateTime(2025, 11, 28),
        anual: true,
        contarAnios: true,
      );
      expect(primero.cuentaRegresiva(hoy), '¡Hoy! 🎉 · cumple 1 año');
      // Si el año es este mismo, no hay años que contar.
      final nueva = fecha(
        'Nueva',
        DateTime(2026, 12, 1),
        anual: true,
        contarAnios: true,
      );
      expect(nueva.cumple(hoy), isNull);
    });

    test('cercanas: 7 días o menos', () {
      expect(fecha('a', DateTime(2026, 12, 5)).esCercana(hoy), isTrue);
      expect(fecha('b', DateTime(2026, 12, 6)).esCercana(hoy), isFalse);
      expect(fecha('c', DateTime(2026, 11, 27)).esCercana(hoy), isFalse);
    });

    test('formato de fecha', () {
      expect(formatoFecha(DateTime(2025, 2, 14)), '14 feb 2025');
      expect(formatoFecha(DateTime(2025, 2, 14), conAnio: false), '14 feb');
    });
  });

  group('repositorio en memoria', () {
    test('ordena por cercanía y las pasadas al final', () async {
      final repo = MemoriaFechasRepository(autor: () => null, reloj: () => hoy);
      await repo.add(NuevaFecha(titulo: 'Viaje', fecha: DateTime(2027, 6, 1)));
      await repo.add(
        NuevaFecha(
          titulo: 'Cumpleaños de Ana',
          fecha: DateTime(1996, 12, 10),
          anual: true,
        ),
      );
      await repo.add(
        NuevaFecha(titulo: 'Concierto', fecha: DateTime(2026, 10, 1)),
      );
      await repo.add(
        NuevaFecha(
          titulo: 'San Valentín',
          fecha: DateTime(2020, 2, 14),
          anual: true,
        ),
      );
      final lista = await repo.watch().first;
      expect(lista.map((f) => f.titulo), [
        'Cumpleaños de Ana',
        'San Valentín',
        'Viaje',
        'Concierto',
      ]);
    });

    test('agrega, edita y elimina (y avisa los cambios)', () async {
      const autor = Autor(uid: 'u1', nombre: 'Ana López');
      final repo = MemoriaFechasRepository(
        autor: () => autor,
        reloj: () => hoy,
      );
      final emitidos = <List<FechaImportante>>[];
      final sub = repo.watch().listen(emitidos.add);
      await repo.add(
        NuevaFecha(titulo: ' Boda ', fecha: DateTime(2027, 3, 1), emoji: '💍'),
      );
      await pumpEventQueue();
      final boda = emitidos.last.single;
      expect(boda.titulo, 'Boda');
      expect(boda.emoji, '💍');
      expect(boda.creadaPor?.uid, 'u1');

      await repo.update(
        boda.id,
        NuevaFecha(titulo: 'Boda civil', fecha: DateTime(2026, 12, 1)),
      );
      await pumpEventQueue();
      expect(emitidos.last.single.titulo, 'Boda civil');
      expect(emitidos.last.single.creadaPor?.uid, 'u1');
      expect(emitidos.last.single.diasRestantes(hoy), 3);

      await repo.delete(boda.id);
      await pumpEventQueue();
      expect(emitidos.last, isEmpty);
      await sub.cancel();
    });

    test('toMap guarda la fecha a mediodía y los campos propios', () {
      final mapa = NuevaFecha(
        titulo: ' Cumple ',
        fecha: DateTime(1996, 12, 10, 0, 5),
        anual: false,
        contarAnios: true,
        emoji: '🎂',
      ).toMap();
      expect(mapa['titulo'], 'Cumple');
      expect(mapa['fecha'], DateTime(1996, 12, 10, 12));
      expect(mapa['anual'], false);
      expect(mapa['contarAnios'], false);
      expect(mapa['emoji'], '🎂');
      final leida = FechaImportante.fromMap('x', mapa);
      expect(leida.titulo, 'Cumple');
      expect(leida.emoji, '🎂');
    });
  });

  group('tarjeta en el inicio', () {
    Widget app(
      ListaRepository repo, {
      ConfigClub config = const ConfigClub(),
    }) => MaterialApp(
      theme: AppTheme.light,
      home: ConfigClubScope(
        config: config,
        child: Scaffold(body: TarjetaFechas(repository: repo)),
      ),
    );

    testWidgets('muestra la próxima fecha y abre la página', (tester) async {
      final repo = MemoriaListaRepository(reloj: () => hoy);
      await repo.fechas.add(
        NuevaFecha(titulo: 'Viaje a la playa', fecha: DateTime(2027, 4, 1)),
      );
      await repo.fechas.add(
        NuevaFecha(
          titulo: 'Cumpleaños de Ana',
          fecha: DateTime(1996, 12, 10),
          anual: true,
          emoji: '🎂',
        ),
      );
      await tester.pumpWidget(app(repo));
      await tester.pump();
      expect(find.text('Cumpleaños de Ana · Faltan 12 días'), findsOneWidget);
      expect(find.text('Fechas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tarjeta-fechas')));
      await tester.pumpAndSettle();
      expect(find.byType(FechasPage), findsOneWidget);
      expect(find.text('🎂'), findsOneWidget);
      expect(find.text('Viaje a la playa'), findsOneWidget);
      expect(find.textContaining('En 4 meses'), findsOneWidget);
    });

    testWidgets('sin fechas invita a agregarlas', (tester) async {
      await tester.pumpWidget(app(MemoriaListaRepository(reloj: () => hoy)));
      await tester.pump();
      expect(
        find.textContaining('Agrega sus fechas importantes'),
        findsOneWidget,
      );
    });

    testWidgets('se oculta con la bandera fechas en false', (tester) async {
      await tester.pumpWidget(
        app(
          MemoriaListaRepository(reloj: () => hoy),
          config: const ConfigClub(fechas: false),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('tarjeta-fechas')), findsNothing);
      expect(find.textContaining('fechas importantes'), findsNothing);
    });
  });

  group('página de fechas', () {
    testWidgets('agrega una fecha desde la hoja', (tester) async {
      final repo = MemoriaFechasRepository(autor: () => null, reloj: () => hoy);
      await repo.add(
        NuevaFecha(titulo: 'Concierto', fecha: DateTime(2026, 12, 2)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: FechasPage(repository: repo),
        ),
      );
      await tester.pump();
      // Faltan 4 días: se resalta.
      final card = tester.widget<Card>(find.byKey(const ValueKey('fecha-0')));
      expect(card.color, isNotNull);

      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fecha-guardar')));
      await tester.pump();
      expect(find.text('Escribe un título'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('fecha-titulo')), 'Navidad');
      await tester.tap(find.byKey(const Key('fecha-guardar')));
      await tester.pump();
      expect(find.text('Elige la fecha'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fecha-elegir')));
      await tester.pumpAndSettle();
      // El selector abre en "hoy" (28 nov 2026); se elige el 25 de diciembre.
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25'));
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fecha-guardar')));
      await tester.pumpAndSettle();

      expect(find.text('Navidad'), findsOneWidget);
      expect(find.textContaining('Faltan 27 días'), findsOneWidget);
    });

    testWidgets('elimina con confirmación', (tester) async {
      final repo = MemoriaFechasRepository(autor: () => null, reloj: () => hoy);
      await repo.add(
        NuevaFecha(titulo: 'Concierto', fecha: DateTime(2027, 1, 2)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: FechasPage(repository: repo),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Concierto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar la fecha?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Concierto'), findsNothing);
      expect(await repo.watch().first, isEmpty);
    });
  });

  group('widget de Android', () {
    final fechas = [
      fecha('Viaje', DateTime(2026, 11, 1)),
      fecha(
        'Cumpleaños de Ana',
        DateTime(1996, 12, 10),
        anual: true,
        contarAnios: true,
      ),
    ];

    test('incluye la línea de la próxima fecha', () {
      final datos = datosWidget(
        peliculas: const [],
        planes: const [],
        config: const ConfigClub(),
        hoy: hoy,
        fechas: fechas,
      );
      expect(
        datos[ClavesWidget.fecha],
        '📆 Cumpleaños de Ana · Faltan 12 días · cumple 30 años',
      );
      expect(datos[ClavesWidget.fechaTitulo], '📆 Cumpleaños de Ana');
      expect(datos[ClavesWidget.fechaDia], '2026-12-10');
      expect(datos[ClavesWidget.fechaExtra], 'cumple 30 años');
    });

    test('la omite con la bandera apagada o sin fechas próximas', () {
      final apagada = datosWidget(
        peliculas: const [],
        planes: const [],
        config: const ConfigClub(fechas: false),
        hoy: hoy,
        fechas: fechas,
      );
      final pasadas = datosWidget(
        peliculas: const [],
        planes: const [],
        config: const ConfigClub(),
        hoy: hoy,
        fechas: [fechas.first],
      );
      for (final datos in [apagada, pasadas]) {
        expect(datos.containsKey(ClavesWidget.fecha), isTrue);
        expect(datos[ClavesWidget.fecha], isNull);
        expect(datos[ClavesWidget.fechaDia], isNull);
        expect(datos[ClavesWidget.plan], '🧺 Próximo plan: ¡Nada pendiente!');
      }
    });
  });
}
