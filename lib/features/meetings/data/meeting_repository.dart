import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';
import '../../tracking/data/tracking_models.dart';

/// Bir günün görüşmesinin koç tarafından işaretlenen durumu.
enum MeetingStatus {
  held('held', 'Yapıldı'),
  missed('missed', 'Yapılmadı'),
  cancelled('cancelled', 'İptal');

  const MeetingStatus(this.db, this.trLabel);
  final String db;
  final String trLabel;

  String get label => tr(trLabel);

  static MeetingStatus? tryDb(String? v) =>
      MeetingStatus.values.where((s) => s.db == v).firstOrNull;
}

/// Koçun bir öğrenciyle planladığı görüşme: tek seferlik ya da haftalık
/// rutin ("her salı 11:00"). Saatler Türkiye saatidir; cihaz saatiyle
/// aynı kabul edilir.
class MeetingSchedule {
  const MeetingSchedule({
    required this.id,
    required this.coachId,
    required this.studentId,
    required this.firstDate,
    required this.hour,
    required this.minute,
    this.durationMin = 30,
    this.repeatWeekly = true,
    this.untilDate,
    this.note,
    this.coachName,
    this.studentName,
  });

  final String id;
  final String coachId;
  final String studentId;

  /// İlk görüşmenin günü (haftalıkta haftanın günü de budur).
  final DateTime firstDate;
  final int hour;
  final int minute;
  final int durationMin;
  final bool repeatWeekly;

  /// Rutinin bittiği gün (dahil); null ise sürüyor.
  final DateTime? untilDate;
  final String? note;
  final String? coachName;
  final String? studentName;

  /// Bu planın o gün bir görüşmesi var mı? (SQL'deki meeting_occurs_on ile aynı.)
  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(firstDate)) return false;
    if (untilDate != null && d.isAfter(untilDate!)) return false;
    final diff = d.difference(firstDate).inDays;
    return repeatWeekly ? diff % 7 == 0 : diff == 0;
  }

  /// Başlangıcı geçmiş olsa da bugünden sonra görüşmesi kalmış mı?
  bool isActiveOn(DateTime today) =>
      untilDate == null || !untilDate!.isBefore(dateOnly(today));

  /// [day] günündeki görüşmenin başlangıç anı.
  DateTime startOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  /// [from] ile [to] arasındaki (ikisi dahil) görüşme günleri.
  List<DateTime> daysBetween(DateTime from, DateTime to) {
    final start = dateOnly(from), end = dateOnly(to);
    return [
      for (
        var d = start;
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        if (occursOn(d)) d,
    ];
  }

  /// [now] anından sonraki ilk görüşmenin başlangıcı (yoksa null).
  DateTime? nextAfter(DateTime now) {
    final today = dateOnly(now);
    // Haftalıkta en fazla 7 gün, tek seferlikte ilk tarih yeter.
    final last = repeatWeekly
        ? DateTime(today.year, today.month, today.day + 7)
        : firstDate;
    for (final d in daysBetween(today, last)) {
      final at = startOn(d);
      if (at.isAfter(now)) return at;
    }
    if (repeatWeekly && today.isBefore(firstDate)) return startOn(firstDate);
    return null;
  }

  /// "Her salı 11:00" / "21 Ekim Salı 11:00" gibi kısa açıklama.
  String describe() {
    final time = formatClock(hour, minute);
    return repeatWeekly
        ? tr('Her {day} {time}', {'day': weekdayName(firstDate), 'time': time})
        : '${formatDayMonth(firstDate)} ${weekdayName(firstDate)} $time';
  }
}

/// Tek bir günün görüşmesi (plan + gün + işaretlenen durum).
class Meeting {
  const Meeting({required this.schedule, required this.day, this.status});

  final MeetingSchedule schedule;
  final DateTime day;
  final MeetingStatus? status;

  DateTime get start => schedule.startOn(day);
  String get studentName => schedule.studentName ?? '';
  String get coachName => schedule.coachName ?? '';
}

class MeetingDraft {
  const MeetingDraft({
    required this.studentId,
    required this.firstDate,
    required this.hour,
    required this.minute,
    this.durationMin = 30,
    this.repeatWeekly = true,
    this.note,
  });

  final String studentId;
  final DateTime firstDate;
  final int hour;
  final int minute;
  final int durationMin;
  final bool repeatWeekly;
  final String? note;
}

