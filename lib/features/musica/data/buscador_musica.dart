import 'package:flutter/foundation.dart';

import '../domain/cancion.dart';
import 'deezer_client.dart';
import 'itunes_client.dart';

/// Busca a la vez en iTunes y en Deezer y mezcla los resultados (alternando
/// uno y uno), sin repetir la misma canción que aparezca en los dos. Si uno
/// de los dos falla, se muestran los del otro; solo falla si fallan ambos.
Future<List<Cancion>> buscarEnAmbas(String termino) async {
  final resultados = await Future.wait([
    _seguro(() => ItunesClient.fabrica().buscar(termino)),
    _seguro(() => DeezerClient.fabrica().buscar(termino)),
  ]);
  final [itunes, deezer] = resultados;
  if (itunes == null && deezer == null) {
    throw const ItunesException(
      'No se pudo buscar. Revisa tu conexión a internet.',
    );
  }
  return mezclarResultados(itunes ?? const [], deezer ?? const []);
}

Future<List<Cancion>?> _seguro(Future<List<Cancion>> Function() buscar) async {
  try {
    return await buscar();
  } catch (e) {
    debugPrint('Búsqueda de música falló: $e');
    return null;
  }
}

/// Alterna resultados de [a] y [b] quitando repetidos (mismo título y
/// artista).
List<Cancion> mezclarResultados(List<Cancion> a, List<Cancion> b) {
  final vistas = <String>{};
  final salida = <Cancion>[];
  for (var i = 0; i < a.length || i < b.length; i++) {
    for (final lista in [a, b]) {
      if (i < lista.length && vistas.add(lista[i].huella)) salida.add(lista[i]);
    }
  }
  return salida;
}
