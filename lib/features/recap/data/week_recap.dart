import '../../../core/i18n/i18n.dart';
import '../../exams/data/exam.dart';
import '../../tracking/data/tracking_models.dart';

/// Öğrencinin bu haftaki "arı tipi": haftanın verisinden çıkarılan, hikayenin
/// sonunda açılan unvan.
enum BeePersona {
  /// Yedi günün yedisinde de çalıştı.
  steady('🏅'),

  /// Doğruluk %85 ve üstü (en az 50 soru).
  sharpshooter('🎯'),

  /// Oturumların çoğu 21:00'den sonra.
  nightOwl('🦉'),

  /// Oturumların çoğu 09:00'dan önce.
  earlyBird('🌅'),

  /// Ortalama oturum 45 dakika ve üstü.
  marathoner('🏃'),

  /// Varsayılan: çok soru çözen.
  hunter('⚡');

  const BeePersona(this.emoji);
  final String emoji;

  String get title => switch (this) {
    steady => tr('İstikrar Arısı'),
    sharpshooter => tr('Keskin Nişancı Arı'),
    nightOwl => tr('Gece Kuşu Arı'),
    earlyBird => tr('Sabahçı Arı'),
    marathoner => tr('Maratoncu Arı'),
    hunter => tr('Soru Avcısı Arı'),
  };

  String get description => switch (this) {
    steady => tr(
      'Haftanın her günü kovandaydın. Bu istikrar YKS\'de altın değerinde.',
    ),
    sharpshooter => tr(
      'Az yanlış, çok doğru. Soruları gözünü kırpmadan vurdun.',
    ),
    nightOwl => tr('Şehir uyurken sen çalıştın. Uykunu da ihmal etme!'),
    earlyBird => tr('Güneşten önce kalktın, balı ilk sen topladın.'),
    marathoner => tr('Uzun ve derin odaklandın. Dikkat kasın çok güçlü.'),
    hunter => tr('Soruları tek tek avladın. Kovan seninle gurur duyuyor.'),
  };
}

/// Son 7 günün özeti ("Haftanın Bal Raporu"). Tamamen istemcide, ana
/// sayfanın zaten yüklediği verilerden hesaplanır.
class WeekRecap {
  const WeekRecap({
    required this.start,
    required this.end,
    required this.questions,
    required this.correct,
    required this.wrong,
    required this.previousQuestions,
    required this.studyMinutes,
    required this.sessions,
    required this.dailyQuestions,
    required this.activeDays,
    required this.topSubjectCode,
    required this.topSubjectQuestions,
    required this.topSubjectAccuracy,
    required this.exams,
    required this.bestExamNet,
    required this.persona,
  });

  /// Haftanın ilk ve son günü (bugün dahil, son 7 gün).
  final DateTime start;
  final DateTime end;

  final int questions;
  final int correct;
  final int wrong;

  /// Bir önceki 7 günün soru sayısı (karşılaştırma için).
  final int previousQuestions;

  final int studyMinutes;
  final int sessions;

  /// 7 günün her biri için çözülen soru (start'tan başlayarak).
  final List<int> dailyQuestions;

  final String? topSubjectCode;
  final int topSubjectQuestions;

  /// 0..1
  final double topSubjectAccuracy;

  final int exams;
  final double? bestExamNet;
  final BeePersona persona;

  /// Hafta boyunca hiç kayıt yok.
  bool get isEmpty => questions == 0 && studyMinutes == 0 && exams == 0;

  /// 0..1 (boş bırakılanlar hariç).
  double get accuracy => correct + wrong == 0 ? 0 : correct / (correct + wrong);

  /// Soru çözülen ya da odaklanma oturumu olan gün sayısı.
  final int activeDays;

  /// En çok soru çözülen gün (yoksa null).
  int? get bestDayIndex {
    if (questions == 0) return null;
    var best = 0;
    for (var i = 1; i < 7; i++) {
      if (dailyQuestions[i] > dailyQuestions[best]) best = i;
    }
    return best;
  }

  /// Önceki haftaya göre değişim yüzdesi (önceki hafta boşsa null).
  int? get changePercent => previousQuestions == 0
      ? null
      : ((questions - previousQuestions) * 100 / previousQuestions).round();

