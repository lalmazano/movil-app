import 'package:flutter/material.dart';

import '../../../../core/widgets/iconos_club.dart';
import '../../domain/item_lista.dart';
import '../config_scope.dart';
import 'huellitas.dart';
import 'repetible.dart';

/// Fila pequeña bajo el título de la tarjeta: quién lo agregó / marcó,
/// contador de repetibles (🔁), promedio de huellitas y número de fotos.
class InsigniasItem extends StatelessWidget {
  const InsigniasItem({super.key, required this.item});

  final ItemLista item;

  @override
  Widget build(BuildContext context) {
    final config = ConfigClubScope.of(context);
    final repetible = usaRepetible(item, config);
    final hechoPor = item.hecho || (repetible && item.veces > 0)
        ? item.hechoPor
        : null;
    final autores = [
      if (config.autores) ...[
        ?item.creadoPor,
        if (hechoPor != null && hechoPor.uid != item.creadoPor?.uid) hechoPor,
      ],
    ];
    final promedio = config.calificaciones ? item.promedioHuellitas : null;
    final textos = [
      if (repetible) resumenRepetible(item),
      if (promedio != null) '🐾 ${promedioTexto(promedio)}',
      if (config.fotos && item.fotos > 0) '📷 ${item.fotos}',
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
                child: textoConHuellitas(
                  textos.join('  '),
                  maxLines: 1,
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
