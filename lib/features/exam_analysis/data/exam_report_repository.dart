import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/static_cache.dart';
import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';
import '../../exam_import/domain/exam_scorer.dart';
import '../domain/outcome_analysis.dart';

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
double? _dn(Object? v) => (v as num?)?.toDouble();

/// Karnede bir ders.
class CardSubject {
  const CardSubject({
    required this.subject,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.net,
    this.weight = 1,
    this.rankOrg,
    this.rankClass,
    this.orgAvg,
    this.classAvg,
    this.previousNet,
  });

  final String subject;
  final int correct;
  final int wrong;
  final int blank;
  final double net;
  final double weight;
  final int? rankOrg;
  final int? rankClass;
  final double? orgAvg;
  final double? classAvg;

  /// Aynı türdeki bir önceki denemede bu dersin neti.
  final double? previousNet;
}

/// Öğrencinin bir kurum sınavı karnesi.
class ReportCard {
  const ReportCard({
    required this.examId,
    required this.studentId,
    required this.examName,
    required this.examType,
    required this.takenOn,
    required this.totalNet,
    required this.subjects,
    required this.responses,
    required this.outcomes,
    this.studentName,
    this.studentNumber,
    this.booklet,
    this.field,
    this.rankOrg,
    this.rankClass,
    this.orgCount,
    this.classCount,
    this.className,
    this.orgAvg,
    this.classAvg,
    this.previousTotal,
    this.tytNets = const {},
  });

  final String examId;
  final String studentId;
  final String? studentName;
  final String? studentNumber;
  final String examName;
  final ExamType examType;
  final FieldType? field;
  final DateTime takenOn;
  final String? booklet;
  final double totalNet;
  final int? rankOrg;
  final int? rankClass;
  final int? orgCount;
  final int? classCount;
  final String? className;
  final double? orgAvg;
  final double? classAvg;
  final double? previousTotal;

  /// AYT/YDT karnesinde puan için: öğrencinin bu denemeyle aynı gün ya da
  /// daha önceki en yakın TYT denemesinin netleri (ders kodu → net).
  final Map<String, double> tytNets;
  final List<CardSubject> subjects;
  final List<QuestionResponse> responses;
  final List<OutcomeStat> outcomes;
}

/// Sınav raporunda ders özeti.
class SubjectReport {
  const SubjectReport({
    required this.subject,
    required this.avgNet,
    required this.avgCorrect,
    required this.avgWrong,
    required this.avgBlank,
    this.histogram = const {},
  });

  final String subject;
  final double avgNet;
  final double avgCorrect;
  final double avgWrong;
  final double avgBlank;

  /// Net aralığının alt sınırı (5'er) → öğrenci sayısı.
  final Map<int, int> histogram;
}

class ClassReport {
  const ClassReport({
    required this.id,
    required this.name,
    required this.students,
    required this.avgNet,
    this.subjects = const {},
  });

  final String id;
  final String name;
  final int students;
  final double avgNet;
  final Map<String, double> subjects;
}

/// Soru zorluğu ve "anahtar hatalı olabilir" sinyali.
class QuestionStat {
  const QuestionStat({
    required this.subject,
    required this.number,
    required this.students,
    required this.correctPct,
    required this.blankPct,
    this.correctAnswer,
    this.topWrong,
    this.outcome,
    this.discrimination,
  });

  final String subject;
  final int number;
  final int students;
  final double correctPct;
  final double blankPct;
  final String? correctAnswer;
  final String? topWrong;
  final String? outcome;

  /// En iyi %27 − en zayıf %27 doğru oranı (−1..1).
  final double? discrimination;

  /// Başarılı öğrenciler daha çok yanlış yapmış ya da neredeyse hiç kimse
  /// doğru yapmamış: cevap anahtarı kontrol edilmeli.
  bool get suspectKey =>
      students >= 5 &&
      ((discrimination != null && discrimination! < 0) || correctPct < 10);

  /// Çok düşük başarı: konu anlaşılmamış olabilir.
  bool get veryHard => !suspectKey && students >= 5 && correctPct < 25;
}

class RankRow {
  const RankRow({
    required this.examId,
    required this.studentId,
    required this.name,
    required this.totalNet,
    required this.subjects,
    this.studentNumber,
    this.classroomId,
    this.booklet,
    this.rankOrg,
    this.rankClass,
  });

