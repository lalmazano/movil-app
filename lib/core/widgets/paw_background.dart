import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo decorativo con huellitas de gato.
///
/// Las huellitas se dibujan detrás de la barra de navegación del sistema,
/// pero el contenido ([child]) se mantiene fuera de ella para que el último
/// elemento de una lista no quede tapado.
class PawBackground extends StatelessWidget {
  const PawBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
    return CustomPaint(
      painter: _PawPainter(color),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _PawPainter extends CustomPainter {
  _PawPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 90.0;
    var row = 0;
    for (var y = 20.0; y < size.height + spacing; y += spacing, row++) {
      final offset = row.isEven ? 0.0 : spacing / 2;
      for (var x = offset; x < size.width + spacing; x += spacing) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate((row.isEven ? -1 : 1) * math.pi / 10);
        _drawPaw(canvas, paint);
        canvas.restore();
      }
    }
  }

  void _drawPaw(Canvas canvas, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 8), width: 22, height: 18),
      paint,
    );
    const toes = [
      Offset(-12, -6),
      Offset(-4, -13),
      Offset(4, -13),
      Offset(12, -6),
    ];
    for (final toe in toes) {
      canvas.drawOval(
        Rect.fromCenter(center: toe, width: 8, height: 10),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PawPainter oldDelegate) => oldDelegate.color != color;
}
