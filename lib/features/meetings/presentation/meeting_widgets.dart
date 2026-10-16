import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../../shared/widgets/panel.dart';
import '../../tracking/data/tracking_models.dart';
import '../data/meeting_repository.dart';

/// Görüşme durumunun görünümü: ikon + etiket + renk (renk tek başına anlam
/// taşımaz). İşaretlenmemiş görüşme gelecekteyse "Planlı", geçtiyse
/// "İşaretlenmedi".
({IconData icon, String label, Color? color}) meetingLook(
  BuildContext context,
  Meeting m, [
  DateTime? now,
]) {
  final brand = context.brand;
  return switch (m.status) {
    MeetingStatus.held => (
      icon: Icons.check_circle_rounded,
      label: MeetingStatus.held.label,
      color: brand.success,
    ),
    MeetingStatus.missed => (
      icon: Icons.cancel_rounded,
      label: MeetingStatus.missed.label,
      color: brand.danger,
    ),
    MeetingStatus.cancelled => (
      icon: Icons.block_rounded,
      label: MeetingStatus.cancelled.label,
      color: null,
    ),
    null when m.start.isAfter(now ?? DateTime.now()) => (
      icon: Icons.schedule_rounded,
      label: tr('Planlı'),
      color: brand.info,
    ),
    null => (
      icon: Icons.help_outline_rounded,
      label: tr('İşaretlenmedi'),
      color: brand.primaryDeep,
    ),
  };
}

/// "Bugün", "Yarın" ya da "Salı 21 Ekim".
String meetingDayLabel(DateTime day, [DateTime? now]) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = dateOnly(day).difference(today).inDays;
  return switch (diff) {
    0 => tr('Bugün'),
    1 => tr('Yarın'),
    -1 => tr('Dün'),
    _ => '${weekdayName(day)} ${formatDayMonth(day)}',
  };
}

class MeetingStatusPill extends StatelessWidget {
  const MeetingStatusPill({super.key, required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final look = meetingLook(context, meeting);
    return InfoPill(icon: look.icon, text: look.label, color: look.color);
  }
}

/// Koçun bir günün görüşmesini işaretlediği alt sayfa. Gelecekteki görüşme
/// yalnızca iptal edilebilir.
Future<void> showMeetingStatusSheet(
  BuildContext context,
  WidgetRef ref,
  Meeting m,
) async {
  final future = m.start.isAfter(DateTime.now());
  final options = <(MeetingStatus?, IconData, String)>[
    if (!future) ...[
      (MeetingStatus.held, Icons.check_circle_rounded, tr('Görüşme yapıldı')),
      (MeetingStatus.missed, Icons.cancel_rounded, tr('Görüşme yapılmadı')),
    ],
    if (m.status != MeetingStatus.cancelled)
      (MeetingStatus.cancelled, Icons.block_rounded, tr('Bu haftalık iptal')),
    if (m.status != null) (null, Icons.undo_rounded, tr('İşareti kaldır')),
  ];
  final picked = await showModalBottomSheet<(MeetingStatus?,)>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              [
                if (m.studentName.isNotEmpty) m.studentName,
                meetingDayLabel(m.day),
                formatClock(m.schedule.hour, m.schedule.minute),
              ].join(' · '),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (future)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                tr(
                  'Görüşme saati gelince "yapıldı" ya da "yapılmadı" olarak işaretleyebilirsin.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final (status, icon, label) in options)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.pop(context, (status,)),
            ),
        ],
      ),
    ),
  );
  if (picked == null) return;
  try {
    await ref
        .read(meetingRepositoryProvider)
        .setStatus(m.schedule.id, m.day, picked.$1);
    HapticFeedback.selectionClick();
    invalidateMeetings(ref);
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }
}

/// Tek bir günün görüşmesi: tarih rozeti, kim / ne zaman, durum hapı.
class MeetingTile extends ConsumerWidget {
  const MeetingTile({
    super.key,
    required this.meeting,
    this.showStudent = false,
    this.canMark = false,
  });

