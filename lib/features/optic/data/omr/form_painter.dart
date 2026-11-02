import 'package:image/image.dart' as img;

import '../../../../core/constants/exam_subjects.dart';
import 'optic_template.dart';

/// Şablonu sade bir resim olarak çizer: okuyucu testleri için işaretlenmiş
/// form (yazdırılan form `optic_form_print.dart`'ta, aynı koordinatlarla).
///
/// [answers]: [type] sınavının ders düzeninde, öğrencinin kitapçığındaki
/// sırayla işaretler. [scale]: sayfa birimi başına piksel (1000 birimlik
/// A4 → 2 ≈ 170 dpi). [markShade]: işaretlerin gri tonu (0 siyah; açık
/// basılmış kalem ~120).
img.Image paintForm(
  OpticTemplate t, {
  ExamType type = ExamType.tyt,
  double scale = 2,
  int markShade = 45,
  img.Color? inkColor,
  Map<String, List<String?>> answers = const {},
  String? studentNumber,
  String? session,
  String? booklet,
}) {
  final w = (t.width * scale).round(), h = (t.height * scale).round();
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  final black = img.ColorRgb8(0, 0, 0);
  final ink = inkColor ?? img.ColorRgb8(150, 150, 170);
  final pencil = img.ColorRgb8(markShade, markShade, markShade + 5);
  int px(double v) => (v * scale).round();

  void square(PagePoint c, double size) => img.fillRect(
    image,
    x1: px(c.x - size / 2),
    y1: px(c.y - size / 2),
    x2: px(c.x + size / 2),
    y2: px(c.y + size / 2),
    color: black,
  );
  for (final a in t.anchors) {
    square(a, t.anchorSize);
  }
  if (t.orientationMark case final m?) square(m, t.orientationMarkSize);
  if (t.track case final tr?) {
    for (var i = 0; i < tr.count; i++) {
      final b = tr.bar(i);
      img.fillRect(
        image,
        x1: px(b.x - tr.barWidth / 2),
        y1: px(b.y - tr.barHeight / 2),
        x2: px(b.x + tr.barWidth / 2),
        y2: px(b.y + tr.barHeight / 2),
        color: black,
      );
    }
  }

  void bubble(PagePoint p, String label, {required bool marked}) {
    final r = px(t.bubbleRadius);
    img.drawCircle(image, x: px(p.x), y: px(p.y), radius: r, color: ink);
    if (marked) {
      img.fillCircle(
        image,
        x: px(p.x),
        y: px(p.y),
        radius: (r * 0.9).round(),
        color: pencil,
      );
    } else {
      img.drawString(
        image,
        label,
        font: img.arial14,
        x: px(p.x) - 4,
        y: px(p.y) - 7,
        color: ink,
      );
    }
  }

  // Boş ızgara (tüm sınavların kutucukları), sonra [type]'ın işaretleri.
  for (final blocks in t.layouts.values) {
    for (final block in blocks) {
      for (var q = 0; q < block.questionCount; q++) {
        for (var o = 0; o < block.options.length; o++) {
          bubble(block.bubble(q, o), block.options[o], marked: false);
        }
      }
    }
  }
  for (final block in t.blocksFor(type)) {
    for (var q = 0; q < block.questionCount; q++) {
      final at = block.questionAt(q);
      final mark = answers[at.subject]?.elementAtOrNull(at.number - 1);
      final o = mark == null ? -1 : block.options.indexOf(mark);
      if (o >= 0) bubble(block.bubble(q, o), mark!, marked: true);
    }
  }

  final field = t.studentNumber;
  if (field != null) {
    final digits = (studentNumber ?? '').split('');
    for (var d = 0; d < field.digits; d++) {
      final value = d < digits.length ? int.tryParse(digits[d]) : null;
      for (var v = 0; v < 10; v++) {
        bubble(field.bubble(d, v), '$v', marked: value == v);
      }
    }
  }
  for (final (f, value) in [(t.session, session), (t.booklet, booklet)]) {
    if (f == null) continue;
    for (final (i, p) in f.bubbles.indexed) {
      bubble(p, f.values[i].substring(0, 1), marked: f.values[i] == value);
    }
  }
  return image;
}
