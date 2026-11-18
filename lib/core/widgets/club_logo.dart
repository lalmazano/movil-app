import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Logo del club: la imagen del icono de la app en un círculo.
class ClubLogo extends StatelessWidget {
  const ClubLogo({super.key, this.radio = 64});

  final double radio;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return CircleAvatar(
      radius: radio,
      backgroundColor: color.withValues(alpha: 0.35),
      child: ClipOval(
        child: Image.asset(
          AppConstants.logoAsset,
          width: radio * 2,
          height: radio * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Text('😼', style: TextStyle(fontSize: radio)),
        ),
      ),
    );
  }
}
