import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';
import 'huellitas.dart';

/// Fila pequeña bajo el título de la tarjeta: quién lo agregó / marcó,
/// promedio de huellitas y número de fotos.
class InsigniasItem extends StatelessWidget {
  const InsigniasItem({super.key, required this.item});

  final ItemLista item;

  @override
  Widget build(BuildContext context) {
    final hechoPor = item.hecho ? item.hechoPor : null;
    final autores = [
      ?item.creadoPor,
      if (hechoPor != null && hechoPor.uid != item.creadoPor?.uid) hechoPor,
    ];
    final promedio = item.promedioHuellitas;
    final textos = [
      if (promedio != null) '🐾 ${promedioTexto(promedio)}',
      if (item.fotos > 0) '📷 ${item.fotos}',
    ];
    if (autores.isEmpty && textos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          for (final a in autores)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: AvatarAutor(autor: a, radio: 8),
            ),
          if (textos.isNotEmpty)
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(left: autores.isEmpty ? 0 : 3),
                child: Text(
                  textos.join('  '),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