  /// Her 100 doğru bir kavanoz bal.
  double get honeyJars => correct / 100;

  /// 25 dakikalık pomodoro karşılığı.
  int get pomodoros => (studyMinutes / 25).floor();

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  factory WeekRecap.compute({
    required List<QuestionLog> logs,
    required List<StudySession> sessions,
    required List<Exam> exams,
    required DateTime now,
  }) {
    final end = _day(now);
    final start = end.subtract(const Duration(days: 6));
    final prevStart = start.subtract(const Duration(days: 7));
    bool inWeek(DateTime d) =>
        !_day(d).isBefore(start) && !_day(d).isAfter(end);

    final week = logs.where((l) => inWeek(l.loggedOn)).toList();
    final previous = logs
        .where(
          (l) => !l.loggedOn.isBefore(prevStart) && l.loggedOn.isBefore(start),
        )
        .fold<int>(0, (s, l) => s + l.total);
    final weekSessions = sessions.where((s) => inWeek(s.startedAt)).toList();
    final weekExams = exams.where((e) => inWeek(e.takenOn)).toList();

    final daily = List<int>.filled(7, 0);
    final bySubject = <String, (int total, int correct, int wrong)>{};
    var questions = 0, correct = 0, wrong = 0;
    for (final l in week) {
      daily[_day(l.loggedOn).difference(start).inDays] += l.total;
      questions += l.total;
      correct += l.correct;
      wrong += l.wrong;
      final (t, c, w) = bySubject[l.subjectCode] ?? (0, 0, 0);
      bySubject[l.subjectCode] = (t + l.total, c + l.correct, w + l.wrong);
    }

    String? topCode;
    var topTotal = 0;
    var topAccuracy = 0.0;
    bySubject.forEach((code, v) {
      if (v.$1 > topTotal) {
        topCode = code;
        topTotal = v.$1;
        topAccuracy = v.$2 + v.$3 == 0 ? 0 : v.$2 / (v.$2 + v.$3);
      }
    });

    final minutes =
        weekSessions.fold<int>(0, (m, s) => m + s.durationSec) ~/ 60;
    final activeDays = {
      ...week.where((l) => l.total > 0).map((l) => _day(l.loggedOn)),
      ...weekSessions.map((s) => _day(s.startedAt)),
    }.length;

    return WeekRecap(
      start: start,
      end: end,
      questions: questions,
      correct: correct,
      wrong: wrong,
      previousQuestions: previous,
      studyMinutes: minutes,
      sessions: weekSessions.length,
      dailyQuestions: daily,
      activeDays: activeDays,
      topSubjectCode: topCode,
      topSubjectQuestions: topTotal,
      topSubjectAccuracy: topAccuracy,
      exams: weekExams.length,
      bestExamNet: weekExams.isEmpty
          ? null
          : weekExams.map((e) => e.totalNet).reduce((a, b) => a > b ? a : b),
      persona: _persona(
        activeDays: activeDays,
        questions: questions,
        correct: correct,
        wrong: wrong,
        sessions: weekSessions,
        minutes: minutes,
      ),
    );
  }

  static BeePersona _persona({
    required int activeDays,
    required int questions,
    required int correct,
    required int wrong,
    required List<StudySession> sessions,
    required int minutes,
  }) {
    if (activeDays >= 7) return BeePersona.steady;
    if (questions >= 50 &&
        correct + wrong > 0 &&
        correct / (correct + wrong) >= 0.85) {
      return BeePersona.sharpshooter;
    }
    if (sessions.length >= 3) {
      final night = sessions
          .where((s) => s.startedAt.hour >= 21 || s.startedAt.hour < 4)
          .length;
      final early = sessions
          .where((s) => s.startedAt.hour >= 4 && s.startedAt.hour < 9)
          .length;
      if (night * 2 > sessions.length) return BeePersona.nightOwl;
      if (early * 2 > sessions.length) return BeePersona.earlyBird;
      if (minutes / sessions.length >= 45) return BeePersona.marathoner;
    }
    return BeePersona.hunter;
  }
}
