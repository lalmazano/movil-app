import 'package:flutter/material.dart';

import '../../../core/tmdb/tmdb_client.dart';
import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/widgets/buscador_tmdb.dart';

/// Póster, título y año de una sugerencia, con "+" para agregarla a la lista
/// (o "✓ En la lista" si ya está). Necesita una altura acotada.
class TarjetaSugerencia extends StatelessWidget {
  const TarjetaSugerencia({
    super.key,
    required this.resultado,
    required this.enLista,
    required this.onAgregar,
    this.ancho = 96,
  });

  final ResultadoTmdb resultado;
  final bool enLista;
  final VoidCallback onAgregar;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;
    return SizedBox(
      width: ancho,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PosterTmdb(
                url: resultado.posterUrl,
                ancho: ancho,
                alto: ancho * 1.5,
                radio: 8,
              ),
              if (!enLista)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: IconButton.filled(
                    key: Key('agregar-sugerencia-${resultado.id}'),
                    tooltip: 'Agregar a la lista',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: onAgregar,
                    icon: const Icon(Icons.add),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // El texto usa el espacio que quede; si no cabe se recorta.
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resultado.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium,
                  ),
                  if (enLista)
                    Text(
                      '✓ En la lista',
                      style: textTheme.labelSmall?.copyWith(
                        color: colores.primary,
                      ),
                    )
                  else if (resultado.anio != null)
                    Text(
                      '${resultado.anio}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colores.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pregunta la categoría (con [categoriaInicial] elegida) y agrega
/// [resultado] a la lista de películas con sus datos de TMDB.
Future<void> agregarSugerencia(
  BuildContext context, {
  required ListaRepository repository,
  required ResultadoTmdb resultado,
  String? categoriaInicial,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  var categorias = TipoLista.peliculas.categorias;
  try {
    final deLaBase = await repository
        .watchCategorias(TipoLista.peliculas)
        .first
        .timeout(const Duration(seconds: 5));
    if (deLaBase.isNotEmpty) categorias = deLaBase;
  } catch (_) {
    // Se usan las categorías de la app.
  }
  if (!context.mounted) return;
  final categoria = await showDialog<String>(
    context: context,
    builder: (_) => _ElegirCategoria(
      titulo: resultado.titulo,
      categorias: categorias,
      inicial: categorias.contains(categoriaInicial)
          ? categoriaInicial!
          : categorias.last,
    ),
  );
  if (categoria == null) return;
  try {
    await repository.add(TipoLista.peliculas, (
      titulo: resultado.titulo,
      categoria: categoria,
      nota: '',
    ), pelicula: resultado.info);
    messenger.showSnackBar(
      SnackBar(content: Text('🎬 ${resultado.titulo} se agregó a la lista')),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo guardar. Revisa la conexión')),
    );
  }
}

class _ElegirCategoria extends StatefulWidget {
  const _ElegirCategoria({
    required this.titulo,
    required this.categorias,
    required this.inicial,
  });

  final String titulo;
  final List<String> categorias;
  final String inicial;

  @override
  State<_ElegirCategoria> createState() => _ElegirCategoriaState();
}

class _ElegirCategoriaState extends State<_ElegirCategoria> {
  late String _elegida = widget.inicial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agregar "${widget.titulo}"'),
      content: SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in widget.categorias)
              ChoiceChip(
                label: Text(c),
                selected: c == _elegida,
                onSelected: (_) => setState(() => _elegida = c),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('boton-confirmar-sugerencia'),
          onPressed: () => Navigator.pop(context, _elegida),
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
