// Veliye giden ödev PDF'i (NOTLAR §89): tek A4 sayfa; kurum, ödevi veren,
// öğrenci, son tarih, maddeler (ders, konu, soru sayısı, not) ve koçun notu.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/format.dart';
import '../../schedule_generator/presentation/schedule_export.dart'
    show jpegPagesToPdf;
import '../data/assignment_repository.dart';

Future<Uint8List> renderHomeworkPdf({
  required String orgName,
  required String senderName,
  required String studentName,
  required String title,
  required List<AssignmentItemDraft> items,
  DateTime? dueOn,
  String? note,
  DateTime? createdAt,
  Color accent = const Color(0xFF2E7D5B),
  String? fontFamily,
}) async {
  const w = 1240, h = 1754;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w + 0.0, h + 0.0),
    Paint()..color = Colors.white,
  );
  double text(
    String s,
    Offset at, {
    double size = 22,
    FontWeight weight = FontWeight.w500,
    double width = 1100,
    Color color = Colors.black87,
    int maxLines = 2,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: width);
    p.paint(canvas, at);
    return p.height;
  }

  const m = 80.0;
  // Kurum şeridi.
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w + 0.0, 150),
    Paint()..color = accent,
  );
  text(
    orgName,
    const Offset(m, 46),
    size: 40,
    weight: FontWeight.w800,
    color: Colors.white,
    maxLines: 1,
  );
  text(
    tr('Ödev bildirimi'),
    const Offset(m, 100),
    size: 22,
    color: Colors.white70,
    maxLines: 1,
  );

  var y = 200.0;
  y += text(title, Offset(m, y), size: 44, weight: FontWeight.w800) + 24;

  final rows = [
    (tr('Öğrenci'), studentName),
    (tr('Ödevi veren'), senderName),
    (tr('Verildiği gün'), formatLongDate(createdAt ?? DateTime.now())),
    (
      tr('Son tarih'),
      dueOn == null ? tr('Belirtilmedi') : formatLongDate(dueOn),
    ),
  ];
  for (final (label, value) in rows) {
    text(label, Offset(m, y), size: 22, color: Colors.black54, width: 260);
    text(
      value,
      Offset(m + 280, y),
      size: 24,
      weight: FontWeight.w700,
      width: 820,
    );
    y += 42;
  }
  y += 20;
  canvas.drawLine(
    Offset(m, y),
    Offset(w - m, y),
    Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = 2,
  );
  y += 30;

  final questions = items.fold(0, (s, i) => s + (i.questionCount ?? 0));
  text(
    questions > 0
        ? tr('{n} madde · toplam {q} soru', {'n': items.length, 'q': questions})
        : tr('{n} madde', {'n': items.length}),
    Offset(m, y),
    size: 26,
    weight: FontWeight.w800,
  );
  y += 54;

  for (final (i, d) in items.indexed) {
    if (y > h - 260) {
      text(
        tr('… ve {n} madde daha (uygulamada).', {'n': items.length - i}),
        Offset(m, y),
        size: 22,
        color: Colors.black54,
      );
      y += 40;
      break;
    }
    final top = y;
    canvas.drawCircle(
      Offset(m + 18, y + 18),
      18,
      Paint()..color = accent.withValues(alpha: 0.15),
    );
    text(
      '${i + 1}',
      Offset(m + (i + 1 < 10 ? 11 : 5), y + 4),
      size: 22,
      weight: FontWeight.w800,
      color: accent,
      width: 40,
      maxLines: 1,
    );
    final subject = subjectByCode(d.subjectCode).name;
    y += text(
      '$subject · ${d.topicName ?? tr('Genel tekrar')}',
      Offset(m + 56, y),
      size: 26,
      weight: FontWeight.w700,
      width: 860,
    );
    if (d.questionCount != null) {
      text(
        tr('{n} soru', {'n': d.questionCount!}),
        Offset(w - m - 160, top),
        size: 26,
        weight: FontWeight.w800,
        width: 160,
        maxLines: 1,
      );
    }
    if (d.note != null && d.note!.trim().isNotEmpty) {
      y += 4;
      y += text(
        d.note!.trim(),
        Offset(m + 56, y),
        size: 21,
        color: Colors.black54,
        width: 960,
        maxLines: 3,
      );
    }
    y += 26;
  }

  if (note != null && note.trim().isNotEmpty && y < h - 200) {
    y += 10;
    final noteH = text(
      note.trim(),
      Offset(m + 24, y + 54),
      size: 22,
      width: w - 2 * m - 48,
      maxLines: 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(m, y, w - 2 * m, noteH + 84),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFFF3F1EA),
    );
    text(tr('Not'), Offset(m + 24, y + 16), size: 22, weight: FontWeight.w800);
    text(
      note.trim(),
      Offset(m + 24, y + 54),
      size: 22,
      width: w - 2 * m - 48,
      maxLines: 6,
    );
  }

  text(
    tr('Bu belge {org} tarafından hazırlanmıştır.', {'org': orgName}),
    const Offset(m, h - 80.0),
    size: 18,
    color: Colors.black38,
  );

  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final rgba = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: data!.buffer,
    numChannels: 4,
  );
  return jpegPagesToPdf([(img.encodeJpg(rgba, quality: 88), w, h)]);
}
