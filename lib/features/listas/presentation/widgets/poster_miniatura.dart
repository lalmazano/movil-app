import 'package:flutter/material.dart';

import '../config_scope.dart';
import '../../domain/item_lista.dart';

/// Póster pequeño de la película en la tarjeta (si tiene datos de TMDB).
class PosterMiniatura extends StatelessWidget {
  const PosterMiniatura({super.key, required this.item});

  final ItemLista item;

  @override
  Widget build(BuildContext context) {
    final url = item.pelicula?.posterUrl;
    if (url == null || !ConfigClubScope.of(context).posters) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          url,
          width: 32,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
