import 'package:flutter/foundation.dart';

import '../../../core/tmdb/tmdb_client.dart';
import '../../listas/domain/item_lista.dart';

/// Una película sugerida y cuántas películas del club la recomendaron.
class Sugerencia {
  const Sugerencia(this.resultado, this.veces);

  final ResultadoTmdb resultado;

  /// Cuántas "semillas" (películas que les gustaron) la recomendaron.
  final int veces;
}

/// Clave de TMDB del club, o null si no hay (o no se pudo leer).
Future<String?> claveTmdb(ListaRepository repository) => repository
    .tmdbApiKey()
    .then((c) => (c?.trim().isEmpty ?? true) ? null : c!.trim())
    .catchError((Object _) => null);

/// `true` si la película ya está en la lista: mismo id de TMDB o mismo título
/// (sin importar mayúsculas).
bool yaEnLista(ResultadoTmdb r, Iterable<ItemLista> items) {
  final titulo = _normalizar(r.titulo);
  return items.any(
    (i) => i.pelicula?.tmdbId == r.id || _normalizar(i.titulo) == titulo,
  );
}

String _normalizar(String s) => s.trim().toLowerCase();

/// Películas del club que sirven de punto de partida: las vinculadas a TMDB
/// con promedio de 4 huellitas o más (las mejores primero). Si ninguna tiene
/// esa calificación, las vistas más recientes; y si no hay vistas, las
/// vinculadas más recientes.
List<ItemLista> semillasSugerencias(List<ItemLista> items, {int maximo = 5}) {
  final vinculadas = items.where((i) => i.pelicula != null).toList();
  DateTime fecha(ItemLista i) => i.hechoEn ?? i.creadoEn;
  int recientes(ItemLista a, ItemLista b) => fecha(b).compareTo(fecha(a));

  final favoritas =
      vinculadas.where((i) => (i.promedioHuellitas ?? 0) >= 4).toList()
        ..sort((a, b) {
          final c = b.promedioHuellitas!.compareTo(a.promedioHuellitas!);
          return c != 0 ? c : recientes(a, b);
        });
  if (favoritas.isNotEmpty) return favoritas.take(maximo).toList();

  final vistas = vinculadas.where((i) => i.hecho).toList()..sort(recientes);
  if (vistas.isNotEmpty) return vistas.take(maximo).toList();

  return (vinculadas..sort(recientes)).take(maximo).toList();
}

/// Junta las recomendaciones de cada semilla y las ordena: primero las que
/// recomendaron más semillas, luego por popularidad y calificación de TMDB.
/// Quita las que ya están en [items] y las repetidas.
List<Sugerencia> combinarSugerencias(
  Iterable<List<ResultadoTmdb>> porSemilla,
  List<ItemLista> items, {
  int maximo = 30,
}) {
  final veces = <int, int>{};
  final primero = <int, ResultadoTmdb>{};
  for (final lista in porSemilla) {
    // Cada semilla cuenta una sola vez aunque repita la película.
    for (final r in {for (final r in lista) r.id: r}.values) {
      if (yaEnLista(r, items)) continue;
      veces[r.id] = (veces[r.id] ?? 0) + 1;
      primero.putIfAbsent(r.id, () => r);
    }
  }
  final sugerencias = [
    for (final MapEntry(:key, :value) in primero.entries)
      Sugerencia(value, veces[key]!),
  ];
  sugerencias.sort((a, b) {
    var c = b.veces.compareTo(a.veces);
    if (c != 0) return c;
    c = (b.resultado.popularidad ?? 0).compareTo(a.resultado.popularidad ?? 0);
    if (c != 0) return c;
    return (b.resultado.votos ?? 0).compareTo(a.resultado.votos ?? 0);
  });
  return sugerencias.take(maximo).toList();
}

/// Recomendaciones ya pedidas en esta sesión, por id de TMDB.
final _cache = <int, Future<List<ResultadoTmdb>>>{};

/// Recomendaciones de [tmdbId], guardadas en memoria durante la sesión. Si
/// fallan no se guardan (para poder reintentar).
Future<List<ResultadoTmdb>> recomendacionesCacheadas(
  TmdbClient cliente,
  int tmdbId,
) {
  final enCache = _cache[tmdbId];
  if (enCache != null) return enCache;
  final futuro = cliente.recomendaciones(tmdbId);
  _cache[tmdbId] = futuro;
  futuro.catchError((Object _) {
    if (identical(_cache[tmdbId], futuro)) _cache.remove(tmdbId);
    return const <ResultadoTmdb>[];
  });
  return futuro;
}

/// Borra las recomendaciones guardadas (para pruebas).
@visibleForTesting
void limpiarCacheSugerencias() => _cache.clear();

/// Sugerencias "Para ustedes": recomendaciones de hasta [maxSemillas]
/// películas favoritas, combinadas y ordenadas. Si todas las consultas
/// fallan, lanza el primer error.
Future<List<Sugerencia>> sugerenciasParaUstedes(
  TmdbClient cliente,
  List<ItemLista> items, {
  int maxSemillas = 5,
}) async {
  final semillas = semillasSugerencias(items, maximo: maxSemillas);
  if (semillas.isEmpty) return const [];
  Object? error;
  final listas = await Future.wait([
    for (final s in semillas)
      recomendacionesCacheadas(cliente, s.pelicula!.tmdbId).catchError((
        Object e,
      ) {
        error ??= e;
        return const <ResultadoTmdb>[];
      }),
  ]);
  if (error case final e? when listas.every((l) => l.isEmpty)) throw e;
  return combinarSugerencias(listas, items);
}
