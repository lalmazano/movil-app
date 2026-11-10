import 'package:flutter/material.dart';

import '../../../michis/domain/michi.dart';
import '../../../michis/presentation/widgets/michi_avatar.dart';

/// Chips para elegir qué michi sale en la foto. Tocar el elegido lo quita.
class SelectorMichi extends StatelessWidget {
  const SelectorMichi({
    super.key,
    required this.michis,
    required this.seleccionado,
    required this.onChanged,
  });

  final List<Michi> michis;
  final String? seleccionado;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Qué michi sale en la foto?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in michis)
              ChoiceChip(
                avatar: MichiAvatar.de(m, radius: 12),
                label: Text(m.nombre),
                selected: m.id == seleccionado,
                showCheckmark: false,
                onSelected: (sel) => onChanged(sel ? m.id : null),
              ),
          ],
        ),
      ],
    );
  }
}

/// Etiqueta pequeña con el avatar y el nombre del michi.
class EtiquetaMichi extends StatelessWidget {
  const EtiquetaMichi({super.key, required this.michi});

  final Michi michi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MichiAvatar.de(michi, radius: 10),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              michi.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carga los michis sin romper la pantalla si el almacenamiento falla.
Future<List<Michi>> cargarMichisSeguro(MichiRepository repository) async {
  try {
    return await repository.getAll();
  } catch (_) {
    return const [];
  }
}
