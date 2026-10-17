import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/effects.dart';
import '../../../shared/widgets/panel.dart';
import '../data/exam.dart';
import '../data/exam_analysis.dart';

/// Kaç denemeye bakılsın.
enum AnalysisWindow {
  last5(5),
  last10(10),
  all(null);

  const AnalysisWindow(this.size);
  final int? size;

  String get label => switch (this) {
    last5 => tr('Son 5'),
    last10 => tr('Son 10'),
    all => tr('Tümü'),
  };
}

extension on SubjectMomentum {
  String get label => switch (this) {
    SubjectMomentum.rising => tr('Yükselişte'),
    SubjectMomentum.falling => tr('Düşüşte'),
    SubjectMomentum.fluctuating => tr('Dalgalı'),
    SubjectMomentum.steady => tr('İstikrarlı'),
    SubjectMomentum.single => tr('Tek deneme'),
  };

  IconData get icon => switch (this) {
    SubjectMomentum.rising => Icons.trending_up_rounded,
    SubjectMomentum.falling => Icons.trending_down_rounded,
    SubjectMomentum.fluctuating => Icons.waves_rounded,
    SubjectMomentum.steady => Icons.trending_flat_rounded,
    SubjectMomentum.single => Icons.more_horiz_rounded,
  };

  Color color(BrandTheme b) => switch (this) {
    SubjectMomentum.rising => b.success,
    SubjectMomentum.falling => b.danger,
    SubjectMomentum.fluctuating => const Color(0xFF1E6FD9),
    SubjectMomentum.steady => b.primaryDeep,
    SubjectMomentum.single => b.ink.withValues(alpha: 0.5),
  };
}

String _perExam(double v) => tr('{v} net/deneme', {'v': formatChange(v)});

/// Deneme analizi: her ders için son denemelerdeki matematiksel gelişim
/// (doğrusal eğilim, istikrar, tahmin, ısı haritası).
class ExamAnalysisView extends StatefulWidget {
  const ExamAnalysisView({super.key, required this.exams});

  /// Tek sınav türünün denemeleri.
  final List<Exam> exams;

  @override
  State<ExamAnalysisView> createState() => _ExamAnalysisViewState();
}

class _ExamAnalysisViewState extends State<ExamAnalysisView> {
  AnalysisWindow _window = AnalysisWindow.last5;

  @override
  Widget build(BuildContext context) {
    final a = ExamAnalysis.of(widget.exams, window: _window.size);
    if (!a.enough) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const Bizz(size: 120),
          const SizedBox(height: 12),
          Text(
            tr('Analiz için en az 2 deneme gerekiyor.'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      );
    }
    final children = <Widget>[
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<AnalysisWindow>(
          showSelectedIcon: false,
          segments: [
            for (final w in AnalysisWindow.values)
              ButtonSegment(value: w, label: Text(w.label)),
          ],
          selected: {_window},
          onSelectionChanged: (s) => setState(() => _window = s.first),
        ),
      ),
      _Overview(analysis: a),
      _Heatmap(analysis: a),
      PanelSectionTitle(
        title: tr('Ders ders gelişim'),
        subtitle: tr('{n} deneme · kesikli çizgi eğilimi gösterir', {
          'n': a.exams.length,
        }),
      ),
      for (final s in a.subjects) _SubjectCard(s: s),
    ];
    return ListView(
      key: ValueKey(_window),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          staggered(i, c),
        ],
      ],
    );
  }
}

/// Üst özet: toplam net eğilimi, tahmin ve öne çıkan dersler.
class _Overview extends StatelessWidget {
  const _Overview({required this.analysis});
  final ExamAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final brand = context.brand;
    final t = a.totalTrend!;
    final up = t.slope >= 0;
    final last = a.exams.last.totalNet;
    final projected = a.exams.length >= 3
        ? math.max(0.0, t.at(a.exams.length - 1 + 5.0))
        : null;
    final rising = a.fastestRising;
    final attention = a.needsAttention;
    final consistent = a.mostConsistent;

    Widget pill(String emoji, String title, String value) => Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brand.primaryDeep,
            Color.lerp(brand.primaryDeep, brand.secondary, 0.7)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Toplam net eğilimi'),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                up ? Icons.north_east_rounded : Icons.south_east_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: CountUp(
                  value: t.slope,
                  format: formatChange,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  tr('net / deneme'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (projected != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tr('Bu gidişle 5 deneme sonra ≈ {p} net (şu an {n})', {
                  'p': formatNet(projected),
                  'n': formatNet(last),
                }),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (rising != null)
            pill(
              '🚀',
              tr('En hızlı yükselen'),
              '${rising.subject.name} · ${_perExam(rising.trend!.slope)}',
            ),
          if (attention != null && attention.code != rising?.code)
            pill(
              '⚠️',
              tr('Dikkat isteyen'),
              attention.trend != null && attention.trend!.slope < 0
                  ? '${attention.subject.name} · ${_perExam(attention.trend!.slope)}'
                  : tr('{s} · %{p} ustalık', {
                      's': attention.subject.name,
                      'p': (attention.mastery * 100).round(),
                    }),
            ),
          if (consistent != null)
            pill('🎯', tr('En istikrarlı'), consistent.subject.name),
        ],
      ),
    );
  }
}

