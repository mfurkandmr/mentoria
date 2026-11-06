import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../data/timetable_repository.dart';
import '../domain/models.dart';
import 'timetable_format.dart';

/// Öğretmen (koç), öğrenci ve veli ana sayfası: yayındaki programdan
/// bugünkü dersler. Kurum programı yayınlamadıysa hiç görünmez.
class MyTimetableCard extends ConsumerWidget {
  const MyTimetableCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myTimetableProvider).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final today = DateTime.now().weekday;
    final todays = [
      for (final i in items)
        if (i.day == today) i,
    ];
    final seen = <String>{};
    final unique = [
      for (final i in todays)
        if (seen.add('${i.seq}|${i.branch}|${i.classroomName}')) i,
    ];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_view_week_rounded),
        title: Text(tr('Ders programı')),
        subtitle: Text(
          unique.isEmpty
              ? tr('Bugün ders yok')
              : tr('Bugün: {list}', {
                  'list': unique
                      .take(4)
                      .map((i) => '${formatClock(i.start)} ${i.branch}')
                      .join(', '),
                }),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MyTimetableScreen()),
        ),
      ),
    );
  }
}

/// Haftalık program: gün gün (veli: çocuk başına sınıf adıyla).
class MyTimetableScreen extends ConsumerWidget {
  const MyTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myTimetableProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ders programı'))),
      body: AsyncView(
        value: items,
        onRetry: () => ref.invalidate(myTimetableProvider),
        builder: (list) {
          if (list.isEmpty) {
            return Center(child: Text(tr('Yayında program yok.')));
          }
          final days = {for (final i in list) i.day}.toList()..sort();
          final today = DateTime.now().weekday;
          final teacherView = list.every((i) => i.studentId == null);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(list.first.scheduleName, style: text.titleMedium),
              for (final d in days) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 6),
                  child: Text(
                    d == today
                        ? tr('{day} (bugün)', {'day': dayLong(d)})
                        : dayLong(d),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final i in _unique(list.where((x) => x.day == d)))
                  Card(
                    child: ListTile(
                      leading: Container(
                        width: 6,
                        height: 40,
                        decoration: BoxDecoration(
                          color: branchColor(i.branch),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      title: Text(i.branch),
                      subtitle: Text(
                        [
                          '${formatClock(i.start)}–${formatClock(i.end)}',
                          teacherView ? i.classroomName : i.teacherName,
                          if (!teacherView &&
                              list.map((x) => x.classroomName).toSet().length >
                                  1)
                            i.classroomName,
                          if (i.roomName != null) i.roomName!,
                        ].join(' · '),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Veli iki çocuğu aynı sınıftaysa aynı ders bir kez.
  static List<TimetableItem> _unique(Iterable<TimetableItem> items) {
    final seen = <String>{};
    return [
      for (final i in items)
        if (seen.add('${i.seq}|${i.branch}|${i.classroomName}')) i,
    ];
  }
}

/// Müdür ana sayfası: ders programına giriş.
class TimetableAdminCard extends ConsumerWidget {
  const TimetableAdminCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(schedulesProvider).value;
    final published = schedules?.where((s) => s.published).firstOrNull;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_view_week_rounded),
        title: Text(tr('Ders programı')),
        subtitle: Text(
          published != null
              ? tr('Yayında: {name}', {'name': published.name})
              : tr('Öğretmen, sınıf ve derslikten çakışmasız program'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/admin/schedule'),
      ),
    );
  }
}
