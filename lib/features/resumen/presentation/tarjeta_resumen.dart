import 'package:flutter/material.dart';

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
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const Key('tarjeta-resumen'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ResumenPage(
              repository: repository,
              reloj: reloj,
              compartir: compartir,
            ),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                paletasResumen.first.first.withValues(alpha: 0.18),
                paletasResumen.first.last.withValues(alpha: 0.18),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('🎁', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Su año $anio en el club',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Su resumen tipo Wrapped ✨',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
