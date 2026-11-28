import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/propuestas.dart';

/// Preguntas de la API pública y gratuita de Truth or Dare Bot
/// (https://api.truthordarebot.xyz). Cada pregunta trae su traducción al
/// español (automática). Se piden solo "Verdad" y "¿Qué prefieres?" con
/// clasificación PG (apta para todos).
class PreguntasInternet {
  PreguntasInternet({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Para pruebas: reemplaza cómo se crea el cliente.
  static PreguntasInternet Function() fabrica = PreguntasInternet.new;

  /// Pregunta en español para [fecha] (alterna "Verdad" y "¿Qué prefieres?"),
  /// o null si no hay internet o la respuesta no sirve.
  Future<String?> preguntaPara(DateTime fecha) async {
    final tipo = fecha.day.isEven ? 'truth' : 'wyr';
    try {
      final r = await _client
          .get(
            Uri.https('api.truthordarebot.xyz', '/v1/$tipo', {'rating': 'pg'}),
          )
          .timeout(timeout);
      if (r.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(r.bodyBytes));
      final es = (json is Map ? json['translations'] : null) is Map
          ? (json['translations'] as Map)['es']
          : null;
      if (es is! String) return null;
      final texto = es.trim();
      if (texto.length < minCaracteresPropuesta ||
          texto.length > maxCaracteresPropuesta) {
        return null;
      }
      return texto;
    } catch (_) {
      return null;
    }
  }
}
