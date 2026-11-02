import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../data/optic_repository.dart';

/// Optikten okunan denemede yanlış ve boş bırakılan sorular, kazanımlarıyla:
/// "Fizik 7 · Sen: B · Doğru: A · Kuvvet ve hareket". Üstte konu bazında
/// özet ("Türkçe · Paragraf — 4 yanlış", altında kaçırılan kazanımlar).
/// Deneme optikten okunmadıysa hiçbir şey çizmez.
///
/// Kendi kaydırması yoktur: çağıran sayfa / alt sayfa kaydırılabilir olmalı.
class ExamAnswersView extends ConsumerStatefulWidget {
  const ExamAnswersView({super.key, required this.examId, this.title});

  final String examId;

  /// Üstte gösterilecek başlık (ör. koçun açtığı öğrencinin adı).
  final String? title;

  @override
  ConsumerState<ExamAnswersView> createState() => _ExamAnswersViewState();
}

class _ExamAnswersViewState extends ConsumerState<ExamAnswersView> {
  /// Konu özetinde ilk açılışta gösterilen konu sayısı.
  static const _topOutcomes = 5;

  bool _allTopics = false;

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(examAnswersProvider(widget.examId)).value;
    if (answers == null || answers.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    final mistakes = answers
        .where((a) => !a.isCancelled && !a.isCorrect)
        .toList();
    final wrong = mistakes.where((a) => a.marked != null).length;
    final byOutcome = mistakesByOutcome(answers);
    final shown = _allTopics
        ? byOutcome
        : byOutcome.take(_topOutcomes).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Text(
            widget.title!,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        Text(
          mistakes.isEmpty
              ? tr('Tüm soruları doğru yaptın!')
              : tr('Yanlışların ve boşların ({w} yanlış, {b} boş)', {
                  'w': wrong,
                  'b': mistakes.length - wrong,
                }),
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        // Konu bazında özet: aynı konudaki yanlışlar tek satırda.
        if (byOutcome.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            tr('En çok kaçırılan konular'),
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final o in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${subjectByCode(o.subject).name} · ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: o.outcome),
                            ],
                          ),
                        ),
                        if (o.details.isNotEmpty)
                          Text(
                            o.details.join(', '),
                            style: text.bodySmall?.copyWith(color: muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    [
                      if (o.wrong > 0) tr('{n} yanlış', {'n': o.wrong}),
                      if (o.blank > 0) tr('{n} boş', {'n': o.blank}),
                    ].join(' · '),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: o.wrong > 0 ? context.brand.danger : muted,
                    ),
                  ),
                ],
              ),
            ),
          if (byOutcome.length > _topOutcomes)
            TextButton(
              onPressed: () => setState(() => _allTopics = !_allTopics),
              child: Text(
                _allTopics
                    ? tr('Daha az göster')
                    : tr('Tüm konuları göster (+{n})', {
                        'n': byOutcome.length - _topOutcomes,
                      }),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            tr('Soru soru'),
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: 6),
        for (final a in mistakes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  a.marked == null
                      ? Icons.radio_button_unchecked
                      : Icons.close_rounded,
                  size: 18,
                  color: a.marked == null ? muted : context.brand.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.marked == null
                            ? tr('{subject} {n}. soru · boş · doğru: {c}', {
                                'subject': subjectByCode(a.subject).name,
                                'n': a.shownNumber,
                                'c': a.correct!,
                              })
                            : tr(
                                '{subject} {n}. soru · sen: {m} · doğru: {c}',
                                {
                                  'subject': subjectByCode(a.subject).name,
                                  'n': a.shownNumber,
                                  'm': a.marked!,
                                  'c': a.correct!,
                                },
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (a.outcome != null)
                        Text(
                          a.outcome!,
                          style: text.bodySmall?.copyWith(color: muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
