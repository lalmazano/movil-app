import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/listas/domain/detalles.dart';

/// Error al hablar con TMDB; [mensaje] se puede mostrar tal cual.
class TmdbException implements Exception {
  const TmdbException(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'TmdbException: $mensaje';
}

/// Una película encontrada en la búsqueda de TMDB.
class ResultadoTmdb {
  const ResultadoTmdb({
    required this.id,
    required this.titulo,
    this.anio,
    this.posterUrl,
    this.resumen,
  });

  final int id;
  final String titulo;
  final int? anio;
  final String? posterUrl;
  final String? resumen;

  /// Datos para guardar (sin duración: esa viene de [TmdbClient.detalle]).
  InfoPelicula get info => InfoPelicula(
    tmdbId: id,
    posterUrl: posterUrl,
    anio: anio,
    resumen: resumen,
  );
}

/// Cliente mínimo de la API de TMDB (búsqueda y detalle de películas).
class TmdbClient {
  TmdbClient(
    this.apiKey, {
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  /// Cómo crea la app sus clientes; las pruebas la reemplazan para no usar
  /// la red (por ejemplo con un `MockClient`).
  @visibleForTesting
  static TmdbClient Function(String apiKey) fabrica = TmdbClient.new;

  /// Crea un cliente con [fabrica].
  static TmdbClient crear(String apiKey) => fabrica(apiKey);

  static const _host = 'api.themoviedb.org';
  static const _idioma = 'es-MX';
  static const _imagenes = 'https://image.tmdb.org/t/p/w342';

  /// Clave v3 (`api_key=`) o token de lectura v4 (`Authorization: Bearer`).
  final String apiKey;
  final Duration timeout;
  final http.Client _client;

  /// Los tokens v4 son JWT largos que empiezan con `eyJ`.
  bool get usaBearer => apiKey.startsWith('eyJ') && apiKey.length > 60;

  /// Busca películas por título. Devuelve lista vacía si [query] está vacía.
  Future<List<ResultadoTmdb>> buscar(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final json = await _get('/3/search/movie', {
      'query': q,
      'language': _idioma,
      'include_adult': 'false',
    });
    final resultados = json['results'];
    if (resultados is! List) return const [];
    return [
      for (final r in resultados)
        if (r is Map && r['id'] is num)
          ResultadoTmdb(
            id: (r['id'] as num).toInt(),
            titulo:
                _texto(r['title']) ??
                _texto(r['original_title']) ??
                '¿Sin título?',
            anio: _anio(r['release_date']),
            posterUrl: _poster(r['poster_path']),
            resumen: _texto(r['overview']),
          ),
    ];
  }

  /// Datos completos de una película (incluye la duración).
  Future<InfoPelicula> detalle(int id) async {
    final json = await _get('/3/movie/$id', {'language': _idioma});
    return InfoPelicula(
      tmdbId: (json['id'] as num?)?.toInt() ?? id,
      posterUrl: _poster(json['poster_path']),
      anio: _anio(json['release_date']),
      duracionMin: switch (json['runtime']) {
        final num n when n > 0 => n.toInt(),
        _ => null,
      },
      resumen: _texto(json['overview']),
    );
  }

  void cerrar() => _client.close();

  Future<Map<String, Object?>> _get(
    String ruta,
    Map<String, String> parametros,
  ) async {
    final uri = Uri.https(_host, ruta, {
      ...parametros,
      if (!usaBearer) 'api_key': apiKey,
    });
    final http.Response respuesta;
    try {
      respuesta = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (usaBearer) 'Authorization': 'Bearer $apiKey',
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TmdbException('TMDB tardó demasiado. Intenta otra vez');
    } catch (_) {
      throw const TmdbException('No se pudo conectar con TMDB');
    }
    if (respuesta.statusCode == 401) {
      throw const TmdbException('La clave de TMDB no es válida');
    }
    if (respuesta.statusCode != 200) {
      throw TmdbException('TMDB respondió con error ${respuesta.statusCode}');
    }
    try {
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (json is Map<String, Object?>) return json;
    } on FormatException {
      // Se trata abajo.
    }
    throw const TmdbException('Respuesta inesperada de TMDB');
  }

  static String? _texto(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;

  static int? _anio(Object? fecha) => fecha is String && fecha.length >= 4
      ? int.tryParse(fecha.substring(0, 4))
      : null;

  static String? _poster(Object? ruta) =>
      ruta is String && ruta.isNotEmpty ? '$_imagenes$ruta' : null;
}

/// "1 h 40 min", "45 min" o "2 h".
String formatearDuracion(int minutos) {
  final h = minutos ~/ 60;
  final m = minutos % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}