  final Meeting meeting;
  final bool showStudent;
  final bool canMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = meeting;
    final text = Theme.of(context).textTheme;
    final brand = context.brand;
    final time = formatClock(m.schedule.hour, m.schedule.minute);
    final when = '${meetingDayLabel(m.day)} · $time';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canMark ? () => showMeetingStatusSheet(context, ref, m) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: brand.secondary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEE', localeTag).format(m.day),
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${m.day.day}',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showStudent && m.studentName.isNotEmpty
                          ? m.studentName
                          : when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        if (showStudent && m.studentName.isNotEmpty) when,
                        tr('{n} dk', {'n': m.schedule.durationMin}),
                        if (m.schedule.note?.isNotEmpty ?? false)
                          m.schedule.note!,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MeetingStatusPill(meeting: m),
            ],
          ),
        ),
      ),
    );
  }
}

/// Koç ana sayfası: bu haftaki görüşmeler ve kaçının yapıldığı. Dokununca
/// durum işaretlenir.
class WeekMeetingsSection extends ConsumerWidget {
  const WeekMeetingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = weekStartOf(DateTime.now());
    final meetings = ref.watch(
      weekMeetingsProvider((studentId: null, weekStart: week)),
    );
    final list = meetings.value ?? const <Meeting>[];
    final held = list.where((m) => m.status == MeetingStatus.held).length;
    final planned = list
        .where((m) => m.status != MeetingStatus.cancelled)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionTitle(
          title: tr('Bu haftaki görüşmeler'),
          subtitle: list.isEmpty
              ? tr('Öğrenciye dokunup görüşme ekleyebilirsin')
              : tr('{held} / {n} görüşme yapıldı', {
                  'held': held,
                  'n': planned,
                }),
        ),
        const SizedBox(height: 4),
        if (meetings.isLoading && list.isEmpty)
          const SizedBox(height: 60, child: BizzLoader())
        else if (list.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    color: context.brand.info,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr(
                        'Bu hafta planlı görüşme yok. Haftalık rutin için öğrencinin sayfasında "Görüşme ekle"ye dokun.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final (i, m) in list.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            MeetingTile(meeting: m, showStudent: true, canMark: true),
          ],
      ],
    );
  }
}

/// Öğrenci detayında (koç / müdür / veli) görüşme planları ve bu haftanın
/// görüşmeleri. [canManage]: koç ekler, bitirir ve işaretler.
class StudentMeetingsCard extends ConsumerWidget {
  const StudentMeetingsCard({
    super.key,
    required this.studentId,
    this.canManage = false,
  });

  final String studentId;
  final bool canManage;

