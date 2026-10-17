import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/sound/app_sounds.dart';
import '../../../shared/motion.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/effects.dart';
import '../data/week_recap.dart';

/// Hikayeyi tam ekran açar (alt menünün de üstünde).
Future<void> openRecapStory(
  BuildContext context, {
  required WeekRecap recap,
  required String firstName,
}) {
  HapticFeedback.mediumImpact();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) =>
          RecapStoryScreen(recap: recap, firstName: firstName),
      transitionsBuilder: (_, anim, _, child) {
        final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(a),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Bir hikaye sayfasının arka plan renkleri.
typedef _Palette = List<Color>;

const _night = [Color(0xFF1B1446), Color(0xFF3B2A8F), Color(0xFF7B4FD0)];
const _honey = [Color(0xFFFF8A00), Color(0xFFFFB300), Color(0xFFFFD84D)];
const _mint = [Color(0xFF0B6E69), Color(0xFF1FB5A6), Color(0xFF7BE3C9)];
const _berry = [Color(0xFF6A1B4D), Color(0xFFC2185B), Color(0xFFFF6F91)];
const _ocean = [Color(0xFF0D2A6B), Color(0xFF1E5BD8), Color(0xFF59B7FF)];
const _sunset = [Color(0xFF3A0F5C), Color(0xFFB0306A), Color(0xFFFF9C5B)];
const _gold = [Color(0xFF2A1B00), Color(0xFF8A5A00), Color(0xFFFFC233)];

class _Page {
  const _Page(this.palette, this.builder, {this.onShow});
  final _Palette palette;
  final Widget Function(BuildContext context) builder;
  final VoidCallback? onShow;
}

/// "Haftanın Bal Raporu": Instagram hikayesi gibi kendiliğinden ilerleyen
/// sayfalar. Sağa dokun: sonraki, sola: önceki, basılı tut: durdur.
class RecapStoryScreen extends StatefulWidget {
  const RecapStoryScreen({
    super.key,
    required this.recap,
    required this.firstName,
  });

  final WeekRecap recap;
  final String firstName;

  /// Bir sayfanın ekranda kalma süresi.
  static const pageDuration = Duration(milliseconds: 5600);

  @override
  State<RecapStoryScreen> createState() => _RecapStoryScreenState();
}

class _RecapStoryScreenState extends State<RecapStoryScreen>
    with SingleTickerProviderStateMixin {
  late final _timer = AnimationController(
    vsync: this,
    duration: RecapStoryScreen.pageDuration,
  );

  final _shareKey = GlobalKey();
  late final List<_Page> _pages = _buildPages();
  int _index = 0;
  bool _sharing = false;

  WeekRecap get r => widget.recap;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Hareketi azalt" açıksa sayfalar kendiliğinden geçmez.
    if (Motion.of(context) && !_timer.isAnimating && _index == 0) {
      _run(_timer.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  /// Sayfa süresi gerçekten dolunca sonrakine geç. (Durum dinleyicisi
  /// kullanılmaz: değeri elle 1 yapmak da "tamamlandı" sayılıp sayfa
  /// atlatıyordu; yarıda kesilen süre ise hiç tamamlanmaz.)
  void _run(TickerFuture f) {
    final page = _index;
    f.then((_) {
      if (mounted && _index == page) _go(page + 1);
    });
  }

  void _go(int i) {
    if (i < 0) i = 0;
    if (i >= _pages.length) {
      // Son sayfada durur (paylaş / kapat).
      _timer.stop();
      return;
    }
    if (i != _index) HapticFeedback.selectionClick();
    setState(() => _index = i);
    _pages[i].onShow?.call();
    if (Motion.of(context) && i < _pages.length - 1) {
      _run(_timer.forward(from: 0));
    } else {
      _timer.value = 1;
      _timer.stop();
    }
  }

  // --- Sayfalar -------------------------------------------------------------

  List<_Page> _buildPages() {
    if (r.isEmpty) {
      return [_Page(_night, (c) => _EmptyPage(name: widget.firstName))];
    }
    final subject = r.topSubjectCode == null
        ? null
        : _subjectName(r.topSubjectCode!);
    return [
      _Page(_night, (c) => _IntroPage(recap: r, name: widget.firstName)),
      if (r.questions > 0) _Page(_honey, (c) => _QuestionsPage(recap: r)),
      if (r.studyMinutes > 0) _Page(_mint, (c) => _FocusPage(recap: r)),
      if (r.questions > 0) _Page(_ocean, (c) => _WeekPage(recap: r)),
      if (subject != null)
        _Page(_berry, (c) => _SubjectPage(recap: r, subject: subject)),
      if (r.exams > 0) _Page(_sunset, (c) => _ExamPage(recap: r)),
      _Page(
        _gold,
        (c) => _PersonaPage(persona: r.persona),
        onShow: () {
          HapticFeedback.heavyImpact();
          AppSounds.play(AppSound.bizzTap);
        },
      ),
      _Page(
        _night,
        (c) => _SummaryPage(
          recap: r,
          name: widget.firstName,
          subject: subject,
          shareKey: _shareKey,
          sharing: _sharing,
          onShare: _share,
          onReplay: () => _go(0),
          onClose: () => Navigator.of(context).maybePop(),
        ),
        onShow: () => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) celebrate(context);
        }),
      ),
    ];
  }

  Future<void> _share() async {
    final boundary =
        _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'bal-raporu.png',
            ),
          ],
          text: tr('Bu haftaki Bal Raporum 🐝 #Mentoria'),
        ),
      );
    } catch (e) {
      debugPrint('Paylaşılamadı: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // --- Görünüm --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    final last = _index == _pages.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _Backdrop(palette: page.palette),
            // Sayfa içeriği
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 480),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.86, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: page.builder(context),
                  ),
                ),
              ),
            ),
            // Dokunma alanları (son sayfada düğmeler çalışsın diye yok)
            if (!last)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _TapZone(
                        label: tr('Önceki'),
                        onTap: () => _go(_index - 1),
                        onHold: _timer.stop,
                        onRelease: _resume,
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: _TapZone(
                        label: tr('Sonraki'),
                        onTap: () => _go(_index + 1),
                        onHold: _timer.stop,
                        onRelease: _resume,
                      ),
                    ),
                  ],
                ),
              ),
            // İlerleme çubukları ve kapat (en üstte)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _timer,
                          builder: (_, _) => Row(
                            children: [
                              for (var i = 0; i < _pages.length; i++)
                                Expanded(
                                  child: _Segment(
                                    value: i < _index
                                        ? 1
                                        : i == _index
                                        ? _timer.value
                                        : 0,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Kapat'),
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resume() {
    if (Motion.of(context) && _index < _pages.length - 1) {
      _run(_timer.forward());
    }
  }
}

String? _subjectName(String code) {
  try {
    return subjectByCode(code).name;
  } catch (_) {
    return null;
  }
}

class _TapZone extends StatelessWidget {
  const _TapZone({
    required this.label,
    required this.onTap,
    required this.onHold,
    required this.onRelease,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onHold;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onLongPressStart: (_) => onHold(),
      onLongPressEnd: (_) => onRelease(),
    ),
  );
}

class _Segment extends StatelessWidget {
  const _Segment({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    height: 3.5,
    margin: const EdgeInsets.symmetric(horizontal: 2.5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(2),
    ),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: value.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [BoxShadow(color: Colors.white54, blurRadius: 4)],
        ),
      ),
    ),
  );
}

// --- Arka plan: renk geçişli gradyan + süzülen petekler ----------------------

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.palette});
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(palette),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (_, _, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette,
          ),
        ),
        child: LoopBuilder(
          period: const Duration(seconds: 16),
          builder: (_, t, _) => CustomPaint(painter: _FloatingHexes(t)),
        ),
      ),
    );
  }
}

