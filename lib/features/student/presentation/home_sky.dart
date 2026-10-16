import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/sound/app_sounds.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/bizz_swap.dart';
import '../../../shared/widgets/effects.dart';
import '../data/bizz_shake.dart';

/// Açık gökyüzünde okunur koyu yazı (gökyüzü markadan bağımsız bir
/// illüstrasyondur).
const _skyInk = Color(0xFF2B2350);

/// Günün saatine göre gökyüzü.
enum DayPhase {
  morning,
  day,
  evening,
  night;

  static DayPhase of(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 11) return DayPhase.morning;
    if (h >= 11 && h < 17) return DayPhase.day;
    if (h >= 17 && h < 21) return DayPhase.evening;
    return DayPhase.night;
  }

  List<Color> get sky => switch (this) {
    DayPhase.morning => const [
      Color(0xFF8FD0FF),
      Color(0xFFFFE6A8),
      Color(0xFFFFC98A),
    ],
    DayPhase.day => const [
      Color(0xFF5BB8FF),
      Color(0xFFA9DDFF),
      Color(0xFFFFF1C2),
    ],
    DayPhase.evening => const [
      Color(0xFF34226E),
      Color(0xFF7B4FD0),
      Color(0xFFFF9C7A),
    ],
    DayPhase.night => const [
      Color(0xFF0C0A22),
      Color(0xFF1A1544),
      Color(0xFF2B2350),
    ],
  };

  /// Gökyüzü üzerindeki yazı rengi.
  Color get ink =>
      this == DayPhase.morning || this == DayPhase.day ? _skyInk : Colors.white;

  String get greeting => switch (this) {
    DayPhase.morning => tr('Günaydın'),
    DayPhase.day => tr('İyi günler'),
    DayPhase.evening => tr('İyi akşamlar'),
    DayPhase.night => tr('Merhaba gece kuşu'),
  };
}

/// Ana sayfanın üstündeki canlı gökyüzü: sabah güneşi, gündüz bulutları,
/// akşam gün batımı, gece ay ve yıldızlar. Sağda konuşan Bızz.
class SkyHeader extends StatefulWidget {
  const SkyHeader({
    super.key,
    required this.firstName,
    required this.lines,
    required this.phase,
    this.contentOpacity = 1,
    this.avatar,
    this.swapLimit,
    this.shakeSource,
    this.shakeClock,
  });

  final String firstName;

  /// Bızz'ın söyleyeceği cümleler (dokundukça sıradakine geçer).
  final List<String> lines;
  final DayPhase phase;

  /// Başlık kapanırken içerik solar.
  final double contentOpacity;

  /// Öğrencinin avatarı: gökyüzünün ortasında hafifçe süzülür.
  final Widget? avatar;

  /// Verilirse telefonu sallamak Bızz'ı değiştirir: yeni bir arı gelip
  /// çarpar, yerini alır ve güler (saatte en fazla iki kez). Öğrenci ana
  /// sayfası verir; koç / müdür panelinde yoktur.
  final BizzSwapLimit? swapLimit;

  /// Testler için ivme kaynağı (varsayılan: telefonun ivmeölçeri).
  final Stream<({double x, double y, double z})>? shakeSource;

  /// Testler için saat (varsayılan: gerçek saat).
  final DateTime Function()? shakeClock;

  @override
  State<SkyHeader> createState() => _SkyHeaderState();
}

class _SkyHeaderState extends State<SkyHeader> {
  final _bizz = BizzSwapController();
  ShakeDetector? _shake;
  int _line = 0;

  /// Sallamadan sonra Bızz'ın söylediği (dokununca normal sıraya döner).
  String? _say;

  @override
  void initState() {
    super.initState();
    if (widget.swapLimit != null) {
      _shake = ShakeDetector(
        onShake: _onShake,
        source: widget.shakeSource,
        clock: widget.shakeClock,
      );
    }
  }

  @override
  void dispose() {
    _shake?.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    AppSounds.play(AppSound.bizzTap);
    _bizz.celebrate();
    setState(() {
      if (_say != null) {
        _say = null;
      } else {
        _line = (_line + 1) % widget.lines.length;
      }
    });
  }

