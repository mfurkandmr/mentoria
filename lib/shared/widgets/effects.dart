import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/brand_theme.dart';
import '../motion.dart';
import 'bizz.dart';
import '../../core/i18n/i18n.dart';

/// Altıgen yolu (sivri tepe yukarıda).
Path hexPath(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 6 + i * math.pi / 3;
    final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// Petek deseni. [progress] 0→1: altıgenler merkezden dışa doğru belirir.
class HoneycombPainter extends CustomPainter {
  HoneycombPainter({
    required this.color,
    this.progress = 1,
    this.radius = 26,
    this.opacity = 0.12,
  });

  final Color color;
  final double progress;
  final double radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = math.sqrt(3) * radius;
    final h = 1.5 * radius;
    final center = size.center(Offset.zero);
    final maxDist = size.longestSide * 0.75;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var row = -1; row * h < size.height + radius; row++) {
      for (var col = -1; col * w < size.width + w; col++) {
        final c = Offset(col * w + (row.isOdd ? w / 2 : 0), row * h);
        final d = (c - center).distance / maxDist;
        final local = ((progress * 1.4 - d) / 0.4).clamp(0.0, 1.0);
        if (local <= 0) continue;
        stroke.color = color.withValues(alpha: opacity * local);
        canvas.drawPath(hexPath(c, (radius - 3) * (0.6 + 0.4 * local)), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(HoneycombPainter old) =>
      old.progress != progress || old.color != color;
}

/// Gecikmeli "aşağıdan süzülerek belirme" girişi.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.offset = 24,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  /// Listelerde sıra numarasına göre gecikme.
  static Duration stagger(int index, [int stepMs = 60]) =>
      Duration(milliseconds: 80 + index * stepMs);

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!Motion.of(context)) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _curve.value,
      child: Transform.translate(
        offset: Offset(0, widget.offset * (1 - _curve.value)),
        child: child,
      ),
    ),
  );
}

/// Basılınca hafifçe küçülen sarmalayıcı (kartlar, butonlar).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _down = true),
    onPointerUp: (_) => setState(() => _down = false),
    onPointerCancel: (_) => setState(() => _down = false),
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Sayının 0'dan hedefe sayarak gelmesi. [format] son biçimi üretir.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (!Motion.of(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(format(v), style: style),
    );
  }
}

/// Bal rengi altıgen konfeti patlaması (görev tamamlandı, hedefe ulaşıldı).
void celebrate(BuildContext context, {Offset? origin}) {
  HapticFeedback.mediumImpact();
  if (!Motion.of(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final box = context.findRenderObject() as RenderBox?;
  final from =
      origin ??
      (box != null && box.hasSize
          ? box.localToGlobal(box.size.center(Offset.zero))
          : MediaQuery.sizeOf(context).center(Offset.zero));
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _Confetti(origin: from, onDone: () => entry.remove()),
    ),
  );
  overlay.insert(entry);
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.origin, required this.onDone});

  final Offset origin;
  final VoidCallback onDone;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward().whenComplete(widget.onDone);
  late final _pieces = List.generate(26, (i) {
    final r = math.Random(i * 7919);
    return (
      angle: r.nextDouble() * 2 * math.pi,
      speed: 180 + r.nextDouble() * 260,
      size: 5 + r.nextDouble() * 7,
      spin: (r.nextDouble() - 0.5) * 8,
      color: [
        context.brand.primary,
        context.brand.primaryDeep,
        context.brand.secondary,
        const Color(0xFFFF8A65),
        context.brand.success,
      ][i % 5],
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => CustomPaint(
      size: Size.infinite,
      painter: _ConfettiPainter(widget.origin, _pieces, _c.value),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.origin, this.pieces, this.t);

  final Offset origin;
  final List<
    ({double angle, double speed, double size, double spin, Color color})
  >
  pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(t);
    for (final p in pieces) {
      final d = p.speed * ease;
      final pos =
          origin +
          Offset(math.cos(p.angle) * d, math.sin(p.angle) * d + 260 * t * t);
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      canvas.drawPath(hexPath(Offset.zero, p.size), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Değeri değişince yumuşakça dolan çubuk.
class AnimatedLinearProgress extends StatelessWidget {
  const AnimatedLinearProgress({
    super.key,
    required this.value,
    this.minHeight = 8,
    this.backgroundColor,
    this.color,
  });

  final double value;
  final double minHeight;
  final Color? backgroundColor;
  final Color? color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.clamp(0.0, 1.0)),
    duration: Motion.of(context)
        ? const Duration(milliseconds: 800)
        : Duration.zero,
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => LinearProgressIndicator(
      value: v,
      minHeight: minHeight,
      backgroundColor: backgroundColor,
      color: color,
    ),
  );
}

/// Yükleniyor göstergesi: süzülen küçük Bızz.
class BizzLoader extends StatelessWidget {
  const BizzLoader({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        label: tr('Yükleniyor'),
        child: Bizz(size: size, headOnly: true, interactive: false),
      ),
    ),
  );
}

/// Sürekli dönen 0→1 zaman değeriyle çizim (dalga, alev, parıltı).
/// Hareket kapalıysa [t] sabit 0 kalır ve hiç kare üretilmez.
class LoopBuilder extends StatefulWidget {
  const LoopBuilder({
    super.key,
    required this.period,
    required this.builder,
    this.child,
  });

  final Duration period;
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;

  @override
  State<LoopBuilder> createState() => _LoopBuilderState();
}

class _LoopBuilderState extends State<LoopBuilder>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => widget.builder(context, _c.value, child),
  );
}

/// Grafiklerin ilk görünüşte açılması: çizgi soldan sağa çizilir,
/// çubuklar alttan yükselir.
class RevealIn extends StatelessWidget {
  const RevealIn({
    super.key,
    required this.child,
    this.axis = Axis.horizontal,
    this.duration = const Duration(milliseconds: 1100),
  });

  final Widget child;
  final Axis axis;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (!Motion.of(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, v, child) => v >= 1
          ? child!
          : ClipRect(clipper: _RevealClipper(v, axis), child: child),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.v, this.axis);

  final double v;
  final Axis axis;

  @override
  Rect getClip(Size size) => axis == Axis.horizontal
      // Kenardaki noktalar için biraz pay.
      ? Rect.fromLTWH(-8, -8, (size.width + 16) * v, size.height + 16)
      : Rect.fromLTWH(
          -8,
          size.height * (1 - v),
          size.width + 16,
          size.height * v + 8,
        );

  @override
  bool shouldReclip(_RevealClipper old) => old.v != v || old.axis != axis;
}