  Future<void> _end(
    BuildContext context,
    WidgetRef ref,
    MeetingSchedule s,
  ) async {
    final ok = await confirm(
      context,
      title: s.repeatWeekly
          ? tr('Rutin görüşme bitirilsin mi?')
          : tr('Görüşme kaldırılsın mı?'),
      message: s.repeatWeekly
          ? tr(
              '"{p0}" görüşmeleri bundan sonra planlanmaz. Geçmiş görüşme kayıtları kalır.',
              {'p0': s.describe()},
            )
          : tr('{p0} görüşmesi kaldırılacak.', {'p0': s.describe()}),
      action: s.repeatWeekly ? tr('Bitir') : tr('Kaldır'),
    );
    if (!ok) return;
    try {
      await ref.read(meetingRepositoryProvider).endSchedule(s.id);
      invalidateMeetings(ref);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final schedules = ref.watch(meetingSchedulesProvider(studentId));
    final week = ref.watch(
      weekMeetingsProvider((studentId: studentId, weekStart: weekStartOf(now))),
    );
    // Süren rutinler ve henüz gelmemiş tek seferlik görüşmeler.
    final active = [
      for (final s in schedules.value ?? const <MeetingSchedule>[])
        if (s.isActiveOn(now) && (s.repeatWeekly || s.nextAfter(now) != null))
          s,
    ];
    final thisWeek = week.value ?? const <Meeting>[];
    final text = Theme.of(context).textTheme;

    return SectionCard(
      title: tr('Görüşmeler'),
      subtitle: canManage ? tr('Haftalık rutin ya da tek seferlik') : null,
      trailing: canManage
          ? TextButton.icon(
              onPressed: () => showAddMeetingSheet(context, studentId),
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('Görüşme ekle')),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (schedules.isLoading && active.isEmpty)
            const SizedBox(height: 48, child: BizzLoader())
          else if (active.isEmpty)
            Text(
              canManage
                  ? tr(
                      'Henüz planlı görüşme yok. "Görüşme ekle" ile her hafta aynı gün ve saatte tekrarlanan bir görüşme planlayabilirsin.',
                    )
                  : tr('Planlı görüşme yok.'),
              style: text.bodyMedium,
            ),
          for (final s in active)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: context.brand.secondary.withValues(
                  alpha: 0.18,
                ),
                child: Icon(
                  s.repeatWeekly
                      ? Icons.event_repeat_rounded
                      : Icons.event_rounded,
                  color: context.brand.secondary,
                ),
              ),
              title: Text(
                s.describe(),
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                [
                  tr('{n} dk', {'n': s.durationMin}),
                  if (s.note?.isNotEmpty ?? false) s.note!,
                  if (!canManage && s.coachName != null) s.coachName!,
                ].join(' · '),
              ),
              trailing: canManage
                  ? IconButton(
                      tooltip: s.repeatWeekly
                          ? tr('Rutini bitir')
                          : tr('Görüşmeyi kaldır'),
                      icon: const Icon(Icons.event_busy_rounded),
                      onPressed: () => _end(context, ref, s),
                    )
                  : null,
            ),
          if (thisWeek.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tr('Bu hafta'),
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final (i, m) in thisWeek.indexed) ...[
              if (i > 0) const SizedBox(height: 6),
              MeetingTile(meeting: m, canMark: canManage),
            ],
          ],
        ],
      ),
    );
  }
}

