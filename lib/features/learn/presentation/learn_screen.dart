import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/sound/app_sounds.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/motion.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../auth/data/auth_repository.dart';
import '../../student/presentation/home_sky.dart';
import '../data/learn_cards.dart';
import '../data/practice_repository.dart';
import 'notebook_button.dart';

/// Derslerin rengi ve simgesi (AYT dersleri TYT karşılığının rengini alır).
({Color color, IconData icon}) subjectLook(String code) => switch (code) {
  'AYT_EDB' => (
    color: const Color(0xFFE5484D),
    icon: Icons.history_edu_rounded,
  ),
  'AYT_TAR1' || 'AYT_TAR2' => subjectLook('TYT_TAR'),
  'AYT_COG1' || 'AYT_COG2' => subjectLook('TYT_COG'),
  'AYT_FELG' => subjectLook('TYT_FEL'),
  _ when code.startsWith('AYT_') => subjectLook(
    code.replaceFirst('AYT_', 'TYT_'),
  ),
  'TYT_TUR' => (color: const Color(0xFFE5484D), icon: Icons.menu_book_rounded),
  'TYT_MAT' => (color: const Color(0xFF5B4BC8), icon: Icons.calculate_rounded),
  'TYT_FIZ' => (color: const Color(0xFF1E6FD9), icon: Icons.bolt_rounded),
  'TYT_KIM' => (color: const Color(0xFF12A594), icon: Icons.science_rounded),
  'TYT_BIY' => (color: const Color(0xFF2F8F3A), icon: Icons.eco_rounded),
  'TYT_TAR' => (
    color: const Color(0xFFB0662D),
    icon: Icons.account_balance_rounded,
  ),
  'TYT_COG' => (color: const Color(0xFF0D8BB8), icon: Icons.public_rounded),
  'TYT_FEL' => (color: const Color(0xFF8E4EC6), icon: Icons.psychology_rounded),
  'TYT_DIN' => (
    color: const Color(0xFFD08700),
    icon: Icons.auto_stories_rounded,
  ),
  _ => (color: const Color(0xFF5B4BC8), icon: Icons.school_rounded),
};

String _subjectName(String code) => practiceSubjectLabel(code);

/// Öğrencinin "Eğitim" sekmesi: dersler, günlük haklar, bilgi kartları ve
/// telifsiz soru havuzundan günlük çalışma.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(currentProfileProvider).value?.id;
    return Scaffold(
      appBar: SkyAppBar(title: Text(tr('Eğitim'))),
      body: id == null
          ? const Center(child: BizzLoader())
          : _LearnHome(studentId: id),
    );
  }
}

class _LearnHome extends ConsumerStatefulWidget {
  const _LearnHome({required this.studentId});
  final String studentId;

  @override
  ConsumerState<_LearnHome> createState() => _LearnHomeState();
}

class _LearnHomeState extends ConsumerState<_LearnHome> {
  /// Gösterilen sınav: TYT ya da AYT.
  bool _ayt = false;

