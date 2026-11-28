import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';

/// Tarjeta en el inicio con las cartas con fecha. (Pendiente: la completa el agente de
/// esta función; debe ocultarse si la bandera `cartas` de config/app es false.)
class TarjetaCartas extends StatelessWidget {
  const TarjetaCartas({super.key, required this.repository});

  final ListaRepository repository;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
