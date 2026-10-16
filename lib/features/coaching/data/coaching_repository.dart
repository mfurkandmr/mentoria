import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../../tracking/data/tracking_models.dart';
import '../../../core/i18n/i18n.dart';

enum TaskStatus {
  pending('pending', 'Bekliyor'),
  done('done', 'Tamamlandı'),
  skipped('skipped', 'Yapılmadı');

  const TaskStatus(this.db, this.trLabel);
  final String db;
  final String trLabel;

  String get label => tr(trLabel);

  static TaskStatus fromDb(String v) =>
      TaskStatus.values.firstWhere((s) => s.db == v);
}

/// Koçun öğrenciye verdiği görev.
class CoachTask {
  const CoachTask({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.description,
    this.subjectCode,
    this.targetQuestions,
    this.dueOn,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? subjectCode;
  final int? targetQuestions;
  final DateTime? dueOn;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isOverdue =>
      status == TaskStatus.pending &&
      dueOn != null &&
      dueOn!.isBefore(dateOnly(DateTime.now()));
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    this.description,
    this.subjectCode,
    this.targetQuestions,
    this.dueOn,
  });

  final String title;
  final String? description;
  final String? subjectCode;
  final int? targetQuestions;
  final DateTime? dueOn;
}

class CoachNote {
  const CoachNote({
    required this.id,
    required this.body,
    required this.createdAt,
    this.coachName,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String? coachName;
}

abstract interface class CoachingRepository {
  Future<List<CoachTask>> fetchTasks(String studentId);
  Future<void> createTask(String studentId, TaskDraft draft);
  Future<void> setTaskStatus(String taskId, TaskStatus status);
  Future<void> deleteTask(String taskId);

  Future<List<CoachNote>> fetchNotes(String studentId);
  Future<void> addNote(String studentId, String body);
  Future<void> deleteNote(String noteId);
}

class SupabaseCoachingRepository implements CoachingRepository {
  SupabaseCoachingRepository(this._client);

  final SupabaseClient _client;
  Map<String, int>? _idByCode;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<List<CoachTask>> fetchTasks(String studentId) async {
    final rows = await _client
        .from('tasks')
        .select(
          'id, title, description, target_questions, due_on, status, '
          'created_at, completed_at, subjects(code)',
        )
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        CoachTask(
          id: r['id'] as String,
          title: r['title'] as String,
          description: r['description'] as String?,
          subjectCode: (r['subjects'] as Map?)?['code'] as String?,
          targetQuestions: r['target_questions'] as int?,
          dueOn: r['due_on'] == null
              ? null
              : DateTime.parse(r['due_on'] as String),
          status: TaskStatus.fromDb(r['status'] as String),
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          completedAt: r['completed_at'] == null
              ? null
              : DateTime.parse(r['completed_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<void> createTask(String studentId, TaskDraft d) async {
    if (d.subjectCode != null && _idByCode == null) {
      final rows = await _client.from('subjects').select('id, code');
      _idByCode = {for (final r in rows) r['code'] as String: r['id'] as int};
    }
    await _client.from('tasks').insert({
      'coach_id': _uid,
      'student_id': studentId,
      'title': d.title,
      'description': d.description,
      'subject_id': d.subjectCode == null ? null : _idByCode![d.subjectCode],
      'target_questions': d.targetQuestions,
      'due_on': d.dueOn == null ? null : isoDate(d.dueOn!),
    });
  }

  @override
  Future<void> setTaskStatus(String taskId, TaskStatus status) =>
      _client.from('tasks').update({'status': status.db}).eq('id', taskId);

  @override
  Future<void> deleteTask(String taskId) =>
      _client.from('tasks').delete().eq('id', taskId);

  @override
  Future<List<CoachNote>> fetchNotes(String studentId) async {
    final rows = await _client
        .from('coach_notes')
        .select('id, body, created_at, coach_id')
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        CoachNote(
          id: r['id'] as String,
          body: r['body'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<void> addNote(String studentId, String body) => _client
      .from('coach_notes')
      .insert({'coach_id': _uid, 'student_id': studentId, 'body': body});

  @override
  Future<void> deleteNote(String noteId) =>
      _client.from('coach_notes').delete().eq('id', noteId);
}

final coachingRepositoryProvider = Provider<CoachingRepository>(
  (ref) => SupabaseCoachingRepository(ref.watch(supabaseClientProvider)),
);

final tasksProvider = FutureProvider.family<List<CoachTask>, String>((
  ref,
  studentId,
) {
  return ref.watch(coachingRepositoryProvider).fetchTasks(studentId);
});

final notesProvider = FutureProvider.family<List<CoachNote>, String>((
  ref,
  studentId,
) {
  return ref.watch(coachingRepositoryProvider).fetchNotes(studentId);
});
