import 'dart:async';

import '../../listas/domain/detalles.dart';
import '../domain/fechas_repository.dart';

/// Fechas en memoria, para pruebas y modo local.
class MemoriaFechasRepository implements FechasRepository {
  MemoriaFechasRepository({required this.autor, DateTime Function()? reloj})
    : reloj = reloj ?? DateTime.now;

  /// Quién usa la app (null en modo local sin sesión).
  final Autor? Function() autor;
  final DateTime Function() reloj;

  final _fechas = <FechaImportante>[];
  final _cambios = StreamController<void>.broadcast();
  var _siguienteId = 0;

  List<FechaImportante> get _ordenadas =>
      List.unmodifiable(ordenarPorCercania(_fechas, reloj()));

  @override
  DateTime hoy() => reloj();

  @override
  Stream<List<FechaImportante>> watch() async* {
    yield _ordenadas;
    yield* _cambios.stream.map((_) => _ordenadas);
  }

  FechaImportante _crear(String id, NuevaFecha f, Autor? creadaPor) =>
      FechaImportante(
        id: id,
        titulo: f.titulo.trim(),
        fecha: DateTime(f.fecha.year, f.fecha.month, f.fecha.day, 12),
        anual: f.anual,
        emoji: f.emoji,
        contarAnios: f.anual && f.contarAnios,
        creadaPor: creadaPor,
      );

  @override
  Future<void> add(NuevaFecha fecha) async {
    _fechas.add(_crear('${_siguienteId++}', fecha, autor()));
    _cambios.add(null);
  }

  @override
  Future<void> update(String id, NuevaFecha fecha) async {
    final i = _fechas.indexWhere((f) => f.id == id);
    if (i < 0) return;
    _fechas[i] = _crear(id, fecha, _fechas[i].creadaPor);
    _cambios.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _fechas.removeWhere((f) => f.id == id);
    _cambios.add(null);
  }
}
