import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/michi.dart';

/// Foto de perfil del michi en un círculo, o su emoji si no tiene foto.
class MichiAvatar extends StatelessWidget {
  const MichiAvatar({
    super.key,
    this.fotoPath,
    this.emoji = '🐱',
    this.radius = 24,
  });

  MichiAvatar.de(Michi michi, {Key? key, double radius = 24})
    : this(
        key: key,
        fotoPath: michi.fotoPath,
        emoji: michi.emoji,
        radius: radius,
      );

  final String? fotoPath;
  final String emoji;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final emojiTexto = Text(emoji, style: TextStyle(fontSize: radius * 1.1));
    final foto = fotoPath;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.secondary
          .withValues(alpha: 0.35),
      child: foto == null
          ? emojiTexto
          : ClipOval(
              child: Image.file(
                File(foto),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                cacheWidth: 300,
                errorBuilder: (context, error, stack) =>
                    Center(child: emojiTexto),
              ),
            ),
    );
  }
}
