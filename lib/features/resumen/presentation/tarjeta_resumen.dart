import 'package:flutter/material.dart';

import '../../../core/widgets/iconos_club.dart';
import '../../../core/widgets/mosaico_inicio.dart';
import '../../listas/domain/item_lista.dart';
import '../../listas/presentation/config_scope.dart';
import 'resumen_page.dart';

/// Tarjeta en el inicio con el acceso al resumen anual (🎁). Se oculta si la
/// bandera `resumen` de config/app es false o si no hay listas visibles.
class TarjetaResumen extends StatelessWidget {
  const TarjetaResumen({
    super.key,
    required this.repository,
    this.reloj,
    this.compartir,
  });

  final ListaRepository repository;

  /// Para pruebas: qué día es "hoy" (define el año por defecto).
  final DateTime Function()? reloj;

  /// Para pruebas: cómo se comparte la imagen del resumen.
  final CompartirResumen? compartir;

  @override
  Widget build(BuildContext context) {
    final config = ConfigClubScope.of(context);
    if (!config.resumen || config.listasVisibles.isEmpty) {
      return const SizedBox.shrink();
    }
    final anio = (reloj ?? DateTime.now)().year;
    return MosaicoInicio(
      key: const Key('tarjeta-resumen'),
      estilo: Secciones.resumen,
      titulo: 'Su año $anio',
      subtitulo: 'Su resumen del club ✨',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResumenPage(
            repository: repository,
            reloj: reloj,
            compartir: compartir,
          ),
        ),
      ),
    );
  }
}
