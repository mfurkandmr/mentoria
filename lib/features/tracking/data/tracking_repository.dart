import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import 'tracking_models.dart';

/// Soru, konu, çalışma süresi ve hedef verileri.
abstract interface class TrackingRepository {
  Future<List<QuestionLog>> fetchQuestionLogs(
    String studentId, {
    required DateTime since,
  });
  Future<void> addQuestionLog(String studentId, QuestionLogDraft draft);
  Future<void> deleteQuestionLog(String id);

  Future<List<Topic>> fetchTopics();
  Future<Map<int, TopicStatus>> fetchTopicProgress(String studentId);
  Future<void> setTopicStatus(String studentId, int topicId, TopicStatus s);

  Future<List<StudySession>> fetchSessions(
    String studentId, {
    required DateTime since,
  });
  Future<void> addSession(
    String studentId, {
    required SessionType type,
    required DateTime startedAt,
    required int durationSec,
    String? subjectCode,
  });
  Future<void> deleteSession(String id);

  Future<Goals> fetchGoals(String studentId);
  Future<void> saveGoals(String studentId, Goals goals);
}

class SupabaseTrackingRepository implements TrackingRepository {
  SupabaseTrackingRepository(this._client);

  final SupabaseClient _client;
  Map<String, int>? _idByCode;
  Map<int, String>? _codeById;

  Future<void> _loadSubjects() async {
    if (_idByCode != null) return;
    final rows = await _client.from('subjects').select('id, code');
    _idByCode = {for (final r in rows) r['code'] as String: r['id'] as int};
    _codeById = {for (final e in _idByCode!.entries) e.value: e.key};
  }

  @override
  Future<List<QuestionLog>> fetchQuestionLogs(
    String studentId, {
    required DateTime since,
  }) async {
    final rows = await _client
        .from('question_logs')
        .select(
          'id, correct, wrong, blank, logged_on, source, topic_id, '
          'subjects(code), topics(name)',
        )
        .eq('student_id', studentId)
        .gte('logged_on', isoDate(since))
        .order('logged_on', ascending: false)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        QuestionLog(
          id: r['id'] as String,
          subjectCode: (r['subjects'] as Map)['code'] as String,
          topicId: r['topic_id'] as int?,
          topicName: (r['topics'] as Map?)?['name'] as String?,
          correct: r['correct'] as int,
          wrong: r['wrong'] as int,
          blank: r['blank'] as int,
          loggedOn: DateTime.parse(r['logged_on'] as String),
          source: r['source'] as String?,
        ),
    ];
  }

  @override
  Future<void> addQuestionLog(String studentId, QuestionLogDraft d) async {
    await _loadSubjects();
    await _client.from('question_logs').insert({
      'student_id': studentId,
      'subject_id': _idByCode![d.subjectCode],
      'topic_id': d.topicId,
      'correct': d.correct,
      'wrong': d.wrong,
      'blank': d.blank,
      'logged_on': isoDate(d.loggedOn),
      'source': d.source,
    });
  }

  @override
  Future<void> deleteQuestionLog(String id) =>
      _client.from('question_logs').delete().eq('id', id);

  @override
  Future<List<Topic>> fetchTopics() async {
    await _loadSubjects();
    final rows = await _client
        .from('topics')
        .select('id, subject_id, name, sort')
        .order('sort');
    return [
      for (final r in rows)
        Topic(
          id: r['id'] as int,
          subjectCode: _codeById![r['subject_id'] as int]!,
          name: r['name'] as String,
          sort: r['sort'] as int,
        ),
    ];
  }

  @override
  Future<Map<int, TopicStatus>> fetchTopicProgress(String studentId) async {
    final rows = await _client
        .from('topic_progress')
        .select('topic_id, status')
        .eq('student_id', studentId);
    return {
      for (final r in rows)
        r['topic_id'] as int: TopicStatus.fromDb(r['status'] as String),
    };
  }

  @override
  Future<void> setTopicStatus(
    String studentId,
    int topicId,
    TopicStatus s,
  ) async {
    await _client.from('topic_progress').upsert({
      'student_id': studentId,
      'topic_id': topicId,
      'status': s.db,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<StudySession>> fetchSessions(
    String studentId, {
    required DateTime since,
  }) async {
    final rows = await _client
        .from('study_sessions')
        .select('id, type, started_at, duration_sec, subjects(code)')
        .eq('student_id', studentId)
        .gte('started_at', since.toUtc().toIso8601String())
        .order('started_at', ascending: false);
    return [
      for (final r in rows)
        StudySession(
          id: r['id'] as String,
          subjectCode: (r['subjects'] as Map?)?['code'] as String?,
          type: SessionType.fromDb(r['type'] as String),
          startedAt: DateTime.parse(r['started_at'] as String).toLocal(),
          durationSec: r['duration_sec'] as int,
        ),
    ];
  }

  @override
  Future<void> addSession(
    String studentId, {
    required SessionType type,
    required DateTime startedAt,
    required int durationSec,
    String? subjectCode,
  }) async {
    await _loadSubjects();
    await _client.from('study_sessions').insert({
      'student_id': studentId,
      'subject_id': subjectCode == null ? null : _idByCode![subjectCode],
      'type': type.db,
      'started_at': startedAt.toUtc().toIso8601String(),
      'duration_sec': durationSec,
    });
  }

  @override
  Future<void> deleteSession(String id) =>
      _client.from('study_sessions').delete().eq('id', id);

  @override
  Future<Goals> fetchGoals(String studentId) async {
    final r = await _client
        .from('goals')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();
    if (r == null) return const Goals();
    return Goals(
      dailyQuestions: r['daily_questions'] as int?,
      dailyMinutes: r['daily_minutes'] as int?,
      targetUniversity: r['target_university'] as String?,
      targetDepartment: r['target_department'] as String?,
      targetRank: r['target_rank'] as int?,
    );
  }

  @override
  Future<void> saveGoals(String studentId, Goals g) async {
    await _client.from('goals').upsert({
      'student_id': studentId,
      'daily_questions': g.dailyQuestions,
      'daily_minutes': g.dailyMinutes,
      'target_university': g.targetUniversity,
      'target_department': g.targetDepartment,
      'target_rank': g.targetRank,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => SupabaseTrackingRepository(ref.watch(supabaseClientProvider)),
);

/// Son 30 günün soru kayıtları.
final questionLogsProvider = FutureProvider.family<List<QuestionLog>, String>((
  ref,
  studentId,
) {
  final since = dateOnly(DateTime.now()).subtract(const Duration(days: 29));
  return ref
      .watch(trackingRepositoryProvider)
      .fetchQuestionLogs(studentId, since: since);
});

final topicsProvider = FutureProvider<List<Topic>>(
  (ref) => ref.watch(trackingRepositoryProvider).fetchTopics(),
);

final topicProgressProvider =
    FutureProvider.family<Map<int, TopicStatus>, String>((ref, studentId) {
      return ref
          .watch(trackingRepositoryProvider)
          .fetchTopicProgress(studentId);
    });

/// Son 30 günün çalışma oturumları.
final studySessionsProvider = FutureProvider.family<List<StudySession>, String>(
  (ref, studentId) {
    final since = dateOnly(DateTime.now()).subtract(const Duration(days: 29));
    return ref
        .watch(trackingRepositoryProvider)
        .fetchSessions(studentId, since: since);
  },
);

final goalsProvider = FutureProvider.family<Goals, String>((ref, studentId) {
  return ref.watch(trackingRepositoryProvider).fetchGoals(studentId);
});
