import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/michis/data/local_michi_repository.dart';
import 'package:movil_app/features/michis/domain/michi.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('michis'));
  tearDown(() => tmp.delete(recursive: true));

  LocalMichiRepository repo() => LocalMichiRepository(baseDir: () async => tmp);

  test('crea, actualiza foto y borra michis', () async {
    final foto = await File('${tmp.path}/f.jpg').writeAsBytes([1]);
    final pelusa = await repo().add(
      nombre: 'Pelusa',
      fotoOrigen: foto.path,
      nacimiento: DateTime(2020, 3, 15),
    );
    expect(File(pelusa.fotoPath!).existsSync(), isTrue);
    expect((await repo().getAll()).single.nombre, 'Pelusa');

    final cambiado = await repo().update(
      pelusa.copyWith(nombre: 'Pelusita'),
      fotoOrigen: foto.path,
    );
    expect(File(pelusa.fotoPath!).existsSync(), isFalse);
    expect(File(cambiado.fotoPath!).existsSync(), isTrue);
    expect((await repo().getAll()).single.nombre, 'Pelusita');

    await repo().delete(pelusa.id);
    expect(await repo().getAll(), isEmpty);
    expect(File(cambiado.fotoPath!).existsSync(), isFalse);
  });

  test('edad y cumpleaños', () {
    final m = Michi(id: '1', nombre: 'Tom', nacimiento: DateTime(2020, 3, 15));
    expect(m.edad(DateTime(2026, 3, 14)), 5);
    expect(m.edad(DateTime(2026, 3, 15)), 6);
    expect(m.esCumpleanos(DateTime(2026, 3, 15)), isTrue);
    expect(m.esCumpleanos(DateTime(2026, 3, 16)), isFalse);
  });
}
