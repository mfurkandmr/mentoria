import '../../exam_import/domain/exam_definition.dart';
import '../../exam_import/domain/exam_scorer.dart';

/// Bir kazanımda başarı (öğrenci, sınıf ya da kurum için; sunucudaki
/// v_*_outcome_analysis görünümlerinin satırı).
class OutcomeStat {
  const OutcomeStat({
    required this.subject,
    required this.outcomeKey,
    required this.outcome,
    required this.questions,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.lostNet,
    this.students = 1,
    this.examId,
    this.takenOn,
  });

  final String subject;

  /// Kazanım kimliği ya da metnin sadeleşmiş hâli (sınavlar arası eşleşme).
  final String outcomeKey;
  final String outcome;
  final int questions;
  final int correct;
  final int wrong;
  final int blank;

  /// Bu kazanımda kaybedilen net (yanlış: 1 + katsayı, boş: 1; ders
  /// katsayısıyla). Sınıf / kurumda öğrenci başına ortalama.
  final double lostNet;
  final int students;
  final String? examId;
  final DateTime? takenOn;

  /// 0-100, bir basamak.
  double get successPct =>
      questions == 0 ? 0 : (1000 * correct / questions).round() / 10;
}

/// Kazanım anahtarı: kimlik varsa o, yoksa metnin sadeleşmiş hâli.
String outcomeKeyOf(String? outcomeId, String outcome) =>
    outcomeId ?? foldTr(outcome).replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Soru soru sonuçlardan kazanım başarıları. İptal sorular ve kazanımı
/// yazılmamış sorular sayılmaz.
List<OutcomeStat> outcomeStats(
  List<QuestionResponse> responses, {
  required double penalty,
  Map<String, double> weights = const {},
  String? examId,
  DateTime? takenOn,
}) {
  final groups = <(String, String), List<QuestionResponse>>{};
  for (final r in responses) {
    final o = r.outcome?.trim() ?? '';
    if (r.result == ResponseResult.cancelled || o.isEmpty) continue;
    groups
        .putIfAbsent((r.subject, outcomeKeyOf(r.outcomeId, o)), () => [])
        .add(r);
  }
  return [
    for (final MapEntry(key: (subject, key), value: rs) in groups.entries)
      () {
        int n(ResponseResult x) => rs.where((r) => r.result == x).length;
        final w = n(ResponseResult.wrong);
        final b = n(ResponseResult.blank);
        final weight = weights[subject] ?? 1;
        return OutcomeStat(
          subject: subject,
          outcomeKey: key,
          outcome: rs.first.outcome!.trim(),
          questions: rs.length,
          correct: n(ResponseResult.correct),
          wrong: w,
          blank: b,
          lostNet: round2((w * (1 + penalty) + b) * weight),
          examId: examId,
          takenOn: takenOn,
        );
      }(),
  ];
}

/// Zayıf kazanımlar: başarı yüzdesi artan; eşitlikte çok net kaybettiren önce.
List<OutcomeStat> weakestOutcomes(List<OutcomeStat> stats, {int limit = 5}) {
  final list =
      [
        for (final s in stats)
          if (s.correct < s.questions) s,
      ]..sort((a, b) {
        final c = a.successPct.compareTo(b.successPct);
        return c != 0 ? c : b.lostNet.compareTo(a.lostNet);
      });
  return list.take(limit).toList();
}

/// Net kaybı haritası: en çok net kaybettiren (düzelince en çok kazandıran)
/// kazanım önce.
List<OutcomeStat> lostNetMap(List<OutcomeStat> stats, {int? limit}) {
  final list = [
    for (final s in stats)
      if (s.lostNet > 0) s,
  ]..sort((a, b) => b.lostNet.compareTo(a.lostNet));
  return limit == null ? list : list.take(limit).toList();
}

enum TrendDirection { improving, worsening, steady }

class OutcomeTrend {
  const OutcomeTrend({
    required this.subject,
    required this.outcomeKey,
    required this.outcome,
    required this.points,
  });

  final String subject;
  final String outcomeKey;
  final String outcome;

  /// Sınav tarihine göre (eski → yeni).
  final List<OutcomeStat> points;

  /// Son sınav ile ilk sınav arası fark (yüzde puanı).
  double get change => points.last.successPct - points.first.successPct;

  /// 10 puandan fazla değişim yön sayılır.
  TrendDirection get direction => change >= 10
      ? TrendDirection.improving
      : change <= -10
      ? TrendDirection.worsening
      : TrendDirection.steady;
}

/// Birden çok sınavda ölçülen kazanımların gidişatı (en az iki sınav).
/// En çok kötüleşen önce.
List<OutcomeTrend> outcomeTrends(List<OutcomeStat> stats) {
  final groups = <(String, String), List<OutcomeStat>>{};
  for (final s in stats) {
    if (s.takenOn == null) continue;
    groups.putIfAbsent((s.subject, s.outcomeKey), () => []).add(s);
  }
  return [
    for (final MapEntry(key: (subject, key), value: list) in groups.entries)
      if (list.map((s) => s.examId).toSet().length >= 2)
        OutcomeTrend(
          subject: subject,
          outcomeKey: key,
          outcome: list.last.outcome,
          points: list..sort((a, b) => a.takenOn!.compareTo(b.takenOn!)),
        ),
  ]..sort((a, b) => a.change.compareTo(b.change));
}
