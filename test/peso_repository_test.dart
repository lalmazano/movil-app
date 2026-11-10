import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/peso/data/local_peso_repository.dart';
import 'package:movil_app/features/peso/domain/registro_peso.dart';

RegistroPeso _r(String id, DateTime fecha, double kg) =>
    RegistroPeso(id: id, michiId: 'm', fecha: fecha, kg: kg);

void main() {
  group('LocalPesoRepository', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('peso'));
    tearDown(() => tmp.delete(recursive: true));

    LocalPesoRepository repo() => LocalPesoRepository(baseDir: () async => tmp);

    test('guarda, ordena por fecha, filtra por michi y borra', () async {
      final b = await repo().add(
        michiId: 'pelusa',
        fecha: DateTime(2026, 5, 2),
        kg: 4.256,
        nota: ' después de comer ',
      );
      await repo().add(michiId: 'pelusa', fecha: DateTime(2026, 5, 1), kg: 4);
      await repo().add(michiId: 'tom', fecha: DateTime(2026, 5, 3), kg: 6.5);

      expect(b.kg, 4.26);
      expect(b.nota, 'después de comer');

      final todos = await repo().getAll();
      expect(todos.map((r) => r.kg), [4.0, 4.26, 6.5]);

      final pelusa = await repo().deMichi('pelusa');
      expect(pelusa.map((r) => r.fecha.day), [1, 2]);
      expect(pelusa.last.nota, 'después de comer');

      await repo().delete(b.id);
      expect((await repo().deMichi('pelusa')).single.kg, 4.0);
      expect(await repo().deMichi('nadie'), isEmpty);
    });
  });

  group('cambio de peso', () {
    test('sin registros es null', () {
      expect(calcularCambioPeso([]), isNull);
    });

    test('un solo registro no tiene diferencia', () {
      final c = calcularCambioPeso([_r('1', DateTime(2026, 1, 1), 4)])!;
      expect(c.ultimo.kg, 4);
      expect(c.diferencia, isNull);
      expect(c.descripcion, isNull);
    });

    test('sube, baja o se mantiene (sin importar el orden de entrada)', () {
      final sube = calcularCambioPeso([
        _r('2', DateTime(2026, 1, 2), 4.35),
        _r('1', DateTime(2026, 1, 1), 4.1),
      ])!;
      expect(sube.ultimo.id, '2');
      expect(sube.diferencia, 0.25);
      expect(sube.descripcion, '↑ 0.25 kg 🍗');

      final baja = calcularCambioPeso([
        _r('1', DateTime(2026, 1, 1), 5),
        _r('2', DateTime(2026, 1, 5), 4.9),
        _r('0', DateTime(2025, 1, 1), 1),
      ])!;
      expect(baja.anterior!.id, '1');
      expect(baja.diferencia, -0.1);
      expect(baja.descripcion, '↓ 0.10 kg 🏃');

      final igual = calcularCambioPeso([
        _r('1', DateTime(2026, 1, 1), 5),
        _r('2', DateTime(2026, 1, 2), 5),
      ])!;
      expect(igual.diferencia, 0);
      expect(igual.descripcion, '= sin cambios 😺');
    });
  });

  test('validación de peso', () {
    expect(validarPeso('4.5'), isNull);
    expect(validarPeso('4,5'), isNull);
    expect(validarPeso('0.1'), isNull);
    expect(validarPeso('30'), isNull);
    expect(validarPeso('0.09'), isNotNull);
    expect(validarPeso('30.01'), isNotNull);
    expect(validarPeso(''), isNotNull);
    expect(validarPeso('michi'), isNotNull);
    expect(parsearPeso(' 3,75 '), 3.75);
    expect(redondearKg(3.14159), 3.14);
  });
}
