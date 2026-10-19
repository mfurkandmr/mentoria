import '../../../core/cache/static_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';
import '../../student/data/home_seed.dart';
import 'exam.dart';

abstract interface class ExamRepository {
  Future<List<Exam>> fetchExams({required String studentId});
  Future<void> createExam({
    required String studentId,
    required ExamDraft draft,
  });

  /// Düzeltme süresi geçmişse [ExamLockedException].
  Future<void> deleteExam(String examId);

  /// Kendi yüklediğim paketler (son yüklenen önce).
  Future<List<ExamBatch>> fetchMyBatches({int limit = 30, int offset = 0});

  /// Paketi içindeki tüm öğrencilerden siler; silinen deneme sayısını döner.
  /// Düzeltme süresi geçmişse [ExamLockedException].
  Future<int> deleteBatch(String batchId);
}

class SupabaseExamRepository implements ExamRepository {
  SupabaseExamRepository(this._client);

  final SupabaseClient _client;
  Map<String, int>? _subjectIds;

  Future<Map<String, int>> _loadSubjectIds() async {
    if (_subjectIds != null) return _subjectIds!;
    final rows = await StaticCache.subjects(_client);
    return _subjectIds = {
      for (final r in rows) r['code'] as String: r['id'] as int,
    };
  }

  @override
  Future<List<Exam>> fetchExams({required String studentId}) async {
    final seed = await HomeSeed.take(studentId, 'exams');
    final List rows =
        seed?.value as List? ??
        await _client
            .from('exams')
            .select(
              'id, exam_type, field, name, publisher, taken_on, created_at, '
              'exam_subject_results(correct, wrong, blank, subjects(code))',
            )
            .eq('student_id', studentId)
            .order('taken_on', ascending: false)
            // Aynı gündeki denemelerde en son girilen önce gelsin.
            .order('created_at', ascending: false);

    return [
      for (final r in rows)
        Exam(
          id: r['id'] as String,
          examType: ExamType.fromDb(r['exam_type'] as String),
          field: FieldType.fromDb(r['field'] as String?),
          name: r['name'] as String,
          publisher: r['publisher'] as String?,
          takenOn: DateTime.parse(r['taken_on'] as String),
          createdAt: r['created_at'] == null
              ? null
              : DateTime.parse(r['created_at'] as String),
          results: [
            for (final s in r['exam_subject_results'] as List)
              SubjectResult(
                code: (s['subjects'] as Map)['code'] as String,
                correct: s['correct'] as int,
                wrong: s['wrong'] as int,
                blank: s['blank'] as int,
              ),
          ],
        ),
    ];
  }

  @override
  Future<void> createExam({
    required String studentId,
    required ExamDraft draft,
  }) async {
    final ids = await _loadSubjectIds();
    final exam = await _client
        .from('exams')
        .insert({
          'student_id': studentId,
          'exam_type': draft.examType.db,
          'field': draft.field?.db,
          'name': draft.name,
          'publisher': draft.publisher,
          'taken_on': draft.takenOn.toIso8601String().substring(0, 10),
          'source': draft.imported ? 'import' : 'manual',
          'batch_id': ?draft.batchId,
        })
        .select('id')
        .single();
    final examId = exam['id'] as String;

    try {
      await _client.from('exam_subject_results').insert([
        for (final r in draft.results)
          {
            'exam_id': examId,
            'subject_id': ids[r.code],
            'correct': r.correct,
            'wrong': r.wrong,
            'blank': r.blank,
          },
      ]);
    } catch (_) {
      // Sonuçlar kaydedilemezse yarım kalmış denemeyi geri al.
      await _client.from('exams').delete().eq('id', examId);
      rethrow;
    }
  }

  @override
  Future<void> deleteExam(String examId) async {
    // RLS eski denemeyi sessizce atlar: silinen satır yoksa kilitlidir.
    final rows = await _client
        .from('exams')
        .delete()
        .eq('id', examId)
        .select('id');
    if (rows.isEmpty) throw const ExamLockedException();
  }

  @override
  Future<List<ExamBatch>> fetchMyBatches({
    int limit = 30,
    int offset = 0,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'my_exam_batches',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    return [
      for (final r in rows)
        ExamBatch.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<int> deleteBatch(String batchId) async {
    try {
      return await _client.rpc<int>(
        'delete_exam_batch',
        params: {'p_batch': batchId},
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('EXAM_LOCKED')) {
        throw const ExamLockedException();
      }
      rethrow;
    }
  }
}

final examRepositoryProvider = Provider<ExamRepository>(
  (ref) => SupabaseExamRepository(ref.watch(supabaseClientProvider)),
);

/// Bir öğrencinin tüm denemeleri (yeniden eskiye). RLS sayesinde öğrenci
/// yalnızca kendisininkini, koç yalnızca kendi öğrencilerininkini görür.
final examsForStudentProvider = FutureProvider.family<List<Exam>, String>((
  ref,
  studentId,
) {
  return ref.watch(examRepositoryProvider).fetchExams(studentId: studentId);
});

/// Kendi yüklediğim deneme paketleri (Denemeler ekranı).
final myExamBatchesProvider = FutureProvider<List<ExamBatch>>(
  (ref) => ref.watch(examRepositoryProvider).fetchMyBatches(),
);
