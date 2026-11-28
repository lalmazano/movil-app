import '../../listas/domain/detalles.dart';
import '../domain/fechas_repository.dart';

/// Fechas en memoria, para pruebas y modo local.
class MemoriaFechasRepository implements FechasRepository {
  MemoriaFechasRepository({required this.autor, DateTime Function()? reloj})
    : reloj = reloj ?? DateTime.now;

  /// Quién usa la app (null en modo local sin sesión).
  final Autor? Function() autor;
  final DateTime Function() reloj;
}
