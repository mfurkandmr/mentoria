import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/features/exams/data/exam_analysis.dart';

Exam exam(int day, Map<String, (int, int)> results) => Exam(
  id: 'e$day',
  examType: ExamType.tyt,
  name: 'Deneme $day',
  takenOn: DateTime(2026, 9, day),
  results: [
    for (final e in results.entries)
      SubjectResult(
        code: e.key,
        correct: e.value.$1,
        wrong: e.value.$2,
        blank: 0,
      ),
  ],
);

void main() {
  group('doğrusal eğilim', () {
    test('düz artış: eğim ve uyum', () {
      final t = Trend.fit([10, 12, 14, 16])!;
      expect(t.slope, closeTo(2, 1e-9));
      expect(t.intercept, closeTo(10, 1e-9));
      expect(t.r2, closeTo(1, 1e-9));
      expect(t.at(5), closeTo(20, 1e-9));
    });
    test('sabit seri: eğim 0, tam uyum', () {
      final t = Trend.fit([5, 5, 5])!;
      expect(t.slope, 0);
      expect(t.r2, 1);
    });
    test('tek nokta: eğilim yok', () => expect(Trend.fit([3]), isNull));
  });

  group('ders analizi', () {
    // Matematik yükseliyor, Türkçe düşüyor, Fizik dalgalı, Kimya istikrarlı.
    final exams = [
      exam(1, {
        'TYT_MAT': (10, 8),
        'TYT_TUR': (34, 4),
        'TYT_FIZ': (2, 1),
        'TYT_KIM': (4, 0),
      }),
      exam(8, {
        'TYT_MAT': (14, 8),
        'TYT_TUR': (32, 4),
        'TYT_FIZ': (7, 0),
        'TYT_KIM': (4, 0),
      }),
      exam(15, {
        'TYT_MAT': (18, 4),
        'TYT_TUR': (30, 6),
        'TYT_FIZ': (1, 2),
        'TYT_KIM': (4, 1),
      }),
      exam(22, {
        'TYT_MAT': (22, 4),
        'TYT_TUR': (28, 8),
        'TYT_FIZ': (6, 0),
        'TYT_KIM': (4, 0),
      }),
    ];
    final a = ExamAnalysis.of(exams);
    SubjectAnalysis s(String c) => a.subjects.firstWhere((x) => x.code == c);

    test('dersler müfredat sırasında', () {
      expect(a.subjects.map((x) => x.code), [
        'TYT_TUR',
        'TYT_MAT',
        'TYT_FIZ',
        'TYT_KIM',
      ]);
    });

    test('netler, ortalama, isabet, ustalık', () {
      final mat = s('TYT_MAT');
      expect(mat.nets, [8, 12, 17, 21]);
      expect(mat.average, 14.5);
      expect(mat.best, 21);
      expect(mat.accuracy, closeTo(64 / 88, 1e-9));
      expect(mat.mastery, closeTo(14.5 / 40, 1e-9));
      expect(mat.halfChange, 9);
    });

    test('gidişat', () {
      expect(s('TYT_MAT').momentum, SubjectMomentum.rising);
      expect(s('TYT_TUR').momentum, SubjectMomentum.falling);
      expect(s('TYT_FIZ').momentum, SubjectMomentum.fluctuating);
      expect(s('TYT_KIM').momentum, SubjectMomentum.steady);
    });

    test('tahmin soru sayısını aşmaz', () {
      final p = s('TYT_MAT').projection(5)!;
      expect(p, greaterThan(21));
      expect(p, lessThanOrEqualTo(40));
      final big = ExamAnalysis.of([
        for (var i = 1; i <= 4; i++) exam(i, {'TYT_KIM': (i * 2, 0)}),
      ]).subjects.single;
      expect(big.projection(20), 7, reason: 'TYT Kimya 7 soru');
    });

    test('öne çıkanlar', () {
      expect(a.fastestRising?.code, 'TYT_MAT');
      expect(a.needsAttention?.code, 'TYT_TUR');
      expect(a.mostConsistent?.code, 'TYT_KIM');
      expect(a.totalTrend!.slope, greaterThan(0));
    });

    test('pencere: son N deneme', () {
      final last2 = ExamAnalysis.of(exams, window: 2);
      expect(last2.exams.map((e) => e.id), ['e15', 'e22']);
      expect(last2.subjects.first.nets.length, 2);
    });

    test('dersi olmayan denemeler atlanır', () {
      final partial = ExamAnalysis.of([
        exam(1, {'TYT_MAT': (10, 0)}),
        exam(2, {'TYT_TUR': (20, 0)}),
        exam(3, {'TYT_MAT': (12, 0)}),
      ]);
      final mat = partial.subjects.firstWhere((x) => x.code == 'TYT_MAT');
      expect(mat.nets, [10, 12]);
      final tur = partial.subjects.firstWhere((x) => x.code == 'TYT_TUR');
      expect(tur.momentum, SubjectMomentum.single);
    });
  });
}
