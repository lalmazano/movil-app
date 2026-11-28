import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Sugerencias de TMDB en el detalle de una película ("Si les gustó…").
/// (Pendiente: la completa el agente de sugerencias; se oculta con la
/// bandera `sugerencias` en false.)
class SeccionSugerencias extends StatelessWidget {
  const SeccionSugerencias({
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
