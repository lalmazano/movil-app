import 'dart:io';

import 'package:flutter/material.dart';

/// Muestra la foto de un recuerdo, con un michi de respaldo si no carga.
class FotoRecuerdo extends StatelessWidget {
  const FotoRecuerdo({super.key, required this.path, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: fit == BoxFit.cover ? 600 : null,
      errorBuilder: (context, error, stack) => ColoredBox(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
        child: const Center(child: Text('🐱', style: TextStyle(fontSize: 48))),
      ),
    );
  }
}

String formatearFecha(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
}
