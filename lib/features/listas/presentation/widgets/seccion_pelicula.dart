import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Sección "pelicula" en el detalle del elemento. (Pendiente.)
class SeccionPelicula extends StatelessWidget {
  const SeccionPelicula({
    super.key,
    required this.tipo,
    required this.item,
    required this.repository,
  });

  final TipoLista tipo;
  final ItemLista item;
  final ListaRepository repository;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
