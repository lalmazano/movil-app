import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Fila pequeña bajo el título de la tarjeta: quién lo agregó / marcó,
/// promedio de huellitas, número de fotos. (Pendiente: agente de
/// calificaciones y autores.)
class InsigniasItem extends StatelessWidget {
  const InsigniasItem({super.key, required this.item});

  final ItemLista item;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
