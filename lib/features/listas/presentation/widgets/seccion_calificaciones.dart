import 'package:flutter/material.dart';

import '../config_scope.dart';
import '../../domain/item_lista.dart';
import 'dialogo_calificar.dart';
import 'huellitas.dart';
import 'tarjeta_item.dart';

/// Sección "Calificaciones" en el detalle del elemento: quién lo agregó y
/// quién lo marcó, las huellitas de cada persona y el promedio.
class SeccionCalificaciones extends StatelessWidget {
  const SeccionCalificaciones({
    super.key,
    required this.tipo,
    required this.item,
    required this.repository,
  });

  final TipoLista tipo;
  final ItemLista item;
  final ListaRepository repository;

  @override
  Widget build(BuildContext context) {
    final config = ConfigClubScope.of(context);
    if (!config.calificaciones && !config.autores) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final autor = config.calificaciones ? repository.autorActual : null;
    final calificaciones = item.calificaciones.values.toList()
      ..sort(
        (a, b) =>
            (a.fecha ?? item.creadoEn).compareTo(b.fecha ?? item.creadoEn),
      );
    final promedio = config.calificaciones ? item.promedioHuellitas : null;
    final procedencia = [
      if (config.autores) ...[
        if (item.creadoPor case final p?)
          'Agregado por ${p.nombreCorto} el ${fechaCorta(item.creadoEn)}',
        if (item.hecho && item.hechoPor != null)
          '${tipo.accionHecho} por ${item.hechoPor!.nombreCorto}'
              '${item.hechoEn == null ? '' : ' el ${fechaCorta(item.hechoEn!)}'}',
      ],
    ];
    final yaCalifico =
        autor != null && item.calificaciones.containsKey(autor.uid);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      config.calificaciones ? 'Calificaciones' : 'Historial',
                      style: textTheme.titleSmall,
                    ),
                  ),
                  if (promedio != null)
                    Text(
                      '🐾 ${promedioTexto(promedio)} de 5',
                      style: textTheme.labelLarge,
                    ),
                ],
              ),
            ),
            for (final linea in procedencia)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(linea, style: textTheme.bodySmall),
              ),
            if (!config.calificaciones)
              const SizedBox(height: 4)
            else if (calificaciones.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  item.hecho
                      ? 'Nadie ha calificado todavía.'
                      : 'Aún sin calificaciones: se califica al terminar 🐾',
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final c in calificaciones) _Calificacion(c),
            if (autor != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => calificarItem(
                    context,
                    repository: repository,
                    tipo: tipo,
                    item: item,
                  ),
                  icon: const Text('🐾'),
                  label: Text(
                    yaCalifico ? 'Cambiar mi calificación' : 'Calificar',
                  ),
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _Calificacion extends StatelessWidget {
  const _Calificacion(this.calificacion);

  final Calificacion calificacion;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarAutor(autor: calificacion.autor, radio: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        calificacion.autor.nombreCorto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FilaHuellitas(cantidad: calificacion.huellitas),
                  ],
                ),
                if (calificacion.comentario.isNotEmpty)
                  Text(calificacion.comentario, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
