import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/recordatorios/data/local_recordatorio_repository.dart';
import 'package:movil_app/features/recordatorios/domain/recordatorio.dart';
import 'package:movil_app/features/salud/data/local_salud_repository.dart';
import 'package:movil_app/features/salud/domain/entrada_salud.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('cuidados'));
  tearDown(() => tmp.delete(recursive: true));

  test('recordatorios: guarda, edita, ordena y borra', () async {
    LocalRecordatorioRepository repo() =>
        LocalRecordatorioRepository(baseDir: () async => tmp);
    expect(await repo().getAll(), isEmpty);

    final tarde = Recordatorio(
      id: 'a',
      tipo: TipoRecordatorio.arenero,
      titulo: 'Arenero',
      fecha: DateTime(2026, 11, 10, 20),
      repeticion: Repeticion.diario,
      michiId: 'p',
    );
    final temprano = Recordatorio(
      id: 'b',
      tipo: TipoRecordatorio.vacuna,
      titulo: 'Triple felina',
      fecha: DateTime(2026, 11, 10, 8),
    );
    await repo().guardar(tarde);
    await repo().guardar(temprano);

    final leidos = await repo().getAll();
    expect(leidos.map((r) => r.id), ['b', 'a']);
    expect(leidos.last.repeticion, Repeticion.diario);
    expect(leidos.last.michiId, 'p');

    await repo().guardar(tarde.copyWith(activo: false, titulo: 'Arena'));
    final editado = (await repo().getAll()).last;
    expect(editado.activo, isFalse);
    expect(editado.titulo, 'Arena');
    expect(await repo().getAll(), hasLength(2));

    await repo().delete('b');
    expect((await repo().getAll()).map((r) => r.id), ['a']);
  });

  test('salud: guarda, edita, ordena (reciente primero) y borra', () async {
    LocalSaludRepository repo() =>
        LocalSaludRepository(baseDir: () async => tmp);
    expect(await repo().getAll(), isEmpty);

    await repo().guardar(
      EntradaSalud(
        id: 'v',
        tipo: TipoSalud.vacuna,
        fecha: DateTime(2026, 3, 1),
        titulo: 'Rabia',
        michiId: 'p',
        costo: 25.5,
      ),
    );
    await repo().guardar(
      EntradaSalud(
        id: 's',
        tipo: TipoSalud.sintoma,
        fecha: DateTime(2026, 10, 1),
        titulo: 'Estornudos',
        notas: 'Solo por la mañana',
      ),
    );

    final leidas = await repo().getAll();
    expect(leidas.map((e) => e.id), ['s', 'v']);
    expect(leidas.last.costo, 25.5);
    expect(leidas.first.costo, isNull);
    expect(leidas.first.notas, 'Solo por la mañana');

    await repo().guardar(
      EntradaSalud(
        id: 'v',
        tipo: TipoSalud.vacuna,
        fecha: DateTime(2026, 3, 1),
        titulo: 'Rabia (refuerzo)',
        michiId: 'p',
      ),
    );
    expect((await repo().getAll()).last.titulo, 'Rabia (refuerzo)');

    await repo().delete('s');
    expect((await repo().getAll()).map((e) => e.id), ['v']);
  });

  test('filtrarEntradas por michi y tipo', () {
    final e = [
      EntradaSalud(
        id: '1',
        tipo: TipoSalud.vacuna,
        fecha: DateTime(2026),
        titulo: 'a',
        michiId: 'p',
      ),
      EntradaSalud(
        id: '2',
        tipo: TipoSalud.medicina,
        fecha: DateTime(2026),
        titulo: 'b',
        michiId: 'p',
      ),
      EntradaSalud(
        id: '3',
        tipo: TipoSalud.vacuna,
        fecha: DateTime(2026),
        titulo: 'c',
        michiId: 'g',
      ),
    ];
    expect(filtrarEntradas(e).length, 3);
    expect(filtrarEntradas(e, michiId: 'p').map((x) => x.id), ['1', '2']);
    expect(filtrarEntradas(e, tipo: TipoSalud.vacuna).map((x) => x.id), [
      '1',
      '3',
    ]);
    expect(
      filtrarEntradas(e, michiId: 'g', tipo: TipoSalud.vacuna).map((x) => x.id),
      ['3'],
    );
  });
}
