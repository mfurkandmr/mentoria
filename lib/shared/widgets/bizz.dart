import '../../core/sound/app_sounds.dart';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../motion.dart';

/// Bızz'ın duygusu.
enum BizzMood {
  /// Normal, hafif gülümseyen.
  idle,

  /// Kocaman gülümseme, kızaran yanaklar.
  happy,

  /// Üzgün (ör. hatalı giriş).
  sad,

  /// Gözleri kapalı (şifre yazılırken bakmıyor).
  eyesClosed,

  /// Tek gözle gizlice bakıyor (şifre gösterilince).
  peek,
}

/// Bızz'ı dışarıdan yönlendirmek için (giriş ekranı vb.).
class BizzController extends ChangeNotifier {
  BizzMood _mood = BizzMood.idle;
  Offset? _look;
  bool _flying = false;
  int _celebrate = 0;
  int _shake = 0;

  BizzMood get mood => _mood;

  /// Göz bebeklerinin bakacağı yön (-1..1). null: kendi kendine bakınır.
  Offset? get look => _look;

  set mood(BizzMood m) {
    if (m == _mood) return;
    _mood = m;
    notifyListeners();
  }

  set look(Offset? o) {
    _look = o;
    notifyListeners();
  }

  /// Uçarken kanatlar sürekli çırpar.
  bool get flying => _flying;
  set flying(bool v) {
    if (v == _flying) return;
    _flying = v;
    notifyListeners();
  }

  /// Zıplar, kanat çırpar, kocaman güler.
  void celebrate() {
    _celebrate++;
    notifyListeners();
  }

  /// Başını iki yana sallar (hata).
  void shake() {
    _shake++;
    notifyListeners();
  }
}

/// Canlı maskot Bızz. Kendiliğinden süzülür, göz kırpar, etrafa bakınır;
/// dokununca kıkırdar. 64 pikselden küçük boyutlarda yalnızca yüzü çizilir.
class Bizz extends StatefulWidget {
  const Bizz({
    super.key,
    this.size = 160,
    this.controller,
    this.mood,
    this.interactive = true,
    this.intro = false,
    this.headOnly,
  });

  final double size;
  final BizzController? controller;

  /// Sabit duygu (controller yerine).
  final BizzMood? mood;

  /// Dokununca tepki versin mi.
  final bool interactive;

  /// İlk görünüşte grafik çubuklarının büyüyerek gelmesi.
  final bool intro;

  /// null: boyuta göre seçilir.
  final bool? headOnly;

  @override
  State<Bizz> createState() => _BizzState();
}

