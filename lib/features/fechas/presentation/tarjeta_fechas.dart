import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';

/// Tarjeta en el inicio con la próxima fecha importante. (Pendiente: la completa el agente de
/// esta función; debe ocultarse si la bandera `fechas` de config/app es false.)
class TarjetaFechas extends StatelessWidget {
  const TarjetaFechas({super.key, required this.repository});

  final ListaRepository repository;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
