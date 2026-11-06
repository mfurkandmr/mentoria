import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/exam_comparison/domain/exam_comparator.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/features/optic/data/optic_repository.dart';

Exam exam(
  String id,
  int day, {
  ExamType type = ExamType.tyt,
  String publisher = '3D',
  Map<String, (int, int, int)> results = const {},
}) => Exam(
  id: id,
  examType: type,
  name: 'Deneme $id',
  publisher: publisher,
  takenOn: DateTime(2026, 10, day),
  results: [
    for (final e in results.entries)
      SubjectResult(
        code: e.key,
        correct: e.value.$1,
        wrong: e.value.$2,
        blank: e.value.$3,
      ),
  ],
);

void main() {
  test('görünüm: 2-4 tablo, 5 ve üzeri özet', () {
    expect(ComparisonMode.forCount(1), ComparisonMode.tooFew);
    expect(ComparisonMode.forCount(2), ComparisonMode.table);
    expect(ComparisonMode.forCount(4), ComparisonMode.table);
    expect(ComparisonMode.forCount(5), ComparisonMode.summary);
    expect(ComparisonMode.forCount(9), ComparisonMode.summary);
  });

  test('ders koduyla eşleşir, olmayan ders boş, en yüksek / düşük ve sıra', () {
    final t = ExamComparator.compare([
      // Tarihe göre sıralanır: b önce.
      exam(
        'a',
        10,
        publisher: 'Toprak',
        results: {'TYT_MAT': (30, 4, 6), 'TYT_TUR': (32, 4, 4)},
      ),
      exam('b', 3, results: {'TYT_MAT': (20, 8, 12), 'TYT_FIZ': (5, 1, 1)}),
      exam(
        'c',
        20,
        publisher: 'Karekök',
        results: {'TYT_MAT': (25, 0, 15), 'TYT_TUR': (32, 4, 4)},
      ),
    ]);
    expect(t.exams.map((e) => e.id), ['b', 'a', 'c']);
    expect(t.rows.map((r) => r.code), ['TYT_TUR', 'TYT_MAT', 'TYT_FIZ']);
    final mat = t.rows.firstWhere((r) => r.code == 'TYT_MAT');
    expect(mat.cells.map((c) => c!.net), [18, 29, 25]);
    expect(mat.best, 1);
    expect(mat.worst, 0);
    final tur = t.rows.firstWhere((r) => r.code == 'TYT_TUR');
    expect(tur.cells.first, isNull); // b'de Türkçe yok → "—"
    expect(tur.best, isNull); // eşit
    final fiz = t.rows.firstWhere((r) => r.code == 'TYT_FIZ');
    expect(fiz.cells.skip(1), [null, null]);
    expect(fiz.best, isNull); // tek denemede
    expect(t.totals, [closeTo(22.75, 1e-9), 60, 56]);
    expect(t.ranks, [3, 1, 2]);
    expect(t.mixedTypes, isFalse);
  });

  test('TYT ile AYT karışınca uyarı; aynı adlı dersler ayrı kalır', () {
    final t = ExamComparator.compare([
      exam('t', 1, results: {'TYT_MAT': (30, 0, 10)}),
      exam('y', 2, type: ExamType.ayt, results: {'AYT_MAT': (20, 0, 20)}),
    ]);
    expect(t.mixedTypes, isTrue);
    expect(t.rows.map((r) => r.code), ['TYT_MAT', 'AYT_MAT']);
  });

  test('özet: gelişen ve gerileyen dersler', () {
    final s = ExamComparator.summarize([
      for (var i = 0; i < 6; i++)
        exam(
          'e$i',
          i + 1,
          results: {
            'TYT_MAT': (10 + i * 3, 0, 0), // yükseliyor
            'TYT_TUR': (35 - i * 2, 0, 0), // düşüyor
            'TYT_FIZ': (5, 0, 0), // sabit
          },
        ),
    ]);
    expect(s.improving.map((t) => t.code), ['TYT_MAT']);
    expect(s.improving.single.change, closeTo(15, 1e-9));
    expect(s.declining.map((t) => t.code), ['TYT_TUR']);
    expect(s.declining.single.change, closeTo(-10, 1e-9));
    expect(s.averages.firstWhere((t) => t.code == 'TYT_FIZ').average, 5);
    expect(
      s.averageTotal,
      closeTo(s.exams.fold<double>(0, (a, e) => a + e.totalNet) / 6, 1e-9),
    );
  });

  test('kazanım: yazım farkı eşleşir, en az iki denemede olanlar', () {
    ExamAnswer a(String outcome, bool ok) => ExamAnswer(
      subject: 'TYT_MAT',
      number: 1,
      marked: ok ? 'A' : 'B',
      correct: 'A',
      outcome: outcome,
    );
    final exams = [exam('x', 1), exam('y', 2), exam('z', 3)];
    final rows = ExamComparator.outcomes(exams, {
      'x': [
        a('Üslü Sayılar', false),
        a('Üslü Sayılar', true),
        a('Problemler', true),
      ],
      'y': [a('ÜSLÜ SAYILAR ', true), a('Üslü sayılar.', true)],
      'z': const [],
    });
    expect(rows, hasLength(1));
    expect(rows.single.label, 'Üslü Sayılar');
    expect(rows.single.rates, [50, 100, null]);
    expect(rows.single.change, 50);
    expect(normalizeLabel('İŞLEM Yeteneği'), normalizeLabel('işlem yeteneği'));
  });
}
