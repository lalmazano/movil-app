import 'dart:typed_data';

/// Persona del club que hizo algo (agregar, marcar, calificar, subir foto).
/// Se guarda en Firestore como `{uid, nombre, foto}`.
class Autor {
  const Autor({required this.uid, this.nombre, this.fotoUrl});

  final String uid;
  final String? nombre;
  final String? fotoUrl;

  String get nombreCorto =>
      (nombre?.trim().isNotEmpty ?? false) ? nombre!.split(' ').first : '¿?';

  Map<String, Object?> toMap() => {
    'uid': uid,
    'nombre': nombre,
    'foto': fotoUrl,
  };

  static Autor? fromMap(Object? map) {
    if (map is! Map || map['uid'] is! String) return null;
    return Autor(
      uid: map['uid'] as String,
      nombre: map['nombre'] as String?,
      fotoUrl: map['foto'] as String?,
    );
  }
}

/// Calificación de una persona: de 1 a 5 huellitas y un comentario.
/// Se guarda en `calificaciones.{uid}` del elemento.
class Calificacion {
  const Calificacion({
    required this.autor,
    required this.huellitas,
    this.comentario = '',
    this.fecha,
  }) : assert(huellitas >= 1 && huellitas <= 5);

  final Autor autor;
  final int huellitas;
  final String comentario;
  final DateTime? fecha;

  Map<String, Object?> toMap() => {
    ...autor.toMap(),
    'huellitas': huellitas,
    'comentario': comentario,
    'fecha': fecha,
  };

  static Calificacion? fromMap(Object? map) {
    final autor = Autor.fromMap(map);
    if (autor == null || map is! Map) return null;
    final h = (map['huellitas'] as num?)?.toInt() ?? 0;
    if (h < 1 || h > 5) return null;
    return Calificacion(
      autor: autor,
      huellitas: h,
      comentario: (map['comentario'] as String?) ?? '',
      fecha: map['fecha'] as DateTime?,
    );
  }
}

/// Datos de una película tomados de TMDB. Se guarda en `pelicula`.
class InfoPelicula {
  const InfoPelicula({
    required this.tmdbId,
    this.posterUrl,
    this.anio,
    this.duracionMin,
    this.resumen,
  });

  final int tmdbId;
  final String? posterUrl;
  final int? anio;
  final int? duracionMin;
  final String? resumen;

  Map<String, Object?> toMap() => {
    'tmdbId': tmdbId,
    'poster': posterUrl,
    'anio': anio,
    'duracion': duracionMin,
    'resumen': resumen,
  };

  static InfoPelicula? fromMap(Object? map) {
    if (map is! Map || map['tmdbId'] is! num) return null;
    return InfoPelicula(
      tmdbId: (map['tmdbId'] as num).toInt(),
      posterUrl: map['poster'] as String?,
      anio: (map['anio'] as num?)?.toInt(),
      duracionMin: (map['duracion'] as num?)?.toInt(),
      resumen: map['resumen'] as String?,
    );
  }
}

/// Foto de un recuerdo, guardada dentro de Firestore (sin Storage) en
/// `clubs/{club}/{lista}/{itemId}/fotos/{fotoId}` con el campo `datos` (Blob,
/// JPEG comprimido de menos de ~900 KB).
class FotoItem {
  const FotoItem({
    required this.id,
    required this.bytes,
    required this.creadoEn,
    this.autor,
  });

  final String id;
  final Uint8List bytes;
  final DateTime creadoEn;
  final Autor? autor;
}

/// Tamaño máximo de una foto guardada en Firestore (un documento admite 1 MiB).
const int maxBytesFoto = 900 * 1024;
