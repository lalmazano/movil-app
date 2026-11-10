import 'recuerdo.dart';

/// Acciones del recuerdo que usan funciones del teléfono.
abstract interface class RecuerdoAcciones {
  /// Guarda la foto en la galería del teléfono (álbum "Michis").
  Future<void> guardarEnGaleria(Recuerdo recuerdo);

  /// Abre el menú de compartir del sistema (WhatsApp, Instagram, etc.).
  Future<void> compartir(Recuerdo recuerdo);
}

/// Error al guardar en galería porque el usuario negó el permiso.
class PermisoGaleriaDenegado implements Exception {
  const PermisoGaleriaDenegado();
}

/// Texto que acompaña la foto al compartirla.
String textoParaCompartir(Recuerdo recuerdo) {
  final nota = recuerdo.nota.isEmpty ? '' : '"${recuerdo.nota}"\n';
  return '📸 Mi recuerdo con mi michi 🐱\n'
      '$nota'
      '${'🐾' * recuerdo.calificacion} '
      '${etiquetaCalificacion(recuerdo.calificacion)}';
}
