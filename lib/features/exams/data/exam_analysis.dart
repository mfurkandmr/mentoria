import 'dart:math' as math;

import '../../../core/constants/exam_subjects.dart';
import 'exam.dart';

/// Bir serinin doğrusal eğilimi (en küçük kareler): y = a + b·x, x = 0..n-1.
class Trend {
  const Trend({required this.slope, required this.intercept, required this.r2});

  /// Deneme başına değişim (net / deneme).
  final double slope;
  final double intercept;

  /// Uyum (0..1): noktalar çizgiye ne kadar yakın.
  final double r2;

  double at(double x) => intercept + slope * x;

  static Trend? fit(List<double> ys) {
    final n = ys.length;
    if (n < 2) return null;
    final mx = (n - 1) / 2;
    final my = ys.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = i - mx, dy = ys[i] - my;
      sxy += dx * dy;
      sxx += dx * dx;
      syy += dy * dy;
    }
    final b = sxy / sxx;
    final r2 = syy == 0 ? 1.0 : (sxy * sxy) / (sxx * syy);
    return Trend(slope: b, intercept: my - b * mx, r2: r2);
  }
}

/// Dersin gidişatı (kullanıcıya gösterilen tek kelimelik durum).
enum SubjectMomentum { rising, steady, falling, fluctuating, single }

/// Bir dersin son denemelerdeki analizi.
class SubjectAnalysis {
  SubjectAnalysis._({
    required this.code,
    required this.nets,
    required this.dates,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.trend,
  });

  final String code;

  /// Eskiden yeniye netler (dersin girildiği denemeler).
  final List<double> nets;
  final List<DateTime> dates;
  final int correct;
  final int wrong;
  final int blank;
  final Trend? trend;

  ExamSubject get subject => subjectByCode(code);
  int get questionCount => subject.questionCount;

  double get last => nets.last;
  double get average => nets.reduce((a, b) => a + b) / nets.length;
  double get best => nets.reduce(math.max);

  /// Standart sapma: küçükse istikrarlı.
  double get spread {
    final m = average;
    return math.sqrt(
      nets.fold<double>(0, (s, v) => s + (v - m) * (v - m)) / nets.length,
    );
  }

  /// Ortalama netin soru sayısına oranı (0..1).
  double get mastery => (average / questionCount).clamp(0.0, 1.0);

  /// Boş bırakılmayanlarda doğru oranı (0..1).
  double get accuracy => correct + wrong == 0 ? 0 : correct / (correct + wrong);

  /// Boş bırakma oranı (0..1).
  double get blankRate {
    final all = correct + wrong + blank;
    return all == 0 ? 0 : blank / all;
  }

  /// İlk yarının ortalamasından son yarının ortalamasına değişim.
  double? get halfChange {
    if (nets.length < 2) return null;
    final h = nets.length ~/ 2;
    double avg(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
    return avg(nets.skip(nets.length - h)) - avg(nets.take(h));
  }

  /// Eğilim sürerse [ahead] deneme sonraki tahmini net (0..soru sayısı).
  double? projection([int ahead = 5]) {
    final t = trend;
    if (t == null || nets.length < 3) return null;
    return t
        .at(nets.length - 1 + ahead.toDouble())
        .clamp(0, questionCount.toDouble());
  }

  SubjectMomentum get momentum {
    final t = trend;
    if (t == null) return SubjectMomentum.single;
    // Ders büyüklüğüne göre eşik: 40 soruluk derste 0,5 net/deneme.
    final threshold = math.max(0.15, questionCount / 80);
    if (t.slope >= threshold && t.r2 >= 0.25) return SubjectMomentum.rising;
    if (t.slope <= -threshold && t.r2 >= 0.25) return SubjectMomentum.falling;
    if (spread > questionCount * 0.12) return SubjectMomentum.fluctuating;
    return SubjectMomentum.steady;
  }
}

/// Bir sınav türündeki son denemelerin ders ders analizi.
class ExamAnalysis {
  ExamAnalysis._(this.exams, this.subjects, this.totalTrend);

  /// [exams] eskiden yeniye; son [window] deneme (null: hepsi).
  factory ExamAnalysis.of(List<Exam> exams, {int? window}) {
    final sorted = [...exams]..sort(Exam.byDate);
    final recent = window == null || sorted.length <= window
        ? sorted
        : sorted.sublist(sorted.length - window);
    final codes =
        <String>{
          for (final e in recent)
            for (final r in e.results) r.code,
        }.toList()..sort(
          (a, b) => examSubjects
              .indexWhere((s) => s.code == a)
              .compareTo(examSubjects.indexWhere((s) => s.code == b)),
        );
    final subjects = <SubjectAnalysis>[];
    for (final code in codes) {
      final nets = <double>[];
      final dates = <DateTime>[];
      var c = 0, w = 0, b = 0;
      for (final e in recent) {
        final r = e.results.where((r) => r.code == code).firstOrNull;
        if (r == null) continue;
        nets.add(r.net);
        dates.add(e.takenOn);
        c += r.correct;
        w += r.wrong;
        b += r.blank;
      }
      subjects.add(
        SubjectAnalysis._(
          code: code,
          nets: nets,
          dates: dates,
          correct: c,
          wrong: w,
          blank: b,
          trend: Trend.fit(nets),
        ),
      );
    }
    return ExamAnalysis._(
      recent,
      subjects,
      Trend.fit([for (final e in recent) e.totalNet]),
    );
  }

  final List<Exam> exams;
  final List<SubjectAnalysis> subjects;
  final Trend? totalTrend;

  bool get enough => exams.length >= 2;

  List<SubjectAnalysis> get _trended =>
      subjects.where((s) => s.trend != null).toList();

  /// En hızlı yükselen ders: deneme başına en çok net kazandıran (eğim > 0).
  SubjectAnalysis? get fastestRising {
    final list = _trended.where((s) => s.trend!.slope > 0).toList()
      ..sort((a, b) => b.trend!.slope.compareTo(a.trend!.slope));
    return list.firstOrNull;
  }

  /// Dikkat isteyen ders: en çok düşen, yoksa ustalığı en düşük.
  SubjectAnalysis? get needsAttention {
    final falling = _trended.where((s) => s.trend!.slope < 0).toList()
      ..sort((a, b) => a.trend!.slope.compareTo(b.trend!.slope));
    if (falling.isNotEmpty) return falling.first;
    final weak = [...subjects]..sort((a, b) => a.mastery.compareTo(b.mastery));
    return weak.firstOrNull;
  }

  /// En istikrarlı ders (soru sayısına göre en küçük sapma, en az 3 deneme).
  SubjectAnalysis? get mostConsistent {
    final list = subjects.where((s) => s.nets.length >= 3).toList()
      ..sort(
        (a, b) =>
            (a.spread / a.questionCount).compareTo(b.spread / b.questionCount),
      );
    return list.firstOrNull;
  }
}
