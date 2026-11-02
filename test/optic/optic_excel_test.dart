import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/import/data/spreadsheet_reader.dart';
import 'package:mentoria/features/optic/data/answer_key.dart';
import 'package:mentoria/features/optic/data/optic_excel.dart';
import 'package:mentoria/features/optic/data/optic_repository.dart';

void main() {
  test('Excel: sonuçlar nete göre sıralı, cevaplar ve kazanım başarısı', () {
    final key = AnswerKey(
      id: 'k',
      name: 'Kasım TYT-1',
      examType: ExamType.tyt,
      takenOn: DateTime(2026, 11, 1),
      templateId: 'mentoria_yks',
      createdAt: DateTime(2026, 11, 1),
      items: const [
        KeyItem(
          subject: 'TYT_TUR',
          number: 1,
          correct: 'B',
          outcome: 'Sözcükte anlam',
        ),
        KeyItem(
          subject: 'TYT_MAT',
          number: 1,
          correct: 'C',
          outcome: 'Trigonometri',
        ),
        KeyItem(subject: 'TYT_MAT', number: 2), // iptal
      ],
    );
    final sheets = [
      OpticSheet(
        examId: 'e1',
        studentId: 'ali',
        readAt: DateTime(2026, 11, 2),
        answers: const {
          'TYT_TUR': ['A'],
          'TYT_MAT': ['C', 'D'],
        },
      ),
      OpticSheet(
        examId: 'e2',
        studentId: 'ayse',
        readAt: DateTime(2026, 11, 2),
        answers: const {
          'TYT_TUR': ['B'],
          'TYT_MAT': ['C', null],
        },
      ),
    ];
    final bytes = buildOpticWorkbook(
      key: key,
      sheets: sheets,
      students: const {
        'ali': (name: 'Ali Kaya', number: '12'),
        'ayse': (name: 'Ayşe Demir', number: null),
      },
    );
    final book = readSpreadsheet(bytes);
    expect(book.keys, containsAll(['Sonuçlar', 'Cevaplar', 'Kazanımlar']));
    expect(book.keys, isNot(contains('Sheet1')));

    final results = book['Sonuçlar']!;
    expect(results[0].take(3), ['Sıra', 'Öğrenci No', 'Ad Soyad']);
    // Ayşe 2 doğru → önce; Ali 1 doğru 1 yanlış.
    expect(results[1][2], 'Ayşe Demir');
    expect(results[1].last, '2');
    expect(results[2].take(3), ['2', '12', 'Ali Kaya']);
    expect(results[2].last, '0.75');

    final answers = book['Cevaplar']!;
    expect(answers[1].skip(2), ['B', 'C', 'İptal']);
    expect(answers[3].skip(2), ['A ✗ B', 'C', 'D']);

    final outcomes = book['Kazanımlar']!;
    // En düşük başarı üstte; iptal soru listede yok.
    expect(outcomes.length, 3);
    expect(outcomes[1].take(3), ['Türkçe', '1', 'Sözcükte anlam']);
    expect(outcomes[1].last, '50');
    expect(outcomes[2].last, '100');
  });
}
