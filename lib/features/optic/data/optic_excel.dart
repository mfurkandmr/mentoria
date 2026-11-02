import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import 'answer_key.dart';
import 'optic_repository.dart';

/// Denemenin Excel dosyası (her okunan optikle güncel; koç indirir):
///  * Sonuçlar: öğrenci başına ders ders D / Y / B / net ve toplam net.
///  * Cevaplar: öğrenci × soru, işaretlenen şık ("B ✗ A": B işaretlemiş,
///    doğrusu A).
///  * Kazanımlar: her sorunun kazanımı, kaç öğrencinin doğru / yanlış / boş
///    yaptığı ve başarı yüzdesi (en düşük başarı üstte).
Uint8List buildOpticWorkbook({
  required AnswerKey key,
  required List<OpticSheet> sheets,
  required Map<String, ({String name, String? number})> students,
}) {
  final book = xl.Excel.createExcel();
  final defaultSheet = book.getDefaultSheet();
  xl.CellValue t(String v) => xl.TextCellValue(v);
  xl.CellValue n(num v) =>
      v is int ? xl.IntCellValue(v) : xl.DoubleCellValue(v.toDouble());

  final subjects = [
    for (final s in examSubjects)
      if (key.items.any((i) => i.subject == s.code)) s,
  ];
  final scored = [
    for (final s in sheets)
      (sheet: s, score: scoreOptic(key.items, s.answers, key.examType)),
  ]..sort((a, b) => b.score.net.compareTo(a.score.net));
  String nameOf(String id) => students[id]?.name ?? '?';
  String numberOf(String id) => students[id]?.number ?? '';

  // --- Sonuçlar ---
  final results = book[tr('Sonuçlar')];
  results.appendRow([
    t(tr('Sıra')),
    t(tr('Öğrenci No')),
    t(tr('Ad Soyad')),
    for (final s in subjects) ...[
      t('${s.name} D'),
      t('${s.name} Y'),
      t('${s.name} B'),
      t('${s.name} Net'),
    ],
    t(tr('Toplam Doğru')),
    t(tr('Toplam Yanlış')),
    t(tr('Toplam Boş')),
    t(tr('Toplam Net')),
  ]);
  for (final (i, r) in scored.indexed) {
    results.appendRow([
      n(i + 1),
      t(numberOf(r.sheet.studentId)),
      t(nameOf(r.sheet.studentId)),
      for (final s in subjects) ...[
        n(r.score.bySubject[s.code]?.correct ?? 0),
        n(r.score.bySubject[s.code]?.wrong ?? 0),
        n(r.score.bySubject[s.code]?.blank ?? 0),
        n(
          calculateNet(
            r.score.bySubject[s.code]?.correct ?? 0,
            r.score.bySubject[s.code]?.wrong ?? 0,
          ),
        ),
      ],
      n(r.score.correct),
      n(r.score.wrong),
      n(r.score.blank),
      n(r.score.net),
    ]);
  }

  // --- Cevaplar ---
  final answers = book[tr('Cevaplar')];
  answers.appendRow([
    t(tr('Öğrenci No')),
    t(tr('Ad Soyad')),
    for (final i in key.items)
      t('${subjectByCode(i.subject).name} ${i.number}'),
  ]);
  answers.appendRow([
    t(''),
    t(tr('Cevap anahtarı')),
    for (final i in key.items) t(i.correct ?? tr('İptal')),
  ]);
  for (final r in scored) {
    answers.appendRow([
      t(numberOf(r.sheet.studentId)),
      t(nameOf(r.sheet.studentId)),
      for (final i in key.items)
        t(_cell(r.sheet.answers[i.subject]?.elementAtOrNull(i.number - 1), i)),
    ]);
  }

  // --- Kazanımlar ---
  final outcomes = book[tr('Kazanımlar')];
  outcomes.appendRow([
    t(tr('Ders')),
    t(tr('Soru')),
    t(tr('Kazanım')),
    t(tr('Doğru Cevap')),
    t(tr('Doğru')),
    t(tr('Yanlış')),
    t(tr('Boş')),
    t(tr('Başarı %')),
  ]);
  final rows = [
    for (final i in key.items.where((i) => i.correct != null))
      () {
        var c = 0, w = 0, b = 0;
        for (final s in sheets) {
          final m = s.answers[i.subject]?.elementAtOrNull(i.number - 1);
          if (m == null) {
            b++;
          } else if (m == i.correct) {
            c++;
          } else {
            w++;
          }
        }
        final total = c + w + b;
        return (
          item: i,
          c: c,
          w: w,
          b: b,
          rate: total == 0 ? 0.0 : (c * 1000 / total).round() / 10,
        );
      }(),
  ]..sort((a, b) => a.rate.compareTo(b.rate));
  for (final r in rows) {
    outcomes.appendRow([
      t(subjectByCode(r.item.subject).name),
      n(r.item.number),
      t(r.item.outcome ?? ''),
      t(r.item.correct!),
      n(r.c),
      n(r.w),
      n(r.b),
      n(r.rate),
    ]);
  }

  book.setDefaultSheet(tr('Sonuçlar'));
  if (defaultSheet != null) book.delete(defaultSheet);
  return Uint8List.fromList(book.encode()!);
}

/// Doğruysa şık, yanlışsa "B ✗ A", boşsa "–".
String _cell(String? marked, KeyItem item) {
  if (marked == null) return '–';
  if (item.correct == null || marked == item.correct) return marked;
  return '$marked ✗ ${item.correct}';
}