class _FloatingHexes extends CustomPainter {
  _FloatingHexes(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final x = rnd.nextDouble() * size.width;
      final speed = 0.4 + rnd.nextDouble() * 0.8;
      final y = size.height * (1.1 - ((rnd.nextDouble() + t * speed) % 1.2));
      final r = 10 + rnd.nextDouble() * 34;
      final a = 0.05 + rnd.nextDouble() * 0.1;
      final path = Path();
      for (var k = 0; k < 6; k++) {
        final ang =
            math.pi / 6 +
            k * math.pi / 3 +
            t * math.pi * 2 * (i.isEven ? 0.2 : -0.2);
        final p = Offset(x + r * math.cos(ang), y + r * math.sin(ang));
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: a)
          ..style = i % 3 == 0 ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_FloatingHexes old) => old.t != t;
}

// --- Ortak parçalar -----------------------------------------------------------

/// Gradyanlı dev sayı.
class _BigNumber extends StatelessWidget {
  const _BigNumber({required this.value, this.format, this.size = 96});
  final double value;
  final String Function(double)? format;
  final double size;

  @override
  Widget build(BuildContext context) {
    final f =
        format ??
        (v) => NumberFormat.decimalPattern(localeTag).format(v.round());
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [Colors.white, Color(0xFFFFF4C2)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect),
      child: CountUp(
        value: value,
        format: f,
        duration: const Duration(milliseconds: 1400),
        style: TextStyle(
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -2,
          shadows: const [
            Shadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
      ),
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        fontSize: 12,
      ),
    ),
  );
}

