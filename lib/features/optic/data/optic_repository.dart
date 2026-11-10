import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/static_cache.dart';
import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';
import 'answer_key.dart';

/// Bir öğrencinin okunmuş optiği (sonuç tablosu ve Excel için).
class OpticSheet {
  const OpticSheet({
    required this.examId,
    required this.studentId,
    required this.answers,
    required this.readAt,
  });

  final String examId;
  final String studentId;

  /// Ders kodu → soru soru işaret (`null` boş).
  final Map<String, List<String?>> answers;
  final DateTime readAt;
}

/// Öğrencinin denemesinde bir sorunun cevabı (öğrenci ekranı).
class ExamAnswer {
  const ExamAnswer({
    required this.subject,
    required this.number,
    this.bookletNo,
    this.marked,
    this.correct,
    this.outcome,
  });

  final String subject;

  /// A kitapçığındaki numara (sınıf karşılaştırması bununla).
  final int number;

  /// B kitapçığı okuyan öğrencinin kendi kitapçığındaki numarası.
  final int? bookletNo;

  /// Öğrenciye gösterilecek numara (kendi kitapçığındaki).
  int get shownNumber => bookletNo ?? number;
  final String? marked;

  /// `null`: iptal edilen soru.
  final String? correct;
  final String? outcome;

  bool get isCorrect => correct != null && marked == correct;
  bool get isCancelled => correct == null;
}

/// `submit_optic` sonucu.
class OpticSubmitResult {
  const OpticSubmitResult({
    required this.examId,
    required this.updated,
    required this.correct,
    required this.wrong,
    required this.blank,
  });

  final String examId;

  /// Bu öğrencinin optiği daha önce okunmuştu; deneme güncellendi.
  final bool updated;
  final int correct;
  final int wrong;
  final int blank;

  double get net => calculateNet(correct, wrong);
}

/// 7 günlük düzeltme süresi geçmiş denemenin optiği yeniden okunamaz.
class OpticLockedException implements Exception {
  const OpticLockedException();
}

/// B kitapçığı okundu ama cevap anahtarında B numaraları yok.
class NoBookletBException implements Exception {
  const NoBookletBException();
}

abstract interface class OpticRepository {
  /// Kurumdaki cevap anahtarları (son eklenen önce), okunan optik sayısıyla.
  Future<List<AnswerKey>> fetchKeys();

  /// Anahtar, kazanımlarıyla.
  Future<AnswerKey> fetchKey(String id);

  Future<String> createKey({
    required String name,
    required ExamType examType,
    required String? publisher,
    required DateTime takenOn,
    required String templateId,
    required List<KeyItem> items,
  });

  Future<void> deleteKey(String id);

  /// Okunan optiği sunucuda değerlendirip öğrencinin denemesi olarak yazar.
  /// [answers] öğrencinin [booklet] kitapçığındaki sırayla. Süresi geçmişse
  /// [OpticLockedException]; anahtarın B'si yoksa [NoBookletBException].
  Future<OpticSubmitResult> submit({
    required String keyId,
    required String studentId,
    required Map<String, List<String?>> answers,
    String booklet = 'A',
  });

  /// Bu anahtarla okunmuş optikler.
  Future<List<OpticSheet>> fetchSheets(String keyId);

  /// Bir denemenin soru soru cevapları (optikten okunmadıysa boş).
  Future<List<ExamAnswer>> fetchExamAnswers(String examId);
}

String? _mark(Object? v) => v is String && v.isNotEmpty ? v : null;

class SupabaseOpticRepository implements OpticRepository {
  SupabaseOpticRepository(this._client);

  final SupabaseClient _client;
  Map<int, String>? _codes;

  /// subjects.id → kod.
  Future<Map<int, String>> _subjectCodes() async {
    if (_codes != null) return _codes!;
    final rows = await StaticCache.subjects(_client);
    return _codes = {for (final r in rows) r['id'] as int: r['code'] as String};
  }

