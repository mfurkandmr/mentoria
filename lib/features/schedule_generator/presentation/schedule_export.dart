import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/i18n.dart';
import '../data/timetable_repository.dart';
import '../domain/models.dart';
import 'timetable_format.dart';

/// Dışa aktarılacak sayfalar: her sınıf (ya da öğretmen) için başlık ve
/// (gün, sıra) → hücre metni.
List<(String, Map<(int, int), String>)> exportPages(
  TimetableSetup setup,
  List<ScheduleEntry> entries,
  TimetableMode mode,
) {
  final teachers = {
    for (final t in setup.teachers) t.teacher.id: t.teacher.name,
  };
  final classes = {
    for (final c in setup.classrooms) c.classroom.id: c.classroom.name,
  };
  final rooms = {for (final r in setup.rooms) r.id: r.name};
  final targets = switch (mode) {
    TimetableMode.classroom => [
      for (final c in setup.classrooms) (c.classroom.id, c.classroom.name),
    ],
    TimetableMode.teacher => [
      for (final t in setup.teachers) (t.teacher.id, t.teacher.name),
    ],
    TimetableMode.room => [for (final r in setup.rooms) (r.id, r.name)],
  };
  return [
    for (final (id, name) in targets)
      (
        name,
        {
          for (final MapEntry(key: cell, value: list) in cellsFor(
            setup,
            entries,
            mode,
            id,
          ).entries)
            cell: [
              for (final i in list)
                [
                  entries[i].branch,
                  if (mode != TimetableMode.teacher)
                    teachers[entries[i].teacherId] ?? '',
                  if (mode != TimetableMode.classroom)
                    classes[entries[i].classroomId] ?? '',
                  if (mode != TimetableMode.room && entries[i].roomId != null)
                    rooms[entries[i].roomId] ?? '',
                ].where((s) => s.isNotEmpty).join(' · '),
            ].join('\n'),
        },
      ),
  ];
}

/// Excel: her sınıf (öğretmen) ayrı sayfa; satır saat, sütun gün.
Uint8List buildScheduleWorkbook(
  TimetableSetup setup,
  List<ScheduleEntry> entries,
  TimetableMode mode,
) {
  final book = xl.Excel.createExcel();
  final defaultSheet = book.getDefaultSheet();
  final (days, maxSeq) = gridShape(setup.slots);
  final used = <String>{};
  String sheetName(String name) {
    // Excel sayfa adı: en çok 31 karakter, []:*?/\ yok, tekil.
    var n = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (n.isEmpty) n = tr('Sayfa');
    if (n.length > 28) n = n.substring(0, 28);
    var out = n;
    for (var k = 2; !used.add(out); k++) {
      out = '$n $k';
    }
    return out;
  }

  final pages = exportPages(setup, entries, mode);
  String? first;
  for (final (name, cells) in pages) {
    final sheetTitle = sheetName(name);
    first ??= sheetTitle;
    final sheet = book[sheetTitle];
    sheet.appendRow([
      xl.TextCellValue(tr('Saat')),
      for (final d in days) xl.TextCellValue(dayLong(d)),
    ]);
    for (var seq = 1; seq <= maxSeq; seq++) {
      sheet.appendRow([
        xl.TextCellValue(rowLabel(setup.slots, seq)),
        for (final d in days) xl.TextCellValue(cells[(d, seq)] ?? ''),
      ]);
    }
  }
  if (first != null) {
    book.setDefaultSheet(first);
    if (defaultSheet != null && defaultSheet != first) {
      book.delete(defaultSheet);
    }
  }
  return Uint8List.fromList(book.encode()!);
}

