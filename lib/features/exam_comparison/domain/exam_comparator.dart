import '../../../core/constants/exam_subjects.dart';
import '../../exams/data/exam.dart';
import '../../optic/data/optic_repository.dart';

/// Seçim sayısına göre görünüm.
enum ComparisonMode {
  /// 2'den az deneme.
  tooFew,

  /// 2-4 deneme: yan yana tablo.
  table,

  /// 5 ve üzeri: özet (trend + ortalamalar).
  summary;

  static ComparisonMode forCount(int n) => n < 2
      ? tooFew
      : n <= ExamComparator.maxTable
      ? table
      : summary;
}

class ComparisonCell {
  const ComparisonCell({
    required this.correct,
    required this.wrong,
    required this.blank,
  });

  final int correct;
  final int wrong;
  final int blank;

  double get net => calculateNet(correct, wrong);
}

/// Bir ders satırı: denemeler sırasıyla hücre (ders o denemede yoksa null).
class ComparisonRow {
  const ComparisonRow({
    required this.code,
    required this.cells,
    required this.best,
    required this.worst,
  });

  final String code;
  final List<ComparisonCell?> cells;

  /// En yüksek / en düşük netin sütunu (en az iki denemede varsa; eşitse null).
  final int? best;
  final int? worst;

  String get name => subjectByCode(code).name;
}

class ComparisonTable {
  const ComparisonTable({
    required this.exams,
    required this.rows,
    required this.totals,
    required this.ranks,
    required this.mixedTypes,
  });

  /// Eskiden yeniye.
  final List<Exam> exams;
  final List<ComparisonRow> rows;
  final List<double> totals;

  /// Toplam nete göre sıra (1 = en yüksek; eşitler aynı sırada).
  final List<int> ranks;

  /// TYT ile AYT (ya da farklı alanlar) birlikte seçildi.
  final bool mixedTypes;
}

/// Ders bazında değişim (özet modu).
class SubjectTrend {
  const SubjectTrend(this.code, this.change, this.average);

  final String code;

  /// İlk ve son denemeler arasındaki eğilim (net / dönem; doğrusal uyum).
  final double change;
  final double average;

  String get name => subjectByCode(code).name;
}

class ComparisonSummary {
  const ComparisonSummary({
    required this.exams,
    required this.averages,
    required this.improving,
    required this.declining,
    required this.mixedTypes,
  });

  /// Eskiden yeniye (toplam net trendi için).
  final List<Exam> exams;
  final List<SubjectTrend> averages;

  /// En çok gelişen / gerileyen en çok 3 ders.
  final List<SubjectTrend> improving;
  final List<SubjectTrend> declining;
  final bool mixedTypes;

  double get averageTotal =>
      exams.fold<double>(0, (s, e) => s + e.totalNet) / exams.length;
}

/// Kazanım satırı: denemeler sırasıyla başarı yüzdesi (yoksa null).
class OutcomeRow {
  const OutcomeRow({
    required this.subject,
    required this.label,
    required this.rates,
    required this.counts,
  });

  final String subject;
  final String label;
  final List<double?> rates;

  /// Denemedeki soru sayısı (yoksa 0).
  final List<int> counts;

  /// İlk ve son ölçüm arasındaki değişim (yüzde puanı).
  double get change {
    final v = [for (final r in rates) ?r];
    return v.length < 2 ? 0 : v.last - v.first;
  }
}