  Future<void> _onShake() async {
    final limit = widget.swapLimit;
    final app = WidgetsBinding.instance.lifecycleState;
    // Başlık kapalıyken, başka sekmedeyken ya da uygulama arka plandayken
    // Bızz görünmüyor: sallama sayılmaz.
    if (limit == null ||
        !mounted ||
        _bizz.busy ||
        widget.contentOpacity < 0.5 ||
        !TickerMode.valuesOf(context).enabled ||
        (app != null && app != AppLifecycleState.resumed)) {
      return;
    }
    final wait = limit.waitTime();
    if (wait != null) {
      HapticFeedback.lightImpact();
      _bizz.shakeHead();
      setState(
        () => _say = tr('Arılar dinleniyor 😴 {n} dk sonra yine salla.', {
          'n': (wait.inSeconds / 60).ceil().clamp(1, 60),
        }),
      );
      return;
    }
    limit.tryUse();
    final lines = [
      tr('Nöbet değişimi! Şimdi sıra bende 🐝'),
      tr('Pardon, çarptım! Ama enerjim tam ⚡'),
      tr('Yeni arı, yeni enerji! Hadi bir soru daha 💪'),
      tr('Vızz! Arkadaşım mola verdi, ben buradayım 😄'),
    ];
    final swapped = _bizz.swap();
    // Yeni arı yerine konarken konuşur.
    await Future.delayed(BizzSwap.duration * 0.6);
    if (!mounted) return;
    setState(() => _say = lines[math.Random().nextInt(lines.length)]);
    await swapped;
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final ink = phase.ink;
    final text = Theme.of(context).textTheme;
    final date = DateFormat('d MMMM EEEE', localeTag).format(DateTime.now());
    final line =
        _say ??
        (widget.lines.isEmpty ? '' : widget.lines[_line % widget.lines.length]);

    return Stack(
      fit: StackFit.expand,
      children: [
        LoopBuilder(
          period: const Duration(seconds: 24),
          // Başlık kapanırken güneş/ay da solar; küçük çubukta takılı kalmaz.
          builder: (_, t, _) => CustomPaint(
            painter: _SkyPainter(phase, t, bodies: widget.contentOpacity),
          ),
        ),
        if (widget.avatar != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 26,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: widget.contentOpacity < 0.5,
              child: Opacity(
                opacity: widget.contentOpacity,
                child: Align(
                  alignment: const Alignment(0.08, 0),
                  child: LoopBuilder(
                    period: const Duration(seconds: 4),
                    child: widget.avatar,
                    builder: (_, t, child) => Transform.translate(
                      offset: Offset(0, 4 * math.sin(t * 2 * math.pi)),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        // İçerik hep alta yaslı, doğal boyunda kalır; başlık kapanırken
        // sıkışmak yerine üstten kırpılıp solar.
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            maxHeight: double.infinity,
            child: Opacity(
              opacity: widget.contentOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // Dershanede kurum adı da görünür: "16 Ekim Cuma · Bal Akademi"
                            context.brand.isDefaultBrand
                                ? date
                                : '$date · ${context.brand.appName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge?.copyWith(
                              color: ink.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${phase.greeting},',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge?.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${widget.firstName}!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.headlineMedium?.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _next,
                            child: _SpeechBubble(text: line),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _next,
                      child: BizzSwap(size: 104, controller: _bizz),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Alt sayfaların ince gökyüzü üst çubuğu: ana sayfalardaki canlı gökyüzüyle
/// aynı renk ve hareket, Bızz'sız. İsteğe bağlı sekme çubuğu da gökyüzü
/// üzerinde okunur renkte çizilir.
class SkyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SkyAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.bottom,
  });

  final Widget title;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final phase = DayPhase.of(DateTime.now());
    final ink = phase.ink;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        tabBarTheme: theme.tabBarTheme.copyWith(
          labelColor: ink,
          unselectedLabelColor: ink.withValues(alpha: 0.7),
          indicatorColor: ink,
          dividerColor: Colors.transparent,
          labelStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
          unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: AppBar(
        title: title,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w900,
        ),
        backgroundColor: phase.sky.first,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: ink == Colors.white
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        actions: actions,
        bottom: bottom,
        // İnce çubukta güneş/ay çizilmez: sığmaz, köşede takılı kalır.
        flexibleSpace: LoopBuilder(
          period: const Duration(seconds: 24),
          builder: (_, t, _) =>
              CustomPaint(painter: _SkyPainter(phase, t, bodies: 0)),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: context.brand.ink,
      fontWeight: FontWeight.w700,
      height: 1.3,
    );
    return CustomPaint(
      painter: _BubblePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 22, 10),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
            child: Text(
              text,
              key: ValueKey(text),
              style: style,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sağa, Bızz'a doğru kuyruklu beyaz balon.
class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tail = 8.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width - tail, size.height),
      const Radius.circular(16),
    );
    final path = Path()
      ..addRRect(body)
      ..moveTo(size.width - tail, size.height - 22)
      ..quadraticBezierTo(
        size.width - tail + 4,
        size.height - 10,
        size.width,
        size.height - 6,
      )
      ..quadraticBezierTo(
        size.width - tail,
        size.height - 4,
        size.width - tail - 6,
        size.height,
      )
      ..close();
    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => false;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.phase, this.t, {this.bodies = 1});

  final DayPhase phase;
  final double t;

  /// Güneş ve ayın görünürlüğü (0 = hiç çizilmez).
  final double bodies;

  static final _stars = List.generate(46, (i) {
    final r = math.Random(i * 7919);
    return (
      r.nextDouble(),
      r.nextDouble() * 0.8,
      r.nextDouble(),
      r.nextDouble(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Gün batımı güneşi ve ışıltılar başlığın dışına, içeriğin üstüne
    // taşmasın.
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: phase.sky,
        ).createShader(rect),
    );

    void body(void Function() draw) {
      if (bodies <= 0) return;
      if (bodies >= 1) return draw();
      canvas.saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, bodies));
      draw();
      canvas.restore();
    }

    switch (phase) {
      case DayPhase.morning:
        body(
          () => _sun(
            canvas,
            Offset(size.width * 0.84, size.height * 0.62),
            26,
            const Color(0xFFFFB443),
          ),
        );
        _clouds(canvas, size, 0.7);
      case DayPhase.day:
        body(
          () => _sun(
            canvas,
            Offset(size.width * 0.86, size.height * 0.3),
            24,
            const Color(0xFFFFD23F),
          ),
        );
        _clouds(canvas, size, 1);
      case DayPhase.evening:
        _drawStars(canvas, size, 0.5);
        body(
          () => _sun(
            canvas,
            Offset(size.width * 0.78, size.height * 1.02),
            46,
            const Color(0xFFFF8A5B),
            rays: false,
          ),
        );
      case DayPhase.night:
        _drawStars(canvas, size, 1);
        body(
          () => _moon(canvas, Offset(size.width * 0.8, size.height * 0.3), 20),
        );
    }

    // Altta petek dokusu: başlık ile içerik arasında yumuşak geçiş.
    final honey = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = phase.ink.withValues(alpha: 0.07);
    const r = 18.0;
    final w = math.sqrt(3) * r;
    for (var col = 0; col * w < size.width + w; col++) {
      for (var row = 0; row < 2; row++) {
        final c = Offset(
          col * w + (row.isOdd ? w / 2 : 0),
          size.height - 6 - row * 1.5 * r,
        );
        canvas.drawPath(hexPath(c, r - 2), honey);
      }
    }
  }

  void _sun(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    bool rays = true,
  }) {
    canvas.drawCircle(
      c,
      r * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 3.2)),
    );
    if (rays) {
      final ray = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6 + t * 2 * math.pi;
        final pulse = 1 + 0.12 * math.sin(t * 2 * math.pi * 6 + i);
        canvas.drawLine(
          c + Offset(math.cos(a), math.sin(a)) * (r + 6),
          c + Offset(math.cos(a), math.sin(a)) * (r + 14 * pulse),
          ray,
        );
      }
    }
    canvas.drawCircle(c, r, Paint()..color = color);
    canvas.drawCircle(
      c - Offset(r * 0.3, r * 0.3),
      r * 0.45,
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  void _clouds(Canvas canvas, Size size, double alpha) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.75 * alpha);
    for (final (i, base) in [(0, 0.1), (1, 0.55), (2, 0.85)]) {
      final span = size.width + 160;
      final x = (base * span + t * span * (0.6 + i * 0.25)) % span - 80;
      final y = size.height * (0.22 + i * 0.13);
      final s = 0.8 + i * 0.15;
      for (final (dx, dy, r) in [
        (0.0, 0.0, 16.0),
        (18.0, -8.0, 20.0),
        (38.0, 0.0, 15.0),
        (20.0, 6.0, 15.0),
      ]) {
        canvas.drawCircle(Offset(x + dx * s, y + dy * s), r * s, paint);
      }
    }
  }

  void _drawStars(Canvas canvas, Size size, double alpha) {
    final paint = Paint();
    for (final (x, y, phase, big) in _stars) {
      final tw =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin((t * 14 + phase) * 2 * math.pi));
      paint.color = Colors.white.withValues(alpha: tw * alpha * 0.9);
      final c = Offset(x * size.width, y * size.height);
      if (big > 0.88) {
        // Dört köşeli parıltı.
        final r = 3.5 * tw;
        final p = Path()
          ..moveTo(c.dx, c.dy - r * 1.8)
          ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 1.8, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 1.8)
          ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 1.8, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 1.8);
        canvas.drawPath(p, paint);
      } else {
        canvas.drawCircle(c, 0.6 + big * 1.1, paint);
      }
    }
    // Ara sıra kayan yıldız.
    final s = (t * 3) % 1;
    if (alpha >= 1 && s < 0.12) {
      final k = s / 0.12;
      final start = Offset(size.width * 0.15, size.height * 0.1);
      final head = start + const Offset(160, 60) * k;
      canvas.drawLine(
        head - const Offset(40, 15),
        head,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.9 * (1 - k)),
            ],
          ).createShader(Rect.fromPoints(head - const Offset(40, 15), head)),
      );
    }
  }

  void _moon(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r * 3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3C4).withValues(alpha: 0.28),
            const Color(0xFFFFF3C4).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 3)),
    );
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(
        Rect.fromCircle(
          center: c + Offset(r * 0.55, -r * 0.3),
          radius: r * 0.9,
        ),
      ),
    );
    canvas.drawPath(moon, Paint()..color = const Color(0xFFFFF0B8));
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.t != t || old.phase != phase || old.bodies != bodies;
}
