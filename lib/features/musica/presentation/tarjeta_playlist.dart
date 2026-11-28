import 'package:flutter/material.dart';

import '../../listas/domain/item_lista.dart';

/// Tarjeta en el inicio con la playlist del club. (Pendiente: la completa el agente de
/// esta función; debe ocultarse si la bandera `playlist` de config/app es false.)
class TarjetaPlaylist extends StatelessWidget {
  const TarjetaPlaylist({super.key, required this.repository});

  final ListaRepository repository;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
