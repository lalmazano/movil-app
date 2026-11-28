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

/// Letra del nombre del club (Fredoka, redondeada).
const familiaLogotipo = 'Fredoka';

/// Logotipo del club: el gato del ícono en un circulito y el nombre con la
/// letra redondeada. Se usa en la barra del inicio y en la pantalla de
/// entrada.
class LogotipoClub extends StatelessWidget {
  const LogotipoClub({super.key, this.tamano = 22, this.color});

  /// Tamaño de la letra; el circulito del gato se ajusta a él.
  final double tamano;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClubLogo(radio: tamano * 0.8),
      SizedBox(width: tamano * 0.45),
      Flexible(
        child: Text(
          AppConstants.appName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: familiaLogotipo,
            fontWeight: FontWeight.w600,
            fontSize: tamano,
            letterSpacing: 0.2,
            color: color,
          ),
        ),
      ),
    ],
  );
}
