import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/format.dart';
import '../../../tracking/presentation/study_view.dart' show formatMinutes;
import '../../data/cockpit_repository.dart';
import 'metric_card.dart';
import 'section_states.dart';
import 'week_hero_card.dart';

/// Özet şeridi: baş kart "Bu hafta aktif" (katılım halkası), altında
/// kayıtlı öğrenci, bu hafta çözülen soru ve yaklaşan deneme.
class MetricStrip extends ConsumerWidget {
  const MetricStrip({super.key, required this.onOpenStudents});

  /// "Kayıtlı öğrenci" kartı Öğrenciler sekmesine geçer.
  final VoidCallback onOpenStudents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(cockpitProvider);
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const HeroStrip(
        hero: SizedBox(height: 132, child: MetricSkeleton()),
        cards: [MetricSkeleton(), MetricSkeleton(), MetricSkeleton()],
      ),
      error: (_, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SectionError(onRetry: () => ref.invalidate(cockpitProvider)),
        ),
      ),
      data: (d) => _strip(context, d),
    );
  }

  Widget _strip(BuildContext context, CockpitData d) {
    final n = NumberFormat.decimalPattern(localeTag);
    final next = d.nextExam;
    final days = next?.daysFrom(DateTime.now());
    return HeroStrip(
      hero: WeekHeroCard(
        key: const ValueKey('metric-active'),
        active: d.active,
        total: d.students,
        delta: MetricDelta.between(d.active, d.activePrev),
        onTap: () => context.push('/admin/activity'),
      ),
      cards: [
        MetricCard(
          key: const ValueKey('metric-students'),
          label: tr('Kayıtlı öğrenci'),
          value: n.format(d.students),
          count: d.students,
          format: n.format,
          delta: MetricDelta.between(d.students, d.studentsPrev),
          semanticsHint: tr('Öğrenci listesini açar'),
          onTap: onOpenStudents,
        ),
        MetricCard(
          key: const ValueKey('metric-questions'),
          label: tr('Bu hafta çözülen soru'),
          value: n.format(d.questions),
          count: d.questions,
          format: n.format,
          detail: d.minutes > 0
              ? tr('{t} çalışma', {'t': formatMinutes(d.minutes)})
              : null,
          delta: MetricDelta.between(
            d.questions,
            d.questionsPrev,
            percent: true,
          ),
          semanticsHint: tr('Öğrencileri soru sayısına göre sıralar'),
          onTap: () => context.push('/admin/activity?sort=questions'),
        ),
        MetricCard(
          key: const ValueKey('metric-exam'),
          label: tr('Yaklaşan deneme'),
          value: next == null
              ? '–'
              : days == 0
              ? tr('Bugün')
              : days == 1
              ? tr('Yarın')
              : '$days',
          unit: next != null && days! > 1 ? tr('gün sonra') : null,
          detail: next == null
              ? tr('Planlı deneme yok. Planla')
              : '${next.name} · ${formatShortDate(next.plannedOn)}',
          semanticsHint: tr('Deneme takvimini açar'),
          onTap: () => context.push('/admin/exam-plans'),
        ),
      ],
    );
  }
}

/// Baş kart (tam genişlik) ve altında üç kart: genişte üçü yan yana, dar
/// ekranda ikisi yan yana ve üçüncüsü tam genişlik.
class HeroStrip extends StatelessWidget {
  const HeroStrip({super.key, required this.hero, required this.cards});

  final Widget hero;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const gap = 10.0;
      Widget row(List<Widget> items) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, w) in items.indexed) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(child: w),
            ],
          ],
        ),
      );
      final wide = c.maxWidth >= 720;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hero,
          const SizedBox(height: gap),
          if (wide || cards.length < 3)
            row(cards)
          else ...[
            row(cards.take(2).toList()),
            const SizedBox(height: gap),
            for (final (i, w) in cards.skip(2).indexed) ...[
              if (i > 0) const SizedBox(height: gap),
              w,
            ],
          ],
        ],
      );
    },
  );
}

/// Özet kartları: dar ekranda 2 × 2, genişte 4 yan yana; aynı satırdaki
/// kartlar aynı yükseklikte.
class MetricGrid extends StatelessWidget {
  const MetricGrid(this.cards, {super.key});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 720 ? 4 : 2;
      const gap = 10.0;
      // Aynı satırdaki kartlar aynı yükseklikte.
      return Column(
        children: [
          for (var i = 0; i < cards.length; i += cols) ...[
            if (i > 0) const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + cols; j++) ...[
                    if (j > i) const SizedBox(width: gap),
                    Expanded(
                      child: j < cards.length
                          ? cards[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}
