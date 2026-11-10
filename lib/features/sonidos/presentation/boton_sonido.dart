import 'package:flutter/material.dart';

import '../domain/servicio_sonidos.dart';

/// Botón para encender/apagar los sonidos, pensado para `AppBar.actions`.
class BotonSonido extends StatelessWidget {
  const BotonSonido({super.key, required this.sonidos});

  final ServicioSonidos sonidos;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sonidos,
      builder: (context, _) {
        final activado = sonidos.activado;
        return IconButton(
          icon: Icon(activado ? Icons.volume_up : Icons.volume_off),
          tooltip: activado ? 'Silenciar al michi' : 'Activar sonidos michi',
          onPressed: () async {
            final encender = !activado;
            await sonidos.setActivado(encender);
            if (encender) await sonidos.maullar();
          },
        );
      },
    );
  }
}
