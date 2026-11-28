import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';

/// Tarjeta en el inicio con el acceso al resumen anual. (Pendiente: la completa el agente de
/// esta función; debe ocultarse si la bandera `resumen` de config/app es false.)
class TarjetaResumen extends StatelessWidget {
  const TarjetaResumen({super.key, required this.repository});

  final ListaRepository repository;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
