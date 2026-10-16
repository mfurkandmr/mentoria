import 'dart:math' as math;

import '../../../core/theme/brand_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/effects.dart';

import '../../../shared/format.dart';
import '../data/exam.dart';
import '../../../core/i18n/i18n.dart';

/// Toplam net gelişimi: tek seri çizgi grafik (son 12 deneme).
class NetTrendChart extends StatelessWidget {
  const NetTrendChart({super.key, required this.exams, this.valueOf});

  /// Eskiden yeniye sıralı.
  final List<Exam> exams;

  /// Çizilecek değer (varsayılan toplam net). null dönen denemeler atlanır.
  final double? Function(Exam exam)? valueOf;

  static const _maxPoints = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Renk denetiminden geçen tonlar (açık/koyu yüzeyde ayrı ayrı).
    final lineColor = context.brand.chartOn(theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final gridColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    final value = valueOf ?? (Exam e) => e.totalNet;
    final withValue = [
      for (final e in exams)
        if (value(e) != null) e,
    ];
    final points = withValue.length > _maxPoints
        ? withValue.sublist(withValue.length - _maxPoints)
        : withValue;
    final nets = [for (final e in points) value(e)!];
    final lo = nets.reduce(math.min);
    final hi = nets.reduce(math.max);
    final step = _niceStep((hi - lo).abs());
    final minY = math.max(0.0, ((lo - step / 2) / step).floor() * step);
    final maxY = ((hi + step / 2) / step).ceil() * step;

    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: muted);

    return Semantics(
      label: tr(
        'Toplam net gelişimi grafiği, {p0} deneme. İlk {p1}, son {p2} net.',
        {
          'p0': points.length,
          'p1': formatNet(nets.first),
          'p2': formatNet(nets.last),
        },
      ),
      child: RevealIn(
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            minY: minY,
            maxY: maxY,
            // Kenardaki noktalar kesilmesin.
            clipData: const FlClipData.none(),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: gridColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: step,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max || value == meta.min) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(formatNet(value), style: labelStyle),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    final last = points.length - 1;
                    // Kalabalığı önlemek için ilk, son ve aradaki birkaç etiket.
                    final every = math.max(1, (points.length / 4).ceil());
                    final show =
                        i == 0 ||
                        i == last ||
                        (i % every == 0 && last - i >= every / 2);
                    if (value != i || !show) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        formatShortDate(points[i].takenOn),
                        style: labelStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchSpotThreshold: 24,
              getTouchedSpotIndicator: (bar, indexes) => [
                for (final _ in indexes)
                  TouchedSpotIndicatorData(
                    FlLine(color: muted, strokeWidth: 1, dashArray: [4, 4]),
                    FlDotData(
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 6,
                        color: lineColor,
                        strokeWidth: 2,
                        strokeColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
              ],
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                tooltipBorderRadius: BorderRadius.circular(10),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      tr('{p0}\n', {'p0': points[s.x.round()].name}),
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: '${formatNet(s.y)} net',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), nets[i]),
                ],
                color: lineColor,
                barWidth: 2,
                isCurved: true,
                preventCurveOverShooting: true,
                dotData: FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 4,
                    color: lineColor,
                    strokeWidth: 2,
                    strokeColor: theme.colorScheme.surface,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lineColor.withValues(alpha: 0.18),
                      lineColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Eksen için 5, 10, 20 gibi okunaklı aralık.
  static double _niceStep(double range) {
    if (range <= 10) return 5;
    if (range <= 25) return 10;
    if (range <= 60) return 20;
    return 25;
  }
}