  AnswerKey _key(Map<String, dynamic> r, {List<KeyItem> items = const []}) =>
      AnswerKey(
        id: r['id'] as String,
        name: r['name'] as String,
        examType: ExamType.fromDb(r['exam_type'] as String),
        publisher: r['publisher'] as String?,
        takenOn: DateTime.parse(r['taken_on'] as String),
        templateId: r['template_id'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        createdBy: r['created_by'] as String?,
        items: items,
        readCount: r['read_count'] as int? ?? 0,
      );

  static const _keyCols =
      'id, name, exam_type, publisher, taken_on, template_id, created_at, created_by';

  @override
  Future<List<AnswerKey>> fetchKeys() async {
    final List rows = await _client
        .from('answer_keys')
        .select(_keyCols)
        .order('created_at', ascending: false)
        .limit(50);
    if (rows.isEmpty) return const [];
    // Okunan optik sayısı: anahtarın kimliğini paket olarak taşıyan denemeler.
    final List exams = await _client.from('exams').select('batch_id').inFilter(
      'batch_id',
      [for (final r in rows) r['id']],
    );
    final counts = <String, int>{};
    for (final e in exams) {
      final b = e['batch_id'] as String;
      counts[b] = (counts[b] ?? 0) + 1;
    }
    return [
      for (final r in rows)
        _key({
          ...r as Map<String, dynamic>,
          'read_count': counts[r['id']] ?? 0,
        }),
    ];
  }

  @override
  Future<AnswerKey> fetchKey(String id) async {
    final codes = await _subjectCodes();
    final r = await _client
        .from('answer_keys')
        .select(
          '$_keyCols, answer_key_items(subject_id, question_no, question_no_b, correct, outcome, topic_id)',
        )
        .eq('id', id)
        .single();
    final items = [
      for (final i in r['answer_key_items'] as List)
        KeyItem(
          subject: codes[i['subject_id'] as int]!,
          number: i['question_no'] as int,
          numberB: i['question_no_b'] as int?,
          correct: _mark(i['correct']),
          outcome: i['outcome'] as String?,
          topicId: i['topic_id'] as int?,
        ),
    ]..sort(_byQuestion);
    return _key(r, items: items);
  }

  @override
  Future<String> createKey({
    required String name,
    required ExamType examType,
    required String? publisher,
    required DateTime takenOn,
    required String templateId,
    required List<KeyItem> items,
  }) async {
    final id = await _client.rpc(
      'create_answer_key',
      params: {
        'p_name': name.trim(),
        'p_exam_type': examType.db,
        'p_publisher': publisher,
        'p_taken_on': takenOn.toIso8601String().substring(0, 10),
        'p_template': templateId,
        'p_items': [for (final i in items) i.toJson()],
      },
    );
    return id as String;
  }

  @override
  Future<void> deleteKey(String id) =>
      _client.rpc('delete_answer_key', params: {'p_key': id});

  @override
  Future<OpticSubmitResult> submit({
    required String keyId,
    required String studentId,
    required Map<String, List<String?>> answers,
    String booklet = 'A',
  }) async {
    try {
      final r = Map<String, dynamic>.from(
        await _client.rpc(
              'submit_optic',
              params: {
                'p_key': keyId,
                'p_student': studentId,
                'p_answers': answers,
                'p_booklet': booklet,
              },
            )
            as Map,
      );
      return OpticSubmitResult(
        examId: r['exam_id'] as String,
        updated: r['updated'] as bool,
        correct: r['correct'] as int,
        wrong: r['wrong'] as int,
        blank: r['blank'] as int,
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('EXAM_LOCKED')) throw const OpticLockedException();
      if (e.message.contains('NO_B_KEY')) throw const NoBookletBException();
      rethrow;
    }
  }

  @override
  Future<List<OpticSheet>> fetchSheets(String keyId) async {
    final codes = await _subjectCodes();
    final List rows = await _client
        .from('exams')
        .select(
          'id, student_id, created_at, '
          'exam_answers(subject_id, question_no, marked)',
        )
        .eq('batch_id', keyId)
        .eq('source', 'optic');
    return [
      for (final r in rows)
        OpticSheet(
          examId: r['id'] as String,
          studentId: r['student_id'] as String,
          readAt: DateTime.parse(r['created_at'] as String).toLocal(),
          answers: _answerMap([
            for (final a in r['exam_answers'] as List)
              (
                codes[a['subject_id'] as int]!,
                a['question_no'] as int,
                _mark(a['marked']),
              ),
          ]),
        ),
    ];
  }

  @override
  Future<List<ExamAnswer>> fetchExamAnswers(String examId) async {
    final codes = await _subjectCodes();
    final List rows = await _client
        .from('exam_answers')
        .select('subject_id, question_no, booklet_no, marked, correct, outcome')
        .eq('exam_id', examId);
    final rows2 = [
      for (final r in rows)
        ExamAnswer(
          subject: codes[r['subject_id'] as int]!,
          number: r['question_no'] as int,
          bookletNo: r['booklet_no'] as int?,
          marked: _mark(r['marked']),
          correct: _mark(r['correct']),
          outcome: r['outcome'] as String?,
        ),
    ];
    return sortAnswers(rows2);
  }
}

/// Ders sırası (examSubjects), sonra soru no.
int _byQuestion(KeyItem a, KeyItem b) {
  final s =
      examSubjects.indexWhere((x) => x.code == a.subject) -
      examSubjects.indexWhere((x) => x.code == b.subject);
  return s != 0 ? s : a.number - b.number;
}

/// (ders, no, işaret) üçlülerinden ders → soru soru işaret listesi.
Map<String, List<String?>> _answerMap(List<(String, int, String?)> marks) {
  final out = <String, List<String?>>{};
  for (final (code, no, mark) in marks) {
    final list = out.putIfAbsent(code, () => []);
    while (list.length < no) {
      list.add(null);
    }
    list[no - 1] = mark;
  }
  return out;
}

/// Öğrencinin gördüğü sıra: ders sırası, sonra kendi kitapçığındaki no.
List<ExamAnswer> sortAnswers(List<ExamAnswer> list) => list
  ..sort(
    (a, b) => _byQuestion(
      KeyItem(subject: a.subject, number: a.shownNumber),
      KeyItem(subject: b.subject, number: b.shownNumber),
    ),
  );

/// Bir konuda yapılan yanlış ve boşlar (deneme detayındaki özet).
class OutcomeMistakes {
  const OutcomeMistakes({
    required this.subject,
    required this.outcome,
    required this.wrong,
    required this.blank,
    this.details = const [],
  });

