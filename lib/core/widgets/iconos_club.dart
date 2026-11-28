import 'package:flutter/material.dart';

import '../../features/listas/domain/item_lista.dart';

/// Ícono y color de una sección de la app (variante "suave": ícono de color
/// sobre un fondo tenue del mismo color). Se ven iguales en todos los
/// teléfonos, a diferencia de los emojis.
class EstiloSeccion {
  const EstiloSeccion(this.icono, this.color);

  final IconData icono;
  final Color color;
}

abstract final class Secciones {
  static const peliculas = EstiloSeccion(
    Icons.movie_rounded,
    Color(0xFFF28C38),
  );
  static const deseos = EstiloSeccion(
    Icons.auto_awesome_rounded,
    Color(0xFF9C6ADE),
  );
  static const planes = EstiloSeccion(
    Icons.diversity_1_rounded,
    Color(0xFF4CAF7A),
  );
  static const pregunta = EstiloSeccion(Icons.forum_rounded, Color(0xFF26A69A));
  static const banco = EstiloSeccion(
    Icons.lightbulb_rounded,
    Color(0xFFE0A000),
  );
  static const fechas = EstiloSeccion(Icons.event_rounded, Color(0xFFE5574F));
  static const cartas = EstiloSeccion(Icons.draw_rounded, Color(0xFFE86A9A));
  static const canciones = EstiloSeccion(
    Icons.library_music_rounded,
    Color(0xFF3D8BE0),
  );
  static const adivina = EstiloSeccion(
    Icons.headphones_rounded,
    Color(0xFF5C6BC0),
  );
  static const resumen = EstiloSeccion(
    Icons.card_giftcard_rounded,
    Color(0xFFE0A000),
  );
  static const sugerencias = EstiloSeccion(
    Icons.movie_filter_rounded,
    Color(0xFFF28C38),
  );

  static EstiloSeccion deLista(TipoLista tipo) => switch (tipo) {
    TipoLista.peliculas => peliculas,
    TipoLista.deseos => deseos,
    TipoLista.planes => planes,
  };
}

/// El ícono de una sección dentro de un cuadrito redondeado de color tenue.
class InsigniaSeccion extends StatelessWidget {
  const InsigniaSeccion(
    this.estilo, {
    super.key,
    this.lado = 36,
    this.sobreBarra = false,
  });

  final EstiloSeccion estilo;
  final double lado;

  /// En la barra de arriba (de color) el fondo es sólido para que el ícono
  /// contraste.
  final bool sobreBarra;

  @override
  Widget build(BuildContext context) {
    final fondo = sobreBarra
        ? Color.alphaBlend(
            estilo.color.withValues(alpha: 0.18),
            Theme.of(context).colorScheme.surface,
          )
        : estilo.color.withValues(alpha: 0.18);
    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(lado * 0.32),
      ),
      child: Icon(estilo.icono, size: lado * 0.58, color: estilo.color),
    );
  }
}

/// Título de pantalla con la insignia de su sección.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.estilo, this.texto, {super.key});

  final EstiloSeccion estilo;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      InsigniaSeccion(estilo, lado: 30, sobreBarra: true),
      const SizedBox(width: 10),
      Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
    ],
  );
}

/// Una huellita (calificación) del color del tema.
class Huellita extends StatelessWidget {
  const Huellita({super.key, this.llena = true, this.tamano = 16});

  final bool llena;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.pets_rounded,
      size: tamano,
      color: llena ? scheme.primary : scheme.outlineVariant,
    );
  }
}

/// Texto donde cada "🐾" se dibuja como [Huellita].
Widget textoConHuellitas(
  String texto, {
  TextStyle? style,
  int? maxLines,
  TextOverflow? overflow,
}) {
  final partes = texto.split('🐾');
  final tamano = (style?.fontSize ?? 14) * 1.05;
  return Text.rich(
    TextSpan(
      children: [
        for (final (i, p) in partes.indexed) ...[
          if (i > 0)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Huellita(tamano: tamano),
            ),
          TextSpan(text: p),
        ],
      ],
    ),
    style: style,
    maxLines: maxLines,
    overflow: overflow,
  );
}
