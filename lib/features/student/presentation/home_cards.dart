import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/yks_dates.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/motion.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../data/daily_quotes.dart';

// ───────────────────────────── YKS geri sayım ─────────────────────────────

/// "YKS'ye kalan" kartı: kayan rakam kutucukları, canlı saat:dakika:saniye,
/// hazırlık yolculuğu çubuğu ve kalan güne göre değişen bir cümle.
class YksCountdownCard extends StatefulWidget {
  const YksCountdownCard({super.key, this.examYear, this.now});

  final int? examYear;

  /// Testler için sabit zaman.
  final DateTime? now;

  @override
  State<YksCountdownCard> createState() => _YksCountdownCardState();
}

class _YksCountdownCardState extends State<YksCountdownCard> {
  Timer? _timer;
  late DateTime _now = widget.now ?? DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.now == null && Motion.of(context)) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _motto(int days) {
    if (days == 0) return tr('Bugün o gün! Sakin ol, sen hazırsın. 🍀');
    if (days <= 30) return tr('Son viraj: tekrar, deneme ve iyi uyku.');
    if (days <= 100) return tr('Son 100 gün! Deneme temposunu artır.');
    if (days <= 200) return tr('Tempoyu artırma zamanı, her gün say.');
    return tr('Uzun bir yol, ama her gün bir adım yeter.');
  }

  @override
  Widget build(BuildContext context) {
    final next = nextYks(examYear: widget.examYear, now: _now);
    if (next == null) return const SizedBox.shrink();
    final exam = next.date.tyt;
    final left = exam.difference(_now);
    final days = left.inDays;
    final start = seasonStart(exam);
    final journey =
        (_now.difference(start).inMinutes / exam.difference(start).inMinutes)
            .clamp(0.0, 1.0);
    final text = Theme.of(context).textTheme;
    final white70 = Colors.white.withValues(alpha: 0.72);

    return Semantics(
      label: tr('YKS {year} için {days} gün kaldı', {
        'year': next.year,
        'days': days,
      }),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2B2350), Color(0xFF4A3A9C), Color(0xFF6C5CE7)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: HoneycombPainter(
                    color: context.brand.primary,
                    radius: 22,
                    opacity: 0.09,
                  ),
                ),
              ),
              // Köşedeki bal ışıltısı.
              Positioned(
                right: -40,
                top: -40,
                child: LoopBuilder(
                  period: const Duration(seconds: 4),
                  builder: (_, t, _) {
                    final s = 1 + 0.08 * math.sin(t * 2 * math.pi);
                    return Transform.scale(
                      scale: s,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              context.brand.primary.withValues(alpha: 0.35),
                              context.brand.primary.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.hourglass_top_rounded,
                          color: context.brand.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tr('YKS {year} için geri sayım', {
                              'year': next.year,
                            }),
                            style: text.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!next.date.official)
                          Tooltip(
                            message: tr(
                              'ÖSYM tarihi açıklayınca güncellenecek',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: white70),
                              ),
                              child: Text(
                                tr('tahmini'),
                                style: text.labelSmall?.copyWith(
                                  color: white70,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _RollingDays(days: days),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('gün'),
                                  style: text.titleLarge?.copyWith(
                                    color: context.brand.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: _Clock(
                                    left: left,
                                    style: text.labelLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Journey(value: journey),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _motto(days),
                            style: text.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('d MMM y', localeTag).format(exam),
                          style: text.labelSmall?.copyWith(color: white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gün sayısı: ilk açılışta slot makinesi gibi dönerek yerine oturur.
class _RollingDays extends StatelessWidget {
  const _RollingDays({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    Widget tiles(int v) {
      final digits = v.toString().padLeft(days.toString().length, '0');
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, d) in digits.split('').indexed)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
              child: _DigitTile(digit: d),
            ),
        ],
      );
    }

    if (!Motion.of(context)) return tiles(days);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: days + 60.0, end: days.toDouble()),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutQuart,
      builder: (_, v, _) => tiles(v.round()),
    );
  }
}

class _DigitTile extends StatelessWidget {
  const _DigitTile({required this.digit});

  final String digit;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      width: 50,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, a) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, -0.6),
                  end: Offset.zero,
                ).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Text(digit, key: ValueKey(digit), style: style),
            ),
          ),
          // Kapak çizgisi (flip saat görünümü).
          Container(height: 1.2, color: Colors.black.withValues(alpha: 0.25)),
        ],
      ),
    );
  }
}

