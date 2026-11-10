import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/static_cache.dart';
import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/exam_definition.dart';
import '../domain/import_plan.dart';
import '../domain/optic_result_parser.dart';

/// Sınıf (sınavın uygulandığı sınıflar, sınıf raporu).
class ClassroomRef {
  const ClassroomRef({required this.id, required this.name});
  final String id;
  final String name;
}

/// Sunucuya giden bir optik: öğrenci, kitapçık, cevaplar.
class SheetUpload {
  const SheetUpload({
    required this.studentId,
    required this.booklet,
    required this.answers,
  });

  final String studentId;
  final String booklet;
  final Map<String, List<String?>> answers;

  Map<String, Object?> toJson() => {
    'student_id': studentId,
    'booklet': booklet,
    'answers': answers,
  };
}

/// İçe aktarma özeti.
class ImportOutcome {
  const ImportOutcome({
    required this.saved,
    required this.skipped,
    required this.sheets,
    required this.published,
  });

  final int saved;

  /// Sunucunun atladığı öğrenci kimlikleri (kurumda değil, kitapçık yok).
  final List<String> skipped;

  /// Sınavdaki toplam optik.
  final int sheets;
  final bool published;
}

/// Kazanım havuzu toplu ekleme satırı.
class OutcomeImportRow {
  const OutcomeImportRow({
    required this.subject,
    required this.topic,
    this.subtopic,
    this.code,
  });

  final String subject;
  final String topic;
  final String? subtopic;
  final String? code;

  Map<String, Object?> toJson() => {
    'subject': subject,
    'topic': topic,
    'subtopic': subtopic,
    'code': code,
  };
}

class ExamLockedTypeException implements Exception {
  const ExamLockedTypeException();
}

abstract interface class ExamAdminRepository {
  /// Kurumun sınavları (son eklenen önce), optik sayısıyla; soru yok.
  Future<List<ExamDefinition>> fetchExams();

  /// Sınav, dersleri, anahtarları ve kitapçıklarıyla.
  Future<ExamDefinition> fetchExam(String id);

  /// Yeni sınav taslak olarak eklenir; kimliği döner. Yayındaki sınav
  /// kaydedilince sunucu tüm optikleri yeniden puanlar.
  Future<String> saveExam(ExamDefinition exam);

  /// Taslağı yayınlar; puanlanan optik sayısı döner.
  Future<int> publishExam(String id);

  Future<void> deleteExam(String id);

  Future<List<ClassroomRef>> fetchClassrooms();

  Future<List<LearningOutcome>> fetchOutcomes();
  Future<LearningOutcome> addOutcome({
    required String subject,
    required String name,
    String? parentId,
    String? code,
  });
  Future<void> updateOutcome(String id, {required String name, String? code});
  Future<void> deleteOutcome(String id);
  Future<({int inserted, int skipped})> importOutcomes(
    List<OutcomeImportRow> rows,
  );

  Future<List<ImportTemplate>> fetchTemplates();
  Future<ImportTemplate> saveTemplate(ImportTemplate template);

  /// Kurumun bütün öğrencileri (numara eşleştirmesi).
  Future<List<RosterStudent>> fetchRoster();

  /// Sınavdaki optik (öğrenci) sayısı — "üzerine yazılsın mı?" sorusu için.
  Future<int> sheetCount(String examId);

  /// Optikleri 25'lik parçalarla yükler; [onProgress] 0-1.
  Future<ImportOutcome> importSheets({
    required String examId,
    required String fileName,
    required Map<String, Object?> stats,
    required List<SheetUpload> sheets,
    void Function(double progress)? onProgress,
  });
}

/// Bir parçadaki optik sayısı (sunucu en çok 100 kabul eder; zaman aşımına
/// karşı küçük tutulur).
const importChunk = 25;

class SupabaseExamAdminRepository implements ExamAdminRepository {
  SupabaseExamAdminRepository(this._client);

  final SupabaseClient _client;
  Map<int, String>? _codes;

  Future<Map<int, String>> _subjectCodes() async {
    if (_codes != null) return _codes!;
    final rows = await StaticCache.subjects(_client);
    return _codes = {for (final r in rows) r['id'] as int: r['code'] as String};
  }

  static const _cols =
      'id, name, exam_type, kind, publisher, taken_on, status, wrong_penalty, '
      'penalty_ratio, created_by, template_id';

  ExamDefinition _header(Map<String, dynamic> r, {int sheets = 0}) =>
      ExamDefinition(
        id: r['id'] as String,
        name: r['name'] as String,
        examType: ExamType.fromDb(r['exam_type'] as String),
        kind: ExamKind.fromDb(r['kind'] as String?),
        publisher: r['publisher'] as String?,
        takenOn: DateTime.parse(r['taken_on'] as String),
        status: ExamStatus.fromDb(r['status'] as String?),
        wrongPenalty: r['wrong_penalty'] as bool? ?? true,
        penaltyRatio: (r['penalty_ratio'] as num?)?.toDouble() ?? 0.25,
        templateId: r['template_id'] as String? ?? 'standart_yks',
        sheetCount: sheets,
      );

