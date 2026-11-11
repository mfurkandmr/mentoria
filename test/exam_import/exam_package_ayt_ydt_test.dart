import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/exam_import/domain/exam_package.dart';
import 'package:mentoria/features/exam_import/domain/exam_scorer.dart';
import 'package:mentoria/features/exam_import/domain/import_plan.dart';

/// AYT (160 soru) ve YDT (80 soru) paketleri. Elimizde gerçek makine dosyası
/// yok; dosyalar TYT07 örneğinin biçiminde burada üretilir ve sonuçlar
/// uygulama kodundan bağımsız bir hesapla karşılaştırılır.

/// AYT kitapçığı: (ders, soru sayısı) test sırasıyla.
const aytLayout = [
  ('AYT_EDB', 24),
  ('AYT_TAR1', 10),
  ('AYT_COG1', 6),
  ('AYT_TAR2', 11),
  ('AYT_COG2', 11),
  ('AYT_FELG', 12),
  ('AYT_DIN', 6),
  ('AYT_MAT', 40),
  ('AYT_FIZ', 14),
  ('AYT_KIM', 13),
  ('AYT_BIY', 13),
];

String randomKey(Random r, int n) =>
    [for (var i = 0; i < n; i++) 'ABCDE'[r.nextInt(5)]].join();

/// [key] anahtarına göre işaretler: çoğu doğru, bir kısmı yanlış ya da boş.
/// [from]–[to] (1'den, dahil) dışındaki sorular boş bırakılır.
String marks(Random r, String key, int from, int to) => [
  for (var i = 1; i <= key.length; i++)
    if (i < from || i > to)
      ' '
    else
      switch (r.nextInt(10)) {
        < 6 => key[i - 1],
        < 9 => 'ABCDE'[r.nextInt(5)],
        _ => ' ',
      },
].join();

String opticLine(String no, String name, String booklet, String answers) =>
    '$no${name.padRight(25)}${'12-A'.padRight(6)}$booklet$answers';

