import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/recordatorios/domain/recordatorio.dart';
import 'package:movil_app/features/recordatorios/domain/servicio_recordatorios.dart';

import 'cuidados_fakes.dart';

Recordatorio _r(
  DateTime fecha, {
  Repeticion repeticion = Repeticion.unaVez,
  TipoRecordatorio tipo = TipoRecordatorio.comida,
  String id = 'r1',
  String? michiId,
  bool activo = true,
}) => Recordatorio(
  id: id,
  tipo: tipo,
  titulo: 'Croquetas',
  fecha: fecha,
  repeticion: repeticion,
  michiId: michiId,
  activo: activo,
);

void main() {
  // Martes 10 de noviembre de 2026, 09:00.
  final ahora = DateTime(2026, 11, 10, 9);

  group('proximaOcurrencia', () {
    test('una vez: futura se mantiene, pasada es null', () {
      expect(
        _r(DateTime(2026, 11, 10, 10)).proximaOcurrencia(ahora),
        DateTime(2026, 11, 10, 10),
      );
      expect(_r(DateTime(2026, 11, 10, 8)).proximaOcurrencia(ahora), isNull);
      expect(_r(ahora).proximaOcurrencia(ahora), isNull);
    });

    test('diario: hoy si aún no pasó la hora, si no mañana', () {
      final inicio = DateTime(2026, 1, 1, 18, 30);
      expect(
        _r(inicio, repeticion: Repeticion.diario).proximaOcurrencia(ahora),
        DateTime(2026, 11, 10, 18, 30),
      );
      final temprano = DateTime(2026, 1, 1, 7, 15);
      expect(
        _r(temprano, repeticion: Repeticion.diario).proximaOcurrencia(ahora),
        DateTime(2026, 11, 11, 7, 15),
      );
    });

    test('semanal: mismo día de la semana', () {
      // Lunes 2 de noviembre a las 8:00 -> próximo lunes 16.
      final lunes = DateTime(2026, 11, 2, 8);
      expect(
        _r(lunes, repeticion: Repeticion.semanal).proximaOcurrencia(ahora),
        DateTime(2026, 11, 16, 8),
      );
      // Martes a las 20:00 -> hoy mismo.
      final martes = DateTime(2026, 11, 3, 20);
      expect(
        _r(martes, repeticion: Repeticion.semanal).proximaOcurrencia(ahora),
        DateTime(2026, 11, 10, 20),
      );
      // Martes a las 8:00 -> el martes siguiente.
      final martesTemprano = DateTime(2026, 11, 3, 8);
      expect(
        _r(
          martesTemprano,
          repeticion: Repeticion.semanal,
        ).proximaOcurrencia(ahora),
        DateTime(2026, 11, 17, 8),
      );
    });

    test('mensual: mismo día del mes y salta meses sin ese día', () {
      final dia5 = DateTime(2026, 1, 5, 12);
      expect(
        _r(dia5, repeticion: Repeticion.mensual).proximaOcurrencia(ahora),
        DateTime(2026, 12, 5, 12),
      );
      final dia15 = DateTime(2026, 1, 15, 12);
      expect(
        _r(dia15, repeticion: Repeticion.mensual).proximaOcurrencia(ahora),
        DateTime(2026, 11, 15, 12),
      );
      // Día 31: noviembre no lo tiene -> 31 de diciembre.
      final dia31 = DateTime(2026, 1, 31, 12);
      expect(
        _r(dia31, repeticion: Repeticion.mensual).proximaOcurrencia(ahora),
        DateTime(2026, 12, 31, 12),
      );
    });

    test('una fecha futura siempre es la próxima, se repita o no', () {
      final futura = DateTime(2027, 3, 1, 9);
      for (final rep in Repeticion.values) {
        expect(_r(futura, repeticion: rep).proximaOcurrencia(ahora), futura);
      }
    });
  });

  test('idNotificacion es estable, positivo y cabe en 31 bits', () {
    final id = idNotificacionDe('1731234567890123');
    expect(id, idNotificacionDe('1731234567890123'));
    expect(id, isNot(idNotificacionDe('1731234567890124')));
    expect(id, inInclusiveRange(0, 0x7fffffff));
  });

  test('texto de la notificación con sabor michi', () {
    final r = _r(ahora);
    expect(
      textoNotificacion(r, nombreMichi: 'Pelusa').titulo,
      '🐱 ¡Hora de la comida de Pelusa!',
    );
    expect(textoNotificacion(r).titulo, '🐱 ¡Hora de la comida michi!');
    expect(textoNotificacion(r).cuerpo, 'Croquetas 🐾');
    expect(
      textoNotificacion(
        _r(ahora, tipo: TipoRecordatorio.vacuna),
        nombreMichi: 'Garfield',
      ).titulo,
      '💉 ¡Toca vacuna para Garfield!',
    );
  });

  test('json ida y vuelta', () {
    final r = _r(
      DateTime(2026, 12, 1, 8, 5),
      repeticion: Repeticion.mensual,
      tipo: TipoRecordatorio.desparasitacion,
      michiId: 'p',
      activo: false,
    );
    final copia = Recordatorio.fromJson(r.toJson());
    expect(copia.toJson(), r.toJson());
  });

  group('ServicioRecordatorios', () {
    late RecordatoriosEnMemoria repo;
    late NotificadorFalso notificador;
    late ServicioRecordatorios servicio;

    setUp(() {
      repo = RecordatoriosEnMemoria();
      notificador = NotificadorFalso();
      servicio = ServicioRecordatorios(
        repository: repo,
        notificador: notificador,
        michis: MichisEnMemoria([pelusa]),
        reloj: () => ahora,
      );
    });

    test('guardar programa con el nombre del michi y la repetición', () async {
      final r = _r(
        DateTime(2026, 1, 1, 18),
        repeticion: Repeticion.diario,
        michiId: 'p',
      );
      await servicio.guardar(r);
      final n = notificador.programadas[r.idNotificacion]!;
      expect(n.titulo, '🐱 ¡Hora de la comida de Pelusa!');
      expect(n.fecha, DateTime(2026, 11, 10, 18));
      expect(n.repeticion, Repeticion.diario);
      expect(notificador.permisosPedidos, 1);
      expect(repo.datos, hasLength(1));
    });

    test('apagar cancela y encender vuelve a programar', () async {
      final r = _r(DateTime(2026, 11, 12, 8));
      await servicio.guardar(r);
      final apagado = await servicio.alternar(r, false);
      expect(notificador.programadas, isEmpty);
      expect(notificador.cancelados, contains(r.idNotificacion));
      expect(repo.datos.single.activo, isFalse);

      await servicio.alternar(apagado, true);
      expect(notificador.programadas.keys, [r.idNotificacion]);
    });

    test('pasados no se programan; eliminar cancela', () async {
      final pasado = _r(DateTime(2026, 11, 1, 8), id: 'viejo');
      await servicio.guardar(pasado);
      expect(notificador.programadas, isEmpty);

      final futuro = _r(DateTime(2026, 11, 20, 8), id: 'nuevo');
      await servicio.guardar(futuro);
      await servicio.eliminar(futuro);
      expect(notificador.programadas, isEmpty);
      expect(notificador.cancelados.last, futuro.idNotificacion);
      expect(repo.datos.map((r) => r.id), ['viejo']);
    });

    test('sincronizarTodos programa solo los activos con futuro', () async {
      repo.datos.addAll([
        _r(DateTime(2026, 11, 20, 8), id: 'a'),
        _r(DateTime(2026, 11, 20, 8), id: 'b', activo: false),
        _r(DateTime(2026, 1, 1, 8), id: 'c'),
        _r(DateTime(2026, 1, 1, 8), id: 'd', repeticion: Repeticion.semanal),
      ]);
      await servicio.sincronizarTodos();
      expect(notificador.programadas.keys.toSet(), {
        idNotificacionDe('a'),
        idNotificacionDe('d'),
      });
      expect(notificador.cancelados, hasLength(4));
    });
  });
}