  @override
  Future<List<ExamDefinition>> fetchExams() async {
    final List rows = await _client
        .from('answer_keys')
        .select('$_cols, exam_sheets(count)')
        .order('taken_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(100);
    return [
      for (final r in rows)
        _header(
          r as Map<String, dynamic>,
          sheets:
              ((r['exam_sheets'] as List?)?.firstOrNull as Map?)?['count']
                  as int? ??
              0,
        ),
    ];
  }

  @override
  Future<ExamDefinition> fetchExam(String id) async {
    final codes = await _subjectCodes();
    final r = await _client
        .from('answer_keys')
        .select(
          '$_cols, exam_sheets(count), '
          'answer_key_subjects(subject_id, question_count, sort, weight), '
          'answer_key_items(subject_id, question_no, correct, outcome, outcome_id, topic_id, difficulty, cancelled), '
          'answer_key_booklets(subject_id, booklet, question_no, item_no, correct), '
          'answer_key_classrooms(classroom_id)',
        )
        .eq('id', id)
        .single();
    final subjects = [...r['answer_key_subjects'] as List]
      ..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    final booklets = <String, List<BookletQuestion>>{};
    for (final b in r['answer_key_booklets'] as List) {
      booklets
          .putIfAbsent(b['booklet'] as String, () => [])
          .add(
            BookletQuestion(
              subject: codes[b['subject_id'] as int]!,
              number: b['question_no'] as int,
              itemNo: b['item_no'] as int,
              correct: b['correct'] as String?,
            ),
          );
    }
    for (final list in booklets.values) {
      list.sort((a, b) => a.number - b.number);
    }
    return _header(
      r,
      sheets:
          ((r['exam_sheets'] as List?)?.firstOrNull as Map?)?['count']
              as int? ??
          0,
    ).copyWith(
      classroomIds: [
        for (final c in r['answer_key_classrooms'] as List)
          c['classroom_id'] as String,
      ],
      subjects: [
        for (final s in subjects)
          ExamSubjectDef(
            code: codes[s['subject_id'] as int]!,
            questionCount: s['question_count'] as int,
            weight: (s['weight'] as num).toDouble(),
          ),
      ],
      questions: [
        for (final i in r['answer_key_items'] as List)
          KeyQuestion(
            subject: codes[i['subject_id'] as int]!,
            number: i['question_no'] as int,
            correct: i['correct'] as String?,
            outcome: i['outcome'] as String?,
            outcomeId: i['outcome_id'] as String?,
            topicId: i['topic_id'] as int?,
            difficulty: Difficulty.fromDb(i['difficulty'] as String?),
            cancelled: i['cancelled'] as bool? ?? false,
          ),
      ]..sort((a, b) => a.number - b.number),
      booklets: booklets,
    );
  }

  @override
  Future<String> saveExam(ExamDefinition exam) async {
    try {
      final id = await _client.rpc(
        'save_exam',
        params: {'p_key': exam.id, 'p_def': exam.toJson()},
      );
      return id as String;
    } on PostgrestException catch (e) {
      if (e.message.contains('TYPE_LOCKED')) {
        throw const ExamLockedTypeException();
      }
      rethrow;
    }
  }

  @override
  Future<int> publishExam(String id) async =>
      (await _client.rpc('publish_exam', params: {'p_key': id})) as int;

  @override
  Future<void> deleteExam(String id) =>
      _client.rpc('delete_answer_key', params: {'p_key': id});

  @override
  Future<List<ClassroomRef>> fetchClassrooms() async {
    final List rows = await _client
        .from('classrooms')
        .select('id, name')
        .order('name');
    return [
      for (final r in rows)
        ClassroomRef(id: r['id'] as String, name: r['name'] as String),
    ];
  }

  LearningOutcome _outcome(Map<String, dynamic> r, Map<int, String> codes) =>
      LearningOutcome(
        id: r['id'] as String,
        subject: codes[r['subject_id'] as int]!,
        name: r['name'] as String,
        parentId: r['parent_id'] as String?,
        code: r['code'] as String?,
        topicId: r['topic_id'] as int?,
      );

  @override
  Future<List<LearningOutcome>> fetchOutcomes() async {
    final codes = await _subjectCodes();
    final List rows = await _client
        .from('learning_outcomes')
        .select('id, subject_id, parent_id, name, code, topic_id')
        .order('name')
        .limit(5000);
    return [for (final r in rows) _outcome(r as Map<String, dynamic>, codes)];
  }

  @override
  Future<LearningOutcome> addOutcome({
    required String subject,
    required String name,
    String? parentId,
    String? code,
  }) async {
    final codes = await _subjectCodes();
    final id = codes.entries.firstWhere((e) => e.value == subject).key;
    final r = await _client
        .from('learning_outcomes')
        .insert({
          'subject_id': id,
          'name': name.trim(),
          'parent_id': parentId,
          'code': code,
        })
        .select('id, subject_id, parent_id, name, code, topic_id')
        .single();
    return _outcome(r, codes);
  }

  @override
  Future<void> updateOutcome(String id, {required String name, String? code}) =>
      _client
          .from('learning_outcomes')
          .update({'name': name.trim(), 'code': code})
          .eq('id', id);

  @override
  Future<void> deleteOutcome(String id) =>
      _client.from('learning_outcomes').delete().eq('id', id);

  @override
  Future<({int inserted, int skipped})> importOutcomes(
    List<OutcomeImportRow> rows,
  ) async {
    final r = Map<String, dynamic>.from(
      await _client.rpc(
            'import_learning_outcomes',
            params: {
              'p_rows': [for (final x in rows) x.toJson()],
            },
          )
          as Map,
    );
    return (inserted: r['inserted'] as int, skipped: r['skipped'] as int);
  }

  @override
  Future<List<ImportTemplate>> fetchTemplates() async {
    final List rows = await _client
        .from('import_templates')
        .select('id, name, mapping')
        .order('updated_at', ascending: false);
    return [
      for (final r in rows)
        ImportTemplate.fromJson(
          Map<String, dynamic>.from(r['mapping'] as Map),
          id: r['id'] as String,
          name: r['name'] as String,
        ),
    ];
  }

  @override
  Future<ImportTemplate> saveTemplate(ImportTemplate template) async {
    final body = {'name': template.name.trim(), 'mapping': template.toJson()};
    // Aynı adlı şablon varsa üzerine yazılır (ad yazım farkı gözetmeden tekil).
    var id = template.id;
    if (id == null) {
      for (final t in await fetchTemplates()) {
        if (foldTr(t.name) == foldTr(template.name)) id = t.id;
      }
    }
    final r = id == null
        ? await _client
              .from('import_templates')
              .insert(body)
              .select('id')
              .single()
        : await _client
              .from('import_templates')
              .update(body)
              .eq('id', id)
              .select('id')
              .single();
    return template.copyWith(id: r['id'] as String);
  }

  @override
  Future<List<RosterStudent>> fetchRoster() async {
    final List rows = await _client.rpc('exam_import_roster');
    return [
      for (final r in rows)
        RosterStudent(
          id: r['student_id'] as String,
          name: r['full_name'] as String? ?? '',
          number: r['student_number'] as String?,
          className: r['classroom_name'] as String?,
        ),
    ];
  }

  @override
  Future<int> sheetCount(String examId) async {
    final r = await _client
        .from('exam_sheets')
        .select('student_id')
        .eq('key_id', examId)
        .count(CountOption.exact);
    return r.count;
  }

  @override
  Future<ImportOutcome> importSheets({
    required String examId,
    required String fileName,
    required Map<String, Object?> stats,
    required List<SheetUpload> sheets,
    void Function(double progress)? onProgress,
  }) async {
    final importId =
        await _client.rpc(
              'start_exam_import',
              params: {'p_key': examId, 'p_file': fileName, 'p_stats': stats},
            )
            as String;
    final skipped = <String>[];
    var saved = 0;
    for (var i = 0; i < sheets.length; i += importChunk) {
      final chunk = sheets.sublist(
        i,
        i + importChunk > sheets.length ? sheets.length : i + importChunk,
      );
      final r = Map<String, dynamic>.from(
        await _client.rpc(
              'import_exam_sheets',
              params: {
                'p_import': importId,
                'p_rows': [for (final s in chunk) s.toJson()],
              },
            )
            as Map,
      );
      saved += r['saved'] as int;
      for (final s in r['skipped'] as List) {
        skipped.add((s as Map)['student_id'] as String);
      }
      onProgress?.call((i + chunk.length) / sheets.length);
    }
    final fin = Map<String, dynamic>.from(
      await _client.rpc('finish_exam_import', params: {'p_import': importId})
          as Map,
    );
    return ImportOutcome(
      saved: saved,
      skipped: skipped,
      sheets: fin['sheets'] as int,
      published: fin['published'] as bool,
    );
  }
}

final examAdminRepositoryProvider = Provider<ExamAdminRepository>(
  (ref) => SupabaseExamAdminRepository(sessionClient(ref)),
);

final orgExamsProvider = FutureProvider<List<ExamDefinition>>(
  (ref) => ref.watch(examAdminRepositoryProvider).fetchExams(),
);

final orgExamProvider = FutureProvider.family<ExamDefinition, String>(
  (ref, id) => ref.watch(examAdminRepositoryProvider).fetchExam(id),
);

final learningOutcomesProvider = FutureProvider<OutcomeTree>(
  (ref) async =>
      OutcomeTree(await ref.watch(examAdminRepositoryProvider).fetchOutcomes()),
);

final examClassroomsProvider = FutureProvider<List<ClassroomRef>>(
  (ref) => ref.watch(examAdminRepositoryProvider).fetchClassrooms(),
);

final importTemplatesProvider = FutureProvider<List<ImportTemplate>>(
  (ref) => ref.watch(examAdminRepositoryProvider).fetchTemplates(),
);
