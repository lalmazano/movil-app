import 'package:flutter/material.dart';

import '../../../../core/tmdb/tmdb_client.dart';
import '../../../sugerencias/domain/sugerencias.dart';
import '../../../sugerencias/presentation/para_ustedes_page.dart';
import '../../../sugerencias/presentation/tarjeta_sugerencia.dart';
import '../../domain/item_lista.dart';
import '../config_scope.dart';

/// Sugerencias de TMDB en el detalle de una película ("Si les gustó…").
/// Solo para películas vinculadas a TMDB, con clave y con las banderas
/// `sugerencias` y `posters` activas.
class SeccionSugerencias extends StatefulWidget {
  const SeccionSugerencias({
    super.key,
    required this.tipo,
    required this.item,
    required this.repository,
  });

  final TipoLista tipo;
  final ItemLista item;
  final ListaRepository repository;

  /// Cuántas sugerencias se muestran en la fila.
  static const maximo = 10;

  @override
  State<SeccionSugerencias> createState() => _SeccionSugerenciasState();
}

class _SeccionSugerenciasState extends State<SeccionSugerencias> {
  /// Clave de TMDB; se pide una sola vez.
  late final Future<String?> _clave = widget.tipo == TipoLista.peliculas
      ? claveTmdb(widget.repository)
      : Future.value(null);

  late final _items = widget.repository.watch(TipoLista.peliculas);

  Future<List<ResultadoTmdb>>? _sugerencias;
  int? _tmdbId;

  /// Pide (o toma de la caché) las recomendaciones de [tmdbId].
  Future<List<ResultadoTmdb>> _cargar(String clave, int tmdbId) {
    if (_sugerencias != null && _tmdbId == tmdbId) return _sugerencias!;
    _tmdbId = tmdbId;
    final cliente = TmdbClient.crear(clave);
    return _sugerencias = recomendacionesCacheadas(
      cliente,
      tmdbId,
    ).whenComplete(cliente.cerrar);
  }

  void _reintentar() => setState(() {
    _sugerencias = null;
    _tmdbId = null;
  });

  @override
  Widget build(BuildContext context) {
    final config = ConfigClubScope.of(context);
    final pelicula = widget.item.pelicula;
    if (widget.tipo != TipoLista.peliculas ||
        pelicula == null ||
        !config.sugerencias ||
        !config.posters) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<String?>(
      future: _clave,
      builder: (context, snap) {
        final clave = snap.data;
        if (clave == null) return const SizedBox.shrink();
        return Card(
          key: const Key('seccion-sugerencias'),
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Si les gustó ${widget.item.titulo}…',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<ResultadoTmdb>>(
                  future: _cargar(clave, pelicula.tmdbId),
                  builder: (context, snap) => _contenido(context, snap),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('boton-mas-sugerencias'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ParaUstedesPage(
                          repository: widget.repository,
                          apiKey: clave,
                          categoriaInicial: widget.item.categoria,
                        ),
                      ),
                    ),
                    child: const Text('🎬 Más sugerencias para ustedes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _contenido(
    BuildContext context,
    AsyncSnapshot<List<ResultadoTmdb>> snap,
  ) {
    final estilo = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    if (snap.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (snap.hasError) {
      return Row(
        children: [
          Expanded(
            child: Text(switch (snap.error) {
              TmdbException(:final mensaje) => mensaje,
              _ => 'No se pudieron cargar las sugerencias',
            }, style: estilo),
          ),
          IconButton(
            tooltip: 'Reintentar',
            visualDensity: VisualDensity.compact,
            onPressed: _reintentar,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      );
    }
    final resultados = snap.data!
        .where((r) => r.id != widget.item.pelicula?.tmdbId)
        .take(SeccionSugerencias.maximo)
        .toList();
    if (resultados.isEmpty) {
      return Text(
        'TMDB no tiene sugerencias para esta película',
        style: estilo,
      );
    }
    return StreamBuilder<List<ItemLista>>(
      stream: _items,
      builder: (context, items) => SizedBox(
        height: 96 * 1.5 + 68,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: resultados.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final r = resultados[i];
            return TarjetaSugerencia(
              resultado: r,
              enLista: yaEnLista(r, items.data ?? const []),
              onAgregar: () => agregarSugerencia(
                context,
                repository: widget.repository,
                resultado: r,
                categoriaInicial: widget.item.categoria,
              ),
            );
          },
        ),
      ),
    );
  }
}
