import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/juego/domain/juego_presa.dart';

void main() {
  const area = Size(400, 800);

  JuegoPresa nuevo({
    int semilla = 1,
    VelocidadPresa velocidad = VelocidadPresa.rapido,
  }) => JuegoPresa(area: area, velocidad: velocidad, random: Random(semilla));

  bool dentro(JuegoPresa j) =>
      j.posicion.dx >= j.radio &&
      j.posicion.dx <= area.width - j.radio &&
      j.posicion.dy >= j.radio &&
      j.posicion.dy <= area.height - j.radio;

  test('la presa nunca sale del área (con margen de su radio)', () {
    for (var semilla = 0; semilla < 5; semilla++) {
      final j = nuevo(semilla: semilla);
      expect(dentro(j), isTrue);
      for (var i = 0; i < 3000; i++) {
        j.actualizar(1 / 60);
        expect(dentro(j), isTrue, reason: 'semilla $semilla, paso $i');
      }
    }
  });

  test('la presa se mueve con el tiempo', () {
    final j = nuevo();
    final inicio = j.posicion;
    var maxDist = 0.0;
    for (var i = 0; i < 120; i++) {
      j.actualizar(1 / 60);
      maxDist = max(maxDist, (j.posicion - inicio).distance);
    }
    expect(maxDist, greaterThan(50));
  });

  test('el movimiento no depende de los cuadros por segundo', () {
    final a = nuevo(semilla: 9);
    final b = nuevo(semilla: 9);
    for (var i = 0; i < 600; i++) {
      a.actualizar(1 / 60);
    }
    for (var i = 0; i < 300; i++) {
      b.actualizar(1 / 30);
    }
    expect((a.posicion - b.posicion).distance, lessThan(0.5));
  });

  test('un salto de tiempo enorme se limita a dtMaximo', () {
    final a = nuevo(semilla: 4, velocidad: VelocidadPresa.lento);
    final b = nuevo(semilla: 4, velocidad: VelocidadPresa.lento);
    a.actualizar(10);
    b.actualizar(JuegoPresa.dtMaximo);
    expect(a.posicion, b.posicion);
  });

  test('más velocidad recorre más camino', () {
    double recorrido(VelocidadPresa v) {
      final j = nuevo(semilla: 3, velocidad: v);
      var total = 0.0;
      var anterior = j.posicion;
      for (var i = 0; i < 60; i++) {
        j.actualizar(1 / 60);
        total += (j.posicion - anterior).distance;
        anterior = j.posicion;
      }
      return total;
    }

    expect(
      recorrido(VelocidadPresa.rapido),
      greaterThan(recorrido(VelocidadPresa.lento)),
    );
  });

  test('tocar la presa la atrapa, suma y la hace reaparecer lejos', () {
    final j = nuevo();
    final donde = j.posicion;
    expect(j.toca(donde), isTrue);
    expect(j.intentarAtrapar(donde), isTrue);
    expect(j.atrapadas, 1);
    expect((j.posicion - donde).distance, greaterThan(area.shortestSide / 3));
    expect(dentro(j), isTrue);
  });

  test('tocar lejos no cuenta', () {
    final j = nuevo();
    final lejos = j.posicion + Offset(j.radio * 2, 0);
    expect(j.intentarAtrapar(lejos), isFalse);
    expect(j.atrapadas, 0);
  });

  test('el toque tiene tolerancia para patitas imprecisas', () {
    final j = nuevo();
    final borde = j.posicion + Offset(j.radio * 1.2, 0);
    expect(j.toca(borde), isTrue);
  });

  test('las atrapadas se acumulan y se pueden reiniciar', () {
    final j = nuevo();
    for (var i = 0; i < 4; i++) {
      j.actualizar(0.05);
      expect(j.intentarAtrapar(j.posicion), isTrue);
    }
    expect(j.atrapadas, 4);
    j.reiniciarPuntos();
    expect(j.atrapadas, 0);
  });

  test('redimensionar mantiene la presa dentro del área nueva', () {
    final j = nuevo();
    j.redimensionar(const Size(120, 120));
    expect(j.posicion.dx, inInclusiveRange(j.radio, 120 - j.radio));
    expect(j.posicion.dy, inInclusiveRange(j.radio, 120 - j.radio));
    for (var i = 0; i < 300; i++) {
      j.actualizar(1 / 60);
      expect(j.posicion.dx, inInclusiveRange(j.radio, 120 - j.radio));
    }
  });
}
