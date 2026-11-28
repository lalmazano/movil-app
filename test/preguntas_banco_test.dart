import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movil_app/features/listas/domain/detalles.dart';
import 'package:movil_app/features/preguntas/data/memoria_preguntas_repository.dart';
import 'package:movil_app/features/preguntas/data/preguntas_internet.dart';
import 'package:movil_app/features/preguntas/domain/preguntas_repository.dart';
import 'package:movil_app/features/preguntas/presentation/banco_preguntas_page.dart';

const luis = Autor(uid: 'u1', nombre: 'Luis Almazán');

PreguntaPropuesta propuesta(String id, String texto, DateTime creada) =>
    PreguntaPropuesta(id: id, texto: texto, creadaEn: creada, autor: luis);

void main() {
  group('elegirPregunta', () {
    final dia = DateTime(2026, 11, 28);

    test('primero la propuesta más antigua en espera', () {
      final r = elegirPregunta(
        dia,
        banco: [
          propuesta('b', 'Segunda', DateTime(2026, 2)),
          propuesta('a', 'Primera', DateTime(2026, 1)),
        ],
        deInternet: '¿De internet?',
      );
      expect(r.pregunta, 'Primera');
      expect(r.fuente, FuentePregunta.club);
      expect(r.propuesta?.id, 'a');
    });

    test('sin propuestas: internet si hay, si no la de la app', () {
      final conInternet = elegirPregunta(
        dia,
        deInternet: ' ¿Playa o montaña? ',
      );
      expect(conInternet.pregunta, '¿Playa o montaña?');
      expect(conInternet.fuente, FuentePregunta.internet);

      final sinInternet = elegirPregunta(dia);
      expect(sinInternet.fuente, FuentePregunta.app);
      expect(sinInternet.pregunta, preguntaDelDia(dia));
    });

    test('las usadas no vuelven a salir', () {
      final r = elegirPregunta(
        dia,
        banco: [
          PreguntaPropuesta(
            id: 'a',
            texto: 'Ya salió',
            creadaEn: DateTime(2026),
            usadaEn: DateTime(2026, 5),
          ),
        ],
      );
      expect(r.fuente, FuentePregunta.app);
    });

    test('internet se alterna un día sí y otro no', () {
      expect(
        tocaInternet(DateTime(2026, 11, 28)),
        isNot(tocaInternet(DateTime(2026, 11, 29))),
      );
    });

    test('validarPropuesta', () {
      expect(validarPropuesta('  ¿Qué te gusta?  '), '¿Qué te gusta?');
      expect(() => validarPropuesta('¿?'), throwsArgumentError);
      expect(() => validarPropuesta('x' * 301), throwsArgumentError);
    });
  });

  group('PreguntasInternet', () {
    PreguntasInternet cliente(http.Client c) => PreguntasInternet(client: c);

    test('usa la traducción al español', () async {
      late Uri pedida;
      final p = cliente(
        MockClient((r) async {
          pedida = r.url;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'question': 'Would you rather…?',
                'translations': {'es': '¿Preferirías playa o montaña?'},
              }),
            ),
            200,
          );
        }),
      );
      expect(
        await p.preguntaPara(DateTime(2026, 11, 28)),
        '¿Preferirías playa o montaña?',
      );
      expect(pedida.host, 'api.truthordarebot.xyz');
      expect(pedida.queryParameters['rating'], 'pg');
    });

    test('errores y respuestas raras devuelven null', () async {
      expect(
        await cliente(MockClient((_) async => http.Response('nope', 500)))
            .preguntaPara(DateTime(2026)),
        isNull,
      );
      expect(
        await cliente(
          MockClient((_) async => http.Response('{"translations":{}}', 200)),
        ).preguntaPara(DateTime(2026)),
        isNull,
      );
      expect(
        await cliente(MockClient((_) async => throw Exception('sin internet')))
            .preguntaPara(DateTime(2026)),
        isNull,
      );
    });
  });

  group('Repositorio en memoria', () {
    test('la propuesta sale como pregunta del día y queda usada', () async {
      var hoy = DateTime(2026, 11, 28, 9);
      final repo = MemoriaPreguntasRepository(
        autor: () => luis,
        reloj: () => hoy,
      );
      await repo.proponer('¿Cuál es tu canción favorita de los dos?');
      await repo.asegurarHoy();
      expect(
        await repo.watchPregunta(repo.hoy).first,
        '¿Cuál es tu canción favorita de los dos?',
      );
      final propuestas = await repo.watchPropuestas().first;
      expect(propuestas.single.usada, isTrue);

      hoy = DateTime(2026, 11, 29, 9);
      await repo.asegurarHoy();
      expect(
        await repo.watchPregunta(repo.hoy).first,
        preguntaDelDia(DateTime(2026, 11, 29)),
      );
    });

    test('sin propuestas usa internet en su día si está activado', () async {
      final dia = tocaInternet(DateTime(2026, 11, 28))
          ? DateTime(2026, 11, 28)
          : DateTime(2026, 11, 29);
      final repo = MemoriaPreguntasRepository(
        autor: () => luis,
        reloj: () => dia,
        internet: (_) async => '¿Verdad de internet?',
      );
      await repo.asegurarHoy(usarInternet: true);
      expect(await repo.watchPregunta(repo.hoy).first, '¿Verdad de internet?');
    });

    test('con internet apagado usa la de la app', () async {
      final dia = tocaInternet(DateTime(2026, 11, 28))
          ? DateTime(2026, 11, 28)
          : DateTime(2026, 11, 29);
      final repo = MemoriaPreguntasRepository(
        autor: () => luis,
        reloj: () => dia,
        internet: (_) async => '¿Verdad de internet?',
      );
      await repo.asegurarHoy();
      expect(await repo.watchPregunta(repo.hoy).first, preguntaDelDia(dia));
    });
  });

  testWidgets('Proponer una pregunta desde el banco', (tester) async {
    final repo = MemoriaPreguntasRepository(
      autor: () => luis,
      reloj: () => DateTime(2026, 11, 28),
    );
    await tester.pumpWidget(
      MaterialApp(home: BancoPreguntasPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay propuestas'), findsOneWidget);

    await tester.tap(find.text('Proponer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-propuesta')),
      '¿Qué te hace reír siempre?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('boton-proponer')));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué te hace reír siempre?'), findsOneWidget);
    expect(find.textContaining('Sale en la próxima'), findsOneWidget);
    expect(find.byTooltip('Borrar'), findsOneWidget);
  });
}
