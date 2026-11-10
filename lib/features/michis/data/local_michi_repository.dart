import 'dart:io';

import '../../../core/storage/json_store.dart';
import '../domain/michi.dart';

class LocalMichiRepository implements MichiRepository {
  LocalMichiRepository({BaseDir? baseDir})
    : _store = JsonStore(
        carpeta: 'michis',
        archivo: 'michis',
        baseDir: baseDir,
      );

  final JsonStore _store;

  Future<List<Michi>> _leer() async {
    final dir = await _store.directorio();
    return [
      for (final d in await _store.leer())
        Michi(
          id: d['id'] as String,
          nombre: d['nombre'] as String,
          fotoPath: d['foto'] == null ? null : '${dir.path}/${d['foto']}',
          nacimiento: d['nacimiento'] == null
              ? null
              : DateTime.parse(d['nacimiento'] as String),
          raza: d['raza'] as String? ?? '',
          emoji: d['emoji'] as String? ?? '🐱',
        ),
    ];
  }

  Future<void> _escribir(List<Michi> michis) => _store.escribir([
    for (final m in michis)
      {
        'id': m.id,
        'nombre': m.nombre,
        'foto': m.fotoPath?.split('/').last,
        'nacimiento': m.nacimiento?.toIso8601String(),
        'raza': m.raza,
        'emoji': m.emoji,
      },
  ]);

  Future<String> _copiarFoto(String id, String origen) async {
    final punto = origen.lastIndexOf('.');
    final ext = punto == -1 ? '.jpg' : origen.substring(punto);
    final destino =
        '${(await _store.directorio()).path}/perfil_${id}_${nuevoId()}$ext';
    await File(origen).copy(destino);
    return destino;
  }

  @override
  Future<List<Michi>> getAll() => _leer();

  @override
  Future<Michi> add({
    required String nombre,
    String? fotoOrigen,
    DateTime? nacimiento,
    String raza = '',
    String emoji = '🐱',
  }) async {
    final id = nuevoId();
    final michi = Michi(
      id: id,
      nombre: nombre,
      fotoPath: fotoOrigen == null ? null : await _copiarFoto(id, fotoOrigen),
      nacimiento: nacimiento,
      raza: raza,
      emoji: emoji,
    );
    await _escribir([...await _leer(), michi]);
    return michi;
  }

  @override
  Future<Michi> update(Michi michi, {String? fotoOrigen}) async {
    var actualizado = michi;
    final todos = await _leer();
    if (fotoOrigen != null) {
      final anterior = todos.where((m) => m.id == michi.id).firstOrNull;
      final nueva = await _copiarFoto(michi.id, fotoOrigen);
      if (anterior?.fotoPath case final vieja?) {
        final f = File(vieja);
        if (await f.exists()) await f.delete();
      }
      actualizado = michi.copyWith(fotoPath: () => nueva);
    }
    await _escribir([
      for (final m in todos) m.id == michi.id ? actualizado : m,
    ]);
    return actualizado;
  }

  @override
  Future<void> delete(String id) async {
    final todos = await _leer();
    for (final m in todos.where((m) => m.id == id)) {
      if (m.fotoPath case final foto?) {
        final f = File(foto);
        if (await f.exists()) await f.delete();
      }
    }
    await _escribir(todos.where((m) => m.id != id).toList());
  }
}