void main() {
  group('AYT', () {
    final r = Random(7);
    final keyA = randomKey(r, 160);
    // B kitapçığı: sorular kendi testinin (40'lık blok) içinde karışık;
    // dersler test içinde birbirine girer (Tarih-1 sorusu Edebiyat sırasında).
    final bPos = <int, int>{};
    for (var block = 0; block < 4; block++) {
      final places = [for (var i = 1; i <= 40; i++) block * 40 + i]..shuffle(r);
      for (var i = 0; i < 40; i++) {
        bPos[block * 40 + i + 1] = places[i];
      }
    }
    final keyBChars = List.filled(160, '');
    for (var g = 1; g <= 160; g++) {
      keyBChars[bPos[g]! - 1] = keyA[g - 1];
    }
    final keyB = keyBChars.join();
    final keyText = [
      'SINAV: AYT Genel Deneme - 3',
      'TARIH: 15.11.2026',
      '',
      'Türk Dili ve Edebiyatı-Sosyal Bilimler-1   1- 40 (40 soru)',
      'Sosyal Bilimler-2                         41- 80 (40 soru)',
      'Matematik                                 81-120 (40 soru)',
      'Fen Bilimleri                            121-160 (40 soru)',
      '',
      'A KITAPCIGI',
      keyA,
      '',
      'B KITAPCIGI',
      keyB,
      '',
    ].join('\n');
    final tableRows = [
      ['soru_no', 'bolum', 'kazanim', 'zorluk', 'a_cevap', 'b_sorusunun_yeri'],
      for (var g = 1; g <= 160; g++)
        ['$g', '', 'Kazanım ${g % 9}', 'Orta', keyA[g - 1], '${bPos[g]}'],
    ];
    final say = marks(r, keyA, 81, 160);
    final soz = marks(r, keyA, 1, 80);
    // Eşit ağırlık, B kitapçığı: Edebiyat-Sosyal-1 ve Matematik.
    final eaFull = marks(r, keyB, 1, 120);
    final ea = eaFull.replaceRange(40, 80, ' ' * 40);
    final guessB = marks(r, keyB, 81, 160);
    final opticText = [
      opticLine('2026001', 'Sayısal Öğrenci', 'A', say),
      opticLine('2026002', 'Sözel Öğrenci', 'A', soz),
      opticLine('2026003', 'Eşit Ağırlık Öğrenci', 'B', ea),
      opticLine('2026004', 'Kitapçığı Boş', ' ', guessB),
      opticLine('2026005', 'Boş Kağıt', 'A', ' ' * 160),
    ].join('\n');

    final key = parseAnswerKey(keyText);
    final table = parseOutcomeTable(tableRows);

    /// Bağımsız hesap: ders → (doğru, yanlış, boş); işaretsiz ders yok.
    Map<String, (int, int, int)> expected(String answers, String booklet) {
      final out = <String, (int, int, int)>{};
      var g = 0;
      for (final (code, count) in aytLayout) {
        var d = 0, y = 0, b = 0;
        for (var n = 1; n <= count; n++) {
          g++;
          final m = answers[(booklet == 'B' ? bPos[g]! : g) - 1];
          if (m == ' ') {
            b++;
          } else if (m == keyA[g - 1]) {
            d++;
          } else {
            y++;
          }
        }
        if (d + y > 0) out[code] = (d, y, b);
      }
      return out;
    }

    Map<String, (int, int, int)> got(ScoredResult s) => {
      for (final e in s.subjects.entries)
        e.key: (e.value.correct, e.value.wrong, e.value.blank),
    };

    test('anahtar ve tablo AYT sınavını kitapçık sırasıyla kurar', () {
      final exam = buildExamPackage(key, table).exam;
      expect(exam.examType, ExamType.ayt);
      expect(exam.takenOn, DateTime(2026, 11, 15));
      expect([
        for (final s in exam.subjects) (s.code, s.questionCount),
      ], aytLayout);
      expect(exam.keyGaps.isComplete, isTrue);
      expect(exam.bookletList, ['A', 'B']);
      // Genel 81. soru Matematik 1; 148. soru Biyoloji 1.
      expect(exam.question('AYT_MAT', 1)!.correct, keyA[80]);
      expect(exam.question('AYT_BIY', 1)!.correct, keyA[147]);
      expect(exam.question('AYT_EDB', 24)!.outcome, 'Kazanım ${24 % 9}');
    });

    test('her alan yalnızca işaretlediği testlerden puan alır', () {
      final package = buildExamPackage(key, table);
      expect(looksLikeFixedWidthOptic(opticText), isTrue);
      final lines = parseFixedWidthOptic(opticText, 160);
      expect(lines.map((l) => l.booklet), ['A', 'A', 'B', '', 'A']);
      final import = opticRowsFor(lines, package.exam, package.bookletOrders);
      final plan = prepareImport(
        ImportInput(
          rows: import.rows,
          template: import.template,
          exam: package.exam,
          roster: const [],
        ),
      );
      expect(plan.failed, 0);
      final scores = [for (final p in plan.rows) p.score!];
      expect(got(scores[0]), expected(say, 'A'));
      expect(scores[0].subjects.keys, [
        'AYT_MAT',
        'AYT_FIZ',
        'AYT_KIM',
        'AYT_BIY',
      ]);
      expect(got(scores[1]), expected(soz, 'A'));
      expect(scores[1].subjects.keys, isNot(contains('AYT_MAT')));
      expect(scores[1].subjects, hasLength(7));
      expect(got(scores[2]), expected(ea, 'B'));
      expect(scores[2].subjects.keys, [
        'AYT_EDB',
        'AYT_TAR1',
        'AYT_COG1',
        'AYT_MAT',
      ]);
      expect(scores[4].subjects, isEmpty, reason: 'boş kağıt');
      // Toplam net = ders netlerinin toplamı (katsayı 1).
      final e = expected(say, 'A');
      final net = e.values.fold<double>(0, (s, x) => s + x.$1 - x.$2 / 4);
      expect(scores[0].totalNet, closeTo(net, 0.011));
    });

    test('kitapçığı boş AYT satırı cevaplarından B bulunur', () {
      final package = buildExamPackage(key, table);
      final import = opticRowsFor(
        parseFixedWidthOptic(opticText, 160),
        package.exam,
        package.bookletOrders,
      );
      expect(import.guessedBooklets.single.$1, '2026004');
      expect(import.guessedBooklets.single.$3, 'B');
      final plan = prepareImport(
        ImportInput(
          rows: import.rows,
          template: import.template,
          exam: package.exam,
          roster: const [],
        ),
      );
      expect(got(plan.rows[3].score!), expected(guessB, 'B'));
    });

    test('B sorusu test içinde ders değiştirse de doğru derse yazılır', () {
      final package = buildExamPackage(key, table);
      final import = opticRowsFor(
        parseFixedWidthOptic(opticText, 160),
        package.exam,
        package.bookletOrders,
      );
      final plan = prepareImport(
        ImportInput(
          rows: import.rows,
          template: import.template,
          exam: package.exam,
          roster: const [],
        ),
      );
      // Genel 25. soru = Tarih-1'in 1. sorusu.
      final q = plan.rows[2].score!.responses.singleWhere(
        (e) => e.subject == 'AYT_TAR1' && e.number == 1,
      );
      final mark = ea[bPos[25]! - 1];
      expect(q.marked, mark == ' ' ? null : mark);
      expect(q.correct, keyA[24]);
    });

    test('kayıtlı sınavda ders sırası farklı olsa da .txt doğru bölünür', () {
      // Tek kitapçık; dersler eski sırayla (Matematik başta) kaydedilmiş.
      final single = parseAnswerKey(
        keyText.substring(0, keyText.indexOf('B KITAPCIGI')),
      );
      final exam = buildExamPackage(single, table).exam;
      final old = exam.copyWith(
        subjects: [
          for (final s in subjectCodesOfAyt)
            exam.subjects.firstWhere((x) => x.code == s),
        ],
      );
      expect(old.subjects.first.code, 'AYT_MAT');
      final import = opticRowsFor(
        parseFixedWidthOptic(
          [
            opticLine('2026001', 'Sayısal Öğrenci', 'A', say),
            opticLine('2026002', 'Sözel Öğrenci', 'A', soz),
          ].join('\n'),
          160,
        ),
        old,
        const {},
      );
      final plan = prepareImport(
        ImportInput(
          rows: import.rows,
          template: import.template,
          exam: old,
          roster: const [],
        ),
      );
      expect(got(plan.rows[0].score!), expected(say, 'A'));
      expect(got(plan.rows[1].score!), expected(soz, 'A'));
    });

    test('anahtar 160 soru değilse bildirilir', () {
      final short = parseAnswerKey(
        keyText.replaceFirst(keyA, keyA.substring(1)),
      );
      expect(
        () => buildExamPackage(short, table),
        throwsA(
          isA<ExamPackageException>().having(
            (e) => e.problems.map((p) => p.kind),
            'kinds',
            contains(ExamPackageProblemKind.keyLength),
          ),
        ),
      );
    });
  });

  group('YDT', () {
    final r = Random(11);
    final keyA = randomKey(r, 80);
    String keyText(String name) => [
      'SINAV: $name',
      'TARIH: 22.11.2026',
      '',
      'Yabancı Dil   1- 80 (80 soru)',
      '',
      'A KITAPCIGI',
      keyA,
      '',
    ].join('\n');
    final table = parseOutcomeTable([
      ['soru_no', 'bolum', 'kazanim', 'zorluk', 'a_cevap', 'b_sorusunun_yeri'],
      for (var g = 1; g <= 80; g++)
        ['$g', 'Yabancı Dil', 'Kazanım ${g % 5}', 'Zor', keyA[g - 1], ''],
    ]);

    test('YDT paketi kurulur ve puanlanır', () {
      final exam = buildExamPackage(
        parseAnswerKey(keyText('YDT İngilizce Deneme 1')),
        table,
      ).exam;
      expect(exam.examType, ExamType.ydt);
      expect(exam.subjects.single.code, 'YDT_YD');
      expect(exam.subjects.single.questionCount, 80);
      expect(exam.keyGaps.isComplete, isTrue);
      expect(exam.bookletList, ['A']);

      final answers = marks(r, keyA, 1, 80);
      final import = opticRowsFor(
        parseFixedWidthOptic(
          [
            opticLine('2026010', 'Dil Öğrencisi', 'A', answers),
            opticLine('2026011', 'Boş Kağıt', 'A', ' ' * 80),
          ].join('\n'),
          80,
        ),
        exam,
        const {},
      );
      final plan = prepareImport(
        ImportInput(
          rows: import.rows,
          template: import.template,
          exam: exam,
          roster: const [],
        ),
      );
      var d = 0, y = 0, b = 0;
      for (var i = 0; i < 80; i++) {
        if (answers[i] == ' ') {
          b++;
        } else if (answers[i] == keyA[i]) {
          d++;
        } else {
          y++;
        }
      }
      final s = plan.rows.first.score!.subjects['YDT_YD']!;
      expect((s.correct, s.wrong, s.blank), (d, y, b));
      expect(plan.rows.first.score!.totalNet, closeTo(d - y / 4, 0.006));
      expect(plan.rows[1].score!.subjects, isEmpty);
    });

    test('adında tür yoksa soru sayısından anlaşılır', () {
      final exam = buildExamPackage(
        parseAnswerKey(keyText('İngilizce Genel Deneme 5')),
        table,
      ).exam;
      expect(exam.examType, ExamType.ydt);
    });

    test('tür de uzunluk da tutmuyorsa bildirilir', () {
      final odd = parseAnswerKey(
        keyText('Genel Deneme').replaceFirst(keyA, keyA.substring(5)),
      );
      expect(
        () => buildExamPackage(odd, table),
        throwsA(
          isA<ExamPackageException>().having(
            (e) => e.problems.single.kind,
            'kind',
            ExamPackageProblemKind.unsupportedType,
          ),
        ),
      );
    });
  });
}

/// `examSubjects` sırası (Matematik başta): eski kayıtlı AYT sınavları.
final subjectCodesOfAyt = [
  for (final s in examSubjects)
    if (s.examType == ExamType.ayt) s.code,
];