  final String examId;
  final String studentId;
  final String name;
  final String? studentNumber;
  final String? classroomId;
  final String? booklet;
  final double totalNet;
  final int? rankOrg;
  final int? rankClass;
  final Map<String, SubjectScore> subjects;
}

/// Sınıf ve kurum raporu (exam_report).
class ExamReport {
  const ExamReport({
    required this.students,
    required this.avgNet,
    required this.maxNet,
    required this.minNet,
    required this.subjects,
    required this.classes,
    required this.weakOutcomes,
    required this.classOutcomes,
    required this.questions,
    required this.ranking,
  });

  final int students;
  final double avgNet;
  final double maxNet;
  final double minNet;
  final List<SubjectReport> subjects;
  final List<ClassReport> classes;
  final List<OutcomeStat> weakOutcomes;

  /// Sınıf kimliği → en zayıf 5 kazanım.
  final Map<String, List<OutcomeStat>> classOutcomes;
  final List<QuestionStat> questions;
  final List<RankRow> ranking;

  static const empty = ExamReport(
    students: 0,
    avgNet: 0,
    maxNet: 0,
    minNet: 0,
    subjects: [],
    classes: [],
    weakOutcomes: [],
    classOutcomes: {},
    questions: [],
    ranking: [],
  );
}

/// Öğrencinin karne listesi satırı.
class CardSummary {
  const CardSummary({
    required this.examId,
    required this.name,
    required this.takenOn,
    required this.examType,
    required this.totalNet,
    this.rankOrg,
  });

  final String examId;
  final String name;
  final DateTime takenOn;
  final ExamType examType;
  final double totalNet;
  final int? rankOrg;
}

abstract interface class ExamReportRepository {
  /// Öğrencinin kurum sınavları (optik / Excel ile yüklenen), yeni önce.
  Future<List<CardSummary>> fetchCards(String studentId);

  Future<ReportCard> fetchCard(String examId);

  /// Bir sınavın karneleri (toplu PDF); [classroomId] verilirse o sınıf.
  Future<List<ReportCard>> fetchCardsForExam(
    String keyId, {
    String? classroomId,
  });

  /// Öğrencinin bütün kurum sınavlarındaki kazanım başarıları (trend).
  Future<List<OutcomeStat>> fetchOutcomeHistory(String studentId);

  Future<ExamReport> fetchReport(String keyId);
}

class SupabaseExamReportRepository implements ExamReportRepository {
  SupabaseExamReportRepository(this._client);

  final SupabaseClient _client;
  Map<int, String>? _codes;

  Future<Map<int, String>> _subjectCodes() async {
    if (_codes != null) return _codes!;
    final rows = await StaticCache.subjects(_client);
    return _codes = {for (final r in rows) r['id'] as int: r['code'] as String};
  }

  OutcomeStat _stat(Map r, Map<int, String> codes) => OutcomeStat(
    subject: codes[r['subject_id'] as int]!,
    outcomeKey: r['outcome_key'] as String,
    outcome: r['outcome'] as String? ?? '',
    questions: r['questions'] as int? ?? 0,
    correct: r['correct'] as int? ?? 0,
    wrong: r['wrong'] as int? ?? 0,
    blank: r['blank'] as int? ?? 0,
    lostNet: _d(r['lost_net'] ?? r['avg_lost_net']),
    students: r['students'] as int? ?? 1,
    examId: r['exam_id'] as String?,
    takenOn: r['taken_on'] == null
        ? null
        : DateTime.parse(r['taken_on'] as String),
  );

  static const _examCols =
      'id, student_id, name, exam_type, field, taken_on, booklet, total_net, '
      'rank_org, rank_class, classroom_id, batch_id, '
      'exam_subject_results(subject_id, correct, wrong, blank, net, weight, rank_org, rank_class), '
      'exam_answers(subject_id, question_no, booklet_no, marked, correct, outcome, outcome_id)';

