import 'package:flutter/material.dart';

import '../core/routes/app_router.dart';

/// Entrada del menú principal.
class Seccion {
  const Seccion({
    required this.titulo,
    required this.icono,
    required this.ruta,
  });

  final String titulo;
  final IconData icono;
  final String ruta;
}

/// Secciones que aparecen en el inicio. Para agregar una funcionalidad al
/// menú, registra su ruta en `app_router.dart` y añádela aquí.
const secciones = <Seccion>[
  Seccion(
    titulo: 'Foto con mi michi',
    icono: Icons.photo_camera,
    ruta: AppRoutes.recuerdos,
  ),
  Seccion(
    titulo: 'Juego para michi',
    icono: Icons.sports_esports,
    ruta: AppRoutes.juego,
  ),
];
