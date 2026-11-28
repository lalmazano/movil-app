import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/cancion.dart';

class ItunesException implements Exception {
  const ItunesException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Búsqueda de canciones con la API pública de iTunes (gratis, sin clave):
/// https://itunes.apple.com/search
class ItunesClient {
  ItunesClient({
    http.Client? client,
    this.pais = 'GT',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Tienda de iTunes a consultar (afecta qué canciones aparecen).
  final String pais;
  final Duration timeout;

  /// Para pruebas: reemplaza cómo se crea el cliente.
  static ItunesClient Function() fabrica = ItunesClient.new;

  /// Canciones que coinciden con [termino] (título, artista o álbum).
  Future<List<Cancion>> buscar(String termino, {int limite = 25}) async {
    final t = termino.trim();
    if (t.isEmpty) return const [];
    final http.Response r;
    try {
      r = await _client
          .get(
            Uri.https('itunes.apple.com', '/search', {
              'term': t,
              'entity': 'song',
              'media': 'music',
              'country': pais,
              'limit': '$limite',
            }),
          )
          .timeout(timeout);
    } catch (_) {
      throw const ItunesException(
        'No se pudo buscar. Revisa tu conexión a internet.',
      );
    }
    if (r.statusCode != 200) {
      throw ItunesException('La búsqueda falló (${r.statusCode}).');
    }
    try {
      final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      return [
        for (final item in (json['results'] as List? ?? const []))
          if (item is Map) ?Cancion.fromItunes(item.cast<String, Object?>()),
      ];
    } catch (_) {
      throw const ItunesException('Respuesta inesperada de iTunes.');
    }
  }
}
