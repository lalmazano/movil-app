import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';

/// Tarjeta en el inicio con el juego Adivina la canción. (Pendiente: la completa el agente de
/// esta función; debe ocultarse si la bandera `adivina` de config/app es false.)
class TarjetaAdivina extends StatelessWidget {
  const TarjetaAdivina({super.key, required this.repository});

  final ListaRepository repository;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