/// Haftanın pazartesisi.
DateTime weekStartOf(DateTime d) {
  final day = dateOnly(d);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

String formatClock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String weekdayName(DateTime d) => DateFormat('EEEE', localeTag).format(d);

String formatDayMonth(DateTime d) => DateFormat('d MMMM', localeTag).format(d);

/// Planlardan ve işaretli durumlardan [from]–[to] günlerinin görüşmeleri,
/// saat sırasıyla.
List<Meeting> expandMeetings(
  List<MeetingSchedule> schedules,
  Map<(String, DateTime), MeetingStatus> statuses,
  DateTime from,
  DateTime to,
) {
  final list = [
    for (final s in schedules)
      for (final d in s.daysBetween(from, to))
        Meeting(schedule: s, day: d, status: statuses[(s.id, d)]),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return list;
}

abstract interface class MeetingRepository {
  /// Görülebilen planlar ([studentId] verilirse yalnızca o öğrencininki).
  /// Koç: kendi öğrencileri; müdür: kurumu; öğrenci/veli: kendisi/çocuğu.
  Future<List<MeetingSchedule>> fetchSchedules({String? studentId});

  /// [from]–[to] günlerinde işaretlenmiş durumlar.
  Future<Map<(String, DateTime), MeetingStatus>> fetchStatuses({
    String? studentId,
    required DateTime from,
    required DateTime to,
  });

  Future<void> createSchedule(MeetingDraft draft);

  /// Rutini bitirir: hiç işaretlenmiş görüşmesi yoksa ve henüz başlamadıysa
  /// tamamen siler, yoksa bugünden sonrasını kapatır (geçmiş kayıtlar kalır).
  Future<void> endSchedule(String scheduleId);

  /// Bir günün görüşmesini işaretler (null: işareti kaldır).
  Future<void> setStatus(
    String scheduleId,
    DateTime day,
    MeetingStatus? status,
  );
}

class SupabaseMeetingRepository implements MeetingRepository {
  SupabaseMeetingRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  static DateTime _date(Object? v) => DateTime.parse(v as String);

  @override
  Future<List<MeetingSchedule>> fetchSchedules({String? studentId}) async {
    var q = _client
        .from('meeting_schedules')
        .select(
          'id, coach_id, student_id, first_date, start_time, duration_min, '
          'repeat_weekly, until_date, note, '
          'coach:profiles!meeting_schedules_coach_id_fkey(full_name), '
          'student:profiles!meeting_schedules_student_id_fkey(full_name)',
        );
    if (studentId != null) q = q.eq('student_id', studentId);
    final rows = await q.order('start_time');
    return [
      for (final r in rows)
        () {
          final time = (r['start_time'] as String).split(':');
          return MeetingSchedule(
            id: r['id'] as String,
            coachId: r['coach_id'] as String,
            studentId: r['student_id'] as String,
            firstDate: _date(r['first_date']),
            hour: int.parse(time[0]),
            minute: int.parse(time[1]),
            durationMin: r['duration_min'] as int,
            repeatWeekly: r['repeat_weekly'] as bool,
            untilDate: r['until_date'] == null ? null : _date(r['until_date']),
            note: r['note'] as String?,
            coachName: (r['coach'] as Map?)?['full_name'] as String?,
            studentName: (r['student'] as Map?)?['full_name'] as String?,
          );
        }(),
    ];
  }

  @override
  Future<Map<(String, DateTime), MeetingStatus>> fetchStatuses({
    String? studentId,
    required DateTime from,
    required DateTime to,
  }) async {
    var q = _client
        .from('meeting_occurrences')
        .select('schedule_id, occurs_on, status')
        .not('status', 'is', null)
        .gte('occurs_on', isoDate(from))
        .lte('occurs_on', isoDate(to));
    if (studentId != null) q = q.eq('student_id', studentId);
    final rows = await q;
    return {
      for (final r in rows)
        (r['schedule_id'] as String, _date(r['occurs_on'])):
            MeetingStatus.tryDb(r['status'] as String?)!,
    };
  }

  @override
  Future<void> createSchedule(MeetingDraft d) =>
      _client.from('meeting_schedules').insert({
        'coach_id': _uid,
        'student_id': d.studentId,
        'first_date': isoDate(d.firstDate),
        'start_time': formatClock(d.hour, d.minute),
        'duration_min': d.durationMin,
        'repeat_weekly': d.repeatWeekly,
        'note': d.note,
      });

  @override
  Future<void> endSchedule(String scheduleId) async {
    final today = dateOnly(DateTime.now());
    final s = await _client
        .from('meeting_schedules')
        .select('first_date')
        .eq('id', scheduleId)
        .single();
    final marked = await _client
        .from('meeting_occurrences')
        .select('occurs_on')
        .eq('schedule_id', scheduleId)
        .not('status', 'is', null)
        .limit(1);
    if (marked.isEmpty && !_date(s['first_date']).isBefore(today)) {
      await _client.from('meeting_schedules').delete().eq('id', scheduleId);
    } else {
      await _client
          .from('meeting_schedules')
          .update({'until_date': isoDate(today)})
          .eq('id', scheduleId);
    }
  }

  @override
  Future<void> setStatus(
    String scheduleId,
    DateTime day,
    MeetingStatus? status,
  ) => _client.rpc(
    'set_meeting_status',
    params: {
      'p_schedule': scheduleId,
      'p_day': isoDate(day),
      'p_status': status?.db,
    },
  );
}

final meetingRepositoryProvider = Provider<MeetingRepository>(
  (ref) => SupabaseMeetingRepository(ref.watch(supabaseClientProvider)),
);

/// Bir öğrencinin (ya da null: görülebilen tüm öğrencilerin) planları.
final meetingSchedulesProvider =
    FutureProvider.family<List<MeetingSchedule>, String?>(
      (ref, studentId) => ref
          .watch(meetingRepositoryProvider)
          .fetchSchedules(studentId: studentId),
    );

/// Bir haftanın görüşmeleri. [weekStart] pazartesi olmalı.
final weekMeetingsProvider =
    FutureProvider.family<
      List<Meeting>,
      ({String? studentId, DateTime weekStart})
    >((ref, key) async {
      final repo = ref.watch(meetingRepositoryProvider);
      final end = DateTime(
        key.weekStart.year,
        key.weekStart.month,
        key.weekStart.day + 6,
      );
      final schedules = await ref.watch(
        meetingSchedulesProvider(key.studentId).future,
      );
      final statuses = await repo.fetchStatuses(
        studentId: key.studentId,
        from: key.weekStart,
        to: end,
      );
      return expandMeetings(schedules, statuses, key.weekStart, end);
    });

/// Görüşme verisi değişince ilgili tüm sağlayıcıları yeniler.
void invalidateMeetings(WidgetRef ref) {
  ref.invalidate(meetingSchedulesProvider);
  ref.invalidate(weekMeetingsProvider);
}