TextStyle _title(BuildContext context) => const TextStyle(
  color: Colors.white,
  fontSize: 26,
  fontWeight: FontWeight.w900,
  height: 1.2,
);

TextStyle _body(BuildContext context) => TextStyle(
  color: Colors.white.withValues(alpha: 0.88),
  fontSize: 16,
  height: 1.45,
  fontWeight: FontWeight.w600,
);

/// Öğeleri sırayla (gecikmeli) içeri kaydırır.
class _Stagger extends StatelessWidget {
  const _Stagger({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < children.length; i++)
        FadeSlideIn(
          delay: Duration(milliseconds: 120 + i * 160),
          child: children[i],
        ),
    ],
  );
}

// --- Sayfalar ----------------------------------------------------------------

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.recap, required this.name});
  final WeekRecap recap;
  final String name;

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('d MMMM', localeTag);
    return _Stagger(
      children: [
        const Bizz(size: 170, mood: BizzMood.happy, interactive: false),
        const SizedBox(height: 18),
        _Kicker('${f.format(recap.start)} – ${f.format(recap.end)}'),
        const SizedBox(height: 18),
        Text(
          tr('{name}, haftanın Bal Raporu hazır!', {'name': name}),
          textAlign: TextAlign.center,
          style: _title(context).copyWith(fontSize: 32),
        ),
        const SizedBox(height: 12),
        Text(
          tr('Bu hafta kovanda neler yaptığına bir bakalım. 🐝'),
          textAlign: TextAlign.center,
          style: _body(context),
        ),
      ],
    );
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => _Stagger(
    children: [
      const Bizz(size: 160, mood: BizzMood.sad, interactive: false),
      const SizedBox(height: 22),
      Text(
        tr('Bu hafta kovan biraz sessizdi, {name}.', {'name': name}),
        textAlign: TextAlign.center,
        style: _title(context),
      ),
      const SizedBox(height: 12),
      Text(
        tr(
          'Bir soru kaydı ya da bir pomodoro ile başla; gelecek hafta raporun parıl parıl olsun! ✨',
        ),
        textAlign: TextAlign.center,
        style: _body(context),
      ),
    ],
  );
}

class _QuestionsPage extends StatelessWidget {
  const _QuestionsPage({required this.recap});
  final WeekRecap recap;