  ReportCard _card(
    Map<String, dynamic> e,
    Map<int, String> codes, {
    Map<String, dynamic>? ctx,
    Map<String, double> previous = const {},
    double? previousTotal,
    List<OutcomeStat> outcomes = const [],
    String? studentName,
    String? studentNumber,
    Map<String, double> tytNets = const {},
  }) {
    final ctxSubjects = Map<String, dynamic>.from(
      (ctx?['subjects'] as Map?) ?? const {},
    );
    final results = [...e['exam_subject_results'] as List]
      ..sort(
        (a, b) =>
            examSubjects.indexWhere(
              (s) => s.code == codes[a['subject_id'] as int],
            ) -
            examSubjects.indexWhere(
              (s) => s.code == codes[b['subject_id'] as int],
            ),
      );
    return ReportCard(
      examId: e['id'] as String,
      studentId: e['student_id'] as String,
      studentName: studentName,
      studentNumber: studentNumber,
      examName: e['name'] as String,
      examType: ExamType.fromDb(e['exam_type'] as String),
      field: e['field'] == null ? null : FieldType.fromDb(e['field'] as String),
      takenOn: DateTime.parse(e['taken_on'] as String),
      booklet: e['booklet'] as String?,
      totalNet: _d(e['total_net']),
      rankOrg: e['rank_org'] as int?,
      rankClass: e['rank_class'] as int?,
      orgCount: ctx?['org_count'] as int?,
      classCount: ctx?['class_count'] as int?,
      className: ctx?['class_name'] as String?,
      orgAvg: _dn(ctx?['org_avg']),
      classAvg: _dn(ctx?['class_avg']),
      previousTotal: previousTotal,
      tytNets: tytNets,
      subjects: [
        for (final r in results)
          () {
            final code = codes[r['subject_id'] as int]!;
            final c = ctxSubjects['${r['subject_id']}'] as Map?;
            return CardSubject(
              subject: code,
              correct: r['correct'] as int,
              wrong: r['wrong'] as int,
              blank: r['blank'] as int,
              net: _d(r['net']),
              weight: _d(r['weight']),
              rankOrg: r['rank_org'] as int?,
              rankClass: r['rank_class'] as int?,
              orgAvg: _dn(c?['org_avg']),
              classAvg: _dn(c?['class_avg']),
              previousNet: previous[code],
            );
          }(),
      ],
      responses:
          [
            for (final a in e['exam_answers'] as List)
              () {
                final marked = a['marked'] as String?;
                final correct = a['correct'] as String?;
                return QuestionResponse(
                  subject: codes[a['subject_id'] as int]!,
                  number: a['question_no'] as int,
                  bookletNo: a['booklet_no'] as int?,
                  marked: marked,
                  correct: correct,
                  outcome: a['outcome'] as String?,
                  outcomeId: a['outcome_id'] as String?,
                  result: correct == null
                      ? ResponseResult.cancelled
                      : marked == null
                      ? ResponseResult.blank
                      : marked == correct
                      ? ResponseResult.correct
                      : ResponseResult.wrong,
                );
              }(),
          ]..sort((a, b) {
            final s =
                examSubjects.indexWhere((x) => x.code == a.subject) -
                examSubjects.indexWhere((x) => x.code == b.subject);
            return s != 0 ? s : a.shownNumber - b.shownNumber;
          }),
      outcomes: outcomes,
    );
  }

  /// Öğrencilerin [onOrBefore] günü ya da öncesindeki en yakın TYT netleri.
  Future<Map<String, Map<String, double>>> _tytNets(
    List<String> studentIds,
    String onOrBefore,
    Map<int, String> codes,
  ) async {
    final out = <String, Map<String, double>>{};
    for (var i = 0; i < studentIds.length; i += 100) {
      final List rows = await _client
          .from('exams')
          .select('student_id, taken_on, exam_subject_results(subject_id, net)')
          .inFilter(
            'student_id',
            studentIds.sublist(i, math.min(i + 100, studentIds.length)),
          )
          .eq('exam_type', 'TYT')
          .lte('taken_on', onOrBefore)
          .order('taken_on', ascending: false)
          .order('created_at', ascending: false)
          .limit(2000);
      for (final r in rows) {
        out.putIfAbsent(
          r['student_id'] as String,
          () => {
            for (final s in r['exam_subject_results'] as List)
              if (codes[s['subject_id'] as int] != null)
                codes[s['subject_id'] as int]!: _d(s['net']),
          },
        );
      }
    }
    return out;
  }

  /// Öğrencinin [type] türündeki, [before]'dan önceki son denemesi.
  Future<(Map<String, double>, double?)> _previous(
    String studentId,
    String type,
    String before,
    Map<int, String> codes,
  ) async {
    final List rows = await _client
        .from('exams')
        .select('total_net, exam_subject_results(subject_id, net, weight)')
        .eq('student_id', studentId)
        .eq('exam_type', type)
        .lt('taken_on', before)
        .order('taken_on', ascending: false)
        .limit(1);
    if (rows.isEmpty) return (const <String, double>{}, null);
    final r = rows.first;
    final subj = {
      for (final s in r['exam_subject_results'] as List)
        codes[s['subject_id'] as int]!: _d(s['net']),
    };
    final total =
        _dn(r['total_net']) ?? subj.values.fold<double>(0, (a, b) => a + b);
    return (subj, total);
  }

