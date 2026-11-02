import 'dart:async';

import '../core/constants/exam_subjects.dart';
import '../features/exams/data/exam.dart';
import '../features/optic/data/answer_key.dart';
import '../features/optic/data/optic_repository.dart';
import 'demo_mode.dart';

/// Bellekte tutulan optik deposu (demo ve testler için). Okunan optikler
/// [InMemoryExamRepository]'ye anahtarın kimliğiyle paket olarak yazılır;
/// "Denemeler" ekranında da görünür.
class InMemoryOpticRepository implements OpticRepository {
  InMemoryOpticRepository(this._exams);

  final InMemoryExamRepository _exams;
  final _keys = <String, AnswerKey>{};

  /// (anahtar, öğrenci) → deneme kimliği.
  final _examOf = <(String, String), String>{};
  final _sheets = <String, OpticSheet>{};
  final _answers = <String, List<ExamAnswer>>{};
  int _next = 1;

  /// Demo: bir TYT anahtarı ve iki öğrencinin okunmuş optiği.
  factory InMemoryOpticRepository.demo(InMemoryExamRepository exams) {
    final repo = InMemoryOpticRepository(exams);
    const outcomes = {
      'TYT_TUR': ['Sözcükte anlam', 'Cümlede anlam', 'Paragraf', 'Dil bilgisi'],
      'TYT_MAT': [
        'Temel kavramlar',
        'Problemler',
        'Fonksiyonlar',
        'Trigonometri',
      ],
      'TYT_FIZ': ['Kuvvet ve hareket', 'Elektrik'],
      'TYT_KIM': ['Atom ve periyodik sistem', 'Kimyasal türler'],
      'TYT_BIY': ['Hücre', 'Kalıtım'],
    };
    final items = <KeyItem>[
      for (final s in subjectsFor(ExamType.tyt))
        for (var n = 1; n <= s.questionCount; n++)
          KeyItem(
            subject: s.code,
            number: n,
            correct: 'ABCDE'[(n * 3 + s.code.length) % 5],
            outcome: outcomes[s.code]?[n % outcomes[s.code]!.length],
          ),
    ];
    final id = repo._addKey(
      name: 'Kasım TYT-1 (optik)',
      examType: ExamType.tyt,
      publisher: 'Demo Yayınları',
      takenOn: DateTime.now().subtract(const Duration(days: 3)),
      templateId: 'mentoria_yks',
      items: items,
    );
    // Elif çoğunu doğru, Zeynep yarısını doğru işaretlemiş.
    for (final (student, every) in [('demo-student', 5), ('demo-zeynep', 2)]) {
      repo._submit(
        id,
        student,
        readAt: DateTime.now().subtract(const Duration(days: 3)),
        {
          for (final s in subjectsFor(ExamType.tyt))
            s.code: [
              for (final i in items.where((i) => i.subject == s.code))
                i.number % every == 0
                    ? (i.number % 3 == 0
                          ? null
                          : 'ABCDE'[(i.number * 3 + 1) % 5])
                    : i.correct,
            ],
        },
      );
    }
    return repo;
  }

  String _addKey({
    required String name,
    required ExamType examType,
    required String? publisher,
    required DateTime takenOn,
    required String templateId,
    required List<KeyItem> items,
  }) {
    final id = 'key-${_next++}';
    _keys[id] = AnswerKey(
      id: id,
      name: name,
      examType: examType,
      publisher: publisher,
      takenOn: takenOn,
      templateId: templateId,
      createdAt: DateTime.now(),
      items: [...items],
    );
    return id;
  }

  @override
  Future<List<AnswerKey>> fetchKeys() async => [
    for (final k in _keys.values.toList().reversed)
      AnswerKey(
        id: k.id,
        name: k.name,
        examType: k.examType,
        publisher: k.publisher,
        takenOn: k.takenOn,
        templateId: k.templateId,
        createdAt: k.createdAt,
        readCount: _examOf.keys.where((e) => e.$1 == k.id).length,
      ),
  ];

