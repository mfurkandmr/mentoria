import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/optic/data/omr/form_painter.dart';
import 'package:mentoria/features/optic/data/omr/homography.dart';
import 'package:mentoria/features/optic/data/omr/omr_reader.dart';
import 'package:mentoria/features/optic/data/omr/optic_template.dart';

import 'omr_reader_test.dart' show photograph, randomAnswers;

/// Yayınevi formlarına benzeyen sahte form: köşe karesi yok, sol kenarda 54
/// zamanlama çubuğu, pembe baskı (optik makineleri için "görünmez" renk).
const cizgiliTestFormu = OpticTemplate(
  id: 'test_cizgili',
  trName: 'Çizgili test formu',
  width: 1000,
  height: 1414,
  track: TimingTrack(
    x: 35,
    firstY: 80,
    dy: 24,
    count: 54,
    barWidth: 30,
    barHeight: 9,
  ),
  bubbleRadius: 8,
  studentNumber: NumberField(x: 120, y: 128, digits: 6, dx: 22, dy: 24),
  booklet: ChoiceField(
    values: ['A', 'B'],
    bubbles: [(x: 330, y: 128), (x: 370, y: 128)],
  ),
  layouts: {
    ExamType.tyt: [
      AnswerBlock(
        subjects: ['TYT_TUR'],
        x: 250,
        y: 416,
        optionDx: 24,
        rowDy: 24,
      ),
      AnswerBlock(
        subjects: ['TYT_TAR', 'TYT_COG', 'TYT_FEL', 'TYT_DIN'],
        x: 440,
        y: 416,
        optionDx: 24,
        rowDy: 24,
      ),
      AnswerBlock(
        subjects: ['TYT_MAT'],
        x: 630,
        y: 416,
        optionDx: 24,
        rowDy: 24,
      ),
      AnswerBlock(
        subjects: ['TYT_FIZ', 'TYT_KIM', 'TYT_BIY'],
        x: 820,
        y: 416,
        optionDx: 24,
        rowDy: 24,
      ),
    ],
  },
);

final pembe = img.ColorRgb8(235, 120, 200);

img.Image cizgiliForm(Map<String, List<String?>> answers) => paintForm(
  cizgiliTestFormu,
  answers: answers,
  studentNumber: '204517',
  booklet: 'B',
  inkColor: pembe,
);

void main() {
  test('düz taranmış çizgili form', () {
    final answers = randomAnswers(cizgiliTestFormu, 3);
    final r = readOpticImage(
      cizgiliForm(answers),
      cizgiliTestFormu,
      ExamType.tyt,
    );
    expect(r.uncertain, isEmpty);
    expect(r.answers, answers);
    expect(r.studentNumber, '204517');
    expect(r.booklet, 'B');
  });

  test('eğik ve hafif yamuk (~%7 perspektif) telefon fotoğrafı', () {
    for (final seed in [1, 2]) {
      final answers = randomAnswers(cizgiliTestFormu, seed + 10);
      final photo = photograph(
        cizgiliForm(answers),
        seed: seed,
        // Üst kenar alttan ~%7 dar ve kâğıt hafif eğik: tepeden, biraz
        // önden tutulmuş telefon.
        paperCorners: [
          (x: 170.0 + seed * 10, y: 130.0),
          (x: 1340.0, y: 150.0 - seed * 10),
          (x: 1390.0, y: 1870.0),
          (x: 120.0, y: 1855.0 + seed * 5),
        ],
      );
      final r = readOptic(photo, cizgiliTestFormu, ExamType.tyt);
      expect(r.uncertain, isEmpty, reason: 'tohum $seed');
      expect(r.answers, answers, reason: 'tohum $seed');
      expect(r.studentNumber, '204517', reason: 'tohum $seed');
      expect(r.booklet, 'B', reason: 'tohum $seed');
    }
  });

  test('sert perspektif (~%13): yine birebir okunur', () {
    for (final seed in [77, 5]) {
      final answers = randomAnswers(cizgiliTestFormu, seed);
      final photo = photograph(
        cizgiliForm(answers),
        seed: seed,
        paperCorners: [
          (x: 215.0, y: 130.0),
          (x: 1340.0, y: 140.0),
          (x: 1400.0, y: 1870.0),
          (x: 130.0, y: 1860.0),
        ],
      );
      final r = readOptic(photo, cizgiliTestFormu, ExamType.tyt);
      expect(r.uncertain, isEmpty, reason: 'tohum $seed');
      expect(r.answers, answers, reason: 'tohum $seed');
      expect(r.studentNumber, '204517', reason: 'tohum $seed');
    }
  });

  test('hizalama hatası bir birimin altında (gerçek yerlerle kıyas)', () {
    final form = cizgiliForm(randomAnswers(cizgiliTestFormu, 8));
    const corners = [
      (x: 215.0, y: 130.0),
      (x: 1340.0, y: 140.0),
      (x: 1400.0, y: 1870.0),
      (x: 130.0, y: 1860.0),
    ];
    final photo = img.decodeJpg(photograph(form, paperCorners: corners))!;
    final truth = Homography.fromPoints([
      (x: 0.0, y: 0.0),
      (x: form.width - 1.0, y: 0.0),
      (x: form.width - 1.0, y: form.height - 1.0),
      (x: 0.0, y: form.height - 1.0),
    ], corners);
    var worst = 0.0;
    for (final MapEntry(key: p, value: got) in locateBubbles(
      photo,
      cizgiliTestFormu,
      ExamType.tyt,
    ).entries) {
      final want = truth.map(p.x * 2, p.y * 2);
      // Fotoğrafta bir şablon birimi ≈ 1,2 piksel.
      final err =
          math.sqrt(math.pow(want.x - got.x, 2) + math.pow(want.y - got.y, 2)) /
          1.2;
      worst = math.max(worst, err);
    }
    expect(worst, lessThan(1.5));
  });

  test('ters (180°) çekilmiş çizgili form', () {
    final answers = randomAnswers(cizgiliTestFormu, 77);
    final photo = photograph(
      cizgiliForm(answers),
      paperCorners: [
        (x: 1380.0, y: 1870.0),
        (x: 130.0, y: 1850.0),
        (x: 150.0, y: 150.0),
        (x: 1360.0, y: 120.0),
      ],
    );
    final r = readOptic(photo, cizgiliTestFormu, ExamType.tyt);
    expect(r.uncertain, isEmpty);
    expect(r.answers, answers);
  });

  test('çizgiler kadraja girmezse hata', () {
    final form = cizgiliForm(randomAnswers(cizgiliTestFormu, 5));
    final cropped = img.copyCrop(
      form,
      x: 120,
      y: 0,
      width: form.width - 120,
      height: form.height,
    );
    expect(
      () => readOpticImage(cropped, cizgiliTestFormu, ExamType.tyt),
      throwsA(isA<OmrException>()),
    );
  });
}
