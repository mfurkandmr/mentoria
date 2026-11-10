import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

export '../../meetings/data/meeting_repository.dart' show weekStartOf;

/// Haftalık çalışma planı: koç (ya da müdür) öğrencinin günlerine madde
/// yazar, öğrenci "yaptım" diye işaretler. Öğrenci kendi programını da
/// yapabilir (kendi eklediğini siler). Hafta pazartesi başlar.
class PlanItem {
  const PlanItem({
    required this.id,
    required this.studentId,
    required this.day,
    required this.subject,
    this.topic,
    this.questionCount,
    this.minutes,
    this.note,
    this.startTime,
    this.createdBy,
    this.doneAt,
  });

  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
    id: j['id'] as String,
    studentId: j['student_id'] as String,
    day: DateTime.parse(j['day'] as String),
    subject: j['subject_code'] as String,
    topic: j['topic'] as String?,
    questionCount: j['question_count'] as int?,
    minutes: j['minutes'] as int?,
    note: j['note'] as String?,
    // Sunucu "09:00:00" döner; "09:00" yeter.
    startTime: (j['start_time'] as String?)?.substring(0, 5),
    createdBy: j['created_by'] as String?,
    doneAt: j['done_at'] == null
        ? null
        : DateTime.parse(j['done_at'] as String).toLocal(),
  );

  final String id;
  final String studentId;
  final DateTime day;
  final String subject;
  final String? topic;
  final int? questionCount;
  final int? minutes;
  final String? note;

  /// Başlangıç saati, "HH:mm".
  final String? startTime;
  final String? createdBy;
  final DateTime? doneAt;

  bool get done => doneAt != null;

  /// Öğrencinin kendi eklediği madde (koç / müdür değil).
  bool get bySelf => createdBy == studentId;

  /// "09:00–09:45" (süre varsa) ya da "09:00".
  String? get timeRange {
    final s = startTime;
    if (s == null) return null;
    if (minutes == null) return s;
    final start = int.parse(s.substring(0, 2)) * 60 + int.parse(s.substring(3));
    final end = (start + minutes!) % (24 * 60);
    String hm(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return '$s–${hm(end)}';
  }

  PlanDraft toDraft(DateTime newDay) => PlanDraft(
    day: newDay,
    subject: subject,
    topic: topic,
    questionCount: questionCount,
    minutes: minutes,
    note: note,
    startTime: startTime,
  );
}

/// Gün içinde sıralama: saatli maddeler saate göre önce, saatsizler sonra.
int comparePlanItems(PlanItem a, PlanItem b) {
  final d = a.day.compareTo(b.day);
  if (d != 0) return d;
  final at = a.startTime, bt = b.startTime;
  return switch ((at, bt)) {
    (final x?, final y?) => x.compareTo(y),
    (null, null) => 0,
    (null, _) => 1,
    (_, null) => -1,
  };
}

class PlanDraft {
  const PlanDraft({
    required this.day,
    required this.subject,
    this.topic,
    this.questionCount,
    this.minutes,
    this.note,
    this.startTime,
  });

  final DateTime day;
  final String subject;
  final String? topic;
  final int? questionCount;
  final int? minutes;
  final String? note;

  /// "HH:mm".
  final String? startTime;
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Sunucunun reddettiği durumlar.
class PlanException implements Exception {
  const PlanException(this.code);

  /// `PLAN_DAY_FULL`, `PLAN_DAY_PAST` ya da boş.
  final String code;
}

abstract interface class PlanRepository {
  /// [weekStart] pazartesisinden başlayan 7 günün maddeleri.
  Future<List<PlanItem>> fetchWeek(String studentId, DateTime weekStart);
  Future<void> add(String studentId, PlanDraft draft);
  Future<void> delete(String itemId);
  Future<void> setDone(String itemId, bool done);
}

class SupabasePlanRepository implements PlanRepository {
  SupabasePlanRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PlanItem>> fetchWeek(String studentId, DateTime weekStart) async {
    final rows = await _client
        .from('plan_items')
        .select(
          'id, student_id, created_by, day, subject_code, topic, question_count, minutes, note, start_time, done_at',
        )
        .eq('student_id', studentId)
        .gte('day', _ymd(weekStart))
        .lte('day', _ymd(weekStart.add(const Duration(days: 6))))
        .order('day')
        .order('start_time', nullsFirst: false)
        .order('created_at');
    return [for (final r in rows) PlanItem.fromJson(r)];
  }

  @override
  Future<void> add(String studentId, PlanDraft d) async {
    try {
      await _client.from('plan_items').insert({
        'student_id': studentId,
        'day': _ymd(d.day),
        'subject_code': d.subject,
        'topic': d.topic,
        'question_count': d.questionCount,
        'minutes': d.minutes,
        'note': d.note,
        'start_time': d.startTime,
      });
    } on PostgrestException catch (e) {
      final code = [
        'PLAN_DAY_FULL',
        'PLAN_DAY_PAST',
      ].where((c) => e.message.contains(c)).firstOrNull;
      throw PlanException(code ?? '');
    }
  }

  @override
  Future<void> delete(String itemId) =>
      _client.from('plan_items').delete().eq('id', itemId);

  @override
  Future<void> setDone(String itemId, bool done) => _client
      .from('plan_items')
      .update({
        'done_at': done ? DateTime.now().toUtc().toIso8601String() : null,
      })
      .eq('id', itemId);
}

final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => SupabasePlanRepository(sessionClient(ref)),
);

final planWeekProvider =
    FutureProvider.family<List<PlanItem>, (String, DateTime)>(
      (ref, key) => ref.watch(planRepositoryProvider).fetchWeek(key.$1, key.$2),
    );
