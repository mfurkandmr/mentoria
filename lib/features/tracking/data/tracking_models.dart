import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';

/// Günlük soru kaydı.
class QuestionLog {
  const QuestionLog({
    required this.id,
    required this.subjectCode,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.loggedOn,
    this.topicId,
    this.topicName,
    this.source,
  });

  final String id;
  final String subjectCode;
  final int? topicId;
  final String? topicName;
  final int correct;
  final int wrong;
  final int blank;
  final DateTime loggedOn;
  final String? source;

  int get total => correct + wrong + blank;
  double get net => calculateNet(correct, wrong);
  ExamSubject get subject => subjectByCode(subjectCode);
}

class QuestionLogDraft {
  const QuestionLogDraft({
    required this.subjectCode,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.loggedOn,
    this.topicId,
    this.source,
  });

  final String subjectCode;
  final int? topicId;
  final int correct;
  final int wrong;
  final int blank;
  final DateTime loggedOn;
  final String? source;
}

/// Müfredat konusu.
class Topic {
  const Topic({
    required this.id,
    required this.subjectCode,
    required this.name,
    required this.sort,
  });

  final int id;
  final String subjectCode;
  final String name;
  final int sort;
}

enum TopicStatus {
  notStarted('not_started', 'Başlanmadı'),
  inProgress('in_progress', 'Çalışılıyor'),
  done('done', 'Bitti'),
  review('review', 'Tekrar gerekli');

  const TopicStatus(this.db, this.trLabel);
  final String db;
  final String trLabel;

  String get label => tr(trLabel);

  static TopicStatus fromDb(String v) =>
      TopicStatus.values.firstWhere((s) => s.db == v);
}

enum SessionType {
  pomodoro('pomodoro', 'Pomodoro'),
  free('free', 'Kronometre');

  const SessionType(this.db, this.trLabel);
  final String db;
  final String trLabel;

  String get label => tr(trLabel);

  static SessionType fromDb(String v) =>
      SessionType.values.firstWhere((s) => s.db == v);
}

class StudySession {
  const StudySession({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.durationSec,
    this.subjectCode,
  });

  final String id;
  final String? subjectCode;
  final SessionType type;
  final DateTime startedAt;
  final int durationSec;

  int get minutes => (durationSec / 60).round();
}

/// Öğrencinin hedefleri (öğrenci ve koçu düzenleyebilir).
class Goals {
  const Goals({
    this.dailyQuestions,
    this.dailyMinutes,
    this.targetUniversity,
    this.targetDepartment,
    this.targetRank,
  });

  final int? dailyQuestions;
  final int? dailyMinutes;
  final String? targetUniversity;
  final String? targetDepartment;
  final int? targetRank;

  bool get isEmpty =>
      dailyQuestions == null &&
      dailyMinutes == null &&
      (targetUniversity?.isEmpty ?? true) &&
      (targetDepartment?.isEmpty ?? true) &&
      targetRank == null;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// yyyy-MM-dd (yerel tarih).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

/// Son [days] günün tarihleri (eskiden bugüne).
List<DateTime> lastDays(int days, [DateTime? now]) {
  final today = dateOnly(now ?? DateTime.now());
  return [
    for (var i = days - 1; i >= 0; i--) today.subtract(Duration(days: i)),
  ];
}

/// Art arda çalışılan gün sayısı (bugün ya da dün biten seri).
int studyStreak(Iterable<DateTime> activeDays, [DateTime? now]) {
  final days = activeDays.map(dateOnly).toSet();
  var day = dateOnly(now ?? DateTime.now());
  if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
