import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../../schedule_generator/domain/models.dart';
import '../../schedule_generator/presentation/timetable_format.dart';
import '../../tutoring/data/tutoring_repository.dart';
import '../../tutoring/presentation/tutoring_timetable_widgets.dart';
import '../data/student_schedule.dart';

/// Öğrenci: "Bugün" (sırayla, süren ders vurgulu) ve "Hafta" (ızgara).
class StudentScheduleScreen extends ConsumerWidget {
  const StudentScheduleScreen({super.key, this.now});

  /// Testler için sabit zaman.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(studentScheduleProvider);
    Future<void> refresh() async {
      ref.invalidate(myClassroomProvider);
      ref.invalidate(myTimetableProvider);
      ref.invalidate(studentScheduleProvider);
      ref.invalidate(myTutoringRequestsProvider);
      ref.invalidate(openTutoringSlotsProvider);
      await ref
          .read(studentScheduleProvider.future)
          .catchError(
            (_) => const StudentScheduleView(className: null, items: []),
          );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Ders programım')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('Bugün')),
              Tab(text: tr('Hafta')),
            ],
          ),
        ),
        body: AsyncView(
          value: view,
          onRetry: () => ref.invalidate(studentScheduleProvider),
          builder: (v) {
            final at = now ?? DateTime.now();
            Widget wrap(Widget child) =>
                RefreshIndicator(onRefresh: refresh, child: child);
            if (!v.hasClass || v.notPublished) {
              final child = _Empty(view: v);
              return TabBarView(children: [wrap(child), wrap(child)]);
            }
            return TabBarView(
              children: [
                wrap(_TodayTab(view: v, now: at)),
                wrap(_WeekTab(view: v, now: at)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.view});

  final StudentScheduleView view;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(
          view.hasClass
              ? Icons.hourglass_empty_rounded
              : Icons.group_off_rounded,
          size: 56,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Text(
          view.hasClass
              ? tr('Programın henüz yayınlanmadı')
              : tr('Henüz bir sınıfa atanmadın'),
          textAlign: TextAlign.center,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          view.hasClass
              ? tr(
                  '{class} sınıfının programı yayınlanınca burada görünecek.',
                  {'class': view.className!},
                )
              : tr(
                  'Koçun ya da kurum müdürün seni bir sınıfa atayınca programın burada görünür.',
                ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CacheNotice extends StatelessWidget {
  const _CacheNotice({required this.view});

  final StudentScheduleView view;

  @override
  Widget build(BuildContext context) {
    if (!view.fromCache) return const SizedBox.shrink();
    final at = view.savedAt;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_off_rounded),
        title: Text(tr('Çevrimdışı gösteriliyor')),
        subtitle: Text(
          at == null
              ? tr('Son kaydedilen program')
              : tr('Son güncelleme: {d}', {
                  'd': DateFormat('d MMMM HH:mm', localeTag).format(at),
                }),
        ),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.view, required this.now});

  final StudentScheduleView view;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final today = view.day(now.weekday);
    final (current, next) = currentAndNext(today, now);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _CacheNotice(view: view),
        Text(
          '${view.className} · ${dayLong(now.weekday)}',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (view.scheduleName != null)
          Text(view.scheduleName!, style: text.bodySmall),
        const SizedBox(height: 10),
        if (today.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr('Bugün ders yok. İyi dinlenmeler!'),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final i in today)
            _LessonCard(
              item: i,
              badge: identical(i, current)
                  ? tr('Şimdi')
                  : identical(i, next) && current == null
                  ? tr('Sıradaki')
                  : null,
              highlight: identical(i, current),
              past: i.end <= now.hour * 60 + now.minute,
            ),
        // Bugünkü soru çözümü / birebir (NOTLAR §95).
        StudentTutoringSchedule(onlyDate: now),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.item,
    this.badge,
    this.highlight = false,
    this.past = false,
  });

  final TimetableItem item;
  final String? badge;
  final bool highlight;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final color = branchColor(item.branch);
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: past && !highlight ? 0.55 : 1,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: highlight
              ? BorderSide(color: context.brand.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 54,
                child: Column(
                  children: [
                    Text(
                      formatClock(item.start),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(formatClock(item.end), style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.branch,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        item.teacherName,
                        if (item.roomName != null) item.roomName!,
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Chip(
                  label: Text(badge!),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: context.brand.primary.withValues(
                    alpha: 0.15,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekTab extends StatelessWidget {
  const _WeekTab({required this.view, required this.now});

  final StudentScheduleView view;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final days = {for (final i in view.items) i.day}.toList()..sort();
    final seqs = {for (final i in view.items) i.seq}.toList()..sort();
    final at = {for (final i in view.items) (i.day, i.seq): i};
    String rowTime(int seq) {
      final first = view.items.where((i) => i.seq == seq).toList()
        ..sort((a, b) => a.day.compareTo(b.day));
      return first.isEmpty ? '$seq' : formatClock(first.first.start);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _CacheNotice(view: view),
        Text(
          view.className!,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(92),
            columnWidths: const {0: FixedColumnWidth(48)},
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  for (final d in days)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        dayShort(d),
                        textAlign: TextAlign.center,
                        style: text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: d == now.weekday
                              ? context.brand.primary
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              for (final seq in seqs)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(rowTime(seq), style: text.labelSmall),
                    ),
                    for (final d in days)
                      Builder(
                        builder: (context) {
                          final i = at[(d, seq)];
                          return Container(
                            height: 58,
                            margin: const EdgeInsets.all(2),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: i == null
                                  ? scheme.surfaceContainerLow
                                  : branchColor(
                                      i.branch,
                                    ).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: i == null
                                ? null
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        i.branch,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        i.teacherName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.labelSmall,
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
        // Önümüzdeki günlerin soru çözümü / birebir talepleri.
        const StudentTutoringSchedule(),
      ],
    );
  }
}

/// Öğrenci ana sayfası: bugünün dersleri ya da boş durum. Sınıfı ve
/// yayında programı olmayan öğrencide (kurum bu özelliği kullanmıyorsa)
/// görünmez.
class StudentScheduleCard extends ConsumerWidget {
  const StudentScheduleCard({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(studentScheduleProvider).value;
    if (v == null || (!v.hasClass && v.items.isEmpty)) {
      return const SizedBox.shrink();
    }
    final at = now ?? DateTime.now();
    final today = v.day(at.weekday);
    final (current, next) = currentAndNext(today, at);
    final String subtitle;
    if (v.notPublished) {
      subtitle = tr('Programın henüz yayınlanmadı');
    } else if (current != null) {
      subtitle = tr('Şimdi: {branch} · {end}\'e kadar', {
        'branch': current.branch,
        'end': formatClock(current.end),
      });
    } else if (next != null) {
      subtitle = tr('Sıradaki: {time} {branch}', {
        'time': formatClock(next.start),
        'branch': next.branch,
      });
    } else {
      subtitle = today.isEmpty
          ? tr('Bugün ders yok')
          : tr('Bugünkü dersler bitti');
    }
    return Card(
      child: ListTile(
        key: const ValueKey('student-schedule-card'),
        leading: const Icon(Icons.calendar_view_week_rounded),
        title: Text(tr('Ders programım')),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/student/timetable'),
      ),
    );
  }
}
