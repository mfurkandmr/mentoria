import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/exams/data/exam.dart';

int _questions(List<ExamSubject> subjects) =>
    subjects.fold(0, (sum, s) => sum + s.questionCount);

Exam _exam(String id, int day, Map<String, (int, int)> results) => Exam(
  id: id,
  examType: ExamType.tyt,
  name: 'Deneme $id',
  takenOn: DateTime(2026, 10, day),
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
  group('net hesabı', () {
    test('4 yanlış 1 doğruyu götürür', () {
      expect(calculateNet(30, 8), 28);
      expect(calculateNet(10, 3), 9.25);
      expect(calculateNet(0, 0), 0);
    });
  });

  group('sınav türüne göre dersler', () {
    test('TYT 120 soru, 9 ders', () {
      final s = subjectsFor(ExamType.tyt);
      expect(s, hasLength(9));
      expect(_questions(s), 120);
    });

    test('AYT her alanda 80 soru', () {
      for (final field in aytFields) {
        expect(
          _questions(subjectsFor(ExamType.ayt, field)),
          80,
          reason: field.label,
        );
      }
    });

    test('AYT Sayısal dersleri', () {
      expect(subjectsFor(ExamType.ayt, FieldType.say).map((s) => s.code), [
        'AYT_MAT',
        'AYT_FIZ',
        'AYT_KIM',
        'AYT_BIY',
      ]);
    });

    test('YDT 80 soru', () {
      expect(_questions(subjectsFor(ExamType.ydt)), 80);
    });
  });

  group('ExamStats', () {
    final stats = ExamStats([
      _exam('c', 20, {'TYT_TUR': (30, 4), 'TYT_MAT': (20, 8)}), // 29 + 18 = 47
      _exam('a', 1, {'TYT_TUR': (20, 8), 'TYT_MAT': (10, 4)}), // 18 + 9 = 27
      _exam('b', 10, {'TYT_TUR': (25, 4)}), // 24
    ]);

    test('tarihe göre sıralar', () {
      expect(stats.exams.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('son net, değişim, ortalama ve en iyi', () {
      expect(stats.last!.totalNet, 47);
      expect(stats.lastChange, 23);
      expect(stats.recentAverage, closeTo((27 + 24 + 47) / 3, 1e-9));
      expect(stats.best, 47);
    });

    test('ilk denemenin değişimi yok', () {
      expect(stats.changeFor(stats.exams.first), isNull);
      expect(stats.changeFor(stats.exams[1]), -3);
    });

    test('ders ortalaması yalnızca girilen denemeleri sayar', () {
      final avg = stats.recentSubjectAverages();
      expect(avg['TYT_TUR'], closeTo((18 + 24 + 29) / 3, 1e-9));
      expect(avg['TYT_MAT'], closeTo((9 + 18) / 2, 1e-9));
    });
  });

  group('aynı güne girilen denemeler', () {
    Exam sameDay(String id, int minute, int correct) => Exam(
      id: id,
      examType: ExamType.tyt,
      name: 'Deneme $id',
      takenOn: DateTime(2026, 10, 16),
      createdAt: DateTime(2026, 10, 16, 12, minute),
      results: [
        SubjectResult(code: 'TYT_MAT', correct: correct, wrong: 0, blank: 0),
      ],
    );

    test('son deneme en son girilendir (liste sırası önemsiz)', () {
      final first = sameDay('1', 0, 10);
      final second = sameDay('2', 5, 20);
      final third = sameDay('3', 9, 30);
      for (final order in [
        [first, second, third],
        [third, first, second],
        [second, third, first],
      ]) {
        final stats = ExamStats(order);
        expect(stats.last!.id, '3');
        expect(stats.lastChange, 10);
        expect(stats.changeFor(second), 10);
        expect(stats.changeFor(first), isNull);
      }
    });

    test('farklı günlerde tarih, giriş saatinden önce gelir', () {
      final older = Exam(
        id: 'eski',
        examType: ExamType.tyt,
        name: 'Eski',
        takenOn: DateTime(2026, 10, 15),
        // Sonradan girilmiş ama dünkü deneme.
        createdAt: DateTime(2026, 10, 16, 23),
        results: const [],
      );
      expect(ExamStats([sameDay('bugun', 0, 5), older]).last!.id, 'bugun');
    });
  });
}
