/// De qué catálogo salió una canción.
enum FuenteMusica { itunes, deezer }

/// Una canción encontrada en iTunes (Apple) o en Deezer. Se guarda en
/// Firestore como mapa dentro de la playlist o de una carta.
class Cancion {
  const Cancion({
    required this.itunesId,
    this.fuente = FuenteMusica.itunes,
    required this.titulo,
    required this.artista,
    this.album,
    this.portadaUrl,
    this.previewUrl,
    this.appleUrl,
    this.duracionMs,
  });

  /// Id de la canción en su catálogo ([fuente]): iTunes o Deezer.
  final int itunesId;
  final FuenteMusica fuente;

  bool get esDeezer => fuente == FuenteMusica.deezer;

  /// Identificador único entre catálogos (id del documento en la playlist):
  /// `123` para iTunes y `dz123` para Deezer.
  String get clave => esDeezer ? 'dz$itunesId' : '$itunesId';

  /// Página de la canción en Deezer.
  Uri? get deezerUrl =>
      esDeezer ? Uri.https('www.deezer.com', '/track/$itunesId') : null;
  final String titulo;
  final String artista;
  final String? album;

  /// Portada (300×300).
  final String? portadaUrl;

  /// Muestra de 30 segundos. Puede faltar en algunas canciones. En Deezer el
  /// enlace caduca en unas horas: se pide uno nuevo antes de reproducir.
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
    if (esDeezer) ...{
      'fuente': 'deezer',
      'deezerId': itunesId,
    } else
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
    if (map is! Map || map['titulo'] is! String) return null;
    final deezer = map['fuente'] == 'deezer';
    final id = map[deezer ? 'deezerId' : 'itunesId'];
    if (id is! num) return null;
    return Cancion(
      itunesId: id.toInt(),
      fuente: deezer ? FuenteMusica.deezer : FuenteMusica.itunes,
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

  /// Desde un resultado de la API de búsqueda de Deezer.
  static Cancion? fromDeezer(Map<String, Object?> r) {
    final id = r['id'];
    final titulo = r['title'];
    if (id is! num || titulo is! String) return null;
    final artista = r['artist'] is Map ? (r['artist'] as Map)['name'] : null;
    final album = r['album'] is Map ? r['album'] as Map : const {};
    return Cancion(
      itunesId: id.toInt(),
      fuente: FuenteMusica.deezer,
      titulo: titulo,
      artista: artista is String ? artista : '',
      album: album['title'] as String?,
      portadaUrl: (album['cover_medium'] ?? album['cover_big']) as String?,
      previewUrl: (r['preview'] as String?)?.isEmpty ?? true
          ? null
          : r['preview'] as String?,
      duracionMs: (r['duration'] as num?) == null
          ? null
          : (r['duration'] as num).toInt() * 1000,
    );
  }

  /// Título y artista simplificados, para no repetir la misma canción
  /// encontrada en los dos catálogos.
  String get huella {
    String limpio(String t) => t
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), ' ')
        .trim();
    return '${limpio(titulo)}|${limpio(artista.split(RegExp(r'[,&]')).first)}';
  }

  @override
  bool operator ==(Object other) => other is Cancion && other.clave == clave;

  @override
  int get hashCode => clave.hashCode;
}
