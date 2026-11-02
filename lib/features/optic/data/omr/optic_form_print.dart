import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../../../../core/constants/exam_subjects.dart';
import 'optic_template.dart';

/// Yazdırılacak boş cevap kâğıdı: şablonun koordinatlarıyla birebir çizilir
/// (okuyucu aynı şablonu kullanır). Kutular alanların kendi konumundan
/// hesaplanır; her şablon için aynı çizim çalışır. Baloncuk çerçeveleri ve
/// harfler açık renkte (kurşun kalem öne çıksın); köşe kareleri, yön işareti
/// ve zamanlama çubukları tam siyah.
///
/// [fontFamily]: uygulamada yüklü yazı tipi (Türkçe karakterler için).
void paintOpticForm(
  Canvas canvas,
  OpticTemplate t, {
  required double scale,
  String? fontFamily,
  String title = 'YKS CEVAP KÂĞIDI',
}) {
  const black = Color(0xFF000000);
  const ink = Color(0xFF7A80A8);
  const light = Color(0xFFB4B9D3);
  const guide = Color(0xFFE6E8F2);
  Offset o(PagePoint p) => Offset(p.x * scale, p.y * scale);
  double s(double v) => v * scale;
  final r = t.bubbleRadius;

  void text(
    String value,
    PagePoint at, {
    double size = 11,
    Color color = black,
    FontWeight weight = FontWeight.w700,
    TextAlign align = TextAlign.left,
    double width = 300,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: s(size),
          color: color,
          fontWeight: weight,
          height: 1.15,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: s(width));
    final dx = switch (align) {
      TextAlign.center => -p.width / 2,
      TextAlign.right => -p.width,
      _ => 0.0,
    };
    p.paint(canvas, o(at) + Offset(dx, -p.height / 2));
  }

  final stroke = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = s(1.2);
  void box(Rect rect, [String? label]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(s(rect.left), s(rect.top), s(rect.right), s(rect.bottom)),
        Radius.circular(s(8)),
      ),
      stroke,
    );
    if (label != null) {
      text(
        label,
        (x: rect.center.dx, y: rect.top + 13),
        align: TextAlign.center,
        width: rect.width,
      );
    }
  }

  final bubblePaint = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = s(1.1);
  void bubble(PagePoint p, String label) {
    canvas.drawCircle(o(p), s(r), bubblePaint);
    text(
      label,
      p,
      size: r * 1.05,
      color: light,
      weight: FontWeight.w800,
      align: TextAlign.center,
      width: 30,
    );
  }

  Rect around(Iterable<PagePoint> pts, double pad) {
    var l = double.infinity, tp = double.infinity;
    var rt = -double.infinity, b = -double.infinity;
    for (final p in pts) {
      l = math.min(l, p.x);
      tp = math.min(tp, p.y);
      rt = math.max(rt, p.x);
      b = math.max(b, p.y);
    }
    return Rect.fromLTRB(l - pad, tp - pad, rt + pad, b + pad);
  }

  canvas.drawRect(
    Rect.fromLTWH(0, 0, s(t.width), s(t.height)),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  void solid(PagePoint c, double w, double h) => canvas.drawRect(
    Rect.fromCenter(center: o(c), width: s(w), height: s(h)),
    Paint()..color = black,
  );
  for (final a in t.anchors) {
    solid(a, t.anchorSize, t.anchorSize);
  }
  if (t.orientationMark case final m?) {
    solid(m, t.orientationMarkSize, t.orientationMarkSize);
  }
  if (t.track case final tr?) {
    for (var i = 0; i < tr.count; i++) {
      solid(tr.bar(i), tr.barWidth, tr.barHeight);
    }
  }

  text(
    title,
    (x: t.width / 2, y: 45),
    size: 22,
    weight: FontWeight.w900,
    align: TextAlign.center,
    width: 700,
  );

  // Soru ızgarasının üstü: alanlar bu çizginin üstüne sığar.
  final types = t.examTypes.toList();
  final firstRowY = [
    for (final blocks in t.layouts.values)
      for (final b in blocks) b.y,
  ].reduce(math.min);
  final gridTop = firstRowY - 46;
  final fieldBoxes = <Rect>[];

  // Öğrenci numarası: elle yazma kutuları + 0–9 baloncukları.
  final n = t.studentNumber;
  if (n != null) {
    final bubbles = [
      for (var d = 0; d < n.digits; d++)
        for (var v = 0; v < 10; v++) n.bubble(d, v),
    ];
    final inner = around(bubbles, r + 6);
    final rect = Rect.fromLTRB(
      inner.left,
      n.y - r - 52,
      inner.right,
      inner.bottom,
    );
    box(rect, 'ÖĞRENCİ NO');
    fieldBoxes.add(rect);
    for (var d = 0; d < n.digits; d++) {
      final cx = n.x + d * n.dx;
      canvas.drawRect(
        Rect.fromCenter(
          center: o((x: cx, y: n.y - r - 18)),
          width: s(n.dx - 4),
          height: s(20),
        ),
        bubblePaint,
      );
    }
    for (final (i, p) in bubbles.indexed) {
      bubble(p, '${i % 10}');
    }
  }

  // Oturum: etiket baloncuğun solunda; kitapçık: harf baloncuğun içinde.
  void choiceBox(ChoiceField f, String label, {required bool labelsLeft}) {
    final inner = around(f.bubbles, r + 8);
    final rect = Rect.fromLTRB(
      labelsLeft ? inner.left - 110 : inner.left - 40,
      inner.top - 26,
      inner.right + 40,
      inner.bottom,
    );
    box(rect, label);
    fieldBoxes.add(rect);
    for (final (i, p) in f.bubbles.indexed) {
      if (labelsLeft) {
        bubble(p, '');
        text(
          '${i + 1}. Oturum · ${f.values[i]}',
          (x: p.x - r - 8, y: p.y),
          size: 10.5,
          align: TextAlign.right,
        );
      } else {
        bubble(p, f.values[i]);
      }
    }
  }

  if (t.session case final f?) choiceBox(f, 'OTURUM', labelsLeft: true);
  if (t.booklet case final f?) {
    choiceBox(f, 'KİTAPÇIK TÜRÜ', labelsLeft: false);
  }

  // Elle yazılan bilgiler ve kurallar: alanların sağındaki boşluk.
  final infoLeft = fieldBoxes.isEmpty
      ? 70.0
      : fieldBoxes.map((b) => b.right).reduce(math.max) + 20;
  final infoRight = t.width - 75;
  if (infoRight - infoLeft > 220) {
    final top = 80.0, bottom = gridTop - 10;
    final split = top + (bottom - top) * 0.55;
    box(Rect.fromLTRB(infoLeft, top, infoRight, split - 8));
    final lines = ['Ad Soyad', 'Sınıf / Şube', 'Deneme'];
    final rowH = (split - 8 - top) / lines.length;
    for (final (i, label) in lines.indexed) {
      final y = top + rowH * (i + 0.5);
      text('$label:', (x: infoLeft + 15, y: y), size: 11);
      canvas.drawLine(
        o((x: infoLeft + 100, y: y + 9)),
        o((x: infoRight - 15, y: y + 9)),
        Paint()
          ..color = light
          ..strokeWidth = s(1),
      );
    }
    box(Rect.fromLTRB(infoLeft, split, infoRight, bottom));
    text(
      '• Yalnızca yumuşak kurşun kalem (2B) kullan.\n'
      '• Baloncuğu tamamen doldur, dışına taşırma.\n'
      '• Cevabı değiştirirken eskisini iyice sil.\n'
      '• ${t.track != null ? 'Kenardaki siyah çizgilere' : 'Köşelerdeki siyah karelere'} '
      'yazma, kâğıdı katlama.',
      (x: infoLeft + 15, y: (split + bottom) / 2),
      size: 9.5,
      weight: FontWeight.w600,
      width: infoRight - infoLeft - 25,
    );
  }

  // Soru ızgarası: sütun başlıkları her sınavın testini gösterir.
  final columns = t.blocksFor(types.first).length;
  final maxRows = [
    for (final blocks in t.layouts.values)
      for (final b in blocks) b.questionCount,
  ].fold(0, (a, b) => a > b ? a : b);
  for (var c = 0; c < columns; c++) {
    // Sütunu en uzun bloğuyla çiz (TYT Sosyal 20, AYT Sosyal-2 40 soru).
    final first = [
      for (final type in types) t.blocksFor(type)[c],
    ].reduce((a, b) => a.questionCount >= b.questionCount ? a : b);
    final x1 = first.x - 50;
    final x2 = first.x + (first.options.length - 1) * first.optionDx + 22;
    box(
      Rect.fromLTRB(
        x1,
        gridTop,
        x2,
        first.y + (maxRows - 1) * first.rowDy + r + 10,
      ),
    );
    for (final (i, type) in types.indexed) {
      final b = t.blocksFor(type)[c];
      final name =
          b.trTitle ??
          b.subjects.map((s) => subjectByCode(s).trName).join(' · ');
      final range = b.questionCount < maxRows ? ' (1–${b.questionCount})' : '';
      text(
        '${type.label}: $name$range',
        (x: (x1 + x2) / 2, y: gridTop + 11 + i * 12),
        size: 8.5,
        align: TextAlign.center,
        width: x2 - x1 - 6,
      );
    }
    for (var q = 0; q < maxRows; q++) {
      final p = first.bubble(q, 0);
      if (q % 5 == 4 && q < maxRows - 1) {
        canvas.drawLine(
          o((x: x1 + 6, y: p.y + first.rowDy / 2)),
          o((x: x2 - 6, y: p.y + first.rowDy / 2)),
          Paint()
            ..color = guide
            ..strokeWidth = s(1),
        );
      }
      text(
        '${q + 1}',
        (x: p.x - 16, y: p.y),
        size: 9,
        align: TextAlign.right,
        width: 40,
      );
      for (var opt = 0; opt < first.options.length; opt++) {
        bubble(first.bubble(q, opt), first.options[opt]);
      }
    }
  }
}

