import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

export '../../meetings/data/meeting_repository.dart' show weekStartOf;

/// Haftalık çalışma planı: koç (ya da müdür) öğrencinin günlerine madde
/// yazar, öğrenci "yaptım" diye işaretler. Hafta pazartesi başlar.
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
  final DateTime? doneAt;

  bool get done => doneAt != null;

  PlanDraft toDraft(DateTime newDay) => PlanDraft(
    day: newDay,
    subject: subject,
    topic: topic,
    questionCount: questionCount,
    minutes: minutes,
    note: note,
  );
}

class PlanDraft {
  const PlanDraft({
    required this.day,
    required this.subject,
    this.topic,
    this.questionCount,
    this.minutes,
    this.note,
  });

  final DateTime day;
  final String subject;
  final String? topic;
  final int? questionCount;
  final int? minutes;
  final String? note;
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
          'id, student_id, day, subject_code, topic, question_count, minutes, note, done_at',
        )
        .eq('student_id', studentId)
        .gte('day', _ymd(weekStart))
        .lte('day', _ymd(weekStart.add(const Duration(days: 6))))
        .order('day')
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
  (ref) => SupabasePlanRepository(ref.watch(supabaseClientProvider)),
);

final planWeekProvider =
    FutureProvider.family<List<PlanItem>, (String, DateTime)>(
      (ref, key) => ref.watch(planRepositoryProvider).fetchWeek(key.$1, key.$2),
    );