  @override
  Future<List<CardSummary>> fetchCards(String studentId) async {
    final List rows = await _client
        .from('exams')
        .select('id, name, exam_type, taken_on, total_net, rank_org')
        .eq('student_id', studentId)
        .eq('source', 'optic')
        .not('batch_id', 'is', null)
        .order('taken_on', ascending: false)
        .limit(100);
    return [
      for (final r in rows)
        CardSummary(
          examId: r['id'] as String,
          name: r['name'] as String,
          takenOn: DateTime.parse(r['taken_on'] as String),
          examType: ExamType.fromDb(r['exam_type'] as String),
          totalNet: _d(r['total_net']),
          rankOrg: r['rank_org'] as int?,
        ),
    ];
  }

  @override
  Future<ReportCard> fetchCard(String examId) async {
    final codes = await _subjectCodes();
    final e = await _client
        .from('exams')
        .select(_examCols)
        .eq('id', examId)
        .single();
    final ctx = await _client.rpc(
      'exam_card_context',
      params: {'p_exam': examId},
    );
    final (prev, prevTotal) = await _previous(
      e['student_id'] as String,
      e['exam_type'] as String,
      e['taken_on'] as String,
      codes,
    );
    final List stats = await _client
        .from('v_student_outcome_analysis')
        .select()
        .eq('exam_id', examId);
    final tyt = e['exam_type'] == 'TYT'
        ? const <String, Map<String, double>>{}
        : await _tytNets(
            [e['student_id'] as String],
            e['taken_on'] as String,
            codes,
          );
    return _card(
      e,
      codes,
      ctx: ctx == null ? null : Map<String, dynamic>.from(ctx as Map),
      previous: prev,
      previousTotal: prevTotal,
      outcomes: [for (final s in stats) _stat(s as Map, codes)],
      tytNets: tyt[e['student_id']] ?? const {},
    );
  }

  @override
  Future<List<ReportCard>> fetchCardsForExam(
    String keyId, {
    String? classroomId,
  }) async {
    final codes = await _subjectCodes();
    var q = _client
        .from('exams')
        .select(
          '$_examCols, profiles!exams_student_id_fkey(full_name, student_number)',
        )
        .eq('batch_id', keyId)
        .eq('source', 'optic');
    if (classroomId != null) q = q.eq('classroom_id', classroomId);
    final List exams = await q.order('rank_org');
    if (exams.isEmpty) return const [];
    final report = await fetchReport(keyId);
    final List stats = await _client
        .from('v_student_outcome_analysis')
        .select()
        .eq('key_id', keyId);
    final byExam = <String, List<OutcomeStat>>{};
    for (final s in stats) {
      byExam
          .putIfAbsent(s['exam_id'] as String, () => [])
          .add(_stat(s as Map, codes));
    }
    final classOf = {for (final c in report.classes) c.id: c};
    final first = exams.first as Map;
    final tyt = first['exam_type'] == 'TYT'
        ? const <String, Map<String, double>>{}
        : await _tytNets(
            [for (final e in exams) e['student_id'] as String],
            first['taken_on'] as String,
            codes,
          );
    return [
      for (final e in exams)
        () {
          final cls = classOf[e['classroom_id']];
          final p = e['profiles'] as Map?;
          return _card(
            e as Map<String, dynamic>,
            codes,
            ctx: {
              'org_count': report.students,
              'class_count': cls?.students,
              'class_name': cls?.name,
              'org_avg': report.avgNet,
              'class_avg': cls?.avgNet,
              'subjects': {
                for (final s in report.subjects)
                  '${codes.entries.firstWhere((x) => x.value == s.subject).key}':
                      {
                        'org_avg': s.avgNet,
                        'class_avg': cls?.subjects[s.subject],
                      },
              },
            },
            outcomes: byExam[e['id']] ?? const [],
            studentName: p?['full_name'] as String?,
            studentNumber: p?['student_number'] as String?,
            tytNets: tyt[e['student_id']] ?? const {},
          );
        }(),
    ];
  }