/// Formu [dpi] çözünürlükte PNG olarak çizer (A4 210 mm genişlik).
Future<Uint8List> renderOpticFormPng(
  OpticTemplate t, {
  double dpi = 200,
  String? fontFamily,
}) async {
  final widthPx = (210 / 25.4 * dpi).round();
  final scale = widthPx / t.width;
  final heightPx = (t.height * scale).round();
  final recorder = ui.PictureRecorder();
  paintOpticForm(Canvas(recorder), t, scale: scale, fontFamily: fontFamily);
  final image = await recorder.endRecording().toImage(widthPx, heightPx);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Formu tek sayfalık A4 PDF olarak üretir (yazdırmak için).
Future<Uint8List> renderOpticFormPdf(
  OpticTemplate t, {
  String? fontFamily,
}) async {
  final png = await renderOpticFormPng(t, fontFamily: fontFamily);
  final decoded = img.decodePng(png)!;
  return jpegToPdf(
    img.encodeJpg(decoded, quality: 92),
    width: decoded.width,
    height: decoded.height,
  );
}

/// Tek bir JPEG resmi A4 sayfaya tam oturtan en küçük PDF.
Uint8List jpegToPdf(Uint8List jpeg, {required int width, required int height}) {
  const pageW = 595.28, pageH = 841.89;
  final out = BytesBuilder();
  final offsets = <int>[];
  void raw(String s) => out.add(latin1.encode(s));
  void obj(String body) {
    offsets.add(out.length);
    raw('${offsets.length} 0 obj\n$body\nendobj\n');
  }

  raw('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
  obj('<< /Type /Catalog /Pages 2 0 R >>');
  obj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  obj(
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageW $pageH] '
    '/Resources << /XObject << /Im0 4 0 R >> >> /Contents 5 0 R >>',
  );
  offsets.add(out.length);
  raw(
    '4 0 obj\n<< /Type /XObject /Subtype /Image /Width $width '
    '/Height $height /ColorSpace /DeviceRGB /BitsPerComponent 8 '
    '/Filter /DCTDecode /Length ${jpeg.length} >>\nstream\n',
  );
  out.add(jpeg);
  raw('\nendstream\nendobj\n');
  const content = 'q $pageW 0 0 $pageH 0 0 cm /Im0 Do Q';
  obj('<< /Length ${content.length} >>\nstream\n$content\nendstream');
  final xref = out.length;
  raw('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final off in offsets) {
    raw('${off.toString().padLeft(10, '0')} 00000 n \n');
  }
  raw(
    'trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return out.toBytes();
}
