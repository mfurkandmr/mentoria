import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/brand_theme.dart';
import '../../../../shared/motion.dart';
import 'cockpit_motion.dart';
import 'metric_card.dart';

/// Özet şeridinin baş kartı: "Bu hafta aktif" (iOS Fitness halkası gibi).
/// Koyu kurum renginde; halka katılım yüzdesini dolarak gösterir, sayı
/// sayarak gelir. Yarıdan azı çalıştıysa halka dikkat renginde.
class WeekHeroCard extends StatelessWidget {
  const WeekHeroCard({
    super.key,
    required this.active,
    required this.total,
    required this.onTap,
    this.delta,
    this.title,
    this.caption,
    this.ringLabel,
    this.semanticsLabel,
    this.semanticsHint,
  });

  final int active;
  final int total;
  final MetricDelta? delta;
  final VoidCallback onTap;

  /// Varsayılan "Bu hafta aktif".
  final String? title;

  /// Sayının altındaki satır; varsayılan "öğrenci bu hafta çalıştı".
  final String? caption;

  /// Halkanın ortasındaki küçük yazı; varsayılan "katılım".
  final String? ringLabel;

  /// Ekran okuyucu metinleri (varsayılan: öğrenci katılımı).
  final String? semanticsLabel;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final n = NumberFormat.decimalPattern(localeTag);
    final ratio = total == 0 ? 0.0 : active / total;
    final percent = (ratio * 100).round();
    final low = total > 0 && ratio < 0.5;
    final text = Theme.of(context).textTheme;
    final top = brand.ink;
    final bottom = Color.lerp(brand.ink, brand.secondary, 0.45)!;

    return Pressable(
      scale: 0.98,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: top.withValues(alpha: 0.30),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          color: top,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, bottom],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.white.withValues(alpha: 0.08),
              child: Semantics(
                button: true,
                label:
                    semanticsLabel ??
                    tr('Bu hafta {a} / {t} öğrenci aktif, katılım yüzde {p}', {
                      'a': active,
                      't': total,
                      'p': percent,
                    }),
                hint: semanticsHint ?? tr('Bu hafta çalışmayanları açar'),
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                  child: Row(
                    children: [
                      _Ring(
                        ratio: ratio,
                        low: low,
                        percent: percent,
                        label: ringLabel ?? tr('katılım'),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title ?? tr('Bu hafta aktif'),
                                    style: text.labelLarge?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 6,
                              children: [
                                AnimatedCount(
                                  value: active,
                                  format: n.format,
                                  style: text.displaySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                    letterSpacing: -1,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '/ ${n.format(total)}',
                                    style: text.titleMedium?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              caption ?? tr('öğrenci bu hafta çalıştı'),
                              style: text.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            if (delta != null) ...[
                              const SizedBox(height: 10),
                              DeltaBadge(delta: delta!, onDark: true),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dolan halka; ortasında yüzde ve "katılım".
class _Ring extends StatelessWidget {
  const _Ring({
    required this.ratio,
    required this.low,
    required this.percent,
    required this.label,
  });

  final double ratio;
  final bool low;
  final int percent;
  final String label;

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Yarıdan azı çalıştıysa sıcak sarı (dikkat), değilse beyaz.
    final color = low ? const Color(0xFFFFC56B) : Colors.white;
    Widget ring(double v) => CustomPaint(
      painter: _RingPainter(
        value: v,
        color: color,
        track: Colors.white.withValues(alpha: 0.18),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '%${(v * 100).round()}',
              style: text.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: text.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox.square(
      dimension: _size,
      child: Motion.of(context)
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 1100),
              curve: CockpitMotion.curve,
              builder: (_, v, _) => ring(v),
            )
          : ring(ratio),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (value <= 0) return;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value.clamp(0, 1), false, p);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
