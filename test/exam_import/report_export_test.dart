import 'dart:convert';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_exam_center.dart';
import 'package:mentoria/features/exam_analysis/data/report_excel.dart';
import 'package:mentoria/features/exam_analysis/presentation/report_card_pdf.dart';
import 'package:mentoria/features/exam_import/domain/import_plan.dart';
import 'package:mentoria/features/exam_import/presentation/org_exams_screen.dart';
import 'package:mentoria/features/exam_import/presentation/outcome_pool_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  final c = InMemoryExamCenter.demo(
    roster: const [
      RosterStudent(id: 's1', name: 'Elif', number: '1'),
      RosterStudent(id: 's2', name: 'Can', number: '2'),
    ],
  );

  testWidgets('sınıf karneleri tek PDF, öğrenci başına bir sayfa', (t) async {
    final cards = await c.fetchCardsForExam('org-exam-2');
    expect(cards, hasLength(2));
    Object? error;
    final pdf = await t.runAsync(() async {
      try {
        return await renderReportCardsPdf(cards);
      } catch (e, st) {
        error = '$e $st';
        return null;
      }
    });
    expect(error, isNull);
    final head = latin1.decode(pdf!.sublist(0, 5));
    expect(head, '%PDF-');
    expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(pdf)).length, 2);
  });

  test('rapor Excel: sıralama ve soru sayfaları', () async {
    final r = await c.fetchReport('org-exam-2');
    final bytes = buildExamReportWorkbook(r, examName: 'Kurum Denemesi 2');
    final book = xl.Excel.decodeBytes(bytes);
    expect(
      book.tables.keys,
      containsAll(['Sıralama', 'Sorular', 'Kazanımlar']),
    );
    expect(book.tables['Sıralama']!.maxRows, 2 + r.ranking.length);
  });

  test('anahtar metni ve kitapçık sırası', () {
    expect(cleanKeyText('a b\nC\td-*e'), 'ABCD--E');
    expect(parseOrder('5 4 3 2 1', 5), [5, 4, 3, 2, 1]);
    expect(parseOrder('1,1,2', 3), isNull);
    expect(parseOrder('', 3), isEmpty);
  });

  test('kazanım Excel sütunları başlıktan bulunur', () {
    final (rows, unknown) = parseOutcomeSheet([
      ['Kod', 'Ders', 'Konu', 'Alt Konu'],
      ['M.1', 'TYT Matematik', 'Problemler', 'Yaş problemleri'],
      ['', 'TYT Matematik', 'Sayılar', ''],
      ['', 'Bilinmeyen', 'X', ''],
    ]);
    expect(unknown, 1);
    expect(rows.first.subject, 'TYT_MAT');
    expect(
      (rows.first.topic, rows.first.subtopic, rows.first.code),
      ('Problemler', 'Yaş problemleri', 'M.1'),
    );
    expect(rows.last.subtopic, isNull);
  });
}
