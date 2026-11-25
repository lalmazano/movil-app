import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/core/theme/app_theme.dart';
import 'package:movil_app/features/home/data/widget_inicio.dart';
import 'package:movil_app/features/home/domain/aniversario.dart';
import 'package:movil_app/features/home/presentation/home_page.dart';
import 'package:movil_app/features/listas/data/memoria_lista_repository.dart';
import 'package:movil_app/features/listas/domain/config_club.dart';
import 'package:movil_app/features/listas/domain/item_lista.dart';

TiempoJuntos t(int anios, int meses, int dias, int total) =>
    TiempoJuntos(anios: anios, meses: meses, dias: dias, totalDias: total);

void main() {
  group('tiempoJuntos', () {
    test('mismo día', () {
      expect(
        tiempoJuntos(DateTime(2024, 5, 10, 22), DateTime(2024, 5, 10, 8)),
        t(0, 0, 0, 0),
      );
    });

    test('años, meses y días', () {
      expect(
        tiempoJuntos(DateTime(2023, 2, 14), DateTime(2024, 5, 26)),
        t(1, 3, 12, 467),
      );
    });

    test('fin de mes: 31 ene → 28 feb es un mes', () {
      expect(
        tiempoJuntos(DateTime(2023, 1, 31), DateTime(2023, 2, 28)),
        t(0, 1, 0, 28),
      );
      expect(
        tiempoJuntos(DateTime(2023, 1, 31), DateTime(2023, 2, 27)),
        t(0, 0, 27, 27),
      );
      expect(
        tiempoJuntos(DateTime(2023, 1, 31), DateTime(2023, 3, 1)),
        t(0, 1, 1, 29),
      );
    });

    test('año bisiesto', () {
      expect(
        tiempoJuntos(DateTime(2024, 1, 31), DateTime(2024, 2, 29)),
        t(0, 1, 0, 29),
      );
      expect(
        tiempoJuntos(DateTime(2024, 2, 29), DateTime(2025, 2, 28)),
        t(1, 0, 0, 365),
      );
      expect(
        tiempoJuntos(DateTime(2024, 2, 29), DateTime(2028, 2, 29)),
        t(4, 0, 0, 1461),
      );
    });

    test('cruza el año nuevo', () {
      expect(
        tiempoJuntos(DateTime(2023, 12, 20), DateTime(2024, 1, 5)),
        t(0, 0, 16, 16),
      );
    });

    test('fecha futura', () {
      final r = tiempoJuntos(DateTime(2024, 3, 10), DateTime(2024, 3, 1));
      expect(r.esFuturo, isTrue);
      expect(r.totalDias, -9);
    });
  });

  group('textos', () {
    test('plural, singular y partes en cero', () {
      expect(
        textoAniversario(DateTime(2023, 2, 14), DateTime(2024, 5, 26)),
        'Llevamos 1 año, 3 meses y 12 días juntos 🫘',
      );
      expect(
        textoAniversario(DateTime(2022, 1, 1), DateTime(2024, 1, 2)),
        'Llevamos 2 años y 1 día juntos 🫘',
      );
      expect(
        textoAniversario(DateTime(2024, 1, 15), DateTime(2024, 2, 15)),
        'Llevamos 1 mes juntos 🫘',
      );
      expect(
        textoAniversario(DateTime(2024, 1, 15), DateTime(2024, 1, 16)),
        'Llevamos 1 día juntos 🫘',
      );
    });

    test('hoy y fechas futuras', () {
      final hoy = DateTime(2024, 6, 1);
      expect(textoAniversario(hoy, hoy), '¡Hoy empieza todo! 🫘');
      expect(textoDiasJuntos(hoy, hoy), '¡Hoy empieza todo! 🫘');
      expect(textoAniversario(DateTime(2024, 6, 2), hoy), 'Falta 1 día 🫘');
      expect(textoDiasJuntos(DateTime(2024, 6, 11), hoy), 'Faltan 10 días 🫘');
    });

    test('total de días', () {
      expect(
        textoDiasJuntos(DateTime(2023, 2, 14), DateTime(2024, 5, 26)),
        '467 días juntos 🫘',
      );
      expect(
        textoDiasJuntos(DateTime(2024, 1, 1), DateTime(2024, 1, 2)),
        '1 día juntos 🫘',
      );
    });
  });

  group('datosWidget', () {
    ItemLista item(String titulo, int dia, {bool hecho = false}) => ItemLista(
      id: titulo,
      titulo: titulo,
      categoria: 'Otros',
      creadoEn: DateTime(2024, 1, dia),
      hecho: hecho,
    );

    test('elige el pendiente más antiguo y respeta la visibilidad', () {
      final datos = datosWidget(
        peliculas: [
          item('Shrek 2', 3),
          item('Coco', 1, hecho: true),
          item('Enredados', 2),
        ],
        planes: [item('Picnic', 1, hecho: true)],
        config: ConfigClub(aniversario: DateTime(2024, 1, 1)),
        hoy: DateTime(2024, 1, 11),
      );
      expect(datos[ClavesWidget.pelicula], '🎬 Próxima película: Enredados');
      expect(datos[ClavesWidget.plan], '🧺 Próximo plan: ¡Nada pendiente!');
      expect(datos[ClavesWidget.aniversario], 'Llevamos 10 días juntos 🫘');
      expect(datos[ClavesWidget.aniversarioFecha], '2024-01-01');

      final ocultas = datosWidget(
        peliculas: [item('Shrek 2', 3)],
        planes: const [],
        config: const ConfigClub(peliculas: false),
        hoy: DateTime(2024, 1, 11),
      );
      expect(ocultas[ClavesWidget.pelicula], isNull);
      expect(ocultas[ClavesWidget.aniversario], isNull);

      final sinContador = datosWidget(
        peliculas: const [],
        planes: const [],
        config: ConfigClub(aniversario: DateTime(2024, 1, 1), contador: false),
        hoy: DateTime(2024, 1, 11),
      );
      expect(sinContador[ClavesWidget.aniversario], isNull);
      expect(ocultas[ClavesWidget.plan], '🧺 Próximo plan: ¡Nada pendiente!');
    });

    test('en las pruebas el widget de Android no se activa', () {
      expect(WidgetInicio.esAndroid, isFalse);
      expect(WidgetInicio(MemoriaListaRepository()).habilitado, isFalse);
    });
  });

  group('contador en el inicio', () {
    Widget app(ListaRepository repo) => MaterialApp(
      theme: AppTheme.light,
      home: HomePage(repository: repo, reloj: () => DateTime(2024, 5, 26, 9)),
    );

    testWidgets('se muestra y al tocarlo alterna a días', (tester) async {
      await tester.pumpWidget(
        app(
          MemoriaListaRepository(
            config: ConfigClub(aniversario: DateTime(2023, 2, 14)),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Llevamos 1 año, 3 meses y 12 días juntos 🫘'),
        findsOneWidget,
      );
      expect(find.text('Películas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('contador-aniversario')));
      await tester.pump();
      expect(find.text('467 días juntos 🫘'), findsOneWidget);

      await tester.tap(find.byKey(const Key('contador-aniversario')));
      await tester.pump();
      expect(find.textContaining('Llevamos 1 año'), findsOneWidget);
    });

    testWidgets('no aparece con la bandera contador en false', (tester) async {
      await tester.pumpWidget(
        app(
          MemoriaListaRepository(
            config: ConfigClub(
              aniversario: DateTime(2023, 2, 14),
              contador: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('contador-aniversario')), findsNothing);
    });

    testWidgets('no aparece sin fecha de aniversario', (tester) async {
      await tester.pumpWidget(app(MemoriaListaRepository()));
      await tester.pump();
      expect(find.byKey(const Key('contador-aniversario')), findsNothing);
      expect(find.text('Películas'), findsOneWidget);
    });
  });
}