  @override
  Widget build(BuildContext context) {
    final change = recap.changePercent;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: LoopBuilder(
              period: const Duration(seconds: 3),
              builder: (_, t, _) => CustomPaint(
                painter: _HoneyRain(
                  t,
                  drops: (recap.questions / 25).clamp(8, 40).round(),
                ),
              ),
            ),
          ),
        ),
        _Stagger(
          children: [
            _Kicker(tr('Soru avı')),
            const SizedBox(height: 24),
            _BigNumber(value: recap.questions.toDouble(), size: 104),
            const SizedBox(height: 6),
            Text(tr('soru çözdün'), style: _title(context)),
            const SizedBox(height: 22),
            if (change != null)
              _Chip(
                icon: change >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                text: change >= 0
                    ? tr('Geçen haftadan %{n} fazla!', {'n': change})
                    : tr('Geçen haftadan %{n} az, toparlanıyoruz!', {
                        'n': -change,
                      }),
              ),
            const SizedBox(height: 12),
            _Chip(
              icon: Icons.emoji_events_rounded,
              text: tr('{n} doğru = {jars} kavanoz bal 🍯', {
                'n': recap.correct,
                'jars': recap.honeyJars.toStringAsFixed(1).replaceAll('.0', ''),
              }),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HoneyRain extends CustomPainter {
  _HoneyRain(this.t, {required this.drops});
  final double t;
  final int drops;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    for (var i = 0; i < drops; i++) {
      final x = rnd.nextDouble() * size.width;
      final phase = rnd.nextDouble();
      final y = ((t + phase) % 1) * (size.height + 60) - 30;
      final s = 5 + rnd.nextDouble() * 7;
      final path = Path()
        ..moveTo(x, y - s * 1.6)
        ..quadraticBezierTo(x + s, y, x, y + s)
        ..quadraticBezierTo(x - s, y, x, y - s * 1.6);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(
            0xFFFFF0A8,
          ).withValues(alpha: 0.35 + rnd.nextDouble() * 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_HoneyRain old) => old.t != t;
}

class _FocusPage extends StatelessWidget {
  const _FocusPage({required this.recap});
  final WeekRecap recap;

  @override
  Widget build(BuildContext context) {
    final h = recap.studyMinutes ~/ 60;
    final m = recap.studyMinutes % 60;
    // Halka: haftalık 20 saati tam tur sayar.
    final fill = (recap.studyMinutes / (20 * 60)).clamp(0.05, 1.0);
    return _Stagger(
      children: [
        _Kicker(tr('Odak zamanı')),
        const SizedBox(height: 26),
        SizedBox.square(
          dimension: 230,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fill),
            duration: Duration(milliseconds: Motion.of(context) ? 1600 : 0),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CustomPaint(
              painter: _Ring(v, const Color(0xFFFFF4C2)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BigNumber(value: h.toDouble(), size: 72),
                    Text(
                      tr('saat {m} dk', {'m': m}),
                      style: _title(context).copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(tr('odaklandın'), style: _title(context)),
        const SizedBox(height: 14),
        _Chip(
          icon: Icons.timer_rounded,
          text: tr('{n} pomodoro · {s} oturum', {
            'n': recap.pomodoros,
            's': recap.sessions,
          }),
        ),
      ],
    );
  }
}

class _Ring extends CustomPainter {
  _Ring(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [Colors.white, color, Colors.white],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.value != value;
}

class _WeekPage extends StatelessWidget {
  const _WeekPage({required this.recap});
  final WeekRecap recap;

  @override
  Widget build(BuildContext context) {
    final best = recap.bestDayIndex;
    final max = recap.dailyQuestions.fold<int>(1, math.max);
    final day = DateFormat('EEEEE', localeTag);
    final bestName = best == null
        ? ''
        : DateFormat(
            'EEEE',
            localeTag,
          ).format(recap.start.add(Duration(days: best)));
    return _Stagger(
      children: [
        _Kicker(tr('Haftanın ritmi')),
        const SizedBox(height: 22),
        Text(
          tr('{n} günün {d} günü kovandaydın', {'n': 7, 'd': recap.activeDays}),
          textAlign: TextAlign.center,
          style: _title(context),
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 230,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _DayColumn(
                    index: i,
                    label: day.format(recap.start.add(Duration(days: i))),
                    value: recap.dailyQuestions[i],
                    ratio: recap.dailyQuestions[i] / max,
                    best: i == best,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (best != null)
          _Chip(
            icon: Icons.workspace_premium_rounded,
            text: tr('En parlak günün: {day} · {n} soru', {
              'day': bestName,
              'n': recap.dailyQuestions[best],
            }),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.index,
    required this.label,
    required this.value,
    required this.ratio,
    required this.best,
  });

  final int index;
  final String label;
  final int value;
  final double ratio;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final animate = Motion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: animate ? 700 + index * 120 : 0),
      curve: Curves.easeOutBack,
      builder: (_, p, _) {
        final h = 18 + 120 * ratio * p;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (best)
              Text('👑', style: TextStyle(fontSize: 22 * p.clamp(0, 1))),
            if (value > 0)
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 4),
            Container(
              width: 30,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: value == 0
                      ? [Colors.white24, Colors.white10]
                      : best
                      ? const [Color(0xFFFFB300), Color(0xFFFFF0A8)]
                      : const [Color(0xFFFFFFFF), Color(0xFFBFE6FF)],
                ),
                boxShadow: best
                    ? const [
                        BoxShadow(
                          color: Color(0xAAFFC233),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SubjectPage extends StatelessWidget {
  const _SubjectPage({required this.recap, required this.subject});
  final WeekRecap recap;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final acc = recap.topSubjectAccuracy;
    return _Stagger(
      children: [
        _Kicker(tr('Favori dersin')),
        const SizedBox(height: 24),
        Text(
          subject,
          textAlign: TextAlign.center,
          style: _title(context).copyWith(fontSize: 46, letterSpacing: -1),
        ),
        const SizedBox(height: 8),
        Text(
          tr('{n} soruyla haftanın yıldızı', {'n': recap.topSubjectQuestions}),
          style: _body(context),
        ),
        const SizedBox(height: 28),
        SizedBox.square(
          dimension: 180,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: acc),
            duration: Duration(milliseconds: Motion.of(context) ? 1500 : 0),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CustomPaint(
              painter: _Ring(v, const Color(0xFFFFC2D6)),
              child: Center(
                child: Text(
                  '%${(v * 100).round()}',
                  style: _title(context).copyWith(fontSize: 40),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(tr('isabet'), style: _title(context).copyWith(fontSize: 20)),
      ],
    );
  }
}

class _ExamPage extends StatelessWidget {
  const _ExamPage({required this.recap});
  final WeekRecap recap;

  @override
  Widget build(BuildContext context) => _Stagger(
    children: [
      _Kicker(tr('Deneme cephesi')),
      const SizedBox(height: 24),
      const Text('📝', style: TextStyle(fontSize: 72)),
      const SizedBox(height: 12),
      Text(
        tr('{n} denemeye girdin', {'n': recap.exams}),
        style: _title(context),
      ),
      const SizedBox(height: 18),
      if (recap.bestExamNet != null) ...[
        _BigNumber(
          value: recap.bestExamNet!,
          size: 88,
          format: (v) => v.toStringAsFixed(1).replaceAll('.0', ''),
        ),
        Text(tr('en iyi netin'), style: _title(context).copyWith(fontSize: 20)),
      ],
    ],
  );
}

class _PersonaPage extends StatelessWidget {
  const _PersonaPage({required this.persona});
  final BeePersona persona;

  @override
  Widget build(BuildContext context) {
    final animate = Motion.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Kicker(tr('Bu haftaki arı tipin')),
        const SizedBox(height: 18),
        SizedBox.square(
          dimension: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dönen ışık huzmeleri
              Positioned.fill(
                child: LoopBuilder(
                  period: const Duration(seconds: 12),
                  builder: (_, t, _) => CustomPaint(painter: _Rays(t)),
                ),
              ),
              // Rozet: yan dönerek gelir
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: animate ? 1300 : 0),
                curve: Curves.elasticOut,
                builder: (_, p, child) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateY((1 - p) * math.pi * 1.5)
                    ..scaleByDouble(0.4 + 0.6 * p, 0.4 + 0.6 * p, 1, 1),
                  child: child,
                ),
                child: Container(
                  width: 168,
                  height: 168,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFFFF4C2),
                        Color(0xFFFFC233),
                        Color(0xFFE08A00),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xCCFFC233),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    persona.emoji,
                    style: const TextStyle(fontSize: 84),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          delay: const Duration(milliseconds: 700),
          child: Text(
            persona.title,
            textAlign: TextAlign.center,
            style: _title(context).copyWith(fontSize: 34),
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          delay: const Duration(milliseconds: 900),
          child: Text(
            persona.description,
            textAlign: TextAlign.center,
            style: _body(context),
          ),
        ),
      ],
    );
  }
}

class _Rays extends CustomPainter {
  _Rays(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.7;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * math.pi * 2);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(r * math.cos(a - 0.11), r * math.sin(a - 0.11))
        ..lineTo(r * math.cos(a + 0.11), r * math.sin(a + 0.11))
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.5),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Rays old) => old.t != t;
}

class _SummaryPage extends StatelessWidget {
  const _SummaryPage({
    required this.recap,
    required this.name,
    required this.subject,
    required this.shareKey,
    required this.sharing,
    required this.onShare,
    required this.onReplay,
    required this.onClose,
  });

  final WeekRecap recap;
  final String name;
  final String? subject;
  final GlobalKey shareKey;
  final bool sharing;
  final VoidCallback onShare;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: FittedBox(
              child: RepaintBoundary(
                key: shareKey,
                child: RecapShareCard(
                  recap: recap,
                  name: name,
                  subject: subject,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReplay,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.replay_rounded),
                label: Text(tr('Yeniden izle')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: sharing ? null : onShare,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC233),
                  foregroundColor: const Color(0xFF2B2350),
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(tr('Paylaş')),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onClose,
          child: Text(
            tr('Kapat'),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

/// Paylaşılan özet kartı (hikaye boyutunda resim olarak dışa aktarılır).
class RecapShareCard extends StatelessWidget {
  const RecapShareCard({
    super.key,
    required this.recap,
    required this.name,
    this.subject,
  });

  final WeekRecap recap;
  final String name;
  final String? subject;

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('d MMM', localeTag);
    Widget stat(String value, String label, String emoji) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    final hours = recap.studyMinutes / 60;
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2A8F), Color(0xFF7B4FD0), Color(0xFFFF8A00)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: HoneycombPainter(color: Colors.white, opacity: 0.1),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Bizz(
                    size: 64,
                    mood: BizzMood.happy,
                    interactive: false,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Bal Raporu'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$name · ${f.format(recap.start)} – ${f.format(recap.end)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  stat('${recap.questions}', tr('soru'), '⚡'),
                  stat(
                    hours >= 1
                        ? hours.toStringAsFixed(1).replaceAll('.0', '')
                        : '${recap.studyMinutes}',
                    hours >= 1 ? tr('saat odak') : tr('dk odak'),
                    '⏱️',
                  ),
                ],
              ),
              Row(
                children: [
                  stat('${recap.activeDays}/7', tr('aktif gün'), '🔥'),
                  stat(
                    '%${(recap.accuracy * 100).round()}',
                    tr('isabet'),
                    '🎯',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC233),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Text(
                      recap.persona.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recap.persona.title,
                            style: const TextStyle(
                              color: Color(0xFF2B2350),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (subject != null)
                            Text(
                              tr('Favori ders: {s}', {'s': subject!}),
                              style: const TextStyle(
                                color: Color(0xFF2B2350),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Mentoria 🐝',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
