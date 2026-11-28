import 'fecha_importante.dart';

export 'fecha_importante.dart';

/// Contrato del repositorio de fechas importantes (`clubs/{club}/fechas`).
abstract interface class FechasRepository {
  /// Qué día es hoy (inyectable en pruebas).
  DateTime hoy();

  /// Todas las fechas, ordenadas por cercanía ([ordenarPorCercania]).
  Stream<List<FechaImportante>> watch();

  Future<void> add(NuevaFecha fecha);

  Future<void> update(String id, NuevaFecha fecha);

  Future<void> delete(String id);
}
