import '../../../shared/widgets/tool_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';
import '../../tutoring/data/tutoring_repository.dart';
import '../../tutoring/presentation/tutoring_timetable_widgets.dart';
import '../data/timetable_repository.dart';
import '../domain/models.dart';
import 'timetable_format.dart';

/// Öğretmen (koç), öğrenci ve veli ana sayfası: yayındaki programdan
/// bugünkü dersler. Kurum programı yayınlamadıysa hiç görünmez.
/// Kendi ders programı kısayolu (öğretmen, öğrenci, veli). Programda
/// kaydı yoksa null (kart görünmez).
ToolInfo? myTimetableTool(WidgetRef ref) {
  final items = ref.watch(myTimetableProvider).value;
  if (items == null || items.isEmpty) return null;
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
  return ToolInfo(
    id: 'my-timetable-card',
    icon: Icons.calendar_view_week_rounded,
    title: tr('Ders programı'),
    status: unique.isEmpty
        ? tr('Bugün ders yok')
        : tr('Bugün: {list}', {
            'list': unique
                .take(4)
                .map((i) => '${formatClock(i.start)} ${i.branch}')
                .join(', '),
          }),
    open: (context) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyTimetableScreen())),
  );
}

class MyTimetableCard extends ConsumerWidget {
  const MyTimetableCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = myTimetableTool(ref);
    return tool == null ? const SizedBox.shrink() : ToolListCard(tool: tool);
  }
}

/// Haftalık program: gün gün (veli: çocuk başına sınıf adıyla).
class MyTimetableScreen extends ConsumerWidget {
  const MyTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myTimetableProvider);
    final text = Theme.of(context).textTheme;
    // Öğretmen: soru çözümü / birebir oturumları da programda (NOTLAR §95).
    final isTeacher =
        ref.watch(currentProfileProvider).value?.role == UserRole.teacher;
    final sessions = isTeacher
        ? ref.watch(myTutoringSessionsProvider).value ??
              const <TutoringSession>[]
        : const <TutoringSession>[];
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ders programı'))),
      body: AsyncView(
        value: items,
        onRetry: () => ref.invalidate(myTimetableProvider),
        builder: (list) {
          if (list.isEmpty && sessions.isEmpty) {
            return Center(child: Text(tr('Yayında program yok.')));
          }
          final days = {
            for (final i in list) i.day,
            for (final s in sessions)
              if (s.active) s.day,
          }.toList()..sort();
          final today = DateTime.now().weekday;
          final teacherView = list.every((i) => i.studentId == null);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (list.isNotEmpty)
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
                ...teacherTutoringForDay(context, ref, d, sessions: sessions),
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
/// Müdür: ders programı kısayolu.
ToolInfo timetableAdminTool(WidgetRef ref) {
  final schedules = ref.watch(schedulesProvider).value;
  final published = schedules?.where((s) => s.published).firstOrNull;
  return ToolInfo(
    id: 'timetable-admin-card',
    icon: Icons.calendar_view_week_rounded,
    title: tr('Ders programı'),
    status: published != null
        ? tr('Yayında: {name}', {'name': published.name})
        : tr('Öğretmen, sınıf ve derslikten çakışmasız program'),
    open: (context) => context.push('/admin/schedule'),
  );
}

class TimetableAdminCard extends ConsumerWidget {
  const TimetableAdminCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ToolListCard(tool: timetableAdminTool(ref));
}
