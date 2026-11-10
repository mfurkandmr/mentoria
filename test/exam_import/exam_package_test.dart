import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/features/exam_import/domain/exam_package.dart';
import 'package:mentoria/features/exam_import/domain/exam_scorer.dart';
import 'package:mentoria/features/exam_import/domain/import_plan.dart';
import 'package:mentoria/features/import/data/spreadsheet_reader.dart';

/// Kurumun gönderdiği gerçek örnek dosyalar (TYT07): sabit sütunlu optik
/// çıktısı, cevap anahtarı ve soru-kazanım tablosu.
String _read(String name) =>
    File('test/fixtures/optic/$name').readAsStringSync();

void main() {
  final keyText = _read('cevap_anahtari_TYT07.txt');
  final opticText = _read('optik_cikti_TYT07.txt');
  final tableRows = readSpreadsheet(
    File('test/fixtures/optic/soru_kazanim_TYT07.csv').readAsBytesSync(),
  ).values.first;

  final key = parseAnswerKey(keyText);
  final table = parseOutcomeTable(tableRows);
  final package = buildExamPackage(key, table);
  final exam = package.exam;
  final lines = parseFixedWidthOptic(opticText, 120);

  /// Bağımsız hesap: anahtar ve tablodan doğrudan (uygulama kodu kullanmadan).
  (int, int, int) expected(OpticLine l, String booklet) {
    final a = key.booklets['A']!;
    final bPos = {for (final r in table) r.number: r.bookletBNumber!};
    var d = 0, y = 0, b = 0;
    for (var q = 1; q <= 120; q++) {
      final m = l.answers[(booklet == 'B' ? bPos[q]! : q) - 1];
      if (!'ABCDE'.contains(m) || m == ' ') {
        b++;
      } else if (m == a[q - 1]) {
        d++;
      } else {
        y++;
      }
    }
    return (d, y, b);
  }

  test('dosyalar tanınır', () {
    expect(looksLikeAnswerKey(keyText), isTrue);
    expect(looksLikeFixedWidthOptic(opticText), isTrue);
    expect(looksLikeOutcomeTable(tableRows), isTrue);
    expect(looksLikeAnswerKey(opticText), isFalse);
    expect(looksLikeFixedWidthOptic(keyText), isFalse);
  });

  test('anahtar ve kazanım tablosu sınavı kurar', () {
    expect(key.name, 'TYT Genel Deneme - 7 (TYT07)');
    expect(exam.takenOn, DateTime(2026, 11, 8));
    expect(exam.subjects.fold<int>(0, (s, x) => s + x.questionCount), 120);
    expect(exam.keyGaps.isComplete, isTrue);
    expect(exam.bookletList, ['A', 'B']);
    final q = exam.question('TYT_MAT', 34)!; // genel 94
    expect((q.correct, q.outcome), ('D', 'Fonksiyonlar'));
    expect({for (final x in exam.questions) (x.subject, x.outcome)}.length, 57);
  });

  test('optik satırları: ad, sınıf, kitapçık, Türkçe karakter', () {
    expect(lines, hasLength(40));
    final elif = lines.first;
    expect(
      (elif.number, elif.name, elif.className, elif.booklet),
      ('2026001', 'Elif Yılmaz', '11-A', 'A'),
    );
    final seyma = lines.singleWhere((l) => l.number == '2026100');
    expect(seyma.name, 'Şeyma Nur Büyükgüngör');
    expect(lines.singleWhere((l) => l.number == '2026040').booklet, '');
    expect(lines.every((l) => l.answers.length == 120), isTrue);
  });

  test('her öğrencinin puanı bağımsız hesapla aynı', () {
    final import = opticRowsFor(lines, exam, package.bookletOrders);
    final plan = prepareImport(
      ImportInput(
        rows: import.rows,
        template: import.template,
        exam: exam,
        roster: const [],
      ),
    );
    expect(plan.rows, hasLength(40));
    for (final (i, r) in plan.rows.indexed) {
      final l = lines[i];
      final booklet = r.parsed.booklet!;
      final s = r.score!;
      int count(ResponseResult x) =>
          s.responses.where((e) => e.result == x).length;
      expect(
        (
          count(ResponseResult.correct),
          count(ResponseResult.wrong),
          count(ResponseResult.blank),
        ),
        expected(l, booklet),
        reason: '${l.number} ${l.name}',
      );
    }
    final elif = plan.rows.first.score!;
    expect(elif.totalNet, 62.5);
    final vildan = plan.rows.singleWhere(
      (r) => r.parsed.studentNo == '2026067',
    );
    expect(vildan.score!.totalNet, 104.75);
  });

  test('kitapçığı boş öğrenci cevaplarından B bulunur', () {
    final import = opticRowsFor(lines, exam, package.bookletOrders);
    expect(import.guessedBooklets, hasLength(1));
    final g = import.guessedBooklets.single;
    expect((g.$1, g.$3, g.$4, g.$5), ('2026040', 'B', 65, 23));
  });

  test('B sorusu doğru konuya bağlanır (kitapçıkta ders karışsa bile)', () {
    // A 41 (Tarih) B kitapçığında 43. sırada; Sosyal içinde ders sırası karışık.
    final import = opticRowsFor(lines, exam, package.bookletOrders);
    final plan = prepareImport(
      ImportInput(
        rows: import.rows,
        template: import.template,
        exam: exam,
        roster: const [],
      ),
    );
    final burak = plan.rows.singleWhere((r) => r.parsed.studentNo == '2026004');
    final raw = lines.singleWhere((l) => l.number == '2026004').answers;
    final q41 = burak.score!.responses.singleWhere(
      (e) => e.subject == 'TYT_TAR' && e.number == 1,
    );
    expect(q41.outcome, 'Tarih Bilimi');
    final mark = raw[43 - 1];
    expect(q41.marked, 'ABCDE'.contains(mark) && mark != ' ' ? mark : null);
  });

  test('boş, yıldız ve kısa numara uyarısız işlenir', () {
    final can = lines.singleWhere((l) => l.number == '2026022');
    expect(can.answers.trim(), isEmpty);
    final umut = lines.singleWhere((l) => l.number == '2026064');
    expect(umut.answers[3], '*');
    expect(normalizeStudentNo('0045127'), '45127');
  });

  test('çelişen anahtar hepsiyle birlikte bildirilir', () {
    final broken = parseAnswerKey(
      keyText.replaceFirst('DCBBDECECD', 'ACBBDECECD'),
    );
    expect(
      () => buildExamPackage(broken, table),
      throwsA(
        isA<ExamPackageException>().having(
          (e) => e.problems.map((p) => p.kind),
          'kinds',
          contains(ExamPackageProblemKind.answerConflict),
        ),
      ),
    );
  });
}
