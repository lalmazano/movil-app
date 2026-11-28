import 'package:flutter/material.dart';

import '../../domain/config_club.dart';
import '../../domain/item_lista.dart';
import 'tarjeta_item.dart';

/// `true` si el elemento se trata como repetible (🔁): tiene la marca y la
/// función `repetibles` está activa. Si no, se comporta como uno normal.
bool usaRepetible(ItemLista item, ConfigClub config) =>
    config.repetibles && item.repetible;

/// "1 vez" / "3 veces".
String vecesTexto(int n) => n == 1 ? '1 vez' : '$n veces';

/// Texto compacto para la tarjeta: "🔁 ×2 · última vez 12/11/2026".
String resumenRepetible(ItemLista item) => [
  '🔁 ×${item.veces}',
  if (item.ultimaVez case final f?) 'última vez ${fechaCorta(f)}',
].join(' · ');

/// Pregunta antes de sumar una vez (no hay "deshacer": el contador solo se
/// guarda sumando, así evitamos +1 por un toque accidental).
Future<bool> confirmarOtraVez(BuildContext context, ItemLista item) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔁 ¿Otra vez?'),
        content: Text(
          '¿Hicieron «${item.titulo}» otra vez?\n'
          'Llevan ${vecesTexto(item.veces)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-otra-vez'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('¡Sí! +1'),
          ),
        ],
      ),
    ) ??
    false;

/// Botón redondo "+1" que reemplaza al círculo de hecho en los repetibles.
class BotonOtraVez extends StatelessWidget {
  const BotonOtraVez({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: '🔁 Lo hicimos otra vez',
        child: Material(
          key: const Key('boton-otra-vez'),
          color: scheme.primaryContainer,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text(
                  '+1',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
