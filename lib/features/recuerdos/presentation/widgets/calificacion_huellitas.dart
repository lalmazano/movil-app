import 'package:flutter/material.dart';

import '../../domain/recuerdo.dart';

/// Calificación de 1 a 5 huellitas. Si [onChanged] es null, solo se muestra.
class CalificacionHuellitas extends StatelessWidget {
  const CalificacionHuellitas({
    super.key,
    required this.valor,
    this.onChanged,
    this.tamano = 36,
    this.mostrarEtiqueta = false,
  });

  final int valor;
  final ValueChanged<int>? onChanged;
  final double tamano;
  final bool mostrarEtiqueta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final huellitas = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          _Huellita(
            activa: i <= valor,
            tamano: tamano,
            color: scheme.primary,
            semantica: '$i de 5',
            onTap: onChanged == null ? null : () => onChanged!(i),
          ),
      ],
    );
    if (!mostrarEtiqueta) return huellitas;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        huellitas,
        const SizedBox(height: 8),
        Text(
          valor == 0
              ? 'Toca las huellitas para calificar'
              : etiquetaCalificacion(valor),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _Huellita extends StatelessWidget {
  const _Huellita({
    required this.activa,
    required this.tamano,
    required this.color,
    required this.semantica,
    this.onTap,
  });

  final bool activa;
  final double tamano;
  final Color color;
  final String semantica;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icono = AnimatedScale(
      scale: activa ? 1 : 0.85,
      duration: const Duration(milliseconds: 150),
      child: Icon(
        Icons.pets,
        size: tamano,
        color: activa ? color : color.withValues(alpha: 0.25),
      ),
    );
    if (onTap == null) return icono;
    return Semantics(
      button: true,
      label: 'Calificar $semantica',
      child: InkResponse(
        onTap: onTap,
        radius: tamano * 0.8,
        child: Padding(padding: const EdgeInsets.all(4), child: icono),
      ),
    );
  }
}
