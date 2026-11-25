import 'package:flutter/material.dart';

import '../../../../core/tmdb/tmdb_client.dart';
import '../config_scope.dart';
import '../../domain/item_lista.dart';
import 'buscador_tmdb.dart';

/// Sección "película" en el detalle: póster, año, duración y sinopsis de
/// TMDB. Solo para películas.
class SeccionPelicula extends StatefulWidget {
  const SeccionPelicula({
    super.key,
    required this.tipo,
    required this.item,
    required this.repository,
  });

  final TipoLista tipo;
  final ItemLista item;
  final ListaRepository repository;

  @override
  State<SeccionPelicula> createState() => _SeccionPeliculaState();
}

class _SeccionPeliculaState extends State<SeccionPelicula> {
  /// Clave de TMDB; se pide una sola vez.
  late final Future<String?> _clave = widget.tipo == TipoLista.peliculas
      ? widget.repository
            .tmdbApiKey()
            .then((c) => (c?.trim().isEmpty ?? true) ? null : c!.trim())
            .catchError((Object _) => null)
      : Future.value(null);

  bool _sinopsisCompleta = false;

  Future<void> _vincular(String clave) async {
    final messenger = ScaffoldMessenger.of(context);
    final seleccion = await mostrarBuscadorTmdb(
      context,
      apiKey: clave,
      consulta: widget.item.titulo,
    );
    if (seleccion == null || !mounted) return;
    try {
      await widget.repository.update(
        widget.tipo,
        widget.item.copyWith(pelicula: () => seleccion.info),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Revisa la conexión')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tipo != TipoLista.peliculas ||
        !ConfigClubScope.of(context).posters) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<String?>(
      future: _clave,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final clave = snap.data;
        final pelicula = widget.item.pelicula;
        if (pelicula != null) return _vinculada(context, pelicula, clave);
        if (clave != null) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('boton-buscar-poster'),
                onPressed: () => _vincular(clave),
                icon: const Icon(Icons.travel_explore, size: 18),
                label: const Text('Buscar póster en TMDB'),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Agrega tu clave de TMDB en Firestore: config/tmdb → apiKey',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }

  Widget _vinculada(BuildContext context, InfoPelicula p, String? clave) {
    final textTheme = Theme.of(context).textTheme;
    final datos = [
      if (p.anio != null) '${p.anio}',
      if (p.duracionMin != null) formatearDuracion(p.duracionMin!),
    ].join(' · ');
    final resumen = p.resumen;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PosterTmdb(url: p.posterUrl, ancho: 80, alto: 120, radio: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (datos.isNotEmpty)
                    Text(datos, style: textTheme.labelLarge),
                  if (resumen != null) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => setState(
                        () => _sinopsisCompleta = !_sinopsisCompleta,
                      ),
                      child: Text(
                        resumen,
                        maxLines: _sinopsisCompleta ? null : 4,
                        overflow: _sinopsisCompleta
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                  if (clave != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _vincular(clave),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Cambiar'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
