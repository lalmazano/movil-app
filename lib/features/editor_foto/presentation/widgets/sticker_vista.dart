import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/editor_estado.dart';

/// Dibuja un sticker (emoji o dibujado en código) dentro de un cuadrado.
class StickerVista extends StatelessWidget {
  const StickerVista({super.key, required this.sticker, required this.lado});

  final String sticker;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final Widget contenido = switch (sticker) {
      StickersMichi.orejitas => CustomPaint(painter: _OrejitasPainter()),
      StickersMichi.bigotes => CustomPaint(painter: _BigotesPainter()),
      _ => FittedBox(
        child: Text(sticker, style: const TextStyle(fontSize: 100)),
      ),
    };
    return SizedBox.square(dimension: lado, child: contenido);
  }
}

class _OrejitasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final exterior = Paint()..color = MichiColors.naranja;
    final interior = Paint()..color = MichiColors.rosa;
    final borde = Paint()
      ..color = MichiColors.cafe
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeJoin = StrokeJoin.round;

    Path oreja(double x0, double punta, double x1, double inset) => Path()
      ..moveTo(x0 + inset, h * 0.8 - inset * 0.3)
      ..lineTo(punta, h * 0.2 + inset * 1.6)
      ..lineTo(x1 - inset, h * 0.8 - inset * 0.3)
      ..close();

    for (final (x0, punta, x1) in [
      (w * 0.02, w * 0.12, w * 0.42),
      (w * 0.58, w * 0.88, w * 0.98),
    ]) {
      final afuera = oreja(x0, punta, x1, 0);
      canvas.drawPath(afuera, exterior);
      canvas.drawPath(afuera, borde);
      canvas.drawPath(oreja(x0, punta, x1, w * 0.07), interior);
    }
  }

  @override
  bool shouldRepaint(_OrejitasPainter oldDelegate) => false;
}

class _BigotesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final linea = Paint()
      ..color = MichiColors.cafe
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    final centro = Offset(w / 2, h / 2);
    for (final dy in [-0.12, 0.0, 0.12]) {
      canvas.drawLine(
        Offset(w * 0.38, h * 0.5 + dy * h * 0.3),
        Offset(w * 0.02, h * (0.5 + dy)),
        linea,
      );
      canvas.drawLine(
        Offset(w * 0.62, h * 0.5 + dy * h * 0.3),
        Offset(w * 0.98, h * (0.5 + dy)),
        linea,
      );
    }
    final nariz = Path()
      ..moveTo(centro.dx - w * 0.07, centro.dy - h * 0.05)
      ..lineTo(centro.dx + w * 0.07, centro.dy - h * 0.05)
      ..lineTo(centro.dx, centro.dy + h * 0.04)
      ..close();
    canvas.drawPath(nariz, Paint()..color = MichiColors.rosa);
  }

  @override
  bool shouldRepaint(_BigotesPainter oldDelegate) => false;
}
