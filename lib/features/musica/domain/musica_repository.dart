import '../../listas/domain/detalles.dart';
import 'cancion.dart';

export 'cancion.dart';

/// Canción en la playlist del club (`clubs/{club}/playlist/{itunesId}`).
class CancionPlaylist {
  const CancionPlaylist({
    required this.id,
    required this.cancion,
    required this.agregadaEn,
    this.agregadaPor,
    this.corazones = const {},
  });

  final String id;
  final Cancion cancion;
  final DateTime agregadaEn;
  final Autor? agregadaPor;

  /// uid de quienes le dieron ❤️.
  final Set<String> corazones;
}

/// Récord de una persona en "Adivina la canción"
/// (`clubs/{club}/adivina/{uid}`).
class RecordAdivina {
  const RecordAdivina({
    required this.autor,
    required this.mejor,
    required this.partidas,
    this.ultimaEn,
  });

  final Autor autor;

  /// Mejor puntaje (aciertos en una partida).
  final int mejor;
  final int partidas;
  final DateTime? ultimaEn;
}

/// Música del club: playlist compartida y récords del juego.
abstract interface class MusicaRepository {
  /// Quién usa la app (null sin sesión).
  Autor? get autorActual;

  /// Playlist, de la más nueva a la más vieja.
  Stream<List<CancionPlaylist>> watchPlaylist();

  /// Agrega una canción; devuelve false si ya estaba.
  Future<bool> agregar(Cancion cancion);

  /// Quita una canción (solo quien la agregó).
  Future<void> quitar(String id);

  /// Pone o quita mi ❤️.
  Future<void> alternarCorazon(String id);

  /// Récords de todos en "Adivina la canción".
  Stream<List<RecordAdivina>> watchRecords();

  /// Guarda una partida terminada con [aciertos] (suma partidas y actualiza
  /// el mejor puntaje si lo supera).
  Future<void> guardarPartida(int aciertos);
}
