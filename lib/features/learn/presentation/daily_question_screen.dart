import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/sound/app_sounds.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../auth/data/auth_repository.dart';
import '../data/daily_question_repository.dart';
import '../data/practice_repository.dart';
import 'learn_screen.dart';
import 'notebook_button.dart';

/// Ana sayfadaki Günün Sorusu kartı.
class DailyQuestionCard extends ConsumerWidget {
  const DailyQuestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(dailyQuestionProvider).value;
    if (s == null) return const SizedBox.shrink();
    final look = subjectLook(s.subject);
    final subject = subjectByCode(s.subject).name;
    final subtitle = !s.answered
        ? tr('{subject} · çöz, serini büyüt', {'subject': subject})
        : s.correct == true
        ? tr('Bugünkü soruyu bildin ✓ Yarın yenisi gelir')
        : tr('Bugünkü soru çözüldü · yarın yenisi gelir');
    return Semantics(
      button: true,
      label: '${tr('Günün Sorusu')}. $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/student/daily'),
        child: PressScale(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: s.answered
                    ? [const Color(0xFF9AA5B8), const Color(0xFF66708A)]
                    : [const Color(0xFFFFC94D), const Color(0xFFFF8A3D)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8A3D).withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(
                    s.answered ? Icons.check_rounded : look.icon,
                    color: s.answered ? const Color(0xFF66708A) : look.color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Günün Sorusu'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.streak > 0) _StreakChip(streak: s.streak),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak, this.big = false});
  final int streak;
  final bool big;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      tr('🔥 {n} gün', {'n': streak}),
      style: TextStyle(
        color: const Color(0xFFB54708),
        fontWeight: FontWeight.w900,
        fontSize: big ? 16 : 13,
      ),
    ),
  );
}

/// Günün Sorusu: her gün tek soru, günlük hakkı harcamaz; doğru cevaplanan
/// günler seriyi büyütür.
class DailyQuestionScreen extends ConsumerStatefulWidget {
  const DailyQuestionScreen({super.key});

  @override
  ConsumerState<DailyQuestionScreen> createState() =>
      _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends ConsumerState<DailyQuestionScreen> {
  int? _picked;
  bool _saving = false;

  Future<void> _pick(PracticeQuestion q, int option, String studentId) async {
    if (_picked != null || _saving) return;
    final right = option == q.answer;
    setState(() {
      _picked = option;
      _saving = true;
    });
    right ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
    try {
      await ref
          .read(dailyQuestionRepositoryProvider)
          .answer(studentId, questionId: q.id, correct: right);
      ref.invalidate(dailyQuestionProvider);
      if (right && mounted) {
        AppSounds.play(AppSound.bizzTap);
        celebrate(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _picked = null);
        showMessage(
          context,
          tr('Cevap kaydedilemedi. İnternet bağlantını kontrol et.'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentProfileProvider).value;
    final state = ref.watch(dailyQuestionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Günün Sorusu'))),
      body: state.value != null && me != null
          ? _body(state.value!, me.id)
          : state.hasError
          ? Center(
              child: FilledButton(
                onPressed: () => ref.invalidate(dailyQuestionProvider),
                child: Text(tr('Tekrar dene')),
              ),
            )
          : state.isLoading || me == null
          ? const Center(child: BizzLoader())
          : Center(child: Text(tr('Günün Sorusu öğrencilere özel.'))),
    );
  }

  Widget _body(DailyQuestionState s, String studentId) {
    final pool = ref.watch(questionPoolProvider(s.subject));
    final q = pool.value?.where((q) => q.id == s.questionId).firstOrNull;
    if (pool.isLoading) return const Center(child: BizzLoader());
    if (q == null) {
      return Center(child: Text(tr('Bugünkü soru yüklenemedi.')));
    }
    final look = subjectLook(s.subject);
    // Bugün daha önce cevaplandıysa yalnızca doğru şık gösterilir.
    final revealed = _picked != null || s.answered;
    final right = _picked != null ? _picked == q.answer : s.correct == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [look.color, Color.lerp(look.color, Colors.black, 0.25)!],
            ),
          ),
          child: Row(
            children: [
              Icon(look.icon, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectByCode(s.subject).name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      tr('Günlük hakkını harcamaz'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              _StreakChip(streak: s.streak, big: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.topic,
                  style: TextStyle(
                    color: look.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
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
            state: !revealed
                ? OptState.idle
                : k == q.answer
                ? OptState.right
                : k == _picked
                ? OptState.wrong
                : OptState.dim,
            onTap: revealed ? null : () => _pick(q, k, studentId),
          ),
        if (revealed) ...[
          const SizedBox(height: 8),
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (right ? context.brand.success : context.brand.danger)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    right
                        ? tr('Doğru! Serin {n} gün 🔥', {'n': s.streak})
                        : tr(
                            'Bu sefer olmadı. Seri sıfırlandı, yarın yeniden başla!',
                          ),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(q.explanation),
                ],
              ),
            ),
          ),
          if (!right) ...[
            const SizedBox(height: 10),
            AddToNotebookButton(studentId: studentId, question: q),
          ],
          const SizedBox(height: 12),
          Text(
            tr('Yarın sabah 09.00\'da yeni soru gelecek.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.brand.ink.withValues(alpha: 0.6)),
          ),
        ],
      ],
    );
  }
}
