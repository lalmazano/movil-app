import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/cancion.dart';
import 'itunes_client.dart' show ItunesException;

/// Búsqueda de canciones con la API pública de Deezer (gratis, sin clave):
/// https://api.deezer.com/search
///
/// Ojo: los enlaces de las muestras de Deezer caducan en unas horas, así que
/// antes de reproducir se pide uno nuevo con [previewFresco].
class DeezerClient {
  DeezerClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Para pruebas: reemplaza cómo se crea el cliente.
  static DeezerClient Function() fabrica = DeezerClient.new;

  Future<Map<String, Object?>> _get(
    String ruta, [
    Map<String, String>? q,
  ]) async {
    final http.Response r;
    try {
      r = await _client
          .get(Uri.https('api.deezer.com', ruta, q))
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
      final json = jsonDecode(utf8.decode(r.bodyBytes));
      if (json is! Map || json['error'] != null) {
        throw const FormatException();
      }
      return json.cast<String, Object?>();
    } catch (_) {
      throw const ItunesException('Respuesta inesperada de Deezer.');
    }
  }

  /// Canciones que coinciden con [termino].
  Future<List<Cancion>> buscar(String termino, {int limite = 25}) async {
    final t = termino.trim();
    if (t.isEmpty) return const [];
    final json = await _get('/search', {'q': t, 'limit': '$limite'});
    return [
      for (final item in (json['data'] as List? ?? const []))
        if (item is Map) ?Cancion.fromDeezer(item.cast<String, Object?>()),
    ];
  }

  /// Enlace nuevo (vigente) de la muestra de 30 s de la canción [id].
  Future<String?> previewFresco(int id) async {
    try {
      final json = await _get('/track/$id');
      final p = json['preview'];
      return p is String && p.isNotEmpty ? p : null;
    } on ItunesException {
      return null;
    }
  }
}