/// PDF: her sınıf (öğretmen) ayrı A4 yatay sayfa. Yazı tipi uygulamanınki
/// (Türkçe karakterler); sayfa resim olarak gömülür.
Future<Uint8List> renderSchedulePdf(
  TimetableSetup setup,
  List<ScheduleEntry> entries,
  TimetableMode mode, {
  required String title,
  String? fontFamily,
}) async {
  const w = 1684, h = 1190; // A4 yatay, ~144 dpi
  final (days, maxSeq) = gridShape(setup.slots);
  final pages = <(Uint8List, int, int)>[];
  for (final (name, cells) in exportPages(setup, entries, mode)) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w + 0.0, h + 0.0),
      Paint()..color = Colors.white,
    );
    void text(
      String s,
      Offset at, {
      double size = 18,
      double width = 400,
      FontWeight weight = FontWeight.w500,
      Color color = Colors.black87,
      TextAlign align = TextAlign.left,
      int maxLines = 4,
    }) {
      final p = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: color,
            fontFamily: fontFamily,
            height: 1.15,
          ),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: width);
      p.paint(canvas, at);
    }

    const margin = 60.0, top = 140.0, labelW = 110.0;
    text(
      name,
      const Offset(margin, 40),
      size: 40,
      weight: FontWeight.w800,
      width: 1200,
    );
    text(
      title,
      const Offset(margin, 92),
      size: 20,
      color: Colors.black54,
      width: 1200,
    );
    final colW = (w - 2 * margin - labelW) / (days.isEmpty ? 1 : days.length);
    final rowH = (h - top - margin - 44) / (maxSeq == 0 ? 1 : maxSeq);
    final line = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final (i, d) in days.indexed) {
      text(
        dayLong(d),
        Offset(margin + labelW + i * colW, top + 8),
        size: 20,
        weight: FontWeight.w800,
        width: colW,
        align: TextAlign.center,
        maxLines: 1,
      );
    }
    for (var seq = 1; seq <= maxSeq; seq++) {
      final y = top + 44 + (seq - 1) * rowH;
      text(
        rowLabel(setup.slots, seq),
        Offset(margin, y + 8),
        size: 18,
        weight: FontWeight.w700,
        width: labelW - 10,
        maxLines: 1,
      );
      for (final (i, d) in days.indexed) {
        final r = Rect.fromLTWH(margin + labelW + i * colW, y, colW, rowH);
        final v = cells[(d, seq)];
        if (v != null) {
          final branch = v.split(' · ').first;
          canvas.drawRect(
            r.deflate(3),
            Paint()..color = branchColor(branch).withValues(alpha: 0.18),
          );
          text(
            v,
            r.topLeft + const Offset(10, 8),
            size: 16,
            width: colW - 20,
            maxLines: ((rowH - 12) / 19).floor().clamp(1, 6),
          );
        }
        canvas.drawRect(r, line);
      }
    }
    final image = await recorder.endRecording().toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final rgba = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: data!.buffer,
      numChannels: 4,
    );
    pages.add((img.encodeJpg(rgba, quality: 90), w, h));
  }
  return jpegPagesToPdf(pages, landscape: true);
}

/// JPEG sayfalarından çok sayfalı A4 PDF (her resim sayfaya tam oturur).
Uint8List jpegPagesToPdf(
  List<(Uint8List, int, int)> pages, {
  bool landscape = false,
}) {
  final pageW = landscape ? 841.89 : 595.28;
  final pageH = landscape ? 595.28 : 841.89;
  final out = BytesBuilder();
  final offsets = <int>[];
  void raw(String s) => out.add(latin1.encode(s));
  void begin() {
    offsets.add(out.length);
    raw('${offsets.length} 0 obj\n');
  }

  raw('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
  // 1: katalog, 2: sayfalar; her sayfa için sayfa, resim, içerik (3 nesne).
  final n = pages.length;
  final kids = [for (var i = 0; i < n; i++) '${3 + i * 3} 0 R'].join(' ');
  begin();
  raw('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
  begin();
  raw('<< /Type /Pages /Kids [$kids] /Count $n >>\nendobj\n');
  for (var i = 0; i < n; i++) {
    final (jpeg, w, h) = pages[i];
    final page = 3 + i * 3;
    begin();
    raw(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageW $pageH] '
      '/Resources << /XObject << /Im0 ${page + 1} 0 R >> >> '
      '/Contents ${page + 2} 0 R >>\nendobj\n',
    );
    begin();
    raw(
      '<< /Type /XObject /Subtype /Image /Width $w /Height $h '
      '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode '
      '/Length ${jpeg.length} >>\nstream\n',
    );
    out.add(jpeg);
    raw('\nendstream\nendobj\n');
    final content = 'q $pageW 0 0 $pageH 0 0 cm /Im0 Do Q';
    begin();
    raw(
      '<< /Length ${content.length} >>\nstream\n$content\nendstream\nendobj\n',
    );
  }
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

enum ExportFormat { pdf, excel }

/// Programı PDF ya da Excel olarak paylaşır.
Future<void> shareSchedule(
  BuildContext context, {
  required TimetableSetup setup,
  required List<ScheduleEntry> entries,
  required TimetableMode mode,
  required ExportFormat format,
  required String title,
}) async {
  final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;
  final messenger = ScaffoldMessenger.of(context);
  final kind = mode == TimetableMode.teacher ? 'ogretmen' : 'sinif';
  final safe = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9ğüşıöç]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  try {
    final XFile file;
    if (format == ExportFormat.pdf) {
      final bytes = await renderSchedulePdf(
        setup,
        entries,
        mode,
        title: title,
        fontFamily: font,
      );
      file = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: 'ders-programi-$safe-$kind.pdf',
      );
    } else {
      file = XFile.fromData(
        buildScheduleWorkbook(setup, entries, mode),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name: 'ders-programi-$safe-$kind.xlsx',
      );
    }
    await SharePlus.instance.share(ShareParams(files: [file], text: title));
  } catch (e) {
    debugPrint('Ders programı dışa aktarılamadı: $e');
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Dosya hazırlanamadı. Tekrar dene.'))),
    );
  }
}