  final String subject;

  /// Konu: kazanımın " — " öncesi ("Cümlede Anlam"); ayraç yoksa tamamı.
  final String outcome;
  final int wrong;
  final int blank;

  /// Konudaki kaçırılan kazanımlar ("cümle yorumlama", ...), tekrarsız.
  final List<String> details;

  int get total => wrong + blank;
}

/// Kazanım metnini konu + ayrıntı diye böler: "Paragraf — ana düşünce" →
/// ("Paragraf", "ana düşünce"). Uzun tire, kısa tire ve iki nokta ayraçtır.
(String, String?) splitOutcome(String outcome) {
  final m = RegExp(r'\s+[—–-]\s+|:\s+').firstMatch(outcome);
  if (m == null || m.start == 0) return (outcome, null);
  final detail = outcome.substring(m.end).trim();
  return (outcome.substring(0, m.start).trim(), detail.isEmpty ? null : detail);
}

/// Yanlış / boş soruları ders + konu başına toplar; en çok kaçırılan üstte,
/// eşitlikte ders sırası, sonra konu adı. Kazanımı yazılmamış sorular
/// sayılmaz.
List<OutcomeMistakes> mistakesByOutcome(List<ExamAnswer> answers) {
  final counts = <(String, String), (int, int)>{};
  final details = <(String, String), List<String>>{};
  for (final a in answers) {
    final outcome = a.outcome?.trim();
    if (a.isCancelled || a.isCorrect || outcome == null || outcome.isEmpty) {
      continue;
    }
    final (topic, detail) = splitOutcome(outcome);
    final key = (a.subject, topic);
    final (w, b) = counts[key] ?? (0, 0);
    counts[key] = a.marked == null ? (w, b + 1) : (w + 1, b);
    final list = details.putIfAbsent(key, () => []);
    if (detail != null && !list.contains(detail)) list.add(detail);
  }
  int order(String code) => examSubjects.indexWhere((x) => x.code == code);
  return [
    for (final MapEntry(key: key, value: (w, b)) in counts.entries)
      OutcomeMistakes(
        subject: key.$1,
        outcome: key.$2,
        wrong: w,
        blank: b,
        details: details[key]!,
      ),
  ]..sort((a, b) {
    final t = b.total - a.total;
    if (t != 0) return t;
    final s = order(a.subject) - order(b.subject);
    return s != 0 ? s : a.outcome.compareTo(b.outcome);
  });
}

final opticRepositoryProvider = Provider<OpticRepository>(
  (ref) => SupabaseOpticRepository(sessionClient(ref)),
);

final answerKeysProvider = FutureProvider<List<AnswerKey>>(
  (ref) => ref.watch(opticRepositoryProvider).fetchKeys(),
);

final answerKeyProvider = FutureProvider.family<AnswerKey, String>(
  (ref, id) => ref.watch(opticRepositoryProvider).fetchKey(id),
);

final opticSheetsProvider = FutureProvider.family<List<OpticSheet>, String>(
  (ref, keyId) => ref.watch(opticRepositoryProvider).fetchSheets(keyId),
);

final examAnswersProvider = FutureProvider.family<List<ExamAnswer>, String>(
  (ref, examId) => ref.watch(opticRepositoryProvider).fetchExamAnswers(examId),
);
