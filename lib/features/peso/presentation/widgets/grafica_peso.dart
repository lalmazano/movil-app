import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/registro_peso.dart';

/// Gráfica de línea del peso a lo largo del tiempo.
///
/// El eje X son días desde el primer registro; el eje Y, kilos.
class GraficaPeso extends StatelessWidget {
  const GraficaPeso({super.key, required this.registros});

  /// Registros de un solo michi (en cualquier orden, al menos uno).
  final List<RegistroPeso> registros;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final orden = ordenarPorFecha(registros);
    final inicio = DateUtils.dateOnly(orden.first.fecha);
    double xDe(DateTime f) => f.difference(inicio).inMinutes / 1440;
    DateTime fechaDe(double x) =>
        inicio.add(Duration(minutes: (x * 1440).round()));

    final spots = [for (final r in orden) FlSpot(xDe(r.fecha), r.kg)];
    final kilos = orden.map((r) => r.kg);
    final minKg = kilos.reduce((a, b) => a < b ? a : b);
    final maxKg = kilos.reduce((a, b) => a > b ? a : b);
    var minX = spots.first.x;
    var maxX = spots.last.x;
    if (maxX - minX < 1) {
      minX -= 1;
      maxX += 1;
    }
    final rangoX = maxX - minX;
    final minY = (minKg - 0.5).clamp(0, double.infinity).floorToDouble();
    final maxY = (maxKg + 0.5).ceilToDouble();
    final estiloEje = Theme.of(context).textTheme.labelSmall;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (valor, meta) => SideTitleWidget(
                meta: meta,
                child: Text('${valor.toStringAsFixed(1)} kg', style: estiloEje),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: rangoX / 3,
              getTitlesWidget: (valor, meta) {
                final f = fechaDe(valor);
                return SideTitleWidget(
                  meta: meta,
                  child: Text('${f.day}/${f.month}', style: estiloEje),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.secondaryContainer,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (tocados) => [
              for (final t in tocados)
                LineTooltipItem(
                  '${t.y.toStringAsFixed(2)} kg\n'
                  '${fechaDe(t.x).day}/${fechaDe(t.x).month}',
                  TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            preventCurveOverShooting: true,
            color: scheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 5,
                color: MichiColors.rosa,
                strokeWidth: 2,
                strokeColor: scheme.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.35),
                  scheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
