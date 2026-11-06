import '../../../core/constants/exam_subjects.dart';
import 'exam_definition.dart';

enum ResponseResult { correct, wrong, blank, cancelled }

/// Bir sorunun değerlendirmesi (sunucudaki exam_answers satırı).
class QuestionResponse {
  const QuestionResponse({
    required this.subject,
    required this.number,
    required this.result,
    this.bookletNo,
    this.marked,
    this.correct,
    this.outcome,
    this.outcomeId,
  });

  final String subject;

  /// A kitapçığındaki numara.
  final int number;

  /// Öğrencinin kendi kitapçığındaki numara (A'da `null`).
  final int? bookletNo;
  final String? marked;

  /// Öğrencinin kitapçığındaki doğru şık; iptalde `null`.
  final String? correct;
  final String? outcome;
  final String? outcomeId;
  final ResponseResult result;

  int get shownNumber => bookletNo ?? number;
}

class SubjectScore {
  const SubjectScore({
    required this.subject,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.net,
    this.weight = 1,
  });

  final String subject;
  final int correct;
  final int wrong;
  final int blank;

  /// Doğru − yanlış × katsayı, 2 basamağa yuvarlanmış (sunucudaki gibi).
  final double net;
  final double weight;

  int get questions => correct + wrong + blank;
}

class ScoredResult {
  const ScoredResult({
    required this.subjects,
    required this.responses,
    required this.totalNet,
  });

  /// Ders kodu → sonuç (değerlendirilen dersler; AYT'de boş test yok).
  final Map<String, SubjectScore> subjects;
  final List<QuestionResponse> responses;

  /// Ders netleri × katsayı toplamı.
  final double totalNet;

  int get correct => subjects.values.fold(0, (a, s) => a + s.correct);
  int get wrong => subjects.values.fold(0, (a, s) => a + s.wrong);
  int get blank => subjects.values.fold(0, (a, s) => a + s.blank);
}

/// Sınavda olmayan kitapçık (anahtarı girilmemiş).
class NoBookletKeyException implements Exception {
  const NoBookletKeyException(this.booklet);
  final String booklet;
}

/// Sunucudaki yuvarlamayla aynı (yarım yukarı, sıfırdan uzağa).
double round2(double x) => (x * 100 + (x >= 0 ? 1e-9 : -1e-9)).round() / 100;

/// Optiği puanlar. Saf Dart; sunucudaki `_score_sheet` + `_apply_sheet` ile
/// aynı kurallar (testlerle denetlenir):
///  * İptal edilen (ya da cevabı girilmemiş) soru hiçbir sayıma girmez.
///  * B / C / D kitapçığında öğrencinin i. işareti, kitapçık tablosunda
///    i. sıradaki sorunun A'daki karşılığına yazılır; doğru şık o
///    kitapçığınki (girilmemişse A'daki).
///  * TYT'de tüm dersler sayılır; AYT/YDT'de hiç işaret konmayan test
///    (alan dışı) sayılmaz.
///  * Net = doğru − yanlış × katsayı (yanlış götürmüyorsa doğru sayısı);
///    toplam net = Σ ders neti × ders katsayısı.
class ExamScorer {
  const ExamScorer._();

  static ScoredResult score(
    Map<String, List<String?>> answers,
    String booklet,
    ExamDefinition exam,
  ) {
    final b = booklet.isEmpty ? 'A' : booklet;
    if (b != 'A' && (exam.booklets[b]?.isEmpty ?? true)) {
      throw NoBookletKeyException(b);
    }
    final map = <(String, int), BookletQuestion>{
      if (b != 'A')
        for (final q in exam.booklets[b]!) (q.subject, q.itemNo): q,
    };

    bool touched(String code) =>
        answers[code]?.any((m) => m != null && 'ABCDE'.contains(m)) ?? false;

    final responses = <QuestionResponse>[];
    for (final s in exam.subjects) {
      if (exam.examType != ExamType.tyt && !touched(s.code)) continue;
      final marks = answers[s.code] ?? const [];
      final questions = [
        for (final q in exam.questions)
          if (q.subject == s.code && q.number <= s.questionCount) q,
      ]..sort((x, y) => x.number - y.number);
      for (final q in questions) {
        final bq = map[(q.subject, q.number)];
        final pos = bq?.number ?? q.number;
        final raw = pos - 1 < marks.length ? marks[pos - 1] : null;
        final marked = raw != null && raw.length == 1 && 'ABCDE'.contains(raw)
            ? raw
            : null;
        final correct = q.isCancelled
            ? null
            : (b == 'A' ? q.correct : (bq?.correct ?? q.correct));
        final result = correct == null
            ? ResponseResult.cancelled
            : marked == null
            ? ResponseResult.blank
            : marked == correct
            ? ResponseResult.correct
            : ResponseResult.wrong;
        responses.add(
          QuestionResponse(
            subject: q.subject,
            number: q.number,
            bookletNo: b == 'A' ? null : bq?.number,
            marked: marked,
            correct: correct,
            outcome: q.outcome,
            outcomeId: q.outcomeId,
            result: result,
          ),
        );
      }
    }

    final subjects = <String, SubjectScore>{};
    var total = 0.0;
    for (final s in exam.subjects) {
      final rs = [
        for (final r in responses)
          if (r.subject == s.code && r.result != ResponseResult.cancelled) r,
      ];
      if (rs.isEmpty) continue;
      int count(ResponseResult x) => rs.where((r) => r.result == x).length;
      final c = count(ResponseResult.correct);
      final w = count(ResponseResult.wrong);
      final net = round2(c - w * exam.penalty);
      subjects[s.code] = SubjectScore(
        subject: s.code,
        correct: c,
        wrong: w,
        blank: count(ResponseResult.blank),
        net: net,
        weight: s.weight,
      );
      total += net * s.weight;
    }
    return ScoredResult(
      subjects: subjects,
      responses: responses,
      totalNet: round2(total),
    );
  }
}