class _BizzState extends State<Bizz> with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _frame = _BizzFrame();
  final _rand = math.Random();
  Duration _last = Duration.zero;
  double _t = 0;

  double _nextBlink = 1.5;
  double? _blinkStart;
  int _blinksLeft = 0;
  double _nextGlance = 2.5;
  Offset _glance = Offset.zero;
  double _happyUntil = -1;
  double _flutterUntil = -1;
  double? _hopStart;
  double? _shakeStart;
  int _seenCelebrate = 0;
  int _seenShake = 0;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onController);
    _seenCelebrate = widget.controller?._celebrate ?? 0;
    _seenShake = widget.controller?._shake ?? 0;
    _frame.intro = widget.intro ? 0 : 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = Motion.of(context);
    if (animate && !_animating) {
      _animating = true;
      (_ticker ??= createTicker(_onTick)).start();
    } else if (!animate && _animating) {
      _animating = false;
      _ticker?.stop();
      _frame.intro = 1;
    }
    if (!animate) {
      _frame
        ..intro = 1
        ..smile = _targetSmile
        ..eyes = _mood == BizzMood.eyesClosed ? 0 : 1;
    }
  }

  @override
  void didUpdateWidget(Bizz old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onController);
      widget.controller?.addListener(_onController);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onController);
    _ticker?.dispose();
    super.dispose();
  }

  BizzMood get _mood => widget.controller?.mood ?? widget.mood ?? BizzMood.idle;

  double get _targetSmile => switch (_mood) {
    BizzMood.happy => 1,
    BizzMood.sad => -1,
    _ => _t < _happyUntil ? 1 : 0.15,
  };

  void _onController() {
    final c = widget.controller!;
    if (c._celebrate != _seenCelebrate) {
      _seenCelebrate = c._celebrate;
      _celebrate();
    }
    if (c._shake != _seenShake) {
      _seenShake = c._shake;
      _shakeStart = _t;
    }
    if (!_animating) setState(() {});
  }

  void _celebrate() {
    _happyUntil = _t + 1.4;
    _flutterUntil = _t + 0.9;
    _hopStart = _t;
  }

  void _onTap() {
    if (!widget.interactive) return;
    HapticFeedback.lightImpact();
    AppSounds.play(AppSound.bizzTap);
    _celebrate();
  }

  double _approach(double v, double target, double dt, [double speed = 12]) =>
      v + (target - v) * (1 - math.exp(-dt * speed));

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    _t = elapsed.inMicroseconds / 1e6;
    final f = _frame;
    final mood = _mood;

    // Göz kırpma (bazen iki kez)
    if (_blinkStart == null && _t >= _nextBlink) {
      _blinkStart = _t;
      _blinksLeft = _rand.nextDouble() < 0.25 ? 1 : 0;
    }
    var blink = 1.0;
    if (_blinkStart != null) {
      final b = (_t - _blinkStart!) / 0.16;
      if (b >= 1) {
        if (_blinksLeft > 0) {
          _blinksLeft--;
          _blinkStart = _t + 0.08;
        } else {
          _blinkStart = null;
          _nextBlink = _t + 2.4 + _rand.nextDouble() * 3.2;
        }
      } else if (b > 0) {
        blink = 1 - math.sin(math.pi * b);
      }
    }
    final eyesTarget = mood == BizzMood.eyesClosed ? 0.0 : 1.0;
    f.eyes = _approach(f.eyes, eyesTarget, dt, 16);
    f.blink = blink;
    f.peek = _approach(f.peek, mood == BizzMood.peek ? 1 : 0, dt, 10);

    // Bakınma
    if (_t >= _nextGlance) {
      _glance = _rand.nextDouble() < 0.4
          ? Offset.zero
          : Offset(_rand.nextDouble() * 2 - 1, _rand.nextDouble() * 1.2 - 0.6);
      _nextGlance = _t + 1.6 + _rand.nextDouble() * 2.6;
    }
    final look = widget.controller?.look ?? _glance;
    f.lookX = _approach(f.lookX, look.dx, dt, 8);
    f.lookY = _approach(f.lookY, look.dy, dt, 8);

    // Gülümseme
    f.smile = _approach(f.smile, _targetSmile, dt, 9);
    f.squint = _approach(f.squint, _t < _happyUntil ? 1 : 0, dt, 14);

    // Süzülme, zıplama, sallanma
    var hop = 0.0;
    if (_hopStart != null) {
      final h = (_t - _hopStart!) / 0.5;
      if (h >= 1) {
        _hopStart = null;
      } else {
        hop = -math.sin(math.pi * h) * 16;
      }
    }
    var shake = 0.0;
    if (_shakeStart != null) {
      final s = (_t - _shakeStart!) / 0.55;
      if (s >= 1) {
        _shakeStart = null;
      } else {
        shake = math.sin(s * math.pi * 6) * (1 - s) * 7;
      }
    }
    f.dy = math.sin(_t * 2 * math.pi / 2.8) * 3 + hop;
    f.dx = shake;

    // Kanatlar ve antenler
    final flutter = _t < _flutterUntil || (widget.controller?.flying ?? false);
    f.wing = flutter
        ? math.sin(_t * 2 * math.pi * 9) * 0.38
        : math.sin(_t * 2 * math.pi / 1.6) * 0.07;
    f.antenna = math.sin(_t * 2 * math.pi / 2.8 + 0.7) * 0.09 + hop * -0.008;

    if (f.intro < 1) f.intro = math.min(1, f.intro + dt / 1.1);
    f.notify();
  }

  @override
  Widget build(BuildContext context) {
    final headOnly = widget.headOnly ?? widget.size < 64;
    return Semantics(
      label: 'Bızz',
      image: true,
      child: GestureDetector(
        onTap: widget.interactive ? _onTap : null,
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _BizzPainter(_frame, headOnly: headOnly)),
        ),
      ),
    );
  }
}

/// Bir karenin animasyon değerleri.
class _BizzFrame extends ChangeNotifier {
  double eyes = 1, blink = 1, peek = 0;
  double lookX = 0, lookY = 0;
  double smile = 0.15, squint = 0;
  double dx = 0, dy = 0, wing = 0, antenna = 0;
  double intro = 1;

  void notify() => notifyListeners();
}

class _BizzPainter extends CustomPainter {
  _BizzPainter(this.f, {required this.headOnly}) : super(repaint: f);

  final _BizzFrame f;
  final bool headOnly;

