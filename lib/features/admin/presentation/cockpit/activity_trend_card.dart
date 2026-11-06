import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/i18n.dart';
import '../../data/cockpit_repository.dart';
import 'cockpit_motion.dart';
import 'cockpit_theme.dart';
import 'section_states.dart';

enum TrendSeries { active, questions }

/// Son 8 haftanın eğilimi: haftalık aktif öğrenci ya da çözülen soru.
/// Bu haftanın çubuğu vurgu renginde, öncekiler gri; renk anlam taşımaz,
/// yalnızca "bu hafta"yı ayırır (değer ayrıca yazılı).
class ActivityTrendCard extends ConsumerStatefulWidget {
  const ActivityTrendCard({super.key, required this.onInviteStudent});

  /// Hiç öğrenci yokken boş haldeki eylem.
  final VoidCallback onInviteStudent;

  @override
  ConsumerState<ActivityTrendCard> createState() => _ActivityTrendCardState();
}

class _ActivityTrendCardState extends ConsumerState<ActivityTrendCard> {
  TrendSeries _series = TrendSeries.active;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(activityWeeksProvider);
    return CockpitSection(
      key: const ValueKey('section-trend'),
      title: tr('Son 8 hafta'),
      subtitle: _series == TrendSeries.active
          ? tr('Haftalık aktif öğrenci')
          : tr('Haftalık çözülen soru'),
      child: CockpitAsync(
        value: value,
        onRetry: () => ref.invalidate(activityWeeksProvider),
        loading: const SizedBox(height: 150, child: _ChartSkeleton()),
        builder: (weeks) {
          if (weeks.isEmpty || weeks.every((w) => w.students == 0)) {
            return SectionEmpty(
              icon: Icons.insights_outlined,
              message: tr(
                'Öğrenci kaydı olunca haftalık eğilim burada görünür.',
              ),
              actionLabel: tr('Öğrenci davet et'),
              actionIcon: Icons.person_add_alt_1,
              onAction: widget.onInviteStudent,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SlidingSegments<TrendSeries>(
                value: _series,
                onChanged: (v) => setState(() => _series = v),
                segments: {
                  TrendSeries.active: (
                    key: const ValueKey('trend-active'),
                    label: tr('Aktif öğrenci'),
                    count: null,
                  ),
                  TrendSeries.questions: (
                    key: const ValueKey('trend-questions'),
                    label: tr('Çözülen soru'),
                    count: null,
                  ),
                },
              ),
              const SizedBox(height: 14),
              _Bars(weeks: weeks, series: _series),
            ],
          );
        },
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.weeks, required this.series});

  final List<ActivityWeek> weeks;
  final TrendSeries series;

  static const _height = 110.0;

  int _value(ActivityWeek w) =>
      series == TrendSeries.active ? w.active : w.questions;

  @override
  Widget build(BuildContext context) {
    final n = NumberFormat.compact(locale: localeTag);
    final df = DateFormat('d MMM', localeTag);
    final accent = Theme.of(context).colorScheme.primary;
    // Aktif öğrenci kayıtlı öğrenciye göre ölçeklenir (dolu çubuk = herkes).
    final scale = series == TrendSeries.active
        ? weeks.map((w) => w.students).fold(0, (a, b) => b > a ? b : a)
        : weeks.map(_value).fold(0, (a, b) => b > a ? b : a);
    final spoken = [
      for (final w in weeks)
        series == TrendSeries.active
            ? tr('{d}: {a} / {s} aktif', {
                'd': df.format(w.end),
                'a': w.active,
                's': w.students,
              })
            : tr('{d}: {q} soru', {'d': df.format(w.end), 'q': w.questions}),
    ].join(', ');

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, w) in weeks.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    series == TrendSeries.active
                        ? '${w.active}'
                        : n.format(w.questions),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: i == weeks.length - 1
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: i == weeks.length - 1
                          ? context.cockpit.ink
                          : context.cockpit.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // İlk açılışta sırayla yükselir; seri değişince yeni
                  // yüksekliğe kayar. Hareketi azaltta anında.
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: scale == 0
                          ? 2
                          : (_value(w) / scale * _height).clamp(2, _height),
                    ),
                    duration: CockpitMotion.of(
                      context,
                      Duration(milliseconds: 520 + i * 60),
                    ),
                    curve: CockpitMotion.curve,
                    builder: (_, h, _) => Container(
                      height: h,
                      decoration: BoxDecoration(
                        gradient: i == weeks.length - 1
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.lerp(accent, Colors.white, 0.25)!,
                                  accent,
                                ],
                              )
                            : null,
                        color: i == weeks.length - 1
                            ? null
                            : context.cockpit.border,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i == weeks.length - 1
                        ? tr('Bu hafta')
                        : i.isEven
                        ? df.format(w.end)
                        : '',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.cockpit.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 8; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 30.0 + (i % 3) * 25,
              decoration: BoxDecoration(
                color: context.cockpit.faint,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
