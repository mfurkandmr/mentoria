import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/exam_import/domain/exam_definition.dart';
import 'package:mentoria/features/exam_import/domain/exam_scorer.dart';
import 'package:mentoria/features/exam_import/domain/import_plan.dart';
import 'package:mentoria/features/exam_import/domain/optic_result_parser.dart';

/// Matematik 5 soru (katsayı 1,5; 5. soru iptal), Türkçe 4 soru. B
/// kitapçığında matematik ters sırada — SQL testindeki sınavla aynı.
ExamDefinition exam({bool penalty = true}) => ExamDefinition(
  name: 'Kurum Denemesi 1',
  examType: ExamType.tyt,
  takenOn: DateTime(2026, 11, 1),
  wrongPenalty: penalty,
  subjects: const [
    ExamSubjectDef(code: 'TYT_MAT', questionCount: 5, weight: 1.5),
    ExamSubjectDef(code: 'TYT_TUR', questionCount: 4),
  ],
  questions: [
    for (final (i, c) in ['A', 'B', 'C', 'D', 'E'].indexed)
      KeyQuestion(
        subject: 'TYT_MAT',
        number: i + 1,
        correct: c,
        outcome: i < 3 ? 'Problemler — Yaş problemleri' : 'Sayılar',
        cancelled: i == 4,
      ),
    for (var n = 1; n <= 4; n++)
      KeyQuestion(
        subject: 'TYT_TUR',
        number: n,
        correct: 'A',
        outcome: 'Paragraf',
      ),
  ],
  booklets: {
    'B': [
      for (var n = 1; n <= 5; n++)
        BookletQuestion(subject: 'TYT_MAT', number: n, itemNo: 6 - n),
    ],
  },
);

const template = ImportTemplate(
  studentNo: 'ogrenci_no',
  studentName: 'ad_soyad',
  className: 'sinif',
  booklet: 'kitapcik',
  columns: [
    AnswerColumn(column: 'MAT_CEVAP', subjects: ['TYT_MAT']),
    AnswerColumn(column: 'TURKCE_CEVAP', subjects: ['TYT_TUR']),
  ],
);

