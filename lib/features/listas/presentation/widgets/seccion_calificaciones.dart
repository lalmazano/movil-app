import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Sección "calificaciones" en el detalle del elemento. (Pendiente.)
class SeccionCalificaciones extends StatelessWidget {
  const SeccionCalificaciones({
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
