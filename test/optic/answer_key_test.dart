import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/optic/data/answer_key.dart';
import 'package:mentoria/features/optic/data/optic_repository.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';

void main() {
  group('parseAnswerKey', () {
    test('ders içi numaralar, başlık ikinci satırda, küçük harf cevap', () {
      final key = parseAnswerKey([
        ['Kasım TYT-1 Kazanım Tablosu'],
        ['DERS', 'SORU NO', 'DOĞRU CEVAP', 'KAZANIM'],
        ['Matematik', '1', 'c', 'Trigonometri'],
        ['', '2', 'A', 'Üslü sayılar'],
        ['Türkçe', '1', 'B', 'Sözcükte anlam'],
        ['Fizik', '7', 'E', 'Elektrik'],
      ], ExamType.tyt);
      expect(key.skipped, isEmpty);
      expect(
        key.items.map((i) => '${i.subject}${i.number}${i.correct}').toList(),
        ['TYT_TUR1B', 'TYT_MAT1C', 'TYT_MAT2A', 'TYT_FIZ7E'],
      );
      expect(key.items[1].outcome, 'Trigonometri');
      // Ders hücresi boşsa üstteki ders.
      expect(key.items[2].subject, 'TYT_MAT');
    });

    test('test içi numaralar: Sosyal 1–20 ve Fen 1–20 derslere bölünür', () {
      final key = parseAnswerKey([
        ['Test', 'Soru', 'Cevap', 'Konu'],
        ['Sosyal Bilimler', '1', 'A', 'İlk Türk devletleri'],
        ['Sosyal Bilimler', '6', 'B', 'Harita bilgisi'],
        ['Sosyal Bilimler', '20', 'C', 'İslam ve ibadet'],
        ['Fen Bilimleri', '8', 'D', 'Atom'],
        // Ders adı + test içi numara: Coğrafya 7 = Coğrafya 2.
        ['Coğrafya', '7', 'E', 'İklim'],
      ], ExamType.tyt);
      expect(key.items.map((i) => '${i.subject}:${i.number}').toList(), [
        'TYT_TAR:1',
        'TYT_COG:1',
        'TYT_COG:2',
        'TYT_DIN:5',
        'TYT_KIM:1',
      ]);
    });

    test('iptal soru ve okunamayan satırlar', () {
      final key = parseAnswerKey([
        ['Ders', 'No', 'Cevap', 'Kazanım'],
        ['Matematik', '3', 'İPTAL', 'Fonksiyonlar'],
        ['Matematik', '41', 'A', 'Fazla soru'],
        ['Astronomi', '1', 'A', 'Yok böyle ders'],
        ['', '', '', ''],
      ], ExamType.tyt);
      expect(key.items.single.correct, isNull);
      expect(key.skipped, hasLength(2));
    });

    test('AYT: Sosyal Bilimler-1 ve -2 testleri', () {
      final key = parseAnswerKey([
        ['Ders', 'Soru No', 'Cevap'],
        ['Türk Dili ve Edebiyatı-Sosyal Bilimler-1', '25', 'A'],
        ['Sosyal Bilimler-2', '23', 'B'],
        ['Matematik', '40', 'C'],
      ], ExamType.ayt);
      expect(key.items.map((i) => '${i.subject}:${i.number}').toList(), [
        'AYT_MAT:40',
        'AYT_TAR1:1',
        'AYT_FELG:1',
      ]);
    });

    test('başlık yoksa anlaşılır hata', () {
      expect(
        () => parseAnswerKey([
          ['a', 'b'],
          ['1', '2'],
        ], ExamType.tyt),
        throwsA(isA<AnswerKeyFormatException>()),
      );
    });
  });

  test('matchTopic: kazanım konunun adını içeriyorsa bağlanır', () {
    const topics = [
      Topic(id: 1, subjectCode: 'TYT_MAT', name: 'Trigonometri', sort: 1),
      Topic(id: 2, subjectCode: 'TYT_MAT', name: 'Sayılar', sort: 2),
      Topic(id: 3, subjectCode: 'TYT_MAT', name: 'Üslü Sayılar', sort: 3),
      Topic(id: 4, subjectCode: 'TYT_FIZ', name: 'Trigonometri', sort: 1),
    ];
    expect(
      matchTopic('Trigonometrik oranlar — Trigonometri', 'TYT_MAT', topics),
      1,
    );
    // En uzun eşleşen konu.
    expect(matchTopic('Üslü sayılarla işlemler', 'TYT_MAT', topics), 3);
    expect(matchTopic('Paragrafta anlam', 'TYT_MAT', topics), isNull);
    expect(matchTopic(null, 'TYT_MAT', topics), isNull);
  });

  group('scoreOptic', () {
    const items = [
      KeyItem(
        subject: 'TYT_MAT',
        number: 1,
        correct: 'C',
        outcome: 'Trigonometri',
      ),
      KeyItem(subject: 'TYT_MAT', number: 2, correct: 'A'),
      KeyItem(subject: 'TYT_MAT', number: 3), // iptal
      KeyItem(subject: 'TYT_TUR', number: 1, correct: 'B'),
    ];

    test('doğru, yanlış, boş, net ve yanlış listesi', () {
      final s = scoreOptic(items, {
        'TYT_MAT': ['C', 'B', 'D'],
        'TYT_TUR': [null],
      }, ExamType.tyt);
      expect((s.correct, s.wrong, s.blank), (1, 1, 1));
      expect(s.net, 0.75);
      expect(
        s.mistakes.map((m) => '${m.item.subject}${m.item.number}${m.marked}'),
        ['TYT_MAT2B', 'TYT_TUR1null'],
      );
      expect(s.bySubject['TYT_MAT'], (correct: 1, wrong: 1, blank: 0));
    });

    test('AYT: işaret konmayan test sayılmaz', () {
      const ayt = [
        KeyItem(subject: 'AYT_MAT', number: 1, correct: 'A'),
        KeyItem(subject: 'AYT_EDB', number: 1, correct: 'B'),
      ];
      final s = scoreOptic(ayt, {
        'AYT_MAT': ['A'],
      }, ExamType.ayt);
      expect((s.correct, s.wrong, s.blank), (1, 0, 0));
      expect(s.bySubject.keys, ['AYT_MAT']);
    });

    test('B kitapçığı: işaretler B numarasıyla eşleşir', () {
      const b = [
        KeyItem(subject: 'TYT_MAT', number: 1, numberB: 2, correct: 'C'),
        KeyItem(subject: 'TYT_MAT', number: 2, numberB: 1, correct: 'A'),
      ];
      final answers = {
        'TYT_MAT': ['A', 'C'],
      };
      expect(scoreOptic(b, answers, ExamType.tyt, booklet: 'B').correct, 2);
      expect(scoreOptic(b, answers, ExamType.tyt).correct, 0);
      expect(
        AnswerKey(
          id: 'k',
          name: 'x',
          examType: ExamType.tyt,
          takenOn: DateTime(2026),
          templateId: 'mentoria_yks',
          createdAt: DateTime(2026),
          items: b,
        ).hasBookletB,
        isTrue,
      );
      expect(
        AnswerKey(
          id: 'k',
          name: 'x',
          examType: ExamType.tyt,
          takenOn: DateTime(2026),
          templateId: 'mentoria_yks',
          createdAt: DateTime(2026),
          items: const [KeyItem(subject: 'TYT_MAT', number: 1, correct: 'C')],
        ).hasBookletB,
        isFalse,
      );
    });
  });

  group('B Soru No sütunu', () {
    test('ders içi ve test içi B numaraları', () {
      final key = parseAnswerKey([
        ['Ders', 'Soru No', 'B Soru No', 'Cevap', 'Kazanım'],
        ['Matematik', '1', '2', 'C', 'Trigonometri'],
        ['Matematik', '2', '1', 'A', 'Üslü sayılar'],
        // Sosyal testinde test içi numara: Coğrafya 6 (A) = 9 (B) → 1 / 4.
        ['Sosyal Bilimler', '6', '9', 'B', 'Harita'],
      ], ExamType.tyt);
      expect(key.skipped, isEmpty);
      expect(
        key.items.map((i) => '${i.subject}:${i.number}/${i.numberB}').toList(),
        ['TYT_COG:1/4', 'TYT_MAT:1/2', 'TYT_MAT:2/1'],
      );
      // Cevap sütunu "B" harfiyle karışmaz.
      expect(key.items.first.correct, 'B');
    });

    test('tekrar eden ya da başka derse düşen B numarası yok sayılır', () {
      final key = parseAnswerKey([
        ['Ders', 'Soru No', 'B Kitapçığı', 'Cevap'],
        ['Matematik', '1', '3', 'C'],
        ['Matematik', '2', '3', 'A'],
        ['Sosyal Bilimler', '1', '20', 'D'], // A: Tarih 1, B: Din 5
      ], ExamType.tyt);
      expect(key.items.every((i) => i.numberB == null), isTrue);
      expect(key.skipped, hasLength(2));
    });
  });

  test('mistakesByOutcome: konu başına toplar, kazanımlar altında', () {
    ExamAnswer a(String s, int n, String? m, String? c, String? o) =>
        ExamAnswer(subject: s, number: n, marked: m, correct: c, outcome: o);
    final list = mistakesByOutcome([
      a('TYT_TUR', 1, 'A', 'B', 'Paragraf — ana düşünce'),
      a('TYT_TUR', 2, null, 'B', 'Paragraf — akışı bozan cümle'),
      a('TYT_TUR', 3, 'C', 'B', 'Paragraf — ana düşünce'),
      a('TYT_FIZ', 1, 'C', 'A', ' Kuvvet ve hareket '),
      a('TYT_FIZ', 2, 'D', 'D', 'Kuvvet ve hareket'), // doğru
      a('TYT_MAT', 2, 'A', null, 'Problemler'), // iptal
      a('TYT_MAT', 3, 'B', 'C', null), // kazanımı yok
      a('TYT_MAT', 4, 'B', 'C', 'Sayılar: bölünebilme'),
    ]);
    expect(
      [for (final o in list) (o.subject, o.outcome, o.wrong, o.blank)],
      [
        ('TYT_TUR', 'Paragraf', 2, 1),
        ('TYT_MAT', 'Sayılar', 1, 0),
        ('TYT_FIZ', 'Kuvvet ve hareket', 1, 0),
      ],
    );
    expect(list.first.details, ['ana düşünce', 'akışı bozan cümle']);
    expect(list.last.details, isEmpty);
  });

  test('splitOutcome: ayraçlar ve ayraçsız kazanım', () {
    expect(splitOutcome('Paragraf — ana düşünce'), ('Paragraf', 'ana düşünce'));
    expect(splitOutcome('Sayılar - EBOB'), ('Sayılar', 'EBOB'));
    expect(splitOutcome('Kuvvet ve hareket'), ('Kuvvet ve hareket', null));
    expect(splitOutcome('Ses-ışık'), ('Ses-ışık', null));
  });
}
