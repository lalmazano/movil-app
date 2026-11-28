/// Una canción encontrada en iTunes (Apple). Se guarda en Firestore como mapa
/// dentro de la playlist o de una carta.
class Cancion {
  const Cancion({
    required this.itunesId,
    required this.titulo,
    required this.artista,
    this.album,
    this.portadaUrl,
    this.previewUrl,
    this.appleUrl,
    this.duracionMs,
  });

  final int itunesId;
  final String titulo;
  final String artista;
  final String? album;

  /// Portada (300×300).
  final String? portadaUrl;

  /// Muestra de 30 segundos (m4a). Puede faltar en algunas canciones.
  final String? previewUrl;

  /// Página de la canción en Apple Music.
  final String? appleUrl;
  final int? duracionMs;

  String get busqueda => '$titulo $artista';

  /// Buscar la canción completa en Spotify.
  Uri get spotifyUrl =>
      Uri.https('open.spotify.com', '/search/${Uri.encodeComponent(busqueda)}');

  /// Buscar la canción completa en YouTube Music.
  Uri get youtubeMusicUrl =>
      Uri.https('music.youtube.com', '/search', {'q': busqueda});

  Map<String, Object?> toMap() => {
    'itunesId': itunesId,
    'titulo': titulo,
    'artista': artista,
    'album': album,
    'portada': portadaUrl,
    'preview': previewUrl,
    'apple': appleUrl,
    'duracionMs': duracionMs,
  };

  static Cancion? fromMap(Object? map) {
    if (map is! Map || map['itunesId'] is! num || map['titulo'] is! String) {
      return null;
    }
    return Cancion(
      itunesId: (map['itunesId'] as num).toInt(),
      titulo: map['titulo'] as String,
      artista: (map['artista'] as String?) ?? '',
      album: map['album'] as String?,
      portadaUrl: map['portada'] as String?,
      previewUrl: map['preview'] as String?,
      appleUrl: map['apple'] as String?,
      duracionMs: (map['duracionMs'] as num?)?.toInt(),
    );
  }

  /// Desde un resultado de la API de búsqueda de iTunes.
  static Cancion? fromItunes(Map<String, Object?> r) {
    final id = r['trackId'];
    final titulo = r['trackName'];
    if (id is! num || titulo is! String) return null;
    final portada = r['artworkUrl100'] as String?;
    return Cancion(
      itunesId: id.toInt(),
      titulo: titulo,
      artista: (r['artistName'] as String?) ?? '',
      album: r['collectionName'] as String?,
      portadaUrl: portada?.replaceFirst('100x100bb', '300x300bb'),
      previewUrl: r['previewUrl'] as String?,
      appleUrl: r['trackViewUrl'] as String?,
      duracionMs: (r['trackTimeMillis'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Cancion && other.itunesId == itunesId;

  @override
  int get hashCode => itunesId.hashCode;
}