/// Isı haritası: ders × deneme, renk = netin soru sayısına oranı.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.analysis});
  final ExamAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    const cell = 46.0;
    // Kırmızı (boş) → sarı → yeşil (dolu), açık tonlarda.
    Color colorOf(double ratio) =>
        HSVColor.fromAHSV(1, 120 * ratio, 0.42, 1).toColor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Isı haritası'),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              tr('Hücredeki sayı net; renk o dersteki doluluk oranı'),
              style: text.bodySmall,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 96),
                      for (final e in a.exams)
                        SizedBox(
                          width: cell,
                          child: Text(
                            formatShortDate(e.takenOn),
                            textAlign: TextAlign.center,
                            style: text.labelSmall,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final s in a.subjects)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(
                              s.subject.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          for (final e in a.exams)
                            Builder(
                              builder: (_) {
                                final r = e.results
                                    .where((r) => r.code == s.code)
                                    .firstOrNull;
                                return Container(
                                  width: cell - 4,
                                  height: 30,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: r == null
                                        ? brand.ink.withValues(alpha: 0.05)
                                        : colorOf(
                                            (r.net / s.questionCount).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    r == null ? '–' : formatNet(r.net),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2B2350),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bir dersin kartı: gidişat rozeti, eğilim çizgili grafik, sayılar.
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.s});
  final SubjectAnalysis s;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    final m = s.momentum;
    final mColor = m.color(brand);
    final projection = s.projection();
    Widget stat(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(label, textAlign: TextAlign.center, style: text.labelSmall),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.subject.name,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: mColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(m.icon, size: 16, color: mColor),
                      const SizedBox(width: 4),
                      Text(
                        m.label,
                        style: TextStyle(
                          color: mColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (s.trend != null)
              Text(
                tr('Eğilim: {v} · uyum %{r}', {
                  'v': _perExam(s.trend!.slope),
                  'r': (s.trend!.r2 * 100).round(),
                }),
                style: text.bodySmall,
              ),
            const SizedBox(height: 8),
            if (s.nets.length >= 2)
              SizedBox(
                height: 110,
                child: _TrendChart(
                  s: s,
                  color: brand.chartOn(Theme.of(context).brightness),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                stat(tr('Son'), formatNet(s.last)),
                stat(tr('Ortalama'), formatNet(s.average)),
                stat(tr('En iyi'), formatNet(s.best)),
                stat(tr('İsabet'), '%${(s.accuracy * 100).round()}'),
                stat(tr('Boş'), '%${(s.blankRate * 100).round()}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AnimatedLinearProgress(
                    value: s.mastery,
                    color: brand.primaryDeep,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tr('%{p} ustalık', {'p': (s.mastery * 100).round()}),
                  style: text.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (projection != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr('🔮 Bu gidişle 5 deneme sonra ≈ {p} / {q} net', {
                    'p': formatNet(projection),
                    'q': s.questionCount,
                  }),
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Netler + kesikli eğilim çizgisi.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.s, required this.color});
  final SubjectAnalysis s;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = s.nets.length;
    final t = s.trend!;
    final hi = math.max(s.best, math.max(t.at(0), t.at(n - 1.0)));
    final lo = math.min(
      s.nets.reduce(math.min),
      math.min(t.at(0), t.at(n - 1.0)),
    );
    final pad = math.max(1.0, (hi - lo) * 0.2);
    return Semantics(
      label: tr('{s} net grafiği: ilk {a}, son {b}', {
        's': s.subject.name,
        'a': formatNet(s.nets.first),
        'b': formatNet(s.last),
      }),
      excludeSemantics: true,
      child: RevealIn(
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: n - 1.0,
            minY: math.max(lo - pad, -s.questionCount / 4),
            maxY: math.min(hi + pad, s.questionCount.toDouble()),
            clipData: const FlClipData.none(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                getTooltipItems: (spots) => [
                  for (final sp in spots)
                    sp.barIndex == 0
                        ? LineTooltipItem(
                            '${formatShortDate(s.dates[sp.x.round()])}\n${formatNet(sp.y)} net',
                            TextStyle(
                              color: theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < n; i++) FlSpot(i.toDouble(), s.nets[i]),
                ],
                color: color,
                barWidth: 3,
                isCurved: true,
                preventCurveOverShooting: true,
                dotData: FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 3.5,
                    color: color,
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
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              // Eğilim çizgisi (en küçük kareler).
              LineChartBarData(
                spots: [FlSpot(0, t.at(0)), FlSpot(n - 1.0, t.at(n - 1.0))],
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                barWidth: 1.6,
                dashArray: const [6, 5],
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
