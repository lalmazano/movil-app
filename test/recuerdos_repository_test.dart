import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movil_app/features/recuerdos/data/local_recuerdo_repository.dart';

void main() {
  late Directory tmp;
  late File foto;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('recuerdos_test');
    foto = await File('${tmp.path}/camara.jpg').writeAsBytes([1, 2, 3]);
  });

  tearDown(() => tmp.delete(recursive: true));

  LocalRecuerdoRepository repo() =>
      LocalRecuerdoRepository(baseDir: () async => tmp);

  test('guarda, lee, califica y borra recuerdos', () async {
    final r = repo();
    expect(await r.getAll(), isEmpty);

    final nuevo = await r.add(
      sourcePath: foto.path,
      calificacion: 4,
      nota: 'Siesta',
    );
    expect(File(nuevo.imagePath).existsSync(), isTrue);
    expect(nuevo.imagePath, isNot(foto.path));

    // Una instancia nueva lee lo guardado en disco.
    final leidos = await repo().getAll();
    expect(leidos.single.calificacion, 4);
    expect(leidos.single.nota, 'Siesta');

    await r.update(nuevo.copyWith(calificacion: 5));
    expect((await repo().getAll()).single.calificacion, 5);

    await r.delete(nuevo.id);
    expect(await repo().getAll(), isEmpty);
    expect(File(nuevo.imagePath).existsSync(), isFalse);
  });

  test('ordena del más reciente al más antiguo', () async {
    final r = repo();
    final a = await r.add(sourcePath: foto.path, calificacion: 1);
    final b = await r.add(sourcePath: foto.path, calificacion: 2);
    expect((await r.getAll()).map((x) => x.id), [b.id, a.id]);
  });
}
