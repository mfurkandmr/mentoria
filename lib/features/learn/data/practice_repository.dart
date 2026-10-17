import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';

/// Eğitim bölümündeki TYT dersleri.
const tytPracticeSubjects = [
  'TYT_TUR',
  'TYT_MAT',
  'TYT_FIZ',
  'TYT_KIM',
  'TYT_BIY',
  'TYT_TAR',
  'TYT_COG',
  'TYT_FEL',
  'TYT_DIN',
];

/// Eğitim bölümündeki AYT dersleri.
const aytPracticeSubjects = [
  'AYT_MAT',
  'AYT_FIZ',
  'AYT_KIM',
  'AYT_BIY',
  'AYT_EDB',
  'AYT_TAR1',
  'AYT_COG1',
  'AYT_TAR2',
  'AYT_COG2',
  'AYT_FELG',
  'AYT_DIN',
];

/// Tüm dersler (TYT sonra AYT).
const practiceSubjects = [...tytPracticeSubjects, ...aytPracticeSubjects];

/// Günlük hak; sunucudaki `practice_daily_limit` ile aynı. Havuz = hak × 30.
int practiceDailyLimit(String subject) =>
    const {'TYT_TUR', 'TYT_MAT', 'AYT_MAT', 'AYT_EDB'}.contains(subject)
    ? 20
    : 10;

/// Ders adı; AYT'de TYT ile aynı adı taşıyan dersler "AYT" önekiyle
/// (karne ve başlıklarda karışmasın).
String practiceSubjectLabel(String code) {
  final name = subjectByCode(code).name;
  if (!code.startsWith('AYT_')) return name;
  final clash = tytPracticeSubjects.any((c) => subjectByCode(c).name == name);
  return clash ? 'AYT $name' : name;
}

/// Havuzdaki bir soru (`assets/learn/questions/<ders>.json`).
class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.topic,
    required this.text,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory PracticeQuestion.fromJson(Map<String, dynamic> j) => PracticeQuestion(
    id: j['id'] as String,
    topic: j['t'] as String,
    text: j['q'] as String,
    options: [for (final o in j['o'] as List) o as String],
    answer: j['a'] as int,
    explanation: j['e'] as String,
  );

  final String id;
  final String topic;
  final String text;
  final List<String> options;
  final int answer;
  final String explanation;

  String get subject => id.split('-').first;
}

/// Öğrencinin verdiği bir cevap.
class PracticeAnswer {
  const PracticeAnswer({
    required this.subject,
    required this.questionId,
    required this.correct,
    required this.answeredOn,
  });

  factory PracticeAnswer.fromJson(Map<String, dynamic> j) => PracticeAnswer(
    subject: j['subject_code'] as String,
    questionId: j['question_id'] as String,
    correct: j['correct'] as bool,
    answeredOn: DateTime.parse(j['answered_on'] as String),
  );

  final String subject;
  final String questionId;
  final bool correct;
  final DateTime answeredOn;
}

/// Günlük hak dolduğunda.
class DailyLimitReached implements Exception {
  const DailyLimitReached();
}

abstract interface class PracticeRepository {
  Future<List<PracticeAnswer>> fetchAnswers(String studentId);
  Future<void> submit(
    String studentId, {
    required String subject,
    required String questionId,
    required bool correct,
  });
}

class SupabasePracticeRepository implements PracticeRepository {
  SupabasePracticeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PracticeAnswer>> fetchAnswers(String studentId) async {
    final rows = await _client
        .from('practice_answers')
        .select('subject_code, question_id, correct, answered_on')
        .eq('student_id', studentId)
        .order('created_at');
    return [for (final r in rows) PracticeAnswer.fromJson(r)];
  }

