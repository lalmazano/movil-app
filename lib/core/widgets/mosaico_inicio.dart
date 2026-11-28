import 'package:flutter/material.dart';

import 'iconos_club.dart';

/// Altura de cada cuadrito del inicio.
const altoMosaico = 118.0;

/// Cuadrito del inicio: ícono de la sección, título corto, una o dos líneas de detalle y,
/// opcionalmente, una barra de avance o algo extra arriba a la derecha.
/// Todos los accesos del inicio usan este mismo diseño.
class MosaicoInicio extends StatelessWidget {
  const MosaicoInicio({
    super.key,
    required this.estilo,
    required this.titulo,
    this.subtitulo,
    this.onTap,
    this.progreso,
    this.extra,
    this.destacado = false,
  });

  final EstiloSeccion estilo;
  final String titulo;
  final String? subtitulo;
  final VoidCallback? onTap;

  /// De 0 a 1; si no es null se dibuja una barrita abajo.
  final double? progreso;

  /// Algo pequeño arriba a la derecha (p. ej. portadas).
  final Widget? extra;

  /// Resalta el cuadrito (p. ej. una fecha muy cercana).
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    // Dentro de la cuadrícula toma su alto; suelto (p. ej. en una lista)
    // usa el alto estándar.
    return LayoutBuilder(
      builder: (context, c) => c.hasBoundedHeight
          ? _tarjeta(context)
          : SizedBox(
              height: altoMosaico * MediaQuery.textScalerOf(context).scale(1),
              child: _tarjeta(context),
            ),
    );
  }

  Widget _tarjeta(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: destacado ? theme.colorScheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InsigniaSeccion(estilo, lado: 34),
                  const Spacer(),
                  ?extra,
                ],
              ),
              const SizedBox(height: 6),
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitulo != null)
                Expanded(
                  child: Text(
                    subtitulo!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                )
              else
                const Spacer(),
              if (progreso != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progreso!.clamp(0, 1),
                    minHeight: 5,
                    color: estilo.color,
                    backgroundColor: estilo.color.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acomoda cuadritos en [columnas] columnas del mismo ancho.
class CuadriculaInicio extends StatelessWidget {
  const CuadriculaInicio({
    super.key,
    required this.hijos,
    this.columnas = 2,
    this.espacio = 10,
  });

  final List<Widget> hijos;
  final int columnas;
  final double espacio;

  @override
  Widget build(BuildContext context) {
    if (hijos.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        // Respeta la letra grande del teléfono (hasta 1.15x).
        final alto = altoMosaico * MediaQuery.textScalerOf(context).scale(1);
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final h in hijos)
              SizedBox(width: ancho, height: alto, child: h),
          ],
        );
      },
    );
  }
}
