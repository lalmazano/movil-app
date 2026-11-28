import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';
import '../config_scope.dart';
import 'insignias_item.dart';
import 'poster_miniatura.dart';
import 'repetible.dart';

/// Tarjeta de un elemento en la lista. Tocarla abre el detalle; el círculo
/// lo marca como hecho. En los repetibles (🔁) el círculo es un botón "+1"
/// ([onOtraVez]) y nunca se tachan.
class TarjetaItem extends StatelessWidget {
  const TarjetaItem({
    super.key,
    required this.item,
    required this.onMarcar,
    required this.onAbrir,
    required this.onEditar,
    required this.onBorrar,
    this.onOtraVez,
  });

  final ItemLista item;
  final ValueChanged<bool> onMarcar;
  final VoidCallback onAbrir;
  final VoidCallback onEditar;
  final VoidCallback onBorrar;

  /// Suma una vez a un repetible. Sin él se muestra el círculo normal.
  final VoidCallback? onOtraVez;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otraVez = usaRepetible(item, ConfigClubScope.of(context))
        ? onOtraVez
        : null;
    final tachado = item.hecho && otraVez == null;
    final subtitulo = [
      if (item.nota.isNotEmpty) item.nota,
      if (tachado && item.hechoEn != null) '✓ ${fechaCorta(item.hechoEn!)}',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
          child: Row(
            children: [
              if (otraVez != null)
                BotonOtraVez(onPressed: otraVez)
              else
                Checkbox(
                  value: item.hecho,
                  shape: const CircleBorder(),
                  onChanged: (v) => onMarcar(v ?? false),
                ),
              PosterMiniatura(item: item),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.titulo,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: tachado
                              ? TextDecoration.lineThrough
                              : null,
                          color: tachado
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                )
                              : null,
                        ),
                      ),
                      if (subtitulo.isNotEmpty)
                        Text(
                          subtitulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      InsigniasItem(item: item),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<VoidCallback>(
                onSelected: (accion) => accion(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: onEditar, child: const Text('Editar')),
                  PopupMenuItem(value: onBorrar, child: const Text('Borrar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fecha como 25/11/2026.
String fechaCorta(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/'
    '${f.month.toString().padLeft(2, '0')}/${f.year}';
