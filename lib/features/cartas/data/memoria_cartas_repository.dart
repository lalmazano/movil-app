import '../../listas/domain/detalles.dart';
import '../domain/cartas_repository.dart';

/// Cartas en memoria, para pruebas y modo local.
class MemoriaCartasRepository implements CartasRepository {
  MemoriaCartasRepository({required this.autor, DateTime Function()? reloj})
    : reloj = reloj ?? DateTime.now;

  /// Quién usa la app (null en modo local sin sesión).
  final Autor? Function() autor;
  final DateTime Function() reloj;
}
