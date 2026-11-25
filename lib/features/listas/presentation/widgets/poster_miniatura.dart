import 'package:flutter/material.dart';

import '../../domain/item_lista.dart';

/// Póster pequeño de la película en la tarjeta (si tiene datos de TMDB).
/// (Pendiente: agente de TMDB.)
class PosterMiniatura extends StatelessWidget {
  const PosterMiniatura({super.key, required this.item});

  final ItemLista item;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
