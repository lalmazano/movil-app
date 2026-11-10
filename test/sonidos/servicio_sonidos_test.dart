import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/sonidos/data/servicio_sonidos_audioplayers.dart';
import 'package:movil_app/features/sonidos/domain/servicio_sonidos.dart';
import 'package:movil_app/features/sonidos/presentation/boton_sonido.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sonidos_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  ServicioSonidosAudioplayers nuevo() =>
      ServicioSonidosAudioplayers(baseDir: () async => temp);

  test('por defecto los sonidos están activados', () async {
    final s = nuevo();
    await s.cargar();
    expect(s.activado, isTrue);
  });

  test('la preferencia se guarda y se recupera', () async {
    final s = nuevo();
    await s.cargar();
    var avisos = 0;
    s.addListener(() => avisos++);
    await s.setActivado(false);
    expect(s.activado, isFalse);
    expect(avisos, 1);

    final archivo = File('${temp.path}/sonidos/preferencias.json');
    expect(jsonDecode(await archivo.readAsString()), [
      {'activado': false},
    ]);

    final otro = nuevo();
    await otro.cargar();
    expect(otro.activado, isFalse);

    await otro.setActivado(true);
    final tercero = nuevo();
    await tercero.cargar();
    expect(tercero.activado, isTrue);
  });

  test('un archivo dañado no rompe nada', () async {
    await Directory('${temp.path}/sonidos').create();
    await File('${temp.path}/sonidos/preferencias.json').writeAsString('{{');
    final s = nuevo();
    await s.cargar();
    expect(s.activado, isTrue);
  });

  testWidgets('sin plugin de audio (pruebas) los sonidos no lanzan errores', (
    tester,
  ) async {
    final s = nuevo();
    await tester.runAsync(() async {
      await s.maullar();
      await s.pop();
      await s.trino();
      await s.ronronear();
      await s.detenerRonroneo();
    });
    s.dispose();
  });

  testWidgets('usado desde un widget (como en el inicio) no rompe la prueba', (
    tester,
  ) async {
    final s = nuevo();
    var toques = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GestureDetector(
          onTap: () {
            toques++;
            s.maullar();
            if (toques % 5 == 0) s.ronronear();
          },
          child: const Text('🐱'),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('🐱'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(toques, 5);
  });

  test('el falso silencioso anota solo si está activado', () async {
    final s = ServicioSonidosSilencioso();
    await s.maullar();
    await s.pop();
    await s.setActivado(false);
    await s.ronronear();
    expect(s.llamadas, ['maullar', 'pop']);
  });

  testWidgets('BotonSonido alterna el icono y la preferencia', (tester) async {
    final s = ServicioSonidosSilencioso();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [BotonSonido(sonidos: s)]),
        ),
      ),
    );
    expect(find.byIcon(Icons.volume_up), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(s.activado, isFalse);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(s.activado, isTrue);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(s.llamadas, ['maullar']);
  });
}
