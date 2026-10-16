import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sound/app_sounds.dart';
import '../motion.dart';
import 'bizz.dart';

/// [BizzSwap]'ı dışarıdan yönetir (gökyüzü başlığı).
class BizzSwapController {
  _BizzSwapState? _state;

  /// Değişim animasyonu sürüyor mu.
  bool get busy => _state?._busy ?? false;

  /// Yerdeki arı zıplar, güler.
  void celebrate() => _state?._active.celebrate();

  /// Yerdeki arı başını iki yana sallar ("şimdi olmaz").
  void shakeHead() => _state?._active.shake();

  /// Yeni bir arı uçarak gelip yerdekine çarpar, onu savurur, yerine
  /// konar ve güler. Animasyon bitince tamamlanır.
  Future<void> swap() => _state?._swap() ?? Future.value();
}

/// Yerini başka bir Bızz'a bırakabilen Bızz. İki arı da aynı çizimdir; her
/// değişimde rolleri yer değiştirir, böylece yerdeki arı hiç sıçramaz.
class BizzSwap extends StatefulWidget {
  const BizzSwap({super.key, required this.controller, this.size = 104});

  final BizzSwapController controller;
  final double size;

  /// Değişimin süresi; çarpışma bunun [impactAt] anında.
  static const duration = Duration(milliseconds: 1700);
  static const impactAt = 0.32;

  @override
  State<BizzSwap> createState() => _BizzSwapState();
}

