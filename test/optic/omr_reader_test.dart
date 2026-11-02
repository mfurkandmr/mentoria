import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/optic/data/omr/form_painter.dart';
import 'package:mentoria/features/optic/data/omr/homography.dart';
import 'package:mentoria/features/optic/data/omr/omr_reader.dart';
import 'package:mentoria/features/optic/data/omr/optic_template.dart';

/// Şablondaki her ders için rastgele (tohumlu) cevaplar; ~%15 boş.
Map<String, List<String?>> randomAnswers(
  OpticTemplate t,
  int seed, {
  ExamType type = ExamType.tyt,
}) {
  final r = math.Random(seed);
  return {
    for (final code in t.subjectCodes(type))
      code: [
        for (var i = 0; i < subjectByCode(code).questionCount; i++)
          r.nextDouble() < 0.15 ? null : 'ABCDE'[r.nextInt(5)],
      ],
  };
}

/// Formu telefonla çekilmiş gibi yapar: koyu masa zemininde eğik / yamuk
/// kâğıt, bir yandan gelen ışık, gürültü ve JPEG sıkıştırması.
/// [paperCorners]: formun sol üst, sağ üst, sağ alt, sol alt köşelerinin
/// fotoğraftaki yeri (ters çekimde sol üst köşe fotoğrafın sağ altındadır).
Uint8List photograph(
  img.Image form, {
  required List<({double x, double y})> paperCorners,
  int width = 1500,
  int height = 2000,
  int seed = 1,
}) {
  final src = [
    (x: 0.0, y: 0.0),
    (x: form.width - 1.0, y: 0.0),
    (x: form.width - 1.0, y: form.height - 1.0),
    (x: 0.0, y: form.height - 1.0),
  ];
  final back = Homography.fromPoints(paperCorners, src);
  final noise = math.Random(seed);
  final out = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final s = back.map(x.toDouble(), y.toDouble());
      double v;
      if (s.x < 0 || s.y < 0 || s.x >= form.width || s.y >= form.height) {
        v = 70; // masa
      } else {
        v = form.getPixel(s.x.toInt(), s.y.toInt()).luminance.toDouble();
      }
      // Soldan sağa %30 kararan ışık + gürültü.
      v = v * (1 - 0.3 * x / width) + noise.nextInt(25) - 12;
      final c = v.clamp(0, 255).toInt();
      out.setPixelRgb(x, y, c, c, c);
    }
  }
  return img.encodeJpg(out, quality: 80);
}

