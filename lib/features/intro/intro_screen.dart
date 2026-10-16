import '../../core/sound/app_sounds.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/brand_theme.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/bizz.dart';
import '../../shared/widgets/effects.dart';

/// Açılış animasyonu: petekler belirir, Bızz uçarak gelir, harfler düşer.
/// Dokununca atlanır; "hareketi azalt" açıksa hemen geçer.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2700);
  static const _landAt = 0.42;

  late final _c = AnimationController(vsync: this, duration: _total);
  final _bizz = BizzController();
  bool _landed = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _bizz.flying = true;
    _c.addListener(_onTick);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.value > 0) return;
    if (Motion.of(context)) {
      _c.forward();
      // Bızz uçarak gelirken vızıltı, konunca çan (ayarlardan kapatılabilir).
      AppSounds.play(AppSound.intro);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  void _onTick() {
    if (!_landed && _c.value >= _landAt) {
      _landed = true;
      _bizz
        ..flying = false
        ..mood = BizzMood.happy
        ..celebrate();
    }
    setState(() {});
  }

  void _finish() {
    if (_left || !mounted) return;
    _left = true;
    context.go('/');
  }

  @override
  void dispose() {
    _c.dispose();
    _bizz.dispose();
    super.dispose();
  }

  double _interval(double begin, double end, [Curve curve = Curves.easeOut]) =>
      curve.transform(((_c.value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final bizzSize = math.min(size.width * 0.5, 200.0);

    // Bızz'ın uçuş yolu: sol alttan kavisle ortaya.
    final fly = _interval(0, _landAt, Curves.easeOutCubic);
    const start = Offset(-0.9, 0.9);
    const ctrl = Offset(-0.7, -0.6);
    const end = Offset(0, -0.18);
    final p = Offset(
      math.pow(1 - fly, 2) * start.dx +
          2 * (1 - fly) * fly * ctrl.dx +
          fly * fly * end.dx,
      math.pow(1 - fly, 2) * start.dy +
          2 * (1 - fly) * fly * ctrl.dy +
          fly * fly * end.dy,
    );
    final tilt = (1 - fly) * 0.35;

    final burst = _interval(_landAt, _landAt + 0.3);
    final outro = _interval(0.9, 1.0, Curves.easeIn);

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Opacity(
          opacity: 1 - outro,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.1,
                    colors: isDark
                        ? const [Color(0xFF2A2350), Color(0xFF16122E)]
                        : [const Color(0xFFFFF1C2), context.brand.canvas],
                  ),
                ),
              ),
              CustomPaint(
                painter: HoneycombPainter(
                  color: isDark
                      ? context.brand.primary
                      : context.brand.primaryDeep,
                  progress: _interval(0, 0.6),
                  opacity: isDark ? 0.12 : 0.18,
                ),
              ),
              // Konma anında saçılan bal damlaları
              if (burst > 0 && burst < 1)
                CustomPaint(
                  painter: _BurstPainter(
                    brand: context.brand,
                    center: Alignment(
                      end.dx,
                      end.dy,
                    ).alongSize(size).translate(0, bizzSize * 0.1),
                    t: burst,
                  ),
                ),
              Align(
                alignment: Alignment(p.dx, p.dy),
                child: Transform.rotate(
                  angle: tilt,
                  child: Transform.scale(
                    scale: 0.55 + 0.45 * fly,
                    child: Bizz(
                      size: bizzSize,
                      controller: _bizz,
                      intro: true,
                      interactive: false,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.42),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Uzun dershane adları ekrana sığsın.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _DroppingWordmark(
                          progress: _interval(_landAt + 0.05, 0.82),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: _interval(0.72, 0.88),
                      child: Text(
                        tr('Hedefine giden yolda her gün biraz daha.'),
                        style: theme.textTheme.bodyLarge,
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

/// Uygulama adının harfleri sırayla yukarıdan düşer (varsayılanda
/// "mentoria", son üç harf vurgulu; dershanede dershanenin adı).
class _DroppingWordmark extends StatelessWidget {
  const _DroppingWordmark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final letters = brand.isDefaultBrand ? 'mentoria' : brand.appName;
    final accentFrom = brand.isDefaultBrand ? 5 : letters.length;
    final base = Theme.of(context).textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          () {
            final local = Curves.elasticOut.transform(
              ((progress * 1.8 - i * 0.1)).clamp(0.0, 1.0),
            );
            final fade = ((progress * 1.8 - i * 0.1) * 3).clamp(0.0, 1.0);
            return Opacity(
              opacity: fade,
              child: Transform.translate(
                offset: Offset(0, -40 * (1 - local)),
                child: Text(
                  letters[i],
                  style: i >= accentFrom
                      ? base?.copyWith(color: brand.primaryDeep)
                      : base,
                ),
              ),
            );
          }(),
      ],
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.center, required this.t, required this.brand});

  final BrandTheme brand;

  final Offset center;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < 14; i++) {
      final a = i * 2 * math.pi / 14 + 0.2;
      final d = 40 + 110 * ease;
      final pos = center + Offset(math.cos(a) * d, math.sin(a) * d * 0.8);
      canvas.drawPath(
        hexPath(pos, (i.isEven ? 7 : 4) * (1 - t * 0.5)),
        Paint()
          ..color = (i % 3 == 0 ? brand.secondary : brand.primary).withValues(
            alpha: 1 - t,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.brand != brand || old.t != t;
}