  @override
  Future<void> submit(
    String studentId, {
    required String subject,
    required String questionId,
    required bool correct,
  }) async {
    try {
      await _client.from('practice_answers').insert({
        'student_id': studentId,
        'subject_code': subject,
        'question_id': questionId,
        'correct': correct,
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('DAILY_LIMIT')) throw const DailyLimitReached();
      rethrow;
    }
  }
}

final practiceRepositoryProvider = Provider<PracticeRepository>(
  (ref) => SupabasePracticeRepository(ref.watch(supabaseClientProvider)),
);

final practiceAnswersProvider =
    FutureProvider.family<List<PracticeAnswer>, String>(
      (ref, studentId) =>
          ref.watch(practiceRepositoryProvider).fetchAnswers(studentId),
    );

/// Dersin soru havuzu (uygulamaya gömülü).
final questionPoolProvider =
    FutureProvider.family<List<PracticeQuestion>, String>((ref, subject) async {
      final raw = await rootBundle.loadString(
        'assets/learn/questions/$subject.json',
      );
      return [
        for (final j in jsonDecode(raw) as List)
          PracticeQuestion.fromJson(j as Map<String, dynamic>),
      ];
    });

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// FNV-1a: her çalıştırmada aynı sonucu veren metin özeti.
int _stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Bir dersin bugünkü durumu ve sıradaki sorular.
class SubjectPractice {
  SubjectPractice({
    required this.subject,
    required this.limit,
    required this.todayAnswers,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.queue,
    required this.poolSize,
    required this.seenCount,
  });

  /// [answers] öğrencinin tüm cevapları (eskiden yeniye). Havuz bitene kadar
  /// çözülmemiş sorular; bitince en uzun süredir görülmeyenler gelir. Sıra
  /// her öğrenci için sabittir (ekran yeniden açılınca değişmez).
  factory SubjectPractice.of({
    required String subject,
    required String studentId,
    required List<PracticeQuestion> pool,
    required List<PracticeAnswer> answers,
    required DateTime now,
  }) {
    final today = _day(now);
    final mine = answers.where((a) => a.subject == subject).toList();
    final todays = mine.where((a) => _day(a.answeredOn) == today).toList();
    final lastSeen = <String, DateTime>{};
    for (final a in mine) {
      lastSeen[a.questionId] = a.answeredOn;
    }
    // Öğrenciye özel, sabit karışık sıra: cevap verildikçe ya da ekran
    // yeniden açılınca kalan sorular yer değiştirmez. (Object.hash her
    // çalıştırmada değiştiği için kendi özetimiz.)
    final order = [...pool]
      ..shuffle(math.Random(_stableHash('$studentId/$subject')));
    final unseen = [
      for (final q in order)
        if (!lastSeen.containsKey(q.id)) q,
    ];
    final List<PracticeQuestion> queue;
    if (unseen.isNotEmpty) {
      queue = unseen;
    } else {
      // Havuz bitti: bugün çözülmemişler, en uzun süredir görülmeyen önce.
      queue = [
        for (final q in order)
          if (lastSeen[q.id] != today) q,
      ];
      final rank = {for (final (i, q) in order.indexed) q.id: i};
      queue.sort((a, b) {
        final c = lastSeen[a.id]!.compareTo(lastSeen[b.id]!);
        return c != 0 ? c : rank[a.id]! - rank[b.id]!;
      });
    }
    return SubjectPractice(
      subject: subject,
      limit: practiceDailyLimit(subject),
      todayAnswers: todays,
      totalAnswered: mine.length,
      totalCorrect: mine.where((a) => a.correct).length,
      queue: queue,
      poolSize: pool.length,
      seenCount: lastSeen.length,
    );
  }

  final String subject;
  final int limit;
  final List<PracticeAnswer> todayAnswers;
  final int totalAnswered;
  final int totalCorrect;

  /// Sıradaki sorular (ilk [remaining] tanesi bugün sorulur).
  final List<PracticeQuestion> queue;
  final int poolSize;
  final int seenCount;

  int get usedToday => todayAnswers.length;
  int get remaining => math.max(0, limit - usedToday);
  int get correctToday => todayAnswers.where((a) => a.correct).length;

  /// Tüm zamanlar isabeti (0..1); hiç cevap yoksa null.
  double? get accuracy =>
      totalAnswered == 0 ? null : totalCorrect / totalAnswered;

  List<PracticeQuestion> get todaysQuestions => queue.take(remaining).toList();
}
