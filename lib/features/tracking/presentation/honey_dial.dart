import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/motion.dart';
import '../../../shared/widgets/effects.dart';

/// Bal rengi markadan bağımsız bir illüstrasyondur (Bızz gibi sabit).
const _honeyLight = Color(0xFFFFD45C);
const _honeyDeep = Color(0xFFF29D0A);
const _honeyBack = Color(0xFFE08A00);

/// Zamanlayıcının bal kavanozu: yuvarlağın içi [level] (0–1) kadar balla
/// dolu. Pomodoroda süre azaldıkça bal azalır, kronometrede süre arttıkça
/// dolar. Bal yüzeyi dalgalanır, içinden kabarcıklar yükselir; dışta ince
/// bir ilerleme halkası vardır. Seviye değişimi yumuşak animasyonla akar.
class HoneyDial extends StatelessWidget {
  const HoneyDial({
    super.key,
    required this.level,
    required this.ring,
    required this.ringColor,
    required this.child,
    this.flowing = false,
    this.size = 220,
    this.semanticsLabel,
  });

  /// Bal seviyesi (0 boş – 1 dolu).
  final double level;

  /// Dış halkadaki ilerleme (0–1).
  final double ring;
  final Color ringColor;

  /// Ortadaki süre yazısı.
  final Widget child;

  /// Zamanlayıcı çalışırken bal yüzeyi daha canlı dalgalanır.
  final bool flowing;
  final double size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = Motion.of(context);
    final track = scheme.onSurface.withValues(alpha: 0.06);

    Widget dial(double lvl) => LoopBuilder(
      period: const Duration(seconds: 6),
      builder: (_, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _HoneyPainter(
          level: lvl.clamp(0.0, 1.0),
          t: t,
          wave: flowing ? 1 : 0.45,
          track: track,
          rim: scheme.onSurface.withValues(alpha: 0.12),
          ring: ring.clamp(0.0, 1.0),
          ringColor: ringColor,
        ),
      ),
    );

    return Semantics(
      label: semanticsLabel,
      container: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: motion
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(end: level),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => dial(v),
                    )
                  : dial(level),
            ),
            // Yazı hem balın hem boş kısmın üstünde okunsun diye yarı saydam
            // bir zeminde.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(18),
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _HoneyPainter extends CustomPainter {
  _HoneyPainter({
    required this.level,
    required this.t,
    required this.wave,
    required this.track,
    required this.rim,
    required this.ring,
    required this.ringColor,
  });

  final double level;
  final double t;
  final double wave;
  final Color track;
  final Color rim;
  final double ring;
  final Color ringColor;

  static const _ringWidth = 7.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final r = outer - _ringWidth - _gap;
    final circle = Rect.fromCircle(center: c, radius: r);

    // Dış ilerleme halkası.
    final ringRect = Rect.fromCircle(center: c, radius: outer - _ringWidth / 2);
    canvas.drawArc(
      ringRect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringWidth
        ..color = track,
    );
    if (ring > 0) {
      canvas.drawArc(
        ringRect,
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringWidth
          ..strokeCap = StrokeCap.round
          ..color = ringColor,
      );
    }

    // Kavanoz.
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawRect(circle, Paint()..color = track);

    if (level > 0.001) {
      final top = circle.bottom - circle.height * level;
      // Dolu ya da boşa yakınken dalga küçülür (kenarlardan taşmasın).
      final amp =
          5.0 * wave * math.min(1, math.min(level, 1 - level) * 8 + 0.15);
      final phase = t * 2 * math.pi;

      Path surface(double shift, double ampScale) {
        final p = Path()..moveTo(circle.left, circle.bottom);
        for (var x = circle.left; x <= circle.right + 1; x += 4) {
          final k = (x - circle.left) / circle.width;
          final y =
              top +
              math.sin(k * 2 * math.pi * 1.3 + phase + shift) * amp * ampScale;
          p.lineTo(x, y);
        }
        return p
          ..lineTo(circle.right, circle.bottom)
          ..close();
      }

      // Arka dalga (daha koyu), ön dalga (parlak degrade).
      canvas.drawPath(
        surface(math.pi * 0.8, 0.8),
        Paint()..color = _honeyBack.withValues(alpha: 0.75),
      );
      final front = surface(0, 1);
      canvas.drawPath(
        front,
        Paint()
          ..shader =
              const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_honeyLight, _honeyDeep],
              ).createShader(
                Rect.fromLTRB(circle.left, top, circle.right, circle.bottom),
              ),
      );

      // Balın içinde silik petek dokusu ve yükselen kabarcıklar.
      canvas.save();
      canvas.clipPath(front);
      final comb = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.10);
      const hr = 16.0;
      final hw = math.sqrt(3) * hr;
      for (var row = 0; row * 1.5 * hr < circle.height + hr; row++) {
        for (var col = -1; col * hw < circle.width + hw; col++) {
          canvas.drawPath(
            hexPath(
              Offset(
                circle.left + col * hw + (row.isOdd ? hw / 2 : 0),
                circle.bottom - row * 1.5 * hr,
              ),
              hr - 2,
            ),
            comb,
          );
        }
      }
      final bubble = Paint()..color = Colors.white.withValues(alpha: 0.35);
      for (var i = 0; i < 6; i++) {
        final speed = 0.6 + (i % 3) * 0.25;
        final k = (t * speed + i / 6) % 1;
        final x = circle.left + circle.width * (0.18 + 0.13 * i);
        final y = circle.bottom - (circle.bottom - top) * k;
        canvas.drawCircle(
          Offset(x + math.sin(k * 6 + i) * 3, y),
          1.8 + (i % 3),
          bubble,
        );
      }
      canvas.restore();

      // Yüzeyde ince parlak çizgi.
      final shine = Path();
      for (var x = circle.left; x <= circle.right; x += 4) {
        final k = (x - circle.left) / circle.width;
        final y = top + math.sin(k * 2 * math.pi * 1.3 + phase) * amp;
        x == circle.left ? shine.moveTo(x, y) : shine.lineTo(x, y);
      }
      canvas.drawPath(
        shine,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.45),
      );
    }

    // Cam parıltısı.
    canvas.drawArc(
      circle.deflate(10),
      math.pi * 1.1,
      math.pi * 0.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.restore();

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = rim,
    );
  }

  @override
  bool shouldRepaint(_HoneyPainter old) =>
      old.level != level ||
      old.t != t ||
      old.wave != wave ||
      old.ring != ring ||
      old.ringColor != ringColor ||
      old.track != track;
}