  @override
  Future<List<OutcomeStat>> fetchOutcomeHistory(String studentId) async {
    final codes = await _subjectCodes();
    final List rows = await _client
        .from('v_student_outcome_analysis')
        .select()
        .eq('student_id', studentId)
        .not('key_id', 'is', null)
        .order('taken_on')
        .limit(5000);
    return [for (final r in rows) _stat(r as Map, codes)];
  }

  @override
  Future<ExamReport> fetchReport(String keyId) async {
    final codes = await _subjectCodes();
    final r = Map<String, dynamic>.from(
      await _client.rpc('exam_report', params: {'p_key': keyId}) as Map,
    );
    String code(Object? id) =>
        codes[id is int ? id : int.parse('$id')] ?? '$id';
    final classOutcomes = <String, List<OutcomeStat>>{};
    for (final o in r['class_outcomes'] as List) {
      classOutcomes
          .putIfAbsent(o['classroom_id'] as String, () => [])
          .add(_stat(o as Map, codes));
    }
    return ExamReport(
      students: r['students'] as int? ?? 0,
      avgNet: _d(r['avg_net']),
      maxNet: _d(r['max_net']),
      minNet: _d(r['min_net']),
      subjects: [
        for (final s in r['subjects'] as List)
          SubjectReport(
            subject: code(s['subject_id']),
            avgNet: _d(s['avg_net']),
            avgCorrect: _d(s['avg_correct']),
            avgWrong: _d(s['avg_wrong']),
            avgBlank: _d(s['avg_blank']),
            histogram: {
              for (final e in ((s['histogram'] as Map?) ?? const {}).entries)
                int.parse('${e.key}'): e.value as int,
            },
          ),
      ],
      classes: [
        for (final c in r['classes'] as List)
          ClassReport(
            id: c['classroom_id'] as String,
            name: c['name'] as String,
            students: c['students'] as int,
            avgNet: _d(c['avg_net']),
            subjects: {
              for (final e in ((c['subjects'] as Map?) ?? const {}).entries)
                code(e.key): _d(e.value),
            },
          ),
      ],
      weakOutcomes: [
        for (final o in r['weak_outcomes'] as List) _stat(o as Map, codes),
      ],
      classOutcomes: classOutcomes,
      questions: [
        for (final q in r['questions'] as List)
          QuestionStat(
            subject: code(q['subject_id']),
            number: q['question_no'] as int,
            students: q['students'] as int,
            correctPct: _d(q['correct_pct']),
            blankPct: _d(q['blank_pct']),
            correctAnswer: q['correct_answer'] as String?,
            topWrong: q['top_wrong'] as String?,
            outcome: q['outcome'] as String?,
            discrimination: _dn(q['discrimination']),
          ),
      ],
      ranking: [
        for (final x in r['ranking'] as List)
          RankRow(
            examId: x['exam_id'] as String,
            studentId: x['student_id'] as String,
            name: x['name'] as String? ?? '',
            studentNumber: x['student_number'] as String?,
            classroomId: x['classroom_id'] as String?,
            booklet: x['booklet'] as String?,
            totalNet: _d(x['total_net']),
            rankOrg: x['rank_org'] as int?,
            rankClass: x['rank_class'] as int?,
            subjects: {
              for (final e in ((x['subjects'] as Map?) ?? const {}).entries)
                code(e.key): SubjectScore(
                  subject: code(e.key),
                  correct: (e.value as Map)['c'] as int,
                  wrong: e.value['w'] as int,
                  blank: e.value['b'] as int,
                  net: _d(e.value['net']),
                ),
            },
          ),
      ],
    );
  }
}

final examReportRepositoryProvider = Provider<ExamReportRepository>(
  (ref) => SupabaseExamReportRepository(ref.watch(supabaseClientProvider)),
);

final reportCardsProvider = FutureProvider.family<List<CardSummary>, String>(
  (ref, studentId) =>
      ref.watch(examReportRepositoryProvider).fetchCards(studentId),
);

final reportCardProvider = FutureProvider.family<ReportCard, String>(
  (ref, examId) => ref.watch(examReportRepositoryProvider).fetchCard(examId),
);

final outcomeHistoryProvider = FutureProvider.family<List<OutcomeStat>, String>(
  (ref, studentId) =>
      ref.watch(examReportRepositoryProvider).fetchOutcomeHistory(studentId),
);

final examReportProvider = FutureProvider.family<ExamReport, String>(
  (ref, keyId) => ref.watch(examReportRepositoryProvider).fetchReport(keyId),
);
