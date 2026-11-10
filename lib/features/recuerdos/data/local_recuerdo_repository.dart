import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/recuerdo.dart';

/// Guarda las fotos en la carpeta privada de la app y los datos en un JSON.
///
/// Solo se guarda el nombre del archivo (no la ruta completa) porque en iOS
/// la carpeta de documentos puede cambiar entre actualizaciones.
class LocalRecuerdoRepository implements RecuerdoRepository {
  LocalRecuerdoRepository({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;
  Directory? _dir;

  Future<Directory> _carpeta() async {
    final base = await _baseDir();
    return _dir ??= await Directory('${base.path}/recuerdos')
        .create(recursive: true);
  }

  Future<File> _indice() async =>
      File('${(await _carpeta()).path}/recuerdos.json');

  Future<List<Recuerdo>> _leer() async {
    final indice = await _indice();
    if (!await indice.exists()) return [];
    final dir = await _carpeta();
    final datos = jsonDecode(await indice.readAsString()) as List<dynamic>;
    return [
      for (final d in datos.cast<Map<String, dynamic>>())
        Recuerdo(
          id: d['id'] as String,
          imagePath: '${dir.path}/${d['archivo']}',
          fecha: DateTime.parse(d['fecha'] as String),
          calificacion: d['calificacion'] as int,
          nota: d['nota'] as String? ?? '',
        ),
    ];
  }

  Future<void> _escribir(List<Recuerdo> recuerdos) async {
    final datos = [
      for (final r in recuerdos)
        {
          'id': r.id,
          'archivo': r.imagePath.split('/').last,
          'fecha': r.fecha.toIso8601String(),
          'calificacion': r.calificacion,
          'nota': r.nota,
        },
    ];
    await (await _indice()).writeAsString(jsonEncode(datos), flush: true);
  }

  @override
  Future<List<Recuerdo>> getAll() async =>
      (await _leer())..sort((a, b) => b.fecha.compareTo(a.fecha));

  @override
  Future<Recuerdo> add({
    required String sourcePath,
    required int calificacion,
    String nota = '',
  }) async {
    final fecha = DateTime.now();
    final id = fecha.microsecondsSinceEpoch.toString();
    final punto = sourcePath.lastIndexOf('.');
    final ext = punto == -1 ? '.jpg' : sourcePath.substring(punto);
    final destino = '${(await _carpeta()).path}/michi_$id$ext';
    await File(sourcePath).copy(destino);

    final recuerdo = Recuerdo(
      id: id,
      imagePath: destino,
      fecha: fecha,
      calificacion: calificacion,
      nota: nota,
    );
    await _escribir([...await _leer(), recuerdo]);
    return recuerdo;
  }

  @override
  Future<void> update(Recuerdo recuerdo) async {
    final todos = await _leer();
    await _escribir([
      for (final r in todos) r.id == recuerdo.id ? recuerdo : r,
    ]);
  }

  @override
  Future<void> delete(String id) async {
    final todos = await _leer();
    for (final r in todos.where((r) => r.id == id)) {
      final foto = File(r.imagePath);
      if (await foto.exists()) await foto.delete();
    }
    await _escribir(todos.where((r) => r.id != id).toList());
  }
}
