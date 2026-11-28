import '../../listas/domain/detalles.dart';
import '../domain/preguntas_repository.dart';

/// Preguntas en memoria, para pruebas y modo local.
class MemoriaPreguntasRepository implements PreguntasRepository {
  MemoriaPreguntasRepository({required this.autor, DateTime Function()? reloj})
    : reloj = reloj ?? DateTime.now;

  /// Quién usa la app (null en modo local sin sesión).
  final Autor? Function() autor;
  final DateTime Function() reloj;
}