  @override
  Widget build(BuildContext context) {
    final studentId = widget.studentId;
    final answers = ref.watch(practiceAnswersProvider(studentId));
    final subjects = _ayt ? aytPracticeSubjects : tytPracticeSubjects;
    return AsyncView(
      value: answers,
      onRetry: () => ref.invalidate(practiceAnswersProvider(studentId)),
      builder: (all) {
        final today = DateTime.now();
        bool isToday(DateTime d) =>
            d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
        final used = all
            .where((a) => subjects.contains(a.subject) && isToday(a.answeredOn))
            .length;
        final quota = subjects.fold<int>(
          0,
          (s, c) => s + practiceDailyLimit(c),
        );
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(practiceAnswersProvider(studentId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(tr('TYT'))),
                  ButtonSegment(value: true, label: Text(tr('AYT'))),
                ],
                selected: {_ayt},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _ayt = v.first),
              ),
              const SizedBox(height: 12),
              _TodayBanner(used: used, quota: quota),
              const SizedBox(height: 14),
              GridView.count(
                key: ValueKey(_ayt),
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  for (final (i, c) in subjects.indexed)
                    FadeSlideIn(
                      delay: FadeSlideIn.stagger(i),
                      child: _SubjectTile(
                        studentId: studentId,
                        subject: c,
                        answers: all,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodayBanner extends StatelessWidget {
  const _TodayBanner({required this.used, required this.quota});
  final int used;
  final int quota;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brand.primaryDeep,
            Color.lerp(brand.primaryDeep, brand.secondary, 0.7)!,
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Bugünkü çalışman'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                CountUp(
                  value: used.toDouble(),
                  format: (v) => '${v.round()} / $quota',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  tr('soru çözüldü · her gün yenilenir'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedLinearProgress(
                  value: quota == 0 ? 0 : used / quota,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Bizz(
            size: 84,
            mood: used > 0 ? BizzMood.happy : BizzMood.idle,
            interactive: false,
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({
    required this.studentId,
    required this.subject,
    required this.answers,
  });
  final String studentId;
  final String subject;
  final List<PracticeAnswer> answers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = subjectLook(subject);
    final limit = practiceDailyLimit(subject);
    final now = DateTime.now();
    final used = answers
        .where(
          (a) =>
              a.subject == subject &&
              a.answeredOn.year == now.year &&
              a.answeredOn.month == now.month &&
              a.answeredOn.day == now.day,
        )
        .length;
    final done = used >= limit;
    return Semantics(
      button: true,
      label: tr('{s}: bugün {u} / {l} soru', {
        's': _subjectName(subject),
        'u': used,
        'l': limit,
      }),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SubjectLearnScreen(studentId: studentId, subject: subject),
          ),
        ),
        child: PressScale(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Theme.of(context).cardColor,
              border: Border.all(
                color: look.color.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: look.color.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: look.color,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(look.icon, color: Colors.white),
                    ),
                    const Spacer(),
                    SizedBox.square(
                      dimension: 42,
                      child: CustomPaint(
                        painter: _Ring(used / limit, look.color),
                        child: Center(
                          child: done
                              ? Icon(
                                  Icons.check_rounded,
                                  color: look.color,
                                  size: 20,
                                )
                              : Text(
                                  '${limit - used}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: look.color,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  subjectByCode(subject).name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  done
                      ? tr('Bugünlük tamam ✓')
                      : tr('{n} soru hakkın var', {'n': limit - used}),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  tr('{n} bilgi kartı', {
                    'n': learnCards[subject]?.length ?? 0,
                  }),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
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
    final r = size.width / 2 - 3;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color.withValues(alpha: 0.15),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * value.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.value != value;
}

/// Bir dersin sayfası: bilgi kartları ve günlük sorular.
class SubjectLearnScreen extends ConsumerStatefulWidget {
  const SubjectLearnScreen({
    super.key,
    required this.studentId,
    required this.subject,
    this.initialTab = 0,
  });

  final String studentId;
  final String subject;
  final int initialTab;

  @override
  ConsumerState<SubjectLearnScreen> createState() => _SubjectLearnScreenState();
}

class _SubjectLearnScreenState extends ConsumerState<SubjectLearnScreen> {
  @override
  Widget build(BuildContext context) {
    final look = subjectLook(widget.subject);
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: look.color,
          foregroundColor: Colors.white,
          title: Text(_subjectName(widget.subject)),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: const Icon(Icons.style_rounded),
                text: tr('Bilgi kartları'),
              ),
              Tab(icon: const Icon(Icons.quiz_rounded), text: tr('Soru çöz')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CardsView(subject: widget.subject),
            _QuizView(studentId: widget.studentId, subject: widget.subject),
          ],
        ),
      ),
    );
  }
}

// --- Bilgi kartları -----------------------------------------------------------

class _CardsView extends StatefulWidget {
  const _CardsView({required this.subject});
  final String subject;

  @override
  State<_CardsView> createState() => _CardsViewState();
}

class _CardsViewState extends State<_CardsView> {
  final _pages = PageController(viewportFraction: 0.86);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = learnCards[widget.subject] ?? const [];
    final look = subjectLook(widget.subject);
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: cards.length,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _page = i);
            },
            itemBuilder: (_, i) => AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                final p = _pages.hasClients && _pages.position.haveDimensions
                    ? (_pages.page ?? 0) - i
                    : (_page - i).toDouble();
                final t = p.abs().clamp(0.0, 1.0);
                return Transform.scale(
                  scale: 1 - 0.08 * t,
                  child: Opacity(opacity: 1 - 0.4 * t, child: child),
                );
              },
              child: _FlipCard(
                card: cards[i],
                color: look.color,
                index: i,
                total: cards.length,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < cards.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? look.color
                        : look.color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Önde başlık, dokununca dönerek arkada bilgi ve formül.
class _FlipCard extends StatefulWidget {
  const _FlipCard({
    required this.card,
    required this.color,
    required this.index,
    required this.total,
  });
  final LearnCard card;
  final Color color;
  final int index;
  final int total;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> {
  bool _back = false;

  @override
  Widget build(BuildContext context) {
    final animate = Motion.of(context);
    return Semantics(
      button: true,
      label: _back
          ? '${widget.card.title}. ${widget.card.body}'
          : tr('{t} kartı, çevirmek için dokun', {'t': widget.card.title}),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _back = !_back);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _back ? 1 : 0),
          duration: Duration(milliseconds: animate ? 520 : 0),
          curve: Curves.easeInOutBack,
          builder: (_, v, _) {
            final showBack = v > 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(math.pi * v),
              child: showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _side(back: true),
                    )
                  : _side(back: false),
            );
          },
        ),
      ),
    );
  }

  Widget _side({required bool back}) {
    final c = widget.color;
    final card = widget.card;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: back
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c, Color.lerp(c, Colors.black, 0.25)!],
                ),
          color: back ? Theme.of(context).cardColor : null,
          border: back ? Border.all(color: c, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: back
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: TextStyle(
                        color: c,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (card.formula != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          card.formula!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      card.body,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      '${widget.index + 1} / ${widget.total}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.lightbulb_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 56,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    card.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          tr('Çevirmek için dokun'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// --- Soru çözme ---------------------------------------------------------------

class _QuizView extends ConsumerStatefulWidget {
  const _QuizView({required this.studentId, required this.subject});
  final String studentId;
  final String subject;

  @override
  ConsumerState<_QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends ConsumerState<_QuizView> {
  /// Oturum başında belirlenen bugünkü sorular (cevaplandıkça liste değişmesin).
  List<PracticeQuestion>? _questions;
  int _i = 0;
  int? _picked;
  int _correct = 0;
  int _streak = 0;
  bool _saving = false;
  int _startUsed = 0;

  void _start(SubjectPractice p) {
    _questions = p.todaysQuestions;
    _startUsed = p.usedToday;
  }

  Future<void> _pick(int option) async {
    final q = _questions![_i];
    if (_picked != null || _saving) return;
    final right = option == q.answer;
    setState(() {
      _picked = option;
      _saving = true;
      if (right) {
        _correct++;
        _streak++;
      } else {
        _streak = 0;
      }
    });
    right ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
    if (right && _streak > 0 && _streak % 5 == 0) {
      AppSounds.play(AppSound.bizzTap);
      celebrate(context);
    }
    try {
      await ref
          .read(practiceRepositoryProvider)
          .submit(
            widget.studentId,
            subject: widget.subject,
            questionId: q.id,
            correct: right,
          );
    } on DailyLimitReached {
      if (mounted) {
        showMessage(
          context,
          tr('Bugünkü hakkın doldu. Yarın yeni sorular seni bekliyor!'),
        );
        setState(() => _questions = _questions!.take(_i + 1).toList());
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          tr('Cevap kaydedilemedi. İnternet bağlantını kontrol et.'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    setState(() {
      _i++;
      _picked = null;
    });
    if (_i >= _questions!.length) {
      ref.invalidate(practiceAnswersProvider(widget.studentId));
      if (_correct > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) celebrate(context);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(questionPoolProvider(widget.subject));
    final answers = ref.watch(practiceAnswersProvider(widget.studentId));
    if (_questions == null) {
      if (pool.isLoading || answers.isLoading) {
        return const Center(child: BizzLoader());
      }
      if (pool.hasError || answers.hasError) {
        return Center(
          child: FilledButton(
            onPressed: () {
              ref.invalidate(questionPoolProvider(widget.subject));
              ref.invalidate(practiceAnswersProvider(widget.studentId));
            },
            child: Text(tr('Tekrar dene')),
          ),
        );
      }
      _start(
        SubjectPractice.of(
          subject: widget.subject,
          studentId: widget.studentId,
          pool: pool.value!,
          answers: answers.value!,
          now: DateTime.now(),
        ),
      );
    }
    final qs = _questions!;
    final limit = practiceDailyLimit(widget.subject);
    final look = subjectLook(widget.subject);
    if (qs.isEmpty || _i >= qs.length) {
      return _QuizDone(
        color: look.color,
        solvedNow: qs.isEmpty ? null : qs.length,
        correct: _correct,
        limit: limit,
      );
    }
    final q = qs[_i];
    final answered = _picked != null;
    final number = _startUsed + _i + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        Row(
          children: [
            Text(
              tr('Soru {n} / {l}', {'n': number, 'l': limit}),
              style: TextStyle(color: look.color, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            if (_streak >= 2)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8CC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tr('🔥 {n} doğru üst üste', {'n': _streak}),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB54708),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedLinearProgress(value: (number - 1) / limit, color: look.color),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: look.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    q.topic,
                    style: TextStyle(
                      color: look.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  q.text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var k = 0; k < q.options.length; k++)
          OptionTile(
            letter: 'ABCDE'[k],
            text: q.options[k],
            state: !answered
                ? OptState.idle
                : k == q.answer
                ? OptState.right
                : k == _picked
                ? OptState.wrong
                : OptState.dim,
            onTap: answered ? null : () => _pick(k),
          ),
        if (answered) ...[
          const SizedBox(height: 8),
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    (_picked == q.answer
                            ? context.brand.success
                            : context.brand.danger)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _picked == q.answer ? '🎉' : '💡',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _picked == q.answer
                              ? tr('Doğru!')
                              : tr('Doğru cevap: {l}', {
                                  'l': 'ABCDE'[q.answer],
                                }),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(q.explanation),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_picked != q.answer) ...[
            const SizedBox(height: 10),
            AddToNotebookButton(
              key: ValueKey(q.id),
              studentId: widget.studentId,
              question: q,
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _next,
            style: FilledButton.styleFrom(
              backgroundColor: look.color,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: Icon(
              _i + 1 < qs.length
                  ? Icons.arrow_forward_rounded
                  : Icons.flag_rounded,
            ),
            label: Text(_i + 1 < qs.length ? tr('Sonraki soru') : tr('Bitir')),
          ),
        ],
      ],
    );
  }
}

enum OptState { idle, right, wrong, dim }

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    this.onTap,
  });
  final String letter;
  final String text;
  final OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final (bg, border, icon) = switch (state) {
      OptState.right => (
        brand.success.withValues(alpha: 0.14),
        brand.success,
        Icons.check_circle_rounded,
      ),
      OptState.wrong => (
        brand.danger.withValues(alpha: 0.12),
        brand.danger,
        Icons.cancel_rounded,
      ),
      OptState.dim => (
        Colors.transparent,
        brand.ink.withValues(alpha: 0.12),
        null,
      ),
      OptState.idle => (
        Theme.of(context).cardColor,
        brand.ink.withValues(alpha: 0.15),
        null,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: onTap != null,
        label:
            '$letter: $text${state == OptState.right
                ? ', ${tr('doğru')}'
                : state == OptState.wrong
                ? ', ${tr('yanlış')}'
                : ''}',
        excludeSemantics: true,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor:
                        state == OptState.idle || state == OptState.dim
                        ? brand.ink.withValues(alpha: 0.08)
                        : border,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: state == OptState.idle || state == OptState.dim
                            ? brand.ink
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: state == OptState.dim
                            ? brand.ink.withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                  ),
                  if (icon != null) Icon(icon, color: border),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizDone extends StatelessWidget {
  const _QuizDone({
    required this.color,
    required this.correct,
    required this.limit,
    this.solvedNow,
  });
  final Color color;

  /// Bu oturumda çözülen; null ise ekran açıldığında hak zaten bitmişti.
  final int? solvedNow;
  final int correct;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Bizz(size: 140, mood: BizzMood.happy, interactive: false),
            const SizedBox(height: 16),
            Text(
              solvedNow == null
                  ? tr('Bugünlük bu ders tamam!')
                  : tr('{c} / {n} doğru', {'c': correct, 'n': solvedNow}),
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'Günlük {l} soru hakkını kullandın. Yarın havuzdan yepyeni sorular gelecek. 🐝',
                {'l': limit},
              ),
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
