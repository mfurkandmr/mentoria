import 'practice_repository.dart';

/// Bir dersin eğitim karnesi satırı.
class SubjectReport {
  const SubjectReport({
    required this.subject,
    required this.solved,
    required this.correct,
    this.weakestTopic,
    this.weakestWrong = 0,
  });

  final String subject;
  final int solved;
  final int correct;

  /// En çok yanlış yapılan konu (yanlış yoksa null).
  final String? weakestTopic;
  final int weakestWrong;

  double get accuracy => solved == 0 ? 0 : correct / solved;
}

/// Koçun gördüğü Eğitim karnesi: ders ders çözülen soru, isabet, en zayıf
/// konu ve son 7 günün günlük soru sayısı.
class PracticeReport {
  const PracticeReport({
    required this.subjects,
    required this.days,
    required this.perDay,
  });

  /// Konu adları havuzdan gelir ([topicOf]: soru kimliği → konu).
  factory PracticeReport.of({
    required List<PracticeAnswer> answers,
    required String? Function(String questionId) topicOf,
    required DateTime now,
  }) {
    final rows = <SubjectReport>[];
    for (final subject in practiceSubjects) {
      final mine = answers.where((a) => a.subject == subject).toList();
      if (mine.isEmpty) continue;
      final wrongByTopic = <String, int>{};
      for (final a in mine.where((a) => !a.correct)) {
        final t = topicOf(a.questionId);
        if (t != null) wrongByTopic[t] = (wrongByTopic[t] ?? 0) + 1;
      }
      // En çok yanlış; eşitlikte alfabetik (her çalıştırmada aynı sonuç).
      final weakest = wrongByTopic.entries.toList()
        ..sort((a, b) {
          final c = b.value.compareTo(a.value);
          return c != 0 ? c : a.key.compareTo(b.key);
        });
      rows.add(
        SubjectReport(
          subject: subject,
          solved: mine.length,
          correct: mine.where((a) => a.correct).length,
          weakestTopic: weakest.firstOrNull?.key,
          weakestWrong: weakest.firstOrNull?.value ?? 0,
        ),
      );
    }
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var k = 6; k >= 0; k--) today.subtract(Duration(days: k)),
    ];
    final perDay = [
      for (final d in days)
        answers
            .where(
              (a) =>
                  a.answeredOn.year == d.year &&
                  a.answeredOn.month == d.month &&
                  a.answeredOn.day == d.day,
            )
            .length,
    ];
    return PracticeReport(subjects: rows, days: days, perDay: perDay);
  }

  /// Yalnızca çözülmüş dersler, [practiceSubjects] sırasıyla.
  final List<SubjectReport> subjects;
  final List<DateTime> days;
  final List<int> perDay;

  int get solved => subjects.fold(0, (s, r) => s + r.solved);
  int get correct => subjects.fold(0, (s, r) => s + r.correct);
  double get accuracy => solved == 0 ? 0 : correct / solved;
  int get lastWeek => perDay.fold(0, (s, n) => s + n);

  /// En düşük isabetli ders (en az 5 soru çözülmüşse).
  SubjectReport? get weakestSubject {
    final enough = subjects.where((r) => r.solved >= 5).toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return enough.firstOrNull;
  }
}
