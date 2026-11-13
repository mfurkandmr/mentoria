import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../data/tutoring_repository.dart';
import 'tutoring_widgets.dart';

/// Ders programı ekranlarında soru çözümü / birebir / etüt (NOTLAR §95).

/// Bir oturumun programdaki kartı (derslerden ayrı renkte).
class TutoringTimetableCard extends StatelessWidget {
  const TutoringTimetableCard({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final TutoringKind kind;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        onTap: onTap,
        leading: Icon(tutoringIcon(kind), color: scheme.onTertiaryContainer),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.onTertiaryContainer,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
        trailing: trailing,
      ),
    );
  }
}

/// Öğretmen: o günün oturumları ve bekleyen talep sayısı. Talepler
/// öğretmenin ana sayfasında onaylanır.
List<Widget> teacherTutoringForDay(
  BuildContext context,
  WidgetRef ref,
  int weekday, {
  required List<TutoringSession> sessions,
}) {
  final requests =
      ref.watch(teacherTutoringRequestsProvider).value ??
      const <TutoringRequest>[];
  return [
    for (final s in sessions)
      if (s.day == weekday && s.active)
        TutoringTimetableCard(
          key: ValueKey('my-tutoring-${s.id}'),
          kind: s.kind,
          title: '${s.timeLabel} · ${s.kind.label}',
          subtitle: [
            ?s.branch,
            if (s.capacity > 1) tr('{n} kişilik', {'n': s.capacity}),
            ?s.roomName,
            () {
              final pending = requests
                  .where(
                    (r) =>
                        r.sessionId == s.id &&
                        r.status == TutoringStatus.pending,
                  )
                  .length;
              return pending > 0
                  ? tr('{n} talep onay bekliyor', {'n': pending})
                  : null;
            }(),
          ].whereType<String>().join(' · '),
          onTap: () => GoRouter.maybeOf(context)?.go('/teacher'),
        ),
  ];
}

/// Öğrenci: önümüzdeki günlerin soru çözümü talepleri ve açık saatler.
/// [onlyDate] verilirse yalnızca o günün onaylı / bekleyen talepleri.
class StudentTutoringSchedule extends ConsumerWidget {
  const StudentTutoringSchedule({super.key, this.onlyDate});

  final DateTime? onlyDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final mine =
        ref.watch(myTutoringRequestsProvider).value ??
        const <TutoringRequest>[];
    final slots =
        ref.watch(openTutoringSlotsProvider).value ?? const <TutoringSlot>[];
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final day = onlyDate;
    final active =
        [
          for (final r in mine)
            if ((r.status == TutoringStatus.approved ||
                    r.status == TutoringStatus.pending) &&
                (day == null || sameDay(r.date, day)))
              r,
        ]..sort(
          (a, b) => a.date != b.date
              ? a.date.compareTo(b.date)
              : a.start.compareTo(b.start),
        );
    final open = [
      for (final s in slots)
        if (s.myStatus == null && (day == null || sameDay(s.date, day))) s,
    ];
    if (active.isEmpty && open.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            tr('Soru çözümü ve birebir'),
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        for (final r in active)
          TutoringTimetableCard(
            key: ValueKey('schedule-tutoring-${r.id}'),
            kind: r.kind,
            title:
                '${day == null ? '${tutoringDateLabel(r.date)} · ' : ''}'
                '${formatHm(r.start)}–${formatHm(r.end)} · '
                '${r.branch ?? r.kind.label}',
            subtitle: [?r.teacherName, ?r.topic].join(' · '),
            trailing: TutoringStatusPill(r.status),
            onTap: () => context.push('/student/study'),
          ),
        if (open.isNotEmpty)
          Card(
            child: ListTile(
              key: const ValueKey('schedule-tutoring-open'),
              leading: const Icon(Icons.add_circle_outline),
              title: Text(
                day == null
                    ? tr('{n} açık saat var', {'n': open.length})
                    : tr('Bugün {n} açık saat var', {'n': open.length}),
              ),
              subtitle: Text(tr('Öğretmenden soru çözümü ya da birebir iste')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/student/study'),
            ),
          ),
      ],
    );
  }
}
