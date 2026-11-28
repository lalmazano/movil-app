import 'package:flutter/material.dart';

import '../../../core/widgets/paw_background.dart';
import '../domain/item_lista.dart';
import 'widgets/seccion_calificaciones.dart';
import 'widgets/seccion_fotos.dart';
import 'widgets/seccion_pelicula.dart';
import 'widgets/seccion_sugerencias.dart';
import 'widgets/tarjeta_item.dart';

/// Detalle de un elemento: datos, póster (películas), calificaciones y fotos.
/// Se actualiza en vivo.
class ItemDetallePage extends StatefulWidget {
  const ItemDetallePage({
    super.key,
    required this.tipo,
    required this.itemId,
    required this.repository,
    this.onEditar,
  });

  final TipoLista tipo;
  final String itemId;
  final ListaRepository repository;
  final Future<void> Function(ItemLista item)? onEditar;

  @override
  State<ItemDetallePage> createState() => _ItemDetallePageState();
}

class _ItemDetallePageState extends State<ItemDetallePage> {
  late final _item = widget.repository.watchItem(widget.tipo, widget.itemId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ItemLista?>(
      stream: _item,
      builder: (context, snap) {
        final item = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.tipo.titulo),
            actions: [
              if (item != null && widget.onEditar != null)
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit),
                  onPressed: () => widget.onEditar!(item),
                ),
            ],
          ),
          body: PawBackground(
            child: switch ((snap.connectionState, item)) {
              (ConnectionState.waiting, _) => const Center(
                child: CircularProgressIndicator(),
              ),
              (_, null) => const Center(
                child: Text('Este elemento ya no existe.'),
              ),
              (_, final item?) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _Encabezado(tipo: widget.tipo, item: item),
                  SeccionPelicula(
                    tipo: widget.tipo,
                    item: item,
                    repository: widget.repository,
                  ),
                  SeccionCalificaciones(
                    tipo: widget.tipo,
                    item: item,
                    repository: widget.repository,
                  ),
                  SeccionFotos(
                    tipo: widget.tipo,
                    item: item,
                    repository: widget.repository,
                  ),
                  SeccionSugerencias(
                    tipo: widget.tipo,
                    item: item,
                    repository: widget.repository,
                  ),
                ],
              ),
            },
          ),
        );
      },
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.tipo, required this.item});

  final TipoLista tipo;
  final ItemLista item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.titulo, style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(item.categoria),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: Icon(
                    item.hecho ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                  ),
                  label: Text(
                    item.hecho
                        ? '${tipo.accionHecho}'
                              '${item.hechoEn == null ? '' : ' el ${fechaCorta(item.hechoEn!)}'}'
                        : 'Pendiente',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (item.nota.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.nota, style: textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