/// Kazanım metni eşleştirme anahtarı: büyük/küçük harf, Türkçe harf,
/// boşluk ve noktalama fark etmez ("ÜSLÜ SAYILAR " = "üslü sayılar").
String normalizeLabel(String s) {
  const map = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  var t = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  map.forEach((k, v) => t = t.replaceAll(k, v));
  return t.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Deneme karşılaştırma hesapları (saf; arayüzden bağımsız).
class ExamComparator {
  ExamComparator._();

  static const maxTable = 4;

  static bool mixed(List<Exam> exams) =>
      exams.map((e) => (e.examType, e.field)).toSet().length > 1;

  /// 2-4 deneme: ders satırları (ders koduyla eşleşir; [examSubjects]
  /// sırası), toplam ve sıra.
  static ComparisonTable compare(List<Exam> selected) {
    final exams = [...selected]..sort(Exam.byDate);
    final codes = {
      for (final e in exams)
        for (final r in e.results) r.code,
    };
    final ordered = [
      for (final s in examSubjects)
        if (codes.contains(s.code)) s.code,
    ];
    final rows = <ComparisonRow>[];
    for (final code in ordered) {
      final cells = [
        for (final e in exams)
          switch (e.results.where((r) => r.code == code).firstOrNull) {
            final r? => ComparisonCell(
              correct: r.correct,
              wrong: r.wrong,
              blank: r.blank,
            ),
            null => null,
          },
      ];
      int? best, worst;
      final present = [
        for (var i = 0; i < cells.length; i++)
          if (cells[i] != null) i,
      ];
      if (present.length >= 2) {
        best = present.reduce((a, b) => cells[a]!.net >= cells[b]!.net ? a : b);
        worst = present.reduce(
          (a, b) => cells[a]!.net <= cells[b]!.net ? a : b,
        );
        if (cells[best]!.net == cells[worst]!.net) {
          best = null;
          worst = null;
        }
      }
      rows.add(
        ComparisonRow(code: code, cells: cells, best: best, worst: worst),
      );
    }
    final totals = [for (final e in exams) e.totalNet];
    final ranks = [
      for (final t in totals) 1 + totals.where((x) => x > t).length,
    ];
    return ComparisonTable(
      exams: exams,
      rows: rows,
      totals: totals,
      ranks: ranks,
      mixedTypes: mixed(exams),
    );
  }

  /// 5+ deneme: ders ortalamaları ve eğilim (doğrusal uyumun eğimi ×
  /// (ölçüm sayısı − 1): dönem boyunca toplam değişim).
  static ComparisonSummary summarize(List<Exam> selected) {
    final exams = [...selected]..sort(Exam.byDate);
    final series = <String, List<(int, double)>>{};
    for (final (i, e) in exams.indexed) {
      for (final r in e.results) {
        series.putIfAbsent(r.code, () => []).add((i, r.net));
      }
    }
    final trends = <SubjectTrend>[];
    for (final s in examSubjects) {
      final pts = series[s.code];
      if (pts == null) continue;
      final avg = pts.fold<double>(0, (a, p) => a + p.$2) / pts.length;
      var change = 0.0;
      if (pts.length >= 2) {
        final mx = pts.fold<double>(0, (a, p) => a + p.$1) / pts.length;
        var num = 0.0, den = 0.0;
        for (final (x, y) in pts) {
          num += (x - mx) * (y - avg);
          den += (x - mx) * (x - mx);
        }
        change = den == 0 ? 0 : num / den * (pts.length - 1);
      }
      trends.add(SubjectTrend(s.code, change, avg));
    }
    final byChange = [
      for (final t in trends)
        if ((series[t.code]?.length ?? 0) >= 2) t,
    ]..sort((a, b) => b.change.compareTo(a.change));
    return ComparisonSummary(
      exams: exams,
      averages: trends,
      improving: [
        for (final t in byChange.take(3))
          if (t.change > 0) t,
      ],
      declining: [
        for (final t in byChange.reversed.take(3))
          if (t.change < 0) t,
      ],
      mixedTypes: mixed(exams),
    );
  }

  /// Seçilen denemelerin en az ikisinde ölçülen kazanımlar. [answers]:
  /// deneme kimliği → soru cevapları (optikle okunmayan denemede boş).
  static List<OutcomeRow> outcomes(
    List<Exam> selected,
    Map<String, List<ExamAnswer>> answers,
  ) {
    final exams = [...selected]..sort(Exam.byDate);
    final label = <String, String>{};
    final subject = <String, String>{};
    final stats = <String, List<(int, int)>>{};
    for (final (i, e) in exams.indexed) {
      for (final a in answers[e.id] ?? const <ExamAnswer>[]) {
        final o = a.outcome?.trim();
        if (o == null || o.isEmpty || a.isCancelled) continue;
        final key = '${a.subject}|${normalizeLabel(o)}';
        label.putIfAbsent(key, () => o);
        subject.putIfAbsent(key, () => a.subject);
        final list = stats.putIfAbsent(
          key,
          () => List.filled(exams.length, (0, 0)),
        );
        final (n, c) = list[i];
        list[i] = (n + 1, c + (a.isCorrect ? 1 : 0));
      }
    }
    final rows = [
      for (final MapEntry(:key, :value) in stats.entries)
        if (value.where((x) => x.$1 > 0).length >= 2)
          OutcomeRow(
            subject: subject[key]!,
            label: label[key]!,
            rates: [for (final (n, c) in value) n == 0 ? null : c * 100 / n],
            counts: [for (final (n, _) in value) n],
          ),
    ];
    int subjectIndex(String code) =>
        examSubjects.indexWhere((s) => s.code == code);
    rows.sort((a, b) {
      final s = subjectIndex(a.subject).compareTo(subjectIndex(b.subject));
      return s != 0 ? s : a.change.compareTo(b.change);
    });
    return rows;
  }
}
