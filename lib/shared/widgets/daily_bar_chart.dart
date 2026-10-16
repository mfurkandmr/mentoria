import 'dart:math' as math;

import '../../core/theme/brand_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'effects.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/i18n.dart';

/// Günlük değerler için tek serili çubuk grafik (ör. son 7 gün soru sayısı).
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({
    super.key,
    required this.days,
    required this.values,
    required this.unit,
    this.goal,
    this.height = 170,
  });

  /// Eskiden yeniye günler.
  final List<DateTime> days;
  final List<num> values;

  /// Tooltip birimi ("soru", "dk").
  final String unit;

  /// Varsa yatay hedef çizgisi.
  final num? goal;
  final double height;

  static DateFormat get _weekday => DateFormat('E', localeTag);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Renk denetiminden geçen tonlar (net grafiğiyle aynı).
    final barColor = context.brand.chartOn(theme.brightness);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final grid = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: muted);

    final maxValue = values.fold<num>(0, (m, v) => math.max(m, v));
    final top = math.max(maxValue, goal ?? 0).toDouble();
    final maxY = top <= 0 ? 10.0 : top * 1.2;

    return Semantics(
      label: tr('Son {p0} gün: {p1}', {
        'p0': days.length,
        'p1': [
          for (var i = 0; i < days.length; i++)
            '${_weekday.format(days[i])} ${values[i]} $unit',
        ].join(', '),
      }),
      child: SizedBox(
        height: height,
        child: RevealIn(
          axis: Axis.vertical,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: grid, strokeWidth: 1),
              ),
              extraLinesData: goal == null || goal == 0
                  ? null
                  : ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: goal!.toDouble(),
                          color: muted,
                          strokeWidth: 1,
                          dashArray: [5, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: labelStyle,
                            labelResolver: (_) => 'Hedef',
                          ),
                        ),
                      ],
                    ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: maxY / 4,
                    getTitlesWidget: (v, meta) {
                      if (v == meta.max) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(v.round().toString(), style: labelStyle),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        _weekday.format(days[v.toInt()]),
                        style: labelStyle,
                      ),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${rod.toY.round()} $unit',
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i].toDouble(),
                        color: barColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