void main() {
  group('cevap metni', () {
    test('kısa metin: eksik sorular boş + uyarı', () {
      final (m, w) = OpticResultParser.parseAnswers('AB', 5);
      expect(m, ['A', 'B', null, null, null]);
      expect(w.single.kind, RowWarningKind.tooShort);
    });

    test('uzun metin: fazlası kesilir + uyarı', () {
      final (m, w) = OpticResultParser.parseAnswers('ABCDEAB', 5);
      expect(m, ['A', 'B', 'C', 'D', 'E']);
      expect(w.single.kind, RowWarningKind.tooLong);
    });

    test('sondaki boşluk dolgusu uyarı sayılmaz', () {
      final (_, w) = OpticResultParser.parseAnswers('ABCDE   ', 5);
      expect(w, isEmpty);
    });

    test('boş karakterlerin hepsi boş sayılır', () {
      final (m, w) = OpticResultParser.parseAnswers('A -*.', 5);
      expect(m, ['A', null, null, null, null]);
      expect(w, isEmpty);
      expect(OpticResultParser.parseAnswers(null, 3).$1, [null, null, null]);
      expect(OpticResultParser.parseAnswers('', 2).$2, isEmpty);
    });

    test('küçük harf büyür; A-E dışı karakter boş + uyarı', () {
      final (m, w) = OpticResultParser.parseAnswers('abFz', 4);
      expect(m, ['A', 'B', null, null]);
      expect(w.single.kind, RowWarningKind.invalidChar);
      expect(w.single.detail, 'F z');
    });

    test('kitapçık yazımları', () {
      expect(OpticResultParser.normalizeBooklet(null), 'A');
      expect(OpticResultParser.normalizeBooklet(' '), 'A');
      expect(OpticResultParser.normalizeBooklet('TEK'), 'A');
      expect(OpticResultParser.normalizeBooklet('b'), 'B');
      expect(OpticResultParser.normalizeBooklet('C Kitapçığı'), 'C');
      expect(OpticResultParser.normalizeBooklet('2'), 'B');
      expect(OpticResultParser.normalizeBooklet('X'), isNull);
    });
  });

  group('satır', () {
    test('tek sütunda birden çok ders sırayla bölünür', () {
      final r = OpticResultParser.parse(
        {'no': '12', 'FEN': 'ABCDEABCDEABCDEABCDE'},
        const ImportTemplate(
          studentNo: 'no',
          columns: [
            AnswerColumn(
              column: 'FEN',
              subjects: ['TYT_FIZ', 'TYT_KIM', 'TYT_BIY'],
            ),
          ],
        ),
        {'TYT_FIZ': 7, 'TYT_KIM': 7, 'TYT_BIY': 6},
      );
      expect(r.answers['TYT_FIZ']!.join(), 'ABCDEAB');
      expect(r.answers['TYT_KIM']!.join(), 'CDEABCD');
      expect(r.answers['TYT_BIY']!.join(), 'EABCDE');
      expect(r.warnings, isEmpty);
    });

    test('anahtarı olmayan kitapçık satırı hatalı', () {
      final r = OpticResultParser.parse(
        {'ogrenci_no': '1', 'kitapcik': 'C', 'MAT_CEVAP': 'AAAAA'},
        template,
        {'TYT_MAT': 5},
        booklets: const ['A', 'B'],
      );
      expect(r.booklet, isNull);
      expect(r.hasError, isTrue);
    });

    test('başlıklardan eşleştirme tahmini', () {
      final t = OpticResultParser.guess([
        'Öğrenci No',
        'Adı Soyadı',
        'Şube',
        'Kitapçık',
        'TÜRKÇE',
        'SOSYAL',
        'MATEMATİK',
        'FEN',
      ], subjectCodesOf(ExamType.tyt));
      expect(t.studentNo, 'Öğrenci No');
      expect(t.studentName, 'Adı Soyadı');
      expect(t.className, 'Şube');
      expect(t.booklet, 'Kitapçık');
      final cols = {for (final c in t.columns) c.column: c.subjects};
      expect(cols['TÜRKÇE'], ['TYT_TUR']);
      expect(cols['MATEMATİK'], ['TYT_MAT']);
      expect(cols['FEN'], ['TYT_FIZ', 'TYT_KIM', 'TYT_BIY']);
      expect(cols['SOSYAL'], ['TYT_TAR', 'TYT_COG', 'TYT_FEL', 'TYT_DIN']);
    });

    test('AYT başlıkları: dört test sütunu', () {
      final ayt = [for (final s in bookletSubjects(ExamType.ayt)) s.code];
      final t = OpticResultParser.guess([
        'T.C. Kimlik No',
        'Öğrenci No',
        'Adı Soyadı',
        'TÜRK DİLİ VE EDEBİYATI-SOSYAL BİLİMLER-1',
        'SOSYAL BİLİMLER-2',
        'MATEMATİK',
        'FEN BİLİMLERİ',
      ], ayt);
      expect(t.studentNo, 'Öğrenci No');
      final cols = {for (final c in t.columns) c.column: c.subjects};
      expect(cols['TÜRK DİLİ VE EDEBİYATI-SOSYAL BİLİMLER-1'], [
        'AYT_EDB',
        'AYT_TAR1',
        'AYT_COG1',
      ]);
      expect(cols['SOSYAL BİLİMLER-2'], [
        'AYT_TAR2',
        'AYT_COG2',
        'AYT_FELG',
        'AYT_DIN',
      ]);
      expect(cols['MATEMATİK'], ['AYT_MAT']);
      expect(cols['FEN BİLİMLERİ'], ['AYT_FIZ', 'AYT_KIM', 'AYT_BIY']);
      expect(cols.containsKey('T.C. Kimlik No'), isFalse);
    });

    test('AYT başlıkları: kısaltmalar ve ders ders sütunlar', () {
      final ayt = [for (final s in bookletSubjects(ExamType.ayt)) s.code];
      final short = OpticResultParser.guess([
        'NO',
        'SOS1',
        'SOS2',
        'MAT',
        'FEN',
      ], ayt);
      expect(
        {for (final c in short.columns) c.column: c.subjects}['SOS1'],
        ['AYT_EDB', 'AYT_TAR1', 'AYT_COG1'],
        reason: 'ilk test Edebiyat ile başlar',
      );
      final each = OpticResultParser.guess([
        'NO',
        'EDEBİYAT',
        'TARİH-1',
        'COĞRAFYA-1',
        'TARİH-2',
        'COĞRAFYA-2',
        'FELSEFE GRUBU',
        'DİN KÜLTÜRÜ',
        'MATEMATİK',
        'FİZİK',
        'KİMYA',
        'BİYOLOJİ',
      ], ayt);
      expect(
        [for (final c in each.columns) c.subjects.single],
        ayt,
        reason: 'her sütun kendi dersine',
      );
      // Numarasız iki "Tarih" sütunu: ilki Tarih-1, ikincisi Tarih-2.
      final twice = OpticResultParser.guess(
        headersOf([
          ['NO', 'TARİH', 'TARİH'],
        ]),
        ayt,
      );
      expect(
        [for (final c in twice.columns) c.subjects],
        [
          ['AYT_TAR1'],
          ['AYT_TAR2'],
        ],
      );
    });

    test('YDT başlıkları', () {
      for (final h in ['YABANCI DİL', 'İNGİLİZCE', 'YDT', 'Dil Cevapları']) {
        final t = OpticResultParser.guess(
          ['Öğrenci No', 'Ad Soyad', h],
          ['YDT_YD'],
        );
        expect(t.columns.single.subjects, ['YDT_YD'], reason: h);
      }
    });

    test('şablon JSON gidip gelir', () {
      final back = ImportTemplate.fromJson(template.toJson(), name: 'Optik');
      expect(back.toJson(), template.toJson());
      expect(
        back.fits([
          'ogrenci_no',
          'ad_soyad',
          'sinif',
          'kitapcik',
          'MAT_CEVAP',
          'TURKCE_CEVAP',
        ]),
        isTrue,
      );
      expect(back.fits(['ogrenci_no']), isFalse);
    });
  });

  group('puanlama (sunucuyla aynı)', () {
    test('A kitapçığı: iptal soru sayılmaz, katsayılı toplam', () {
      final s = ExamScorer.score(
        {
          'TYT_MAT': ['A', 'C', 'C', 'D', 'A'],
          'TYT_TUR': ['A', 'B', null, null],
        },
        'A',
        exam(),
      );
      final mat = s.subjects['TYT_MAT']!;
      expect((mat.correct, mat.wrong, mat.blank, mat.net), (3, 1, 0, 2.75));
      expect(mat.questions, 4, reason: 'iptal soru soru sayısından düşer');
      expect(s.subjects['TYT_TUR']!.net, 0.75);
      expect(s.totalNet, 4.88, reason: '2,75 × 1,5 + 0,75');
      expect(
        s.responses.firstWhere((r) => r.number == 5).result,
        ResponseResult.cancelled,
      );
    });

    test('A ve B kitapçıklı iki öğrenci farklı anahtarla doğru net', () {
      final a = ExamScorer.score(
        {
          'TYT_MAT': ['A', 'B', 'C', 'D', 'E'],
        },
        'A',
        exam(),
      );
      // Aynı cevaplar B kitapçığında ters sırayla: tamamı doğru.
      final b = ExamScorer.score(
        {
          'TYT_MAT': ['E', 'D', 'C', 'B', 'A'],
        },
        'B',
        exam(),
      );
      expect(a.subjects['TYT_MAT']!.correct, 4);
      expect(b.subjects['TYT_MAT']!.correct, 4);
      // A'nın cevaplarını B'de işaretleyen öğrenci yalnızca ortadakini tutturur.
      final wrong = ExamScorer.score(
        {
          'TYT_MAT': ['A', 'B', 'C', 'D', 'E'],
        },
        'B',
        exam(),
      );
      expect(wrong.subjects['TYT_MAT']!.correct, 1);
      final r = b.responses.firstWhere((r) => r.number == 1);
      expect((r.bookletNo, r.marked), (5, 'A'));
    });

    test('şıkları karışık kitapçık: o kitapçığın cevabı kullanılır', () {
      final e = exam().copyWith(
        booklets: {
          'C': [
            for (var n = 1; n <= 5; n++)
              BookletQuestion(
                subject: 'TYT_MAT',
                number: n,
                itemNo: n,
                correct: 'E',
              ),
          ],
        },
      );
      final s = ExamScorer.score(
        {
          'TYT_MAT': ['E', 'E', 'E', 'E', 'E'],
        },
        'C',
        e,
      );
      expect(s.subjects['TYT_MAT']!.correct, 4);
      expect(
        () => ExamScorer.score(const {}, 'D', e),
        throwsA(isA<NoBookletKeyException>()),
      );
    });

    test('yanlış doğruyu götürmüyorsa net = doğru', () {
      final s = ExamScorer.score(
        {
          'TYT_MAT': ['A', 'C', 'C', 'D', 'A'],
        },
        'A',
        exam(penalty: false),
      );
      expect(s.subjects['TYT_MAT']!.net, 3);
    });

    test('TYT: işaretsiz ders boş; AYT: alan dışı test sayılmaz', () {
      final s = ExamScorer.score(
        {
          'TYT_MAT': ['A'],
        },
        'A',
        exam(),
      );
      expect(s.subjects['TYT_TUR']!.blank, 4);
      final ayt = exam().copyWith(
        examType: ExamType.ayt,
        subjects: const [
          ExamSubjectDef(code: 'AYT_MAT', questionCount: 2),
          ExamSubjectDef(code: 'AYT_FIZ', questionCount: 2),
        ],
        questions: const [
          KeyQuestion(subject: 'AYT_MAT', number: 1, correct: 'A'),
          KeyQuestion(subject: 'AYT_MAT', number: 2, correct: 'B'),
          KeyQuestion(subject: 'AYT_FIZ', number: 1, correct: 'A'),
          KeyQuestion(subject: 'AYT_FIZ', number: 2, correct: 'B'),
        ],
        booklets: const {},
      );
      final a = ExamScorer.score(
        {
          'AYT_MAT': ['A', null],
        },
        'A',
        ayt,
      );
      expect(a.subjects.keys, ['AYT_MAT']);
    });

    test('YDT: 80 soru tek ders; boş kağıt sayılmaz', () {
      final ydt = ExamDefinition(
        name: 'YDT 1',
        examType: ExamType.ydt,
        takenOn: DateTime(2026, 11, 1),
        subjects: const [ExamSubjectDef(code: 'YDT_YD', questionCount: 80)],
        questions: [
          for (var n = 1; n <= 80; n++)
            KeyQuestion(subject: 'YDT_YD', number: n, correct: 'ABCDE'[n % 5]),
        ],
      );
      // İlk 50 doğru, 20 yanlış, 10 boş.
      final s = ExamScorer.score(
        {
          'YDT_YD': [
            for (var n = 1; n <= 80; n++)
              n <= 50
                  ? 'ABCDE'[n % 5]
                  : n <= 70
                  ? 'ABCDE'[(n + 1) % 5]
                  : null,
          ],
        },
        'A',
        ydt,
      );
      final yd = s.subjects['YDT_YD']!;
      expect((yd.correct, yd.wrong, yd.blank, yd.net), (50, 20, 10, 45.0));
      expect(s.totalNet, 45);
      final empty = ExamScorer.score(
        {'YDT_YD': List.filled(80, null)},
        'A',
        ydt,
      );
      expect(empty.subjects, isEmpty);
      expect(empty.totalNet, 0);
    });
  });

  group('içe aktarma planı', () {
    final roster = [
      const RosterStudent(id: 's1', name: 'Ayşe Yılmaz', number: '0012'),
      const RosterStudent(id: 's2', name: 'Mehmet Kaya', number: '13'),
    ];
    List<List<String>> sheet(List<List<String>> body) => [
      [
        'ogrenci_no',
        'ad_soyad',
        'sinif',
        'kitapcik',
        'TURKCE_CEVAP',
        'MAT_CEVAP',
      ],
      ...body,
    ];

    test('eşleşmeyen numara içe aktarmayı durdurmaz, raporlanır', () {
      final plan = prepareImport(
        ImportInput(
          rows: sheet([
            ['12', 'AYSE YILMAZ', '12-A', 'A', 'AB  ', 'ACCDA'],
            ['999', 'Bilinmeyen', '12-A', 'A', 'AAAA', 'AAAAA'],
            ['13', 'Zeynep Kaya', '12-B', 'B', 'AAAA', 'EDCBA'],
            ['', 'Numarasız', '', 'A', 'AAAA', 'AAAAA'],
            ['12', 'Ayşe Yılmaz', '', 'A', 'AAAA', 'AAAAA'],
            ['', '', '', '', '', ''],
          ]),
          template: template,
          exam: exam(),
          roster: roster,
        ),
      );
      expect(plan.rows.length, 5, reason: 'boş satır atlandı');
      expect(plan.matched, 1);
      expect(plan.unmatched, 1);
      expect(plan.mismatched, 1, reason: 'numara tuttu, ad tutmadı');
      expect(plan.failed, 2, reason: 'numarasız + aynı numara ikinci kez');
      expect(plan.rows.last.duplicate, isTrue);
      expect(plan.rows.first.student!.id, 's1', reason: 'baştaki sıfır');
      expect(plan.rows.first.score!.totalNet, 4.88);
      expect(plan.rows[2].score!.subjects['TYT_MAT']!.correct, 4);
    });

    test('adlarda Türkçe harf ve sıra farkı', () {
      expect(namesMatch('AYSE YILMAZ', 'Ayşe Yılmaz'), isTrue);
      expect(namesMatch('Ayşe Nur Yılmaz', 'Ayşe Yılmaz'), isTrue);
      expect(namesMatch('Ayşe Kaya', 'Ayşe Yılmaz'), isFalse);
      expect(normalizeStudentNo(' 00123.0 '), '123');
    });
  });
}