/// Saat:dakika:saniye; saniye her değiştiğinde aşağı kayar.
class _Clock extends StatelessWidget {
  const _Clock({required this.left, this.style});

  final Duration left;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    final s = style?.copyWith(
      color: Colors.white.withValues(alpha: 0.85),
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final h = left.inHours % 24;
    final m = left.inMinutes % 60;
    final sec = left.inSeconds % 60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${two(h)} ${tr('sa')} ${two(m)} ${tr('dk')} ', style: s),
        ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, a) => SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.8),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
              child: child,
            ),
            child: Text(two(sec), key: ValueKey(sec), style: s),
          ),
        ),
        Text(' ${tr('sn')}', style: s),
      ],
    );
  }
}

/// Eylül'den sınava kadar olan yolculuk: bal damlası gibi ilerleyen çubuk.
class _Journey extends StatelessWidget {
  const _Journey({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Hazırlık yolculuğunun %{p}\'i geride', {
            'p': (value * 100).round(),
          }),
          style: text.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: Duration(milliseconds: Motion.of(context) ? 1400 : 0),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Container(
                  height: 8,
                  width: c.maxWidth * v,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        context.brand.primaryDeep,
                        context.brand.primary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.brand.primary.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: (c.maxWidth * v - 9).clamp(0.0, c.maxWidth - 18),
                  top: -5,
                  child: const Text('🐝', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Günün sözü ───────────────────────────────

/// Her gün değişen özlü söz. Yazı mürekkep gibi soldan sağa belirir;
/// uzun basınca ya da düğmeyle kopyalanır.
class DailyQuoteCard extends StatelessWidget {
  const DailyQuoteCard({super.key, this.now});

  final DateTime? now;

  void _copy(BuildContext context, Quote q) {
    Clipboard.setData(ClipboardData(text: '"${q.text}" — ${q.by}'));
    HapticFeedback.lightImpact();
    showMessage(context, tr('Söz kopyalandı'));
  }

  @override
  Widget build(BuildContext context) {
    final q = quoteOfTheDay(now);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;
    final quoteStyle = text.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.45,
      fontStyle: FontStyle.italic,
    );

    Widget body = Text(q.text, style: quoteStyle);
    if (Motion.of(context)) {
      body = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1800),
        curve: Curves.easeInOutCubic,
        child: body,
        builder: (_, v, child) => ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            colors: const [Colors.white, Colors.transparent],
            stops: [v * 1.2 - 0.2, v * 1.2],
          ).createShader(r),
          child: child,
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () => _copy(context, q),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [scheme.surfaceContainerHigh, scheme.surfaceContainer]
                  : [context.brand.canvas, Colors.white],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 8,
                top: -18,
                child: Text(
                  '“',
                  style: TextStyle(
                    fontSize: 110,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: context.brand.primary.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 30),
                        Expanded(
                          child: Text(
                            tr('Günün sözü').toUpperCase(),
                            style: text.labelSmall?.copyWith(
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w800,
                              color: context.brand.primaryDeep,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: tr('Kopyala'),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () => _copy(context, q),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: body,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 2,
                          color: context.brand.primaryDeep,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q.by,
                            style: text.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('Yarın yeni bir söz seni bekliyor 🐝'),
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Bal kavanozu ───────────────────────────────

/// Haftalık soru kavanozu: çözdükçe bal dolar, dalgalanır, kabarcıklar çıkar.
class HoneyJarCard extends StatefulWidget {
  const HoneyJarCard({super.key, required this.weekQuestions, this.dailyGoal});

  final int weekQuestions;
  final int? dailyGoal;

  @override
  State<HoneyJarCard> createState() => _HoneyJarCardState();
}

class _HoneyJarCardState extends State<HoneyJarCard> {
  int _slosh = 0;

  @override
  Widget build(BuildContext context) {
    final goal = widget.dailyGoal == null ? null : widget.dailyGoal! * 7;
    final fill = (widget.weekQuestions / (goal ?? 700)).clamp(0.0, 1.0);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _slosh++);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Bal kavanozu'),
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(tr('Bu haftanın soruları'), style: text.labelSmall),
              const SizedBox(height: 10),
              Center(
                child: SizedBox(
                  width: 92,
                  height: 108,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_slosh),
                    tween: Tween(begin: 1, end: 0),
                    duration: const Duration(milliseconds: 1200),
                    builder: (_, slosh, _) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fill),
                      duration: Duration(
                        milliseconds: Motion.of(context) ? 1600 : 0,
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (_, level, _) => LoopBuilder(
                        period: const Duration(seconds: 3),
                        builder: (_, t, _) => CustomPaint(
                          painter: _JarPainter(
                            brand: context.brand,
                            level: level,
                            t: t,
                            slosh: _slosh == 0 ? 0 : slosh,
                            glass: scheme.onSurface,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Text(
                                '%${(level * 100).round()}',
                                style: text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: level > 0.45
                                      ? context.brand.ink
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: CountUp(
                  value: widget.weekQuestions.toDouble(),
                  format: (v) => tr('{n} soru', {'n': v.round()}),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Center(
                child: Text(
                  goal == null
                      ? tr('hedef koyunca dolmaya başlar')
                      : tr('hedef {goal}', {'goal': goal}),
                  textAlign: TextAlign.center,
                  style: text.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JarPainter extends CustomPainter {
  _JarPainter({
    required this.brand,
    required this.level,
    required this.t,
    required this.slosh,
    required this.glass,
  });

  final BrandTheme brand;
  final double level;
  final double t;
  final double slosh;
  final Color glass;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final lid = Rect.fromLTWH(w * 0.2, 0, w * 0.6, h * 0.12);
    final body = Path()
      ..moveTo(w * 0.24, h * 0.14)
      ..lineTo(w * 0.76, h * 0.14)
      ..quadraticBezierTo(w * 0.78, h * 0.22, w * 0.92, h * 0.28)
      ..quadraticBezierTo(w, h * 0.32, w, h * 0.42)
      ..lineTo(w, h * 0.88)
      ..quadraticBezierTo(w, h, w * 0.86, h)
      ..lineTo(w * 0.14, h)
      ..quadraticBezierTo(0, h, 0, h * 0.88)
      ..lineTo(0, h * 0.42)
      ..quadraticBezierTo(0, h * 0.32, w * 0.08, h * 0.28)
      ..quadraticBezierTo(w * 0.22, h * 0.22, w * 0.24, h * 0.14)
      ..close();

    // Cam.
    canvas.drawPath(body, Paint()..color = glass.withValues(alpha: 0.05));

    // Bal.
    canvas.save();
    canvas.clipPath(body);
    final top = h * 0.2;
    final surface = h - (h - top) * level;
    final amp = 3.0 + 7 * slosh;
    final phase = t * 2 * math.pi;
    Path wave(double offset, double a) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 2) {
        final y =
            surface +
            math.sin(x / w * 2 * math.pi * 1.2 + phase + offset) * a +
            math.sin(slosh * 12) * slosh * 6 * (x / w - 0.5);
        p.lineTo(x, y);
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    if (level > 0) {
      canvas.drawPath(
        wave(math.pi, amp * 0.7),
        Paint()..color = brand.primary.withValues(alpha: 0.55),
      );
      final honeyRect = Rect.fromLTWH(0, surface - amp, w, h - surface + amp);
      canvas.drawPath(
        wave(0, amp),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [brand.primary, brand.primaryDeep],
          ).createShader(honeyRect),
      );
      // Kabarcıklar.
      final bubble = Paint()..color = Colors.white.withValues(alpha: 0.45);
      for (var i = 0; i < 5; i++) {
        final k = (t + i / 5) % 1;
        final y = h - (h - surface) * k;
        if (y < surface + 4) continue;
        final x = w * (0.2 + 0.15 * i) + math.sin(k * 6 + i) * 3;
        canvas.drawCircle(Offset(x, y), 1.5 + (i % 3), bubble);
      }
    }
    canvas.restore();

    // Cam kenarı ve parlaması.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = glass.withValues(alpha: 0.25),
    );
    canvas.drawLine(
      Offset(w * 0.12, h * 0.45),
      Offset(w * 0.12, h * 0.8),
      Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    // Kapak.
    canvas.drawRRect(
      RRect.fromRectAndRadius(lid, const Radius.circular(5)),
      Paint()..color = brand.secondary,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lid.left, lid.bottom - 3, lid.width, 3),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
  }

  @override
  bool shouldRepaint(_JarPainter old) =>
      old.brand != brand ||
      old.level != level ||
      old.t != t ||
      old.slosh != slosh ||
      old.glass != glass;
}

// ─────────────────────────────── Seri alevi ───────────────────────────────

/// Seri kartı: titreyen alev (seri büyüdükçe büyür) ve son 7 günün petekleri.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streak,
    required this.activeDays,
    this.now,
  });

  final int streak;
  final Set<DateTime> activeDays;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime(
      (now ?? DateTime.now()).year,
      (now ?? DateTime.now()).month,
      (now ?? DateTime.now()).day,
    );
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final lit = streak > 0;
    final size = lit ? 64 + math.min(streak, 30) * 0.8 : 60.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Seri'),
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(tr('Art arda çalışılan günler'), style: text.labelSmall),
            const SizedBox(height: 10),
            SizedBox(
              height: 108,
              child: Center(
                child: LoopBuilder(
                  period: const Duration(milliseconds: 1400),
                  builder: (_, t, _) => CustomPaint(
                    size: Size(size * 0.8, size),
                    painter: _FlamePainter(
                      t: t,
                      lit: lit,
                      grey: scheme.outline,
                    ),
                    child: SizedBox(
                      width: size * 0.8,
                      height: size,
                      child: Align(
                        alignment: const Alignment(0, 0.55),
                        child: Text(
                          '$streak',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: lit ? context.brand.ink : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in days)
                  _DayHex(
                    label: DateFormat(
                      'E',
                      localeTag,
                    ).format(d).characters.first,
                    active: activeDays.contains(d),
                    today: d == today,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                lit
                    ? tr('{n} gün seri', {'n': streak})
                    : tr('Bugün başla, seriyi yak!'),
                style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHex extends StatelessWidget {
  const _DayHex({
    required this.label,
    required this.active,
    required this.today,
  });

  final String label;
  final bool active;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        CustomPaint(
          size: const Size(16, 18),
          painter: _HexDot(
            fill: active
                ? context.brand.primaryDeep
                : scheme.onSurface.withValues(alpha: 0.1),
            ring: today ? context.brand.secondary : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            fontWeight: today ? FontWeight.w900 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HexDot extends CustomPainter {
  _HexDot({required this.fill, this.ring});

  final Color fill;
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = hexPath(c, size.width / 2);
    canvas.drawPath(path, Paint()..color = fill);
    if (ring != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = ring!,
      );
    }
  }

  @override
  bool shouldRepaint(_HexDot old) => old.fill != fill || old.ring != ring;
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.t, required this.lit, required this.grey});

  final double t;
  final bool lit;
  final Color grey;

  Path _flame(Size s, double sway, double stretch, double inset) {
    final w = s.width;
    final h = s.height;
    final base = h * (0.98 - inset * 0.1);
    final tip = Offset(
      w / 2 + sway * w * 0.18,
      h * (inset * 0.55) - (stretch - 1) * h * 0.3,
    );
    final half = w / 2 * (1 - inset);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(
        w / 2 + half * 0.9,
        h * (0.35 + inset * 0.2),
        w / 2 + half * 1.15,
        h * 0.62,
        w / 2 + half * 0.82,
        base - h * 0.12,
      )
      ..quadraticBezierTo(
        w / 2,
        base + h * 0.04,
        w / 2 - half * 0.82,
        base - h * 0.12,
      )
      ..cubicTo(
        w / 2 - half * 1.15,
        h * 0.62,
        w / 2 - half * 0.75,
        h * (0.42 + inset * 0.2),
        tip.dx,
        tip.dy,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    final sway = lit ? math.sin(a) * 0.6 + math.sin(a * 3 + 1) * 0.25 : 0.0;
    final stretch = lit ? 1 + 0.06 * math.sin(a * 2 + 0.5) : 1.0;
    final rect = Offset.zero & size;

    if (!lit) {
      canvas.drawPath(
        _flame(size, 0, 1, 0),
        Paint()..color = grey.withValues(alpha: 0.35),
      );
      return;
    }
    // Sıcak ışık halesi.
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.62),
      size.width * 0.75,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFF8A3D).withValues(alpha: 0.3),
                const Color(0xFFFF8A3D).withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width / 2, size.height * 0.62),
                radius: size.width * 0.75,
              ),
            ),
    );
    canvas.drawPath(
      _flame(size, sway, stretch, 0),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFFF5A36), Color(0xFFFF8A3D), Color(0xFFFFC531)],
        ).createShader(rect),
    );
    canvas.drawPath(
      _flame(size, sway * 1.3, stretch * 0.98, 0.32),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFFFC531), Color(0xFFFFF1B0)],
        ).createShader(rect),
    );
    // Uçuşan kıvılcımlar.
    final spark = Paint()..color = const Color(0xFFFFD36B);
    for (var i = 0; i < 3; i++) {
      final k = (t * 1.5 + i / 3) % 1;
      spark.color = const Color(0xFFFFD36B).withValues(alpha: 1 - k);
      canvas.drawCircle(
        Offset(
          size.width / 2 + math.sin(k * 5 + i * 2) * size.width * 0.3,
          size.height * (0.3 - k * 0.35),
        ),
        1.6 * (1 - k) + 0.4,
        spark,
      );
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.t != t || old.lit != lit;
}

// ─────────────────────────────── Rozetler ───────────────────────────────

class Achievement {
  const Achievement({
    required this.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.target,
  });

  /// Sunucudaki rozet anahtarıyla aynı (avatar kilit kuralları bunu kullanır).
  final String key;
  final IconData icon;
  final String title;
  final String description;
  final int value;
  final int target;

  bool get unlocked => value >= target;
  double get progress => (value / target).clamp(0.0, 1.0);
}

/// En uzun art arda gün serisi.
int bestStreak(Iterable<DateTime> days) {
  final sorted = days.toSet().toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = prev != null && d.difference(prev).inHours.round() == 24
        ? run + 1
        : 1;
    best = math.max(best, run);
    prev = d;
  }
  return best;
}

List<Achievement> buildAchievements({
  required int totalQuestions,
  required int bestStreak,
  required int exams,
  required int studyMinutes,
  required int topicsDone,
}) => [
  Achievement(
    key: 'first_step',
    icon: Icons.flag_rounded,
    title: tr('İlk adım'),
    description: tr('İlk soru kaydını gir.'),
    value: totalQuestions,
    target: 1,
  ),
  Achievement(
    key: 'streak_3',
    icon: Icons.local_fire_department_rounded,
    title: tr('3 gün seri'),
    description: tr('Üç gün üst üste çalış.'),
    value: bestStreak,
    target: 3,
  ),
  Achievement(
    key: 'questions_100',
    icon: Icons.bolt_rounded,
    title: tr('100 soru'),
    description: tr('Toplam 100 soru çöz.'),
    value: totalQuestions,
    target: 100,
  ),
  Achievement(
    key: 'first_exam',
    icon: Icons.insights_rounded,
    title: tr('İlk deneme'),
    description: tr('İlk deneme sonucun sisteme girilsin.'),
    value: exams,
    target: 1,
  ),
  Achievement(
    key: 'streak_7',
    icon: Icons.calendar_month_rounded,
    title: tr('Haftalık seri'),
    description: tr('Yedi gün üst üste çalış.'),
    value: bestStreak,
    target: 7,
  ),
  Achievement(
    key: 'focus_master',
    icon: Icons.self_improvement_rounded,
    title: tr('Odak ustası'),
    description: tr('Toplam 10 saat odaklan.'),
    value: studyMinutes,
    target: 600,
  ),
  Achievement(
    key: 'topic_hunter',
    icon: Icons.task_alt_rounded,
    title: tr('Konu avcısı'),
    description: tr('10 konuyu bitir.'),
    value: topicsDone,
    target: 10,
  ),
  Achievement(
    key: 'questions_1000',
    icon: Icons.emoji_events_rounded,
    title: tr('Bin soru'),
    description: tr('Toplam 1000 soru çöz.'),
    value: totalQuestions,
    target: 1000,
  ),
  Achievement(
    key: 'streak_30',
    icon: Icons.whatshot_rounded,
    title: tr('Aylık seri'),
    description: tr('Otuz gün üst üste çalış.'),
    value: bestStreak,
    target: 30,
  ),
  Achievement(
    key: 'question_machine',
    icon: Icons.workspace_premium_rounded,
    title: tr('Soru makinesi'),
    description: tr('Toplam 5000 soru çöz.'),
    value: totalQuestions,
    target: 5000,
  ),
];

/// Yatay rozet şeridi; açılanlar önde ve parıldar.
class AchievementsCard extends StatelessWidget {
  const AchievementsCard({super.key, required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final sorted = [
      ...achievements.where((a) => a.unlocked),
      ...achievements.where((a) => !a.unlocked),
    ];
    final open = achievements.where((a) => a.unlocked).length;
    return SectionCard(
      title: tr('Rozetlerim'),
      subtitle: tr('{open}/{all} rozet açıldı', {
        'open': open,
        'all': achievements.length,
      }),
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 12),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 16),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) =>
              _BadgeTile(achievement: sorted[i], shineDelay: i * 0.12),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.achievement, required this.shineDelay});

  final Achievement achievement;
  final double shineDelay;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${a.title}, ${a.unlocked ? tr('açıldı') : tr('kilitli')}',
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          onTap: () => _showAchievement(context, a),
          child: SizedBox(
            width: 70,
            child: Column(
              children: [
                BadgeHex(achievement: a, size: 60, shineDelay: shineDelay),
                const SizedBox(height: 6),
                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    fontWeight: a.unlocked ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Altıgen rozet. Açıksa bal degradesi ve ara ara geçen bir parıltı.
class BadgeHex extends StatelessWidget {
  const BadgeHex({
    super.key,
    required this.achievement,
    this.size = 60,
    this.shineDelay = 0,
  });

  final Achievement achievement;
  final double size;
  final double shineDelay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = achievement;
    final icon = Icon(
      a.unlocked ? a.icon : Icons.lock_rounded,
      size: size * 0.4,
      color: a.unlocked
          ? context.brand.ink
          : scheme.onSurface.withValues(alpha: 0.35),
    );
    Widget hex(double t) => CustomPaint(
      size: Size.square(size),
      painter: _BadgePainter(
        brand: context.brand,
        unlocked: a.unlocked,
        progress: a.progress,
        shine: a.unlocked ? t : null,
        track: scheme.onSurface.withValues(alpha: 0.08),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(child: icon),
      ),
    );
    if (!a.unlocked) return hex(0);
    return LoopBuilder(
      period: const Duration(milliseconds: 3600),
      builder: (_, t, _) => hex((t + shineDelay) % 1),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({
    required this.brand,
    required this.unlocked,
    required this.progress,
    required this.shine,
    required this.track,
  });

  final BrandTheme brand;
  final bool unlocked;
  final double progress;
  final double? shine;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final outer = hexPath(c, r);
    final inner = hexPath(c, r - 5);

    if (!unlocked) {
      canvas.drawPath(inner, Paint()..color = track);
      // İlerleme: kenar boyunca dolan bal çizgisi.
      final metric = outer.computeMetrics().first;
      canvas.drawPath(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = track,
      );
      if (progress > 0) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * progress),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = brand.primaryDeep,
        );
      }
      return;
    }

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawShadow(outer, brand.primaryDeep, 4, false);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(brand.primary, Colors.white, 0.45)!,
            brand.primaryDeep,
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.6),
    );
    // Parıltı: döngünün ilk %30'unda çapraz geçen ışık.
    final s = shine;
    if (s != null && s < 0.3) {
      final k = s / 0.3;
      canvas.save();
      canvas.clipPath(outer);
      final x = -r + k * size.width * 1.8;
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + 14, 0)
          ..lineTo(x + 14 - size.height * 0.6, size.height)
          ..lineTo(x - size.height * 0.6, size.height)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.brand != brand ||
      old.shine != shine ||
      old.unlocked != unlocked ||
      old.progress != progress ||
      old.track != track;
}

void _showAchievement(BuildContext context, Achievement a) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    // Alt menünün üstünde açılsın (sekme içi gezgin değil).
    useRootNavigator: true,
    showDragHandle: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: Duration(milliseconds: Motion.of(context) ? 600 : 0),
                curve: Curves.elasticOut,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: BadgeHex(achievement: a, size: 96),
              ),
              const SizedBox(height: 14),
              Text(
                a.title,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(a.description, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AnimatedLinearProgress(value: a.progress),
              const SizedBox(height: 6),
              Text(
                a.unlocked
                    ? tr('Rozet açıldı! 🎉')
                    : '${a.value} / ${a.target}',
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    },
  );
}
