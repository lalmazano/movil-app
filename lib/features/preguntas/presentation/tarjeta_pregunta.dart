import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';

/// Tarjeta en el inicio con la pregunta del día. (Pendiente: la completa el agente de
/// esta función; debe ocultarse si la bandera `preguntas` de config/app es false.)
class TarjetaPregunta extends StatelessWidget {
  const TarjetaPregunta({super.key, required this.repository});

  final ListaRepository repository;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
