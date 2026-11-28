import 'package:flutter/material.dart';

import '../domain/aniversario.dart';

/// Tarjetita con el tiempo que llevamos juntos. Al tocarla alterna entre la
/// frase completa y el total de días.
class ContadorAniversario extends StatefulWidget {
  const ContadorAniversario({super.key, required this.desde, this.reloj});

  final DateTime desde;

  /// Para pruebas: qué día es "hoy". Por defecto, [DateTime.now].
  final DateTime Function()? reloj;

  @override
  State<ContadorAniversario> createState() => _ContadorAniversarioState();
}

class _ContadorAniversarioState extends State<ContadorAniversario> {
  var _soloDias = false;

  @override
  Widget build(BuildContext context) {
    final hoy = (widget.reloj ?? DateTime.now)();
    final texto = _soloDias
        ? textoDiasJuntos(widget.desde, hoy)
        : textoAniversario(widget.desde, hoy);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('contador-aniversario'),
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _soloDias = !_soloDias),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            texto,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}
