import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/daily_bar_chart.dart';
import '../../../shared/widgets/effects.dart';
import '../../../shared/widgets/panel.dart';
import '../data/practice_report.dart';
import '../data/practice_repository.dart';
import 'learn_screen.dart';

/// Koç / müdür için öğrencinin Eğitim karnesi (Eğitim sekmesindeki
/// çalışmalar).
class LearnReportView extends ConsumerWidget {
  const LearnReportView({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(practiceAnswersProvider(studentId));
    if (answers.hasError) {
      return Center(
        child: FilledButton(
          onPressed: () => ref.invalidate(practiceAnswersProvider(studentId)),
          child: Text(tr('Tekrar dene')),
        ),
      );
    }
    final list = answers.value;
    if (list == null) return const BizzLoader();
    if (list.isEmpty) {
      return EmptyState(
        title: tr('Henüz soru çözülmedi'),
        message: tr(
          'Öğrenci Eğitim sekmesinde soru çözdükçe karnesi burada oluşur.',
        ),
      );
    }
    // Konu adları için yalnızca çözülen derslerin havuzu yüklenir.
    final topics = <String, String>{};
    for (final s in {for (final a in list) a.subject}) {
      for (final q in ref.watch(questionPoolProvider(s)).value ?? const []) {
        topics[q.id] = q.topic;
      }
    }
    final report = PracticeReport.of(
      answers: list,
      topicOf: (id) => topics[id],
      now: DateTime.now(),
    );
    final brand = context.brand;
    final weak = report.weakestSubject;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        StatRow(
          children: [
            GlowStat(
              icon: Icons.school_rounded,
              label: tr('Toplam'),
              value: report.solved.toDouble(),
              caption: tr('soru'),
              color: brand.primary,
            ),
            GlowStat(
              icon: Icons.verified_rounded,
              label: tr('İsabet'),
              value: report.accuracy * 100,
              format: (v) => '%${v.round()}',
              caption: tr('tüm zamanlar'),
              color: brand.success,
            ),
            GlowStat(
              icon: Icons.date_range_rounded,
              label: tr('Son 7 gün'),
              value: report.lastWeek.toDouble(),
              caption: tr('soru'),
              color: brand.secondary,
            ),
          ],
        ),
        if (weak != null && weak.accuracy < 0.7)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PanelNotice(
              icon: Icons.tips_and_updates_rounded,
              color: brand.danger,
              message: weak.weakestTopic == null
                  ? tr('En zayıf ders: {subject} (%{p} isabet).', {
                      'subject': practiceSubjectLabel(weak.subject),
                      'p': (weak.accuracy * 100).round(),
                    })
                  : tr(
                      'En zayıf ders: {subject} (%{p} isabet). Önce "{topic}" konusuna odaklanılabilir.',
                      {
                        'subject': practiceSubjectLabel(weak.subject),
                        'p': (weak.accuracy * 100).round(),
                        'topic': weak.weakestTopic,
                      },
                    ),
            ),
          ),
        SectionCard(
          title: tr('Son 7 gün'),
          subtitle: tr('Eğitim sekmesinde günlük çözülen soru'),
          child: DailyBarChart(
            days: report.days,
            values: report.perDay,
            unit: tr('soru'),
          ),
        ),
        SectionCard(
          title: tr('Ders ders'),
          subtitle: tr('Çözülen soru, isabet ve en çok yanlış yapılan konu'),
          child: Column(
            children: [for (final r in report.subjects) _SubjectRow(report: r)],
          ),
        ),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.report});
  final SubjectReport report;

  @override
  Widget build(BuildContext context) {
    final look = subjectLook(report.subject);
    final brand = context.brand;
    final pct = (report.accuracy * 100).round();
    final accColor = report.accuracy >= 0.7
        ? brand.success
        : report.accuracy >= 0.5
        ? brand.secondary
        : brand.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: look.color.withValues(alpha: 0.14),
            child: Icon(look.icon, color: look.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        practiceSubjectLabel(report.subject),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      tr('{n} soru', {'n': report.solved}),
                      style: TextStyle(
                        color: brand.ink.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '%$pct',
                      style: TextStyle(
                        color: accColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedLinearProgress(value: report.accuracy, color: accColor),
                if (report.weakestTopic != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    tr('En çok yanlış: {topic} ({n})', {
                      'topic': report.weakestTopic,
                      'n': report.weakestWrong,
                    }),
                    style: TextStyle(
                      color: brand.ink.withValues(alpha: 0.65),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