void main() {
  final t = mentoriaYks;

  for (final form in opticTemplates) {
    test('${form.id}: baloncuklar sayfada ve hizalama işaretlerinin içinde, '
        'üst üste binmiyor; her ders bir kez', () {
      final b = templateBounds(form);
      final r = form.bubbleRadius;
      expect(b.minX - r, greaterThan(0));
      expect(b.minY - r, greaterThan(0));
      expect(b.maxX + r, lessThan(form.width));
      expect(b.maxY + r, lessThan(form.height));
      if (form.anchors.isNotEmpty) {
        final half = form.anchorSize / 2;
        expect(b.minX - r, greaterThan(form.anchors[0].x + half));
        expect(b.maxY + r, lessThan(form.anchors[2].y - half));
      }
      if (form.track case final tr?) {
        // Baloncuklar çubukların sağında ve ilk / son çubuk arasında.
        expect(b.minX - r, greaterThan(tr.x + tr.barWidth / 2));
        expect(b.minY, greaterThanOrEqualTo(tr.firstY));
        expect(b.maxY, lessThanOrEqualTo(tr.bar(tr.count - 1).y));
      }
      final centers = allBubbles(form).toList();
      for (var i = 0; i < centers.length; i++) {
        for (var j = i + 1; j < centers.length; j++) {
          final d = math.sqrt(
            math.pow(centers[i].x - centers[j].x, 2) +
                math.pow(centers[i].y - centers[j].y, 2),
          );
          expect(d, greaterThan(r * 2.2), reason: '$i-$j');
        }
      }
      for (final type in form.examTypes) {
        expect(
          form.subjectCodes(type)..sort(),
          examSubjects
              .where((s) => s.examType == type)
              .map((s) => s.code)
              .toList()
            ..sort(),
        );
      }
    });
  }

  test('şablon tutarlı: baloncuklar köşelerin içinde, üst üste binmiyor', () {
    final b = templateBounds(t);
    final half = t.anchorSize / 2;
    expect(b.minX - t.bubbleRadius, greaterThan(t.anchors[0].x + half));
    expect(b.minY - t.bubbleRadius, greaterThan(t.anchors[0].y + half));
    expect(b.maxX + t.bubbleRadius, lessThan(t.anchors[2].x - half));
    expect(b.maxY + t.bubbleRadius, lessThan(t.anchors[2].y - half));
    final centers = allBubbles(t).toList();
    for (var i = 0; i < centers.length; i++) {
      for (var j = i + 1; j < centers.length; j++) {
        final d = math.sqrt(
          math.pow(centers[i].x - centers[j].x, 2) +
              math.pow(centers[i].y - centers[j].y, 2),
        );
        expect(d, greaterThan(t.bubbleRadius * 2.2), reason: '$i-$j');
      }
    }
    // TYT'nin ve AYT'nin her dersi tam bir kez.
    expect(
      t.subjectCodes(ExamType.tyt)..sort(),
      subjectsFor(ExamType.tyt).map((s) => s.code).toList()..sort(),
    );
    expect(
      t.subjectCodes(ExamType.ayt)..sort(),
      examSubjects
          .where((s) => s.examType == ExamType.ayt)
          .map((s) => s.code)
          .toList()
        ..sort(),
    );
    // Her sütun 40 soruyu aşmaz (ızgara 40 satır).
    for (final blocks in t.layouts.values) {
      for (final block in blocks) {
        expect(block.questionCount, lessThanOrEqualTo(40));
      }
    }
  });

  test('düz taranmış form: cevaplar, numara, oturum, kitapçık', () {
    final answers = randomAnswers(t, 7);
    final form = paintForm(
      t,
      answers: answers,
      studentNumber: '20261042',
      session: 'TYT',
      booklet: 'B',
    );
    final r = readOpticImage(form, t, ExamType.tyt);
    expect(r.uncertain, isEmpty);
    expect(r.answers, answers);
    expect(r.studentNumber, '20261042');
    expect(r.numberUncertain, isFalse);
    expect(r.session, 'TYT');
    expect(r.booklet, 'B');
  });

  test('AYT: aynı ızgara AYT dersleriyle okunur', () {
    final answers = randomAnswers(t, 21, type: ExamType.ayt);
    final form = paintForm(
      t,
      type: ExamType.ayt,
      answers: answers,
      session: 'AYT',
      booklet: 'A',
    );
    final r = readOpticImage(form, t, ExamType.ayt);
    expect(r.uncertain, isEmpty);
    expect(r.answers, answers);
    expect(r.session, 'AYT');
    expect(r.booklet, 'A');
  });

  test('işaretsiz oturum ve kitapçık boş döner', () {
    final r = readOpticImage(
      paintForm(t, answers: randomAnswers(t, 4)),
      t,
      ExamType.tyt,
    );
    expect(r.session, isNull);
    expect(r.booklet, isNull);
    expect(r.bookletUncertain, isFalse);
  });

  test('eğik çekilmiş, gölgeli, gürültülü telefon fotoğrafı', () {
    for (final seed in [1, 2, 3]) {
      final answers = randomAnswers(t, seed);
      final form = paintForm(
        t,
        answers: answers,
        studentNumber: '1234',
        booklet: 'A',
      );
      final photo = photograph(
        form,
        seed: seed,
        paperCorners: [
          (x: 160.0 + seed * 10, y: 140.0),
          (x: 1360.0, y: 210.0 - seed * 15),
          (x: 1420.0, y: 1880.0),
          (x: 110.0, y: 1820.0 + seed * 10),
        ],
      );
      final r = readOptic(photo, t, ExamType.tyt);
      expect(r.uncertain, isEmpty, reason: 'tohum $seed');
      expect(r.answers, answers, reason: 'tohum $seed');
      expect(r.studentNumber, '1234', reason: 'tohum $seed');
      expect(r.booklet, 'A', reason: 'tohum $seed');
    }
  });

  test('ters (180°) çekilmiş fotoğraf yön işaretinden tanınır', () {
    final answers = randomAnswers(t, 31);
    final form = paintForm(t, answers: answers, studentNumber: '77');
    final photo = photograph(
      form,
      paperCorners: [
        (x: 1380.0, y: 1870.0),
        (x: 130.0, y: 1850.0),
        (x: 150.0, y: 150.0),
        (x: 1360.0, y: 120.0),
      ],
    );
    final r = readOptic(photo, t, ExamType.tyt);
    expect(r.uncertain, isEmpty);
    expect(r.answers, answers);
    expect(r.studentNumber, '77');
  });

  test('yan (90°) çekilmiş fotoğraf da okunur', () {
    final answers = randomAnswers(t, 41);
    final form = paintForm(t, answers: answers);
    final photo = photograph(
      form,
      width: 2000,
      height: 1500,
      paperCorners: [
        (x: 1870.0, y: 110.0),
        (x: 1880.0, y: 1400.0),
        (x: 120.0, y: 1390.0),
        (x: 130.0, y: 100.0),
      ],
    );
    final r = readOptic(photo, t, ExamType.tyt);
    expect(r.uncertain, isEmpty);
    expect(r.answers, answers);
  });

  test('kalemi açık basan öğrencinin optiği de okunur', () {
    final answers = randomAnswers(t, 9);
    final form = paintForm(t, answers: answers, markShade: 125);
    final photo = photograph(
      form,
      paperCorners: [
        (x: 120.0, y: 100.0),
        (x: 1400.0, y: 130.0),
        (x: 1380.0, y: 1900.0),
        (x: 100.0, y: 1870.0),
      ],
    );
    final r = readOptic(photo, t, ExamType.tyt);
    expect(r.uncertain, isEmpty);
    expect(r.answers, answers);
  });

  test('iki şık işaretli ve silik işaret belirsiz sayılır', () {
    final answers = randomAnswers(t, 5);
    answers['TYT_MAT']![0] = 'A';
    answers['TYT_MAT']![1] = 'B';
    final form = paintForm(t, answers: answers);
    final mat = t.blocksFor(ExamType.tyt)[2];
    int px(double v) => (v * 2).round();
    // Matematik 1: A'ya ek olarak C de işaretli.
    final c = mat.bubble(0, 2);
    img.fillCircle(
      form,
      x: px(c.x),
      y: px(c.y),
      radius: 15,
      color: img.ColorRgb8(45, 45, 50),
    );
    // Matematik 2: B silinmiş, geriye silik iz kalmış.
    final b = mat.bubble(1, 1);
    img.fillCircle(
      form,
      x: px(b.x),
      y: px(b.y),
      radius: 16,
      color: img.ColorRgb8(255, 255, 255),
    );
    img.fillCircle(
      form,
      x: px(b.x),
      y: px(b.y),
      radius: 11,
      color: img.ColorRgb8(150, 150, 155),
    );

    final r = readOpticImage(form, t, ExamType.tyt);
    expect(r.answers['TYT_MAT']![0], isNull);
    expect(r.answers['TYT_MAT']![1], isNull);
    final byNo = {
      for (final u in r.uncertain.where((u) => u.subject == 'TYT_MAT'))
        u.number: u.candidates,
    };
    expect(byNo[1], 'AC');
    expect(byNo[2], 'B');
    // Diğer sorular etkilenmez.
    expect(r.answers['TYT_TUR'], answers['TYT_TUR']);
  });

  test('köşe işareti kadraj dışında kalınca hata', () {
    final form = paintForm(t, answers: randomAnswers(t, 3));
    final cropped = img.copyCrop(
      form,
      x: 0,
      y: 0,
      width: form.width,
      height: (form.height * 0.8).round(),
    );
    expect(
      () => readOpticImage(cropped, t, ExamType.tyt),
      throwsA(
        isA<OmrException>().having(
          (e) => e.problem,
          'problem',
          OmrProblem.anchorsNotFound,
        ),
      ),
    );
  });

  test('resim olmayan dosya', () {
    expect(
      () => readOptic(Uint8List.fromList([1, 2, 3, 4]), t, ExamType.tyt),
      throwsA(
        isA<OmrException>().having(
          (e) => e.problem,
          'problem',
          OmrProblem.notImage,
        ),
      ),
    );
  });
}
