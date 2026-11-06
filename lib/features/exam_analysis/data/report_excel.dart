import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import 'exam_report_repository.dart';

/// Sınav raporu Excel'i: Sıralama, Dersler, Sınıflar, Kazanımlar, Sorular.
Uint8List buildExamReportWorkbook(
  ExamReport r, {
  required String examName,
  Map<String, String> classNames = const {},
}) {
  final book = xl.Excel.createExcel();
  final defaultSheet = book.getDefaultSheet();
  xl.CellValue t(String v) => xl.TextCellValue(v);
  xl.CellValue n(num v) =>
      v is int ? xl.IntCellValue(v) : xl.DoubleCellValue(v.toDouble());
  xl.CellValue? opt(num? v) => v == null ? null : n(v);
  final bold = xl.CellStyle(bold: true);
  void header(xl.Sheet s, List<String> cols) {
    s.appendRow([for (final c in cols) t(c)]);
    final row = s.maxRows - 1;
    for (var c = 0; c < cols.length; c++) {
      s
              .cell(
                xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
              )
              .cellStyle =
          bold;
    }
  }

  final subjects = [for (final s in r.subjects) s.subject];
  String name(String code) => subjectByCode(code).name;

  final rank = book[tr('Sıralama')];
  rank.appendRow([t(examName)]);
  header(rank, [
    tr('Kurum sırası'),
    tr('Sınıf sırası'),
    tr('Numara'),
    tr('Ad soyad'),
    tr('Sınıf'),
    tr('Kitapçık'),
    for (final s in subjects) ...[
      '${name(s)} ${tr('D')}',
      '${name(s)} ${tr('Y')}',
      '${name(s)} ${tr('B')}',
      '${name(s)} ${tr('Net')}',
    ],
    tr('Toplam net'),
  ]);
  for (final x in r.ranking) {
    rank.appendRow([
      opt(x.rankOrg),
      opt(x.rankClass),
      t(x.studentNumber ?? ''),
      t(x.name),
      t(classNames[x.classroomId] ?? ''),
      t(x.booklet ?? ''),
      for (final s in subjects) ...[
        opt(x.subjects[s]?.correct),
        opt(x.subjects[s]?.wrong),
        opt(x.subjects[s]?.blank),
        opt(x.subjects[s]?.net),
      ],
      n(x.totalNet),
    ]);
  }

  final subj = book[tr('Dersler')];
  header(subj, [
    tr('Ders'),
    tr('Ort. doğru'),
    tr('Ort. yanlış'),
    tr('Ort. boş'),
    tr('Ort. net'),
  ]);
  for (final s in r.subjects) {
    subj.appendRow([
      t(name(s.subject)),
      n(s.avgCorrect),
      n(s.avgWrong),
      n(s.avgBlank),
      n(s.avgNet),
    ]);
  }

  final cls = book[tr('Sınıflar')];
  header(cls, [
    tr('Sınıf'),
    tr('Öğrenci'),
    tr('Ort. toplam net'),
    for (final s in subjects) name(s),
  ]);
  for (final c in r.classes) {
    cls.appendRow([
      t(c.name),
      n(c.students),
      n(c.avgNet),
      for (final s in subjects) opt(c.subjects[s]),
    ]);
  }

  final out = book[tr('Kazanımlar')];
  header(out, [
    tr('Ders'),
    tr('Kazanım'),
    tr('Soru'),
    tr('Doğru'),
    tr('Başarı %'),
    tr('Ort. net kaybı'),
  ]);
  for (final o in r.weakOutcomes) {
    out.appendRow([
      t(name(o.subject)),
      t(o.outcome),
      n(o.questions),
      n(o.correct),
      n(o.successPct),
      n(o.lostNet),
    ]);
  }

  final q = book[tr('Sorular')];
  header(q, [
    tr('Ders'),
    tr('Soru'),
    tr('Cevap'),
    tr('Kazanım'),
    tr('Doğru %'),
    tr('Boş %'),
    tr('En çok işaretlenen yanlış'),
    tr('Ayırt edicilik'),
    tr('Not'),
  ]);
  for (final x in r.questions) {
    q.appendRow([
      t(name(x.subject)),
      n(x.number),
      t(x.correctAnswer ?? ''),
      t(x.outcome ?? ''),
      n(x.correctPct),
      n(x.blankPct),
      t(x.topWrong ?? ''),
      opt(x.discrimination),
      t(
        x.suspectKey
            ? tr('Cevap anahtarını kontrol et')
            : x.veryHard
            ? tr('Konu anlaşılmamış olabilir')
            : '',
      ),
    ]);
  }

  if (defaultSheet != null) book.delete(defaultSheet);
  return Uint8List.fromList(book.encode()!);
}
