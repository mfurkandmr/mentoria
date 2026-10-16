import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';
import '../../tracking/data/tracking_models.dart';

/// Ödev paketindeki tek madde: bir ders, isteğe bağlı konu ve soru sayısı.
class AssignmentItem {
  const AssignmentItem({
    required this.id,
    required this.subjectCode,
    required this.done,
    this.topicId,
    this.topicName,
    this.questionCount,
    this.note,
  });

  final String id;
  final String subjectCode;
  final int? topicId;
  final String? topicName;
  final int? questionCount;
  final String? note;
  final bool done;

  String get subjectName => subjectByCode(subjectCode).name;

  /// "Parabol" ya da konu seçilmemişse "Genel tekrar".
  String get label => topicName ?? tr('Genel tekrar');

  AssignmentItem copyWith({bool? done}) => AssignmentItem(
    id: id,
    subjectCode: subjectCode,
    topicId: topicId,
    topicName: topicName,
    questionCount: questionCount,
    note: note,
    done: done ?? this.done,
  );
}

/// Koçun tek seferde gönderdiği ödev paketi.
class Assignment {
  const Assignment({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.items,
    this.note,
    this.dueOn,
    this.coachName,
  });

  final String id;
  final String title;
  final String? note;
  final DateTime? dueOn;
  final DateTime createdAt;
  final String? coachName;
  final List<AssignmentItem> items;

  int get doneCount => items.where((i) => i.done).length;
  bool get isComplete => items.isNotEmpty && doneCount == items.length;
  double get progress => items.isEmpty ? 0 : doneCount / items.length;
  int get totalQuestions => items.fold(0, (s, i) => s + (i.questionCount ?? 0));

  bool get isOverdue =>
      !isComplete && dueOn != null && dueOn!.isBefore(dateOnly(DateTime.now()));
}

/// Sepetteki (henüz gönderilmemiş) madde.
class AssignmentItemDraft {
  const AssignmentItemDraft({
    required this.subjectCode,
    this.topicId,
    this.topicName,
    this.questionCount,
    this.note,
  });

  final String subjectCode;
  final int? topicId;
  final String? topicName;
  final int? questionCount;
  final String? note;

  /// Sepette aynı ders+konu iki kez olmasın.
  String get key => '$subjectCode/${topicId ?? '-'}';

  AssignmentItemDraft copyWith({int? questionCount, String? note}) =>
      AssignmentItemDraft(
        subjectCode: subjectCode,
        topicId: topicId,
        topicName: topicName,
        questionCount: questionCount ?? this.questionCount,
        note: note ?? this.note,
      );

  Map<String, Object?> toJson() => {
    'subject_code': subjectCode,
    'topic_id': topicId,
    'question_count': questionCount,
    'note': note,
  };
}

abstract interface class AssignmentRepository {
  Future<List<Assignment>> fetchAssignments(String studentId);
  Future<void> sendAssignment({
    required String studentId,
    required String title,
    required List<AssignmentItemDraft> items,
    DateTime? dueOn,
    String? note,
  });
  Future<void> setItemDone(String itemId, bool done);
  Future<void> deleteAssignment(String assignmentId);
}

class SupabaseAssignmentRepository implements AssignmentRepository {
  SupabaseAssignmentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Assignment>> fetchAssignments(String studentId) async {
    final rows = await _client
        .from('assignments')
        .select(
          'id, title, note, due_on, created_at, '
          'coach:profiles!assignments_coach_id_fkey(full_name), '
          'assignment_items(id, question_count, note, sort, done, '
          'subjects(code), topics(id, name))',
        )
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        Assignment(
          id: r['id'] as String,
          title: r['title'] as String,
          note: r['note'] as String?,
          dueOn: r['due_on'] == null
              ? null
              : DateTime.parse(r['due_on'] as String),
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          coachName: (r['coach'] as Map?)?['full_name'] as String?,
          items: [
            for (final i in ([
              ...(r['assignment_items'] as List),
            ]..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int))))
              AssignmentItem(
                id: i['id'] as String,
                subjectCode: (i['subjects'] as Map)['code'] as String,
                topicId: (i['topics'] as Map?)?['id'] as int?,
                topicName: (i['topics'] as Map?)?['name'] as String?,
                questionCount: i['question_count'] as int?,
                note: i['note'] as String?,
                done: i['done'] as bool,
              ),
          ],
        ),
    ];
  }

  @override
  Future<void> sendAssignment({
    required String studentId,
    required String title,
    required List<AssignmentItemDraft> items,
    DateTime? dueOn,
    String? note,
  }) => _client.rpc(
    'send_assignment',
    params: {
      'p_student': studentId,
      'p_title': title,
      'p_items': [for (final i in items) i.toJson()],
      'p_due_on': dueOn == null ? null : isoDate(dueOn),
      'p_note': note,
    },
  );

  @override
  Future<void> setItemDone(String itemId, bool done) =>
      _client.from('assignment_items').update({'done': done}).eq('id', itemId);

  @override
  Future<void> deleteAssignment(String assignmentId) =>
      _client.from('assignments').delete().eq('id', assignmentId);
}

final assignmentRepositoryProvider = Provider<AssignmentRepository>(
  (ref) => SupabaseAssignmentRepository(ref.watch(supabaseClientProvider)),
);

final assignmentsProvider = FutureProvider.family<List<Assignment>, String>((
  ref,
  studentId,
) {
  return ref.watch(assignmentRepositoryProvider).fetchAssignments(studentId);
});
