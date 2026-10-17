import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/motion.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/effects.dart';
import '../../auth/data/auth_repository.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../data/garden.dart';

/// Hangi dönemin bahçesi gösterilsin.
enum GardenRange {
  week(7),
  month(30),
  all(null);

  const GardenRange(this.days);
  final int? days;

  String get label => switch (this) {
    week => tr('Bu hafta'),
    month => tr('Bu ay'),
    all => tr('Tümü'),
  };
}

/// Öğrencinin tüm çalışma oturumları (bahçe için; 30 günle sınırlı değil).
final allSessionsProvider = FutureProvider.family<List<StudySession>, String>(
  (ref, studentId) => ref
      .watch(trackingRepositoryProvider)
      .fetchSessions(studentId, since: DateTime(2020)),
);

/// Odak Bahçesi: her çalışma oturumu bir çiçek. Ders türü çiçeğin cinsini,
/// süre büyüklüğünü belirler; yarıda bırakılan pomodoro solar.
class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key, this.studentId});

  /// Verilmezse oturumdaki öğrenci.
  final String? studentId;

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> {
  GardenRange _range = GardenRange.all;
  final _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    final boundary =
        _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'odak-bahcem.png',
            ),
          ],
          text: tr('Odak Bahçem 🌸 #Mentoria'),
        ),
      );
    } catch (e) {
      debugPrint('Paylaşılamadı: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showFlower(GardenFlower f) {
    HapticFeedback.selectionClick();
    final s = f.session;
    String? subject;
    try {
      subject = s.subjectCode == null
          ? null
          : subjectByCode(s.subjectCode!).name;
    } catch (_) {}
    final when = DateFormat(
      'd MMMM EEEE, HH:mm',
      localeTag,
    ).format(s.startedAt);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${f.kind.flowerName} · ${subject ?? tr('Ders seçilmemiş')}\n'
            '${tr('{n} dk', {'n': (s.durationSec / 60).round()})} · $when'
            '${f.size == FlowerSize.wilted ? '\n${tr('Bu pomodoro yarıda kalmış, çiçek soldu 🥀')}' : ''}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.studentId ?? ref.watch(currentProfileProvider).value?.id;
    final sessions = id == null ? null : ref.watch(allSessionsProvider(id));
    final all = sessions?.value ?? const <StudySession>[];
    final now = DateTime.now();
    final shown = _range.days == null
        ? all
        : all
              .where((s) => now.difference(s.startedAt).inDays < _range.days!)
              .toList();
    final minutes = shown.fold<int>(0, (m, s) => m + s.durationSec) ~/ 60;
    final blooms = shown
        .where((s) => FlowerSize.of(s).index >= FlowerSize.bloom.index)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFF7FCF6B),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(tr('Odak Bahçem')),
        actions: [
          IconButton(
            tooltip: tr('Paylaş'),
            onPressed: shown.isEmpty || _sharing ? null : _share,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: tr('Çiçekler ne anlama geliyor?'),
            onPressed: () => _showLegend(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: sessions == null || sessions.isLoading && all.isEmpty
          ? const Center(child: BizzLoader())
          : RepaintBoundary(
              key: _shareKey,
              child: LayoutBuilder(
                builder: (context, c) {
                  final layout = GardenLayout.of(shown, c.maxWidth);
                  return Stack(
                    children: [
                      Positioned.fill(child: _Sky(height: c.maxHeight)),
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(
                              height:
                                  MediaQuery.paddingOf(context).top +
                                  kToolbarHeight,
                            ),
                            _Header(
                              flowers: shown.length,
                              blooms: blooms,
                              minutes: minutes,
                              range: _range,
                              onRange: (r) => setState(() => _range = r),
                            ),
                            const SizedBox(height: 8),
                            if (shown.isEmpty)
                              const _EmptyField()
                            else
                              GestureDetector(
                                onTapUp: (d) {
                                  final f = layout.hit(d.localPosition);
                                  if (f != null) _showFlower(f);
                                },
                                child: _Field(layout: layout),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  void _showLegend(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            tr('Her çalışma oturumu bahçene bir çiçek eker.'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final k in FlowerKind.values)
            ListTile(
              dense: true,
              leading: SizedBox.square(
                dimension: 36,
                child: CustomPaint(painter: _FlowerIcon(k, FlowerSize.bloom)),
              ),
              title: Text(k.flowerName),
              subtitle: Text(k.label),
            ),
          const Divider(),
          for (final s in FlowerSize.values)
            ListTile(
              dense: true,
              leading: SizedBox.square(
                dimension: 36,
                child: CustomPaint(painter: _FlowerIcon(FlowerKind.cosmos, s)),
              ),
              title: Text(s.label),
            ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.flowers,
    required this.blooms,
    required this.minutes,
    required this.range,
    required this.onRange,
  });

  final int flowers;
  final int blooms;
  final int minutes;
  final GardenRange range;
  final ValueChanged<GardenRange> onRange;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2B2350),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4B4166),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
    final hours = minutes / 60;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                stat('$flowers', tr('çiçek')),
                stat('$blooms', tr('tam açmış')),
                stat(
                  hours >= 1
                      ? hours.toStringAsFixed(1).replaceAll('.0', '')
                      : '$minutes',
                  hours >= 1 ? tr('saat odak') : tr('dk odak'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<GardenRange>(
              showSelectedIcon: false,
              segments: [
                for (final r in GardenRange.values)
                  ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {range},
              onSelectionChanged: (s) => onRange(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyField extends StatelessWidget {
  const _EmptyField();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
    child: Column(
      children: [
        const Bizz(size: 140, mood: BizzMood.happy, interactive: false),
        const SizedBox(height: 16),
        Text(
          tr('Bahçen tohumlarla dolu ama henüz filiz yok.'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1F4D1A),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('Bir pomodoro tamamla, ilk çiçeğin açsın! 🌱'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF2E5E27),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Gökyüzü ve uzak tepeler (sabit arka plan).
class _Sky extends StatelessWidget {
  const _Sky({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => LoopBuilder(
    period: const Duration(seconds: 40),
    builder: (_, t, _) => CustomPaint(painter: _SkyPainter(t)),
  );
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6EC6FF),
            Color(0xFFBDE8FF),
            Color(0xFF9FDC8C),
            Color(0xFF6CC05A),
          ],
          stops: [0, 0.22, 0.3, 1],
        ).createShader(sky),
    );
    // Güneş
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.08),
      34,
      Paint()..color = const Color(0xFFFFE680),
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.08),
      52,
      Paint()..color = const Color(0x40FFE680),
    );
    // Bulutlar
    for (var i = 0; i < 3; i++) {
      final x = ((t + i / 3) % 1) * (size.width + 160) - 80;
      final y = size.height * (0.06 + i * 0.05);
      final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(x, y), 18, p);
      canvas.drawCircle(Offset(x + 20, y - 8), 22, p);
      canvas.drawCircle(Offset(x + 44, y), 17, p);
    }
    // Uzak tepeler
    final hills = Path()..moveTo(0, size.height * 0.3);
    for (var x = 0.0; x <= size.width; x += 8) {
      hills.lineTo(
        x,
        size.height * 0.27 + math.sin(x / 60) * 10 + math.sin(x / 23) * 4,
      );
    }
    hills
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xFF86D274));
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t;
}

/// Tarla: çiçekler rüzgârda sallanır, Bızz aralarında uçar.
class _Field extends StatelessWidget {
  const _Field({required this.layout});
  final GardenLayout layout;

  @override
  Widget build(BuildContext context) {
    final animate = Motion.of(context);
    final field = SizedBox(
      width: layout.size.width,
      height: layout.size.height,
      child: animate
          ? LoopBuilder(
              period: const Duration(seconds: 4),
              builder: (_, t, _) =>
                  CustomPaint(painter: _FieldPainter(layout, t)),
            )
          : CustomPaint(painter: _FieldPainter(layout, 0)),
    );
    if (!animate || layout.flowers.isEmpty) return field;
    return Stack(
      children: [
        field,
        // Bızz çiçekten çiçeğe uçar.
        LoopBuilder(
          period: const Duration(seconds: 14),
          builder: (_, t, child) {
            final w = layout.size.width;
            final h = math.min(layout.size.height, 600.0);
            final x = (w - 60) * (0.5 + 0.45 * math.sin(t * 2 * math.pi));
            final y =
                40 + (h - 120) * (0.5 + 0.4 * math.sin(t * 4 * math.pi + 1));
            return Positioned(
              left: x,
              top: y,
              child: Transform.flip(
                flipX: math.cos(t * 2 * math.pi) < 0,
                child: child,
              ),
            );
          },
          child: const IgnorePointer(
            child: Bizz(size: 52, interactive: false, headOnly: false),
          ),
        ),
      ],
    );
  }
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.layout, this.t);
  final GardenLayout layout;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Çimen dokusu
    final rnd = math.Random(11);
    final grass = Paint()
      ..color = const Color(0xFF4FA83F).withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < (size.width * size.height / 900).clamp(80, 2500); i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + rnd.nextDouble() * 4 - 2, y - 6 - rnd.nextDouble() * 6),
        grass,
      );
    }
    for (final f in layout.flowers) {
      final sway = math.sin((t + f.phase) * 2 * math.pi) * 0.06;
      paintFlower(canvas, f.position, f.kind, f.size, sway: sway);
    }
  }

  @override
  bool shouldRepaint(_FieldPainter old) => old.t != t || old.layout != layout;
}

/// Lejant için tek çiçek simgesi.
class _FlowerIcon extends CustomPainter {
  _FlowerIcon(this.kind, this.size);
  final FlowerKind kind;
  final FlowerSize size;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.save();
    canvas.translate(s.width / 2, s.height - 2);
    canvas.scale(0.55);
    paintFlower(canvas, Offset.zero, kind, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlowerIcon old) => false;
}

/// [base] sapın toprağa değdiği nokta.
void paintFlower(
  Canvas canvas,
  Offset base,
  FlowerKind kind,
  FlowerSize size, {
  double sway = 0,
}) {
  const ink = Color(0xFF2B2350);
  final scale = switch (size) {
    FlowerSize.wilted => 0.85,
    FlowerSize.sprout => 0.6,
    FlowerSize.bud => 0.8,
    FlowerSize.bloom => 1.0,
    FlowerSize.grand => 1.3,
  };
  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.scale(scale);
  canvas.rotate(sway);

  // Gölge
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0, 2), width: 26, height: 7),
    Paint()..color = Colors.black.withValues(alpha: 0.15),
  );

  final stemColor = size == FlowerSize.wilted
      ? const Color(0xFF8A8F3C)
      : const Color(0xFF2F8F3A);
  final stem = Paint()
    ..color = stemColor
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final leaf = Paint()..color = stemColor;

  if (size == FlowerSize.sprout) {
    canvas.drawLine(Offset.zero, const Offset(0, -14), stem);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-6, -14), width: 13, height: 7),
      leaf,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(6, -16), width: 13, height: 7),
      leaf,
    );
    canvas.restore();
    return;
  }

  final wilted = size == FlowerSize.wilted;
  // Sap (solmuşta eğik)
  final head = wilted ? const Offset(12, -30) : const Offset(0, -40);
  final path = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(wilted ? 2 : 3, -22, head.dx, head.dy);
  canvas.drawPath(path, stem);
  canvas.save();
  canvas.translate(-2, -14);
  canvas.rotate(-0.5);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(-7, 0), width: 16, height: 7),
    leaf,
  );
  canvas.restore();

  canvas.save();
  canvas.translate(head.dx, head.dy);
  if (wilted) canvas.rotate(1.1);
  final petalColor = wilted
      ? Color.lerp(kind.petal, const Color(0xFF9C7A5B), 0.6)!
      : kind.petal;
  final petal = Paint()..color = petalColor;
  final outline = Paint()
    ..color = ink.withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;

  if (size == FlowerSize.bud) {
    final bud = Rect.fromCenter(
      center: const Offset(0, -4),
      width: 12,
      height: 18,
    );
    canvas.drawOval(bud, petal);
    canvas.drawOval(bud, outline);
    canvas.restore();
    canvas.restore();
    return;
  }

  switch (kind) {
    case FlowerKind.tulip:
      final cup = Path()
        ..moveTo(-11, -4)
        ..quadraticBezierTo(-12, 10, 0, 10)
        ..quadraticBezierTo(12, 10, 11, -4)
        ..lineTo(6, 2)
        ..lineTo(0, -8)
        ..lineTo(-6, 2)
        ..close();
      canvas.drawPath(cup, petal);
      canvas.drawPath(cup, outline);
    case FlowerKind.bell:
      for (final dx in [-7.0, 7.0]) {
        final bell = Path()
          ..moveTo(dx - 7, 6)
          ..quadraticBezierTo(dx - 7, -8, dx, -8)
          ..quadraticBezierTo(dx + 7, -8, dx + 7, 6)
          ..quadraticBezierTo(dx, 2, dx - 7, 6)
          ..close();
        canvas.drawPath(bell, petal);
        canvas.drawPath(bell, outline);
      }
      canvas.drawCircle(const Offset(0, -10), 3, Paint()..color = kind.center);
    case FlowerKind.daisy || FlowerKind.sunflower || FlowerKind.cosmos:
      final n = kind == FlowerKind.sunflower
          ? 12
          : kind == FlowerKind.daisy
          ? 10
          : 8;
      final len = kind == FlowerKind.sunflower ? 13.0 : 11.0;
      for (var i = 0; i < n; i++) {
        canvas.save();
        canvas.rotate(i * 2 * math.pi / n);
        final r = Rect.fromCenter(
          center: Offset(0, -len / 2 - 4),
          width: kind == FlowerKind.cosmos ? 9 : 6.5,
          height: len,
        );
        canvas.drawOval(r, petal);
        canvas.drawOval(r, outline);
        canvas.restore();
      }
      canvas.drawCircle(
        Offset.zero,
        kind == FlowerKind.sunflower ? 7.5 : 5,
        Paint()..color = kind.center,
      );
      canvas.drawCircle(
        Offset.zero,
        kind == FlowerKind.sunflower ? 7.5 : 5,
        outline,
      );
  }
  if (size == FlowerSize.grand) {
    // Parıltı
    final spark = Paint()..color = Colors.white;
    for (final o in const [Offset(-16, -14), Offset(15, -10), Offset(2, -20)]) {
      final p = Path()
        ..moveTo(o.dx, o.dy - 4)
        ..lineTo(o.dx + 1.2, o.dy - 1.2)
        ..lineTo(o.dx + 4, o.dy)
        ..lineTo(o.dx + 1.2, o.dy + 1.2)
        ..lineTo(o.dx, o.dy + 4)
        ..lineTo(o.dx - 1.2, o.dy + 1.2)
        ..lineTo(o.dx - 4, o.dy)
        ..lineTo(o.dx - 1.2, o.dy - 1.2)
        ..close();
      canvas.drawPath(p, spark);
    }
  }
  canvas.restore();
  canvas.restore();
}