/// Öğrenci ana sayfası: koçla sıradaki görüşme. Planlı görüşme yoksa
/// hiçbir şey çizmez.
class NextMeetingCard extends ConsumerWidget {
  const NextMeetingCard({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final schedules =
        ref.watch(meetingSchedulesProvider(studentId)).value ?? const [];
    MeetingSchedule? next;
    DateTime? at;
    for (final s in schedules) {
      final t = s.nextAfter(now);
      if (t != null && (at == null || t.isBefore(at))) {
        at = t;
        next = s;
      }
    }
    if (next == null || at == null) return const SizedBox.shrink();

    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    final soon = at.difference(now) <= const Duration(hours: 24);
    final color = soon ? brand.primary : brand.secondary;

    return Semantics(
      container: true,
      label: tr('Koçunla görüşme: {when}', {
        'when': '${meetingDayLabel(at)} ${formatClock(at.hour, at.minute)}',
      }),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.26),
              color.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.forum_rounded,
                color:
                    ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : brand.ink,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    next.coachName == null
                        ? tr('Koçunla görüşme')
                        : tr('{coach} ile görüşme', {'coach': next.coachName}),
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${meetingDayLabel(at)} · ${formatClock(at.hour, at.minute)}',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    [
                      if (next.repeatWeekly) next.describe(),
                      tr('{n} dk', {'n': next.durationMin}),
                      if (next.note?.isNotEmpty ?? false) next.note!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Müdür paneli: koçların seçilen haftada hangi öğrencilerle görüştüğü.
/// Görüşmesi olmayan koç da listede görünür.
class CoachMeetingsReport extends ConsumerStatefulWidget {
  const CoachMeetingsReport({super.key, required this.coaches});

  /// (koç kimliği, adı)
  final List<(String, String)> coaches;

  @override
  ConsumerState<CoachMeetingsReport> createState() =>
      _CoachMeetingsReportState();
}

class _CoachMeetingsReportState extends ConsumerState<CoachMeetingsReport> {
  int _weeksAgo = 0;

  @override
  Widget build(BuildContext context) {
    final thisWeek = weekStartOf(DateTime.now());
    final week = DateTime(
      thisWeek.year,
      thisWeek.month,
      thisWeek.day - 7 * _weeksAgo,
    );
    final end = DateTime(week.year, week.month, week.day + 6);
    final meetings =
        ref
            .watch(weekMeetingsProvider((studentId: null, weekStart: week)))
            .value ??
        const <Meeting>[];
    final byCoach = <String, List<Meeting>>{};
    for (final m in meetings) {
      byCoach.putIfAbsent(m.schedule.coachId, () => []).add(m);
    }
    // Listede olmayan (ör. ayrılmış) koçun görüşmeleri de görünsün.
    final coaches = [
      ...widget.coaches,
      for (final id in byCoach.keys)
        if (!widget.coaches.any((c) => c.$1 == id))
          (id, byCoach[id]!.first.coachName),
    ];
    final range = '${formatDayMonth(week)} – ${formatDayMonth(end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionTitle(
          title: tr('Koç görüşmeleri'),
          subtitle: _weeksAgo == 0 ? tr('Bu hafta · {r}', {'r': range}) : range,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: tr('Önceki hafta'),
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() => _weeksAgo++),
              ),
              IconButton(
                tooltip: tr('Sonraki hafta'),
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _weeksAgo == 0
                    ? null
                    : () => setState(() => _weeksAgo--),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (coaches.isEmpty)
          Text(tr('Henüz koç yok.'))
        else
          for (final (i, (id, name)) in coaches.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _CoachMeetingsCard(name: name, meetings: byCoach[id] ?? const []),
          ],
      ],
    );
  }
}

class _CoachMeetingsCard extends StatelessWidget {
  const _CoachMeetingsCard({required this.name, required this.meetings});