class _BizzSwapState extends State<BizzSwap>
    with SingleTickerProviderStateMixin {
  final _bees = [BizzController(), BizzController()];
  int _activeIndex = 0;
  bool _busy = false;
  bool _impacted = false;
  bool _landed = false;
  Timer? _calm;

  late final _anim = AnimationController(
    vsync: this,
    duration: BizzSwap.duration,
  )..addListener(_onFrame);

  BizzController get _active => _bees[_activeIndex];
  BizzController get _incoming => _bees[1 - _activeIndex];

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(BizzSwap old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._state = null;
      widget.controller._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _calm?.cancel();
    _anim.dispose();
    for (final b in _bees) {
      b.dispose();
    }
    super.dispose();
  }

  Future<void> _swap() async {
    if (_busy || !mounted) return;
    final leaver = _active;
    final comer = _incoming;
    // Hareket kapalıysa (erişilebilirlik): yeni arı doğrudan yerinde güler.
    if (!Motion.of(context)) {
      HapticFeedback.mediumImpact();
      setState(() => _activeIndex = 1 - _activeIndex);
      _smile(comer);
      return;
    }
    setState(() {
      _busy = true;
      _impacted = false;
      _landed = false;
    });
    AppSounds.play(AppSound.bizzBump);
    comer
      ..mood = BizzMood.idle
      ..flying = true
      ..look = const Offset(1, 0.3);
    // Yerdeki arı geleni fark eder.
    leaver.look = const Offset(-1, -0.4);
    await _anim.forward(from: 0);
    if (!mounted) return;
    leaver
      ..mood = BizzMood.idle
      ..look = null
      ..flying = false;
    setState(() {
      _activeIndex = 1 - _activeIndex;
      _busy = false;
    });
  }

  void _onFrame() {
    final t = _anim.value;
    final leaver = _active;
    final comer = _incoming;
    if (!_impacted && t >= BizzSwap.impactAt) {
      _impacted = true;
      HapticFeedback.heavyImpact();
      leaver
        ..mood = BizzMood.sad
        ..flying = true
        ..shake();
      comer.look = null;
    }
    if (!_landed && t >= 0.62) {
      _landed = true;
      comer.flying = false;
      _smile(comer);
    }
    setState(() {});
  }

  void _smile(BizzController bee) {
    bee
      ..mood = BizzMood.happy
      ..celebrate();
    _calm?.cancel();
    _calm = Timer(const Duration(milliseconds: 2400), () {
      if (mounted && bee.mood == BizzMood.happy) bee.mood = BizzMood.idle;
    });
  }

  double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final t = _anim.value;
    const impact = BizzSwap.impactAt;

    // İki arı da hep aynı ağaç yapısıyla (anahtarlı) çizilir: rol
    // değişince arının animasyon durumu korunur, yerine konan arı sıçramaz.
    Widget bee(
      int index, {
      Offset at = Offset.zero,
      double turn = 0,
      double scale = 1,
      double opacity = 1,
    }) => Transform.translate(
      key: ValueKey('bizz-$index'),
      offset: at,
      child: Transform.rotate(
        angle: turn,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Bizz(size: s, controller: _bees[index], interactive: false),
          ),
        ),
      ),
    );

    if (!_busy) {
      return SizedBox.square(
        dimension: s,
        child: Stack(clipBehavior: Clip.none, children: [bee(_activeIndex)]),
      );
    }

    // Gelen arı: sol üstten dalış, çarpma, hafif geri sekme, yerine konma.
    final contact = Offset(-s * 0.42, -s * 0.04);
    final start = Offset(-s * 2.8, -s * 1.15);
    late Offset comerAt;
    late double comerTurn;
    if (t < impact) {
      final p = Curves.easeIn.transform(_seg(t, 0, impact));
      comerAt = Offset.lerp(start, contact, p)!;
      // Yay çizerek: ortada biraz yukarıda.
      comerAt += Offset(0, -math.sin(p * math.pi) * s * 0.35);
      comerTurn = 0.45 * p;
    } else {
      final p = _seg(t, impact, 0.62);
      final settle = Curves.easeOutBack.transform(p);
      final bounce = Offset(
        -s * 0.18 * math.sin(math.min(1, p * 3) * math.pi),
        0,
      );
      comerAt = Offset.lerp(contact, Offset.zero, settle)! + bounce * (1 - p);
      comerTurn = 0.45 * (1 - Curves.easeOut.transform(p));
    }

    // Yerdeki arı: çarpılınca sağ üste dönerek savrulur ve küçülerek kaybolur.
    final hit = _seg(t, impact, 0.86);
    final fly = Curves.easeOutCubic.transform(hit);
    final leaverAt = Offset(
      s * 1.9 * fly,
      -s * 1.5 * fly - s * 0.25 * math.sin(fly * math.pi),
    );
    final leaverTurn = fly * math.pi * 2.4;
    final leaverScale = 1 - 0.45 * fly;
    final leaverOpacity = 1 - _seg(t, 0.62, 0.86);

    return SizedBox.square(
      dimension: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bee(
            _activeIndex,
            at: leaverAt,
            turn: leaverTurn,
            scale: leaverScale,
            opacity: leaverOpacity,
          ),
          bee(1 - _activeIndex, at: comerAt, turn: comerTurn),
          if (t >= impact && t < 0.7)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ImpactPainter(
                    progress: _seg(t, impact, 0.7),
                    center: Offset(s * 0.5 + contact.dx * 0.5, s * 0.42),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Çarpışma anı: dışa saçılan bal damlaları ve yıldızlar.
class _ImpactPainter extends CustomPainter {
  _ImpactPainter({required this.progress, required this.center});

  final double progress;
  final Offset center;

  static const _honey = Color(0xFFFFB300);
  static const _spark = Colors.white;
  static const _ink = Color(0xFF2B2350);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Curves.easeOut.transform(progress);
    final fade = 1 - progress;
    final r = size.width * (0.12 + 0.55 * p);
    for (var i = 0; i < 9; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 9 + 0.2;
      final at = center + Offset(math.cos(a), math.sin(a)) * r;
      if (i.isEven) {
        // Yıldız: açık gökyüzünde de seçilsin diye bal rengi, beyaz içli.
        final r = size.width * 0.085 * (1 - 0.4 * p);
        _star(canvas, at, r, _honey, fade);
        _star(canvas, at, r * 0.55, _spark, fade);
      } else {
        canvas.drawCircle(
          at,
          size.width * 0.035 * (1 - 0.5 * p),
          Paint()..color = _honey.withValues(alpha: fade),
        );
        canvas.drawCircle(
          at,
          size.width * 0.035 * (1 - 0.5 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = _ink.withValues(alpha: 0.35 * fade),
        );
      }
    }
    // Merkezde kısa bir parlama.
    canvas.drawCircle(
      center,
      size.width * 0.18 * (1 - p),
      Paint()..color = _spark.withValues(alpha: 0.8 * fade),
    );
  }

  void _star(Canvas canvas, Offset c, double r, Color color, double alpha) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.4;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(_ImpactPainter old) => old.progress != progress;
}