  @override
  Future<AnswerKey> fetchKey(String id) async =>
      _keys[id] ?? (throw StateError('KEY_NOT_FOUND'));

  @override
  Future<String> createKey({
    required String name,
    required ExamType examType,
    required String? publisher,
    required DateTime takenOn,
    required String templateId,
    required List<KeyItem> items,
  }) async {
    if (items.isEmpty) throw StateError('NO_ITEMS');
    return _addKey(
      name: name,
      examType: examType,
      publisher: publisher,
      takenOn: takenOn,
      templateId: templateId,
      items: items,
    );
  }

  @override
  Future<void> deleteKey(String id) async => _keys.remove(id);

  @override
  Future<OpticSubmitResult> submit({
    required String keyId,
    required String studentId,
    required Map<String, List<String?>> answers,
    String booklet = 'A',
  }) async => _submit(keyId, studentId, answers, booklet: booklet);

  OpticSubmitResult _submit(
    String keyId,
    String studentId,
    Map<String, List<String?>> answers, {
    String booklet = 'A',
    DateTime? readAt,
  }) {
    final at = readAt ?? DateTime.now();
    final key = _keys[keyId] ?? (throw StateError('KEY_NOT_FOUND'));
    if (booklet == 'B' && !key.hasBookletB) throw const NoBookletBException();
    // Kayıtlar sunucudaki gibi A numarasıyla tutulur.
    String? markOf(KeyItem i) {
      final no = i.numberIn(booklet);
      return no == null ? null : answers[i.subject]?.elementAtOrNull(no - 1);
    }

    final canonical = <String, List<String?>>{};
    for (final i in key.items) {
      final list = canonical.putIfAbsent(i.subject, () => []);
      while (list.length < i.number) {
        list.add(null);
      }
      list[i.number - 1] = markOf(i);
    }
    final previous = _examOf[(keyId, studentId)];
    if (previous != null) {
      final old = _exams
          .examsOf(studentId)
          .where((e) => e.id == previous)
          .firstOrNull;
      if (old != null && !old.editable) throw const OpticLockedException();
      unawaited(_exams.deleteExam(previous));
      _sheets.remove(previous);
      _answers.remove(previous);
    }
    final score = scoreOptic(key.items, canonical, key.examType);
    final examId = _exams.seedMine(
      studentId,
      ExamDraft(
        examType: key.examType,
        name: key.name,
        publisher: key.publisher,
        takenOn: key.takenOn,
        results: [
          for (final MapEntry(key: code, value: r) in score.bySubject.entries)
            SubjectResult(
              code: code,
              correct: r.correct,
              wrong: r.wrong,
              blank: r.blank,
            ),
        ],
      ),
      batchId: keyId,
      createdAt: at,
    );
    _examOf[(keyId, studentId)] = examId;
    _sheets[examId] = OpticSheet(
      examId: examId,
      studentId: studentId,
      answers: canonical,
      readAt: at,
    );
    _answers[examId] = [
      for (final i in key.items)
        if (key.examType == ExamType.tyt ||
            score.bySubject.containsKey(i.subject))
          ExamAnswer(
            subject: i.subject,
            number: i.number,
            bookletNo: booklet == 'B' ? i.numberB : null,
            marked: markOf(i),
            correct: i.correct,
            outcome: i.outcome,
          ),
    ];
    return OpticSubmitResult(
      examId: examId,
      updated: previous != null,
      correct: score.correct,
      wrong: score.wrong,
      blank: score.blank,
    );
  }

  @override
  Future<List<OpticSheet>> fetchSheets(String keyId) async => [
    for (final MapEntry(key: k, value: examId) in _examOf.entries)
      if (k.$1 == keyId && _sheets[examId] != null) _sheets[examId]!,
  ];

  @override
  Future<List<ExamAnswer>> fetchExamAnswers(String examId) async =>
      sortAnswers([...?_answers[examId]]);
}