  final String name;
  final List<Meeting> meetings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final held = meetings.where((m) => m.status == MeetingStatus.held).length;
    final planned = meetings
        .where((m) => m.status != MeetingStatus.cancelled)
        .length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name: name, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                InfoPill(
                  icon: Icons.forum_rounded,
                  text: tr('{held} / {n} yapıldı', {
                    'held': held,
                    'n': planned,
                  }),
                  color: planned > 0 && held == planned
                      ? context.brand.success
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (meetings.isEmpty)
              Text(tr('Bu hafta planlı görüşme yok.'), style: text.bodySmall)
            else
              for (final m in meetings)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: m.studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '  ${DateFormat('EEE', localeTag).format(m.day)} '
                                    '${formatClock(m.schedule.hour, m.schedule.minute)}',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      MeetingStatusPill(meeting: m),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Koçun görüşme planladığı alt sayfa.
Future<void> showAddMeetingSheet(BuildContext context, String studentId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddMeetingSheet(studentId: studentId),
    );

class _AddMeetingSheet extends ConsumerStatefulWidget {
  const _AddMeetingSheet({required this.studentId});

  final String studentId;

  @override
  ConsumerState<_AddMeetingSheet> createState() => _AddMeetingSheetState();
}

class _AddMeetingSheetState extends ConsumerState<_AddMeetingSheet> {
  bool _weekly = true;
  int _weekday = DateTime.now().weekday;
  DateTime _date = dateOnly(DateTime.now().add(const Duration(days: 1)));
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 0);
  int _duration = 30;
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Haftalıkta seçilen günün ilk geleceği tarih (bugünse ve saat geçtiyse
  /// gelecek hafta).
  DateTime _firstDate() {
    if (!_weekly) return _date;
    final now = DateTime.now();
    final today = dateOnly(now);
    var d = DateTime(
      today.year,
      today.month,
      today.day + (_weekday - today.weekday) % 7,
    );
    if (DateTime(
      d.year,
      d.month,
      d.day,
      _time.hour,
      _time.minute,
    ).isBefore(now)) {
      d = DateTime(d.year, d.month, d.day + 7);
    }
    return d;
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: dateOnly(now),
      lastDate: now.add(const Duration(days: 120)),
    );
    if (d != null) setState(() => _date = dateOnly(d));
  }

  Future<void> _save() async {
    final first = _firstDate();
    final start = DateTime(
      first.year,
      first.month,
      first.day,
      _time.hour,
      _time.minute,
    );
    if (!start.isAfter(DateTime.now())) {
      setState(() => _error = tr('Görüşme zamanı geçmiş olamaz.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(meetingRepositoryProvider)
          .createSchedule(
            MeetingDraft(
              studentId: widget.studentId,
              firstDate: first,
              hour: _time.hour,
              minute: _time.minute,
              durationMin: _duration,
              repeatWeekly: _weekly,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            ),
          );
      invalidateMeetings(ref);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(
        context,
        _weekly
            ? tr('Rutin görüşme planlandı: her {day} {time} 🐝', {
                'day': weekdayName(first),
                'time': formatClock(_time.hour, _time.minute),
              })
            : tr('Görüşme planlandı 🐝'),
      );
    } catch (_) {
      setState(() => _error = tr('Kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = _firstDate();
    final time = formatClock(_time.hour, _time.minute);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Görüşme ekle'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.event_repeat_rounded),
                  label: Text(tr('Her hafta')),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(tr('Tek sefer')),
                ),
              ],
              selected: {_weekly},
              onSelectionChanged: (s) => setState(() => _weekly = s.first),
            ),
            const SizedBox(height: 16),
            if (_weekly) ...[
              Text(tr('Gün'), style: text.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var wd = 1; wd <= 7; wd++)
                    ChoiceChip(
                      // 1 Ocak 2024 pazartesi: haftanın günlerinin kısa adı.
                      label: Text(
                        DateFormat(
                          'EEE',
                          localeTag,
                        ).format(DateTime(2024, 1, wd)),
                      ),
                      selected: _weekday == wd,
                      onSelected: (_) => setState(() => _weekday = wd),
                    ),
                ],
              ),
            ] else
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: tr('Tarih'),
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text('${weekdayName(_date)} ${formatDayMonth(_date)}'),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: tr('Saat'),
                        prefixIcon: const Icon(Icons.schedule_rounded),
                      ),
                      child: Text(time),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _duration,
                    decoration: InputDecoration(labelText: tr('Süre')),
                    items: [
                      for (final m in const [15, 20, 30, 45, 60, 90])
                        DropdownMenuItem(
                          value: m,
                          child: Text(tr('{n} dk', {'n': m})),
                        ),
                    ],
                    onChanged: (v) => setState(() => _duration = v ?? 30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: tr('Not (isteğe bağlı)'),
                hintText: tr('ör. Haftalık değerlendirme'),
              ),
            ),
            PanelNotice(
              icon: Icons.notifications_active_outlined,
              message: _weekly
                  ? tr(
                      'Her {day} {time}. İlk görüşme {first}. Öğrenciye her görüşmeden 24 saat önce bildirim gider.',
                      {
                        'day': weekdayName(first),
                        'time': time,
                        'first': formatDayMonth(first),
                      },
                    )
                  : tr(
                      '{day} {time}. Öğrenciye görüşmeden 24 saat önce bildirim gider.',
                      {
                        'day': '${weekdayName(first)} ${formatDayMonth(first)}',
                        'time': time,
                      },
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.event_available_rounded),
              label: Text(tr('Görüşmeyi kaydet')),
            ),
          ],
        ),
      ),
    );
  }
}