  static const honey = Color(0xFFFFC531);
  static const honeyLight = Color(0xFFFFE07A);
  static const night = Color(0xFF2B2350);
  static const wingFill = Color(0xFFD8ECFF);
  static const wingLine = Color(0xFF9CCBFF);
  static const grape = Color(0xFF6C5CE7);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200);

    if (headOnly) {
      canvas.translate(f.dx, f.dy * 0.6);
      _head(canvas);
    } else {
      // Gölge (zıplayınca küçülür)
      final lift = (-f.dy).clamp(0.0, 20.0) / 20;
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(100, 193),
          width: 128 * (1 - lift * 0.3),
          height: 10,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.08 * (1 - lift * 0.5)),
      );
      canvas.translate(f.dx, f.dy);
      // Kafa, tam maskottaki gövde konumuna ölçeklenir.
      canvas.save();
      canvas.translate(20, 2.4);
      canvas.scale(0.8);
      _head(canvas);
      canvas.restore();
      _board(canvas);
    }
    canvas.restore();
  }

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = night;

  void _rotated(Canvas c, Offset pivot, double angle, void Function() draw) {
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(angle);
    c.translate(-pivot.dx, -pivot.dy);
    draw();
    c.restore();
  }

  void _head(Canvas c) {
    // Antenler
    for (final s in [-1.0, 1.0]) {
      final base = Offset(100 + s * 14, 62);
      _rotated(c, base, f.antenna * s, () {
        final p = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(100 + s * 24, 38, 100 + s * 36, 28);
        c.drawPath(p, _stroke..strokeWidth = 6);
        c.drawCircle(Offset(100 + s * 38, 26), 9, Paint()..color = night);
      });
    }

    // Kanatlar (gövdenin arkasında)
    for (final s in [-1.0, 1.0]) {
      final pivot = Offset(100 + s * 24, 96);
      _rotated(c, pivot, -s * f.wing, () {
        c.save();
        c.translate(100 + s * 46, 74);
        c.rotate(s * 35 * math.pi / 180);
        final r = Rect.fromCenter(center: Offset.zero, width: 40, height: 56);
        c.drawOval(r, Paint()..color = wingFill);
        c.drawOval(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = wingLine,
        );
        c.restore();
      });
    }

    // Gövde
    final body = Rect.fromCenter(
      center: const Offset(100, 112),
      width: 124,
      height: 116,
    );
    c.drawOval(body, Paint()..color = honey);
    c.save();
    c.clipPath(Path()..addOval(body));
    c.save();
    c.translate(82, 80);
    c.rotate(-0.2);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 46, height: 20),
      Paint()..color = honeyLight.withValues(alpha: 0.7),
    );
    c.restore();
    final stripe = Paint()..color = night;
    c.drawRect(const Rect.fromLTWH(30, 136, 140, 13), stripe);
    c.drawRect(const Rect.fromLTWH(30, 160, 140, 13), stripe);
    c.restore();

    // Yanaklar
    final happy = f.smile.clamp(0.0, 1.0);
    for (final x in [60.0, 140.0]) {
      c.drawCircle(
        Offset(x, 118),
        6 + 2 * happy,
        Paint()
          ..color = const Color(
            0xFFFF8A65,
          ).withValues(alpha: 0.4 + 0.4 * happy),
      );
    }

    // Gözler
    for (final s in [-1.0, 1.0]) {
      final center = Offset(100 + s * 21, 100);
      var open = f.eyes * f.blink;
      // Gizlice bakma: sol göz kapalı, sağ göz açık.
      if (s < 0) open *= 1 - f.peek;
      if (s > 0) open = math.max(open, f.peek);
      _eye(c, center, open);
    }

    // Kaşlar (üzgünken)
    final sad = (-f.smile).clamp(0.0, 1.0);
    if (sad > 0.05) {
      for (final s in [-1.0, 1.0]) {
        c.drawLine(
          Offset(100 + s * 12, 78 - 4 * sad),
          Offset(100 + s * 30, 82 + 2 * sad),
          _stroke
            ..strokeWidth = 4
            ..color = night.withValues(alpha: sad),
        );
      }
    }

    _mouth(c);
  }

  void _eye(Canvas c, Offset center, double open) {
    // Kıkırdarken "^" şeklinde mutlu gözler
    if (f.squint > 0.5) {
      final p = Path()
        ..moveTo(center.dx - 10, center.dy + 4)
        ..quadraticBezierTo(
          center.dx,
          center.dy - 9,
          center.dx + 10,
          center.dy + 4,
        );
      c.drawPath(p, _stroke..strokeWidth = 5);
      return;
    }
    if (open < 0.22) {
      final p = Path()
        ..moveTo(center.dx - 11, center.dy + 1)
        ..quadraticBezierTo(
          center.dx,
          center.dy + 7,
          center.dx + 11,
          center.dy + 1,
        );
      c.drawPath(p, _stroke..strokeWidth = 4.5);
      return;
    }
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(1, open);
    c.drawCircle(Offset.zero, 16, Paint()..color = Colors.white);
    final pupil = Offset(3 + f.lookX * 4.5, 2 + f.lookY * 4);
    c.drawCircle(pupil, 8.5, Paint()..color = night);
    c.drawCircle(pupil + const Offset(3, -3), 3, Paint()..color = Colors.white);
    c.restore();
  }

  void _mouth(Canvas c) {
    final s = f.smile;
    if (s < 0) {
      final p = Path()
        ..moveTo(90, 124)
        ..quadraticBezierTo(100, 124 + 12 * s, 110, 124);
      c.drawPath(p, _stroke..strokeWidth = 4.5);
      return;
    }
    final big = ((s - 0.3) / 0.7).clamp(0.0, 1.0);
    if (big <= 0) {
      final depth = 6 + 6 * s;
      final p = Path()
        ..moveTo(90, 118)
        ..quadraticBezierTo(100, 118 + depth, 110, 118);
      c.drawPath(p, _stroke..strokeWidth = 4.5);
      return;
    }
    // Açık ağızla gülümseme
    final w = 22 + 10 * big;
    final depth = 10 + 10 * big;
    final left = Offset(100 - w / 2, 116);
    final right = Offset(100 + w / 2, 116);
    final mouth = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(100, 116 + depth * 2, right.dx, right.dy)
      ..quadraticBezierTo(100, 116 + depth * 0.35, left.dx, left.dy)
      ..close();
    c.drawPath(mouth, Paint()..color = night);
    c.save();
    c.clipPath(mouth);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(100, 116 + depth * 1.05),
        width: w * 0.55,
        height: depth * 0.8,
      ),
      Paint()..color = const Color(0xFFFF7A9A),
    );
    c.restore();
  }

  void _board(Canvas c) {
    // Kollar
    final arm = _stroke..strokeWidth = 7;
    c.drawPath(
      Path()
        ..moveTo(64, 104)
        ..quadraticBezierTo(70, 116, 76, 126),
      arm,
    );
    c.drawPath(
      Path()
        ..moveTo(136, 104)
        ..quadraticBezierTo(130, 116, 124, 126),
      arm,
    );

    // Pano
    final board = RRect.fromRectAndRadius(
      const Rect.fromLTWH(46, 126, 108, 64),
      const Radius.circular(12),
    );
    c.drawRRect(board, Paint()..color = Colors.white);
    c.drawRRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = night,
    );
    c.drawLine(
      const Offset(58, 178),
      const Offset(144, 178),
      _stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFE6E0F7),
    );

    // Çubuklar sırayla büyür
    const bars = [
      (60.0, 16.0, Color(0xFFFFE08A)),
      (80.0, 24.0, Color(0xFFFFD04D)),
      (100.0, 32.0, Color(0xFFFFC531)),
      (120.0, 40.0, Color(0xFFF5A300)),
    ];
    for (var i = 0; i < bars.length; i++) {
      final p = Curves.easeOutBack.transform(
        ((f.intro * 1.6 - i * 0.15)).clamp(0.0, 1.0),
      );
      final (x, h, color) = bars[i];
      final height = h * p;
      if (height <= 0) continue;
      c.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, 178 - height, 14, height),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()..color = color,
      );
    }

    // Trend çizgisi çizilerek gelir
    final line = Path()
      ..moveTo(62, 152)
      ..lineTo(86, 144)
      ..lineTo(106, 136)
      ..lineTo(132, 130);
    final progress = ((f.intro - 0.35) / 0.65).clamp(0.0, 1.0);
    final metric = line.computeMetrics().first;
    final linePaint = _stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round
      ..color = grape;
    c.drawPath(metric.extractPath(0, metric.length * progress), linePaint);
    if (progress >= 1) {
      c.drawPath(
        Path()
          ..moveTo(123, 127)
          ..lineTo(134, 129)
          ..lineTo(129, 139),
        linePaint,
      );
    }

    // Eller
    final hand = Paint()..color = night;
    c.drawCircle(const Offset(76, 126), 6, hand);
    c.drawCircle(const Offset(124, 126), 6, hand);
  }

  @override
  bool shouldRepaint(_BizzPainter old) => old.headOnly != headOnly;
}

/// "mentoria" yazı logosu.
class MentoriaWordmark extends StatelessWidget {
  const MentoriaWordmark({super.key, this.fontSize = 32, this.onDark = false});

  final double fontSize;

  /// Koyu zeminde (gökyüzü başlığı) "mento" beyaz yazılır.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
      color: onDark ? Colors.white : null,
    );
    return Text.rich(
      TextSpan(
        text: 'mento',
        style: style,
        children: const [
          TextSpan(
            text: 'ria',
            style: TextStyle(color: Color(0xFFF5A300)),
          ),
        ],
      ),
    );
  }
}
