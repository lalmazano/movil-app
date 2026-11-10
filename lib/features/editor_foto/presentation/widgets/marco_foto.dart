import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/editor_estado.dart';

/// Envuelve la foto con el [marco] elegido. Ocupa todo el espacio dado.
class MarcoFoto extends StatelessWidget {
  const MarcoFoto({super.key, required this.marco, required this.foto});

  final Marco marco;
  final Widget foto;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final llena = SizedBox.expand(child: foto);
        return switch (marco) {
          Marco.ninguno => llena,
          Marco.huellitas => CustomPaint(
            key: const ValueKey('marco-huellitas'),
            painter: _HuellitasPainter(),
            child: Padding(
              padding: EdgeInsets.all(w * 0.09),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(w * 0.03),
                child: llena,
              ),
            ),
          ),
          Marco.rosa => DecoratedBox(
            key: const ValueKey('marco-rosa'),
            decoration: BoxDecoration(
              color: MichiColors.rosa,
              borderRadius: BorderRadius.circular(w * 0.1),
            ),
            child: Padding(
              padding: EdgeInsets.all(w * 0.05),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(w * 0.07),
                child: llena,
              ),
            ),
          ),
          Marco.polaroid => ColoredBox(
            key: const ValueKey('marco-polaroid'),
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.fromLTRB(w * 0.05, w * 0.05, w * 0.05, 0),
              child: Column(
                children: [
                  Expanded(child: llena),
                  SizedBox(
                    height: w * 0.2,
                    child: Center(
                      child: Text(
                        'Mi michi 🐾',
                        style: TextStyle(
                          color: MichiColors.cafe,
                          fontSize: w * 0.075,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        };
      },
    );
  }
}

/// Borde naranja con huellitas crema alrededor.
class _HuellitasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = MichiColors.naranja);
    final paint = Paint()..color = MichiColors.crema;
    final borde = size.width * 0.09;
    final escala = borde / 40;
    final mitad = borde / 2;
    const paso = 1.6;

    void huella(Offset centro, double angulo) {
      canvas.save();
      canvas.translate(centro.dx, centro.dy);
      canvas.rotate(angulo);
      canvas.scale(escala);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 5), width: 18, height: 14),
        paint,
      );
      for (final dedo in const [
        Offset(-10, -5),
        Offset(-3.5, -11),
        Offset(3.5, -11),
        Offset(10, -5),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(center: dedo, width: 6.5, height: 8),
          paint,
        );
      }
      canvas.restore();
    }

    final separacion = borde * paso;
    var i = 0;
    for (var x = mitad; x <= size.width - mitad + 0.1; x += separacion, i++) {
      huella(Offset(x, mitad), i.isEven ? -0.3 : 0.3);
      huella(Offset(x, size.height - mitad), math.pi + (i.isEven ? 0.3 : -0.3));
    }
    i = 0;
    for (
      var y = mitad + separacion;
      y < size.height - mitad - separacion / 2;
      y += separacion, i++
    ) {
      huella(Offset(mitad, y), -math.pi / 2 + (i.isEven ? 0.3 : -0.3));
      huella(
        Offset(size.width - mitad, y),
        math.pi / 2 + (i.isEven ? -0.3 : 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(_HuellitasPainter oldDelegate) => false;
}
