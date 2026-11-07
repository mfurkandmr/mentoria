import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/optic/data/omr/omr_reader.dart';
import 'package:mentoria/features/optic/data/omr/optic_form_print.dart';
import 'package:mentoria/features/optic/data/omr/optic_template.dart';

import 'omr_reader_test.dart' show photograph, randomAnswers;

/// Yazdırılan formun üstüne kurşun kalemle işaret koyar (şablon
/// koordinatlarıyla, okuyucudan bağımsız).
img.Image fillPrinted(
  img.Image form,
  OpticTemplate t, {
  required ExamType type,
  required Map<String, List<String?>> answers,
  String? number,
  String? session,
  String? booklet,
}) {
  final scale = form.width / t.width;
  final pencil = img.ColorRgb8(50, 50, 55);
  void mark(PagePoint p) => img.fillCircle(
    form,
    x: (p.x * scale).round(),
    y: (p.y * scale).round(),
    radius: (t.bubbleRadius * scale * 0.85).round(),
    color: pencil,
  );
  for (final b in t.blocksFor(type)) {
    for (var q = 0; q < b.questionCount; q++) {
      final at = b.questionAt(q);
      final m = answers[at.subject]?[at.number - 1];
      if (m != null) mark(b.bubble(q, b.options.indexOf(m)));
    }
  }
  final n = t.studentNumber!;
  for (final (d, ch) in (number ?? '').split('').indexed) {
    mark(n.bubble(d, int.parse(ch)));
  }
  for (final (f, v) in [(t.session!, session), (t.booklet!, booklet)]) {
    if (v != null) mark(f.bubbles[f.values.indexOf(v)]);
  }
  return form;
}

Future<void> _loadNunito() async {
  final loader = FontLoader('OpticNunito');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
    final bytes = File('assets/google_fonts/Nunito-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  for (final t in opticTemplates) {
    group(t.id, () => _printed(t));
  }

  testWidgets('PDF: A4 tek sayfa, xref doğru', (tester) async {
    await tester.runAsync(() async {
      final pdf = await renderOpticFormPdf(mentoriaYks);
      _checkPdf(pdf);
    });
  });
}

void _printed(OpticTemplate t) {
  testWidgets(
    'yazdırılan form doldurulup telefonla çekilince okunur (TYT ve AYT)',
    (tester) async {
      await tester.runAsync(() async {
        await _loadNunito();
        final png = await renderOpticFormPng(
          t,
          dpi: 150,
          fontFamily: 'OpticNunito',
        );
        for (final type in [ExamType.tyt, ExamType.ayt]) {
          final answers = randomAnswers(t, 99, type: type);
          final form = fillPrinted(
            img.decodePng(png)!,
            t,
            type: type,
            answers: answers,
            number: '20261042',
            session: type.db,
            booklet: 'B',
          );
          final photo = photograph(
            form,
            paperCorners: [
              (x: 150.0, y: 120.0),
              (x: 1380.0, y: 160.0),
              (x: 1400.0, y: 1890.0),
              (x: 110.0, y: 1860.0),
            ],
          );
          final r = readOptic(photo, t, type);
          expect(r.uncertain, isEmpty, reason: type.label);
          expect(r.answers, answers, reason: type.label);
          expect(r.studentNumber, '20261042', reason: type.label);
          expect(r.session, type.db, reason: type.label);
          expect(r.booklet, 'B', reason: type.label);
        }
      });
    },
  );

  testWidgets('boş yazdırılan formda işaret okunmaz', (tester) async {
    await tester.runAsync(() async {
      // Uygulamadaki gibi gerçek yazı tipiyle: test ortamının kutu çizen
      // varsayılan yazı tipinde rakam etiketleri baloncuğu koyulaştırıp
      // Linux'ta (CI) işaret gibi okunuyordu.
      await _loadNunito();
      final png = await renderOpticFormPng(
        t,
        dpi: 120,
        fontFamily: 'OpticNunito',
      );
      final r = readOpticImage(img.decodePng(png)!, t, ExamType.tyt);
      expect(r.uncertain, isEmpty);
      expect(r.answers.values.expand((l) => l).whereType<String>(), isEmpty);
      expect(r.studentNumber, '');
      expect(r.session, isNull);
      expect(r.booklet, isNull);
    });
  });
}

void _checkPdf(Uint8List pdf) {
  final text = latin1.decode(pdf);
  expect(text.startsWith('%PDF-1.4'), isTrue);
  expect(text, contains('/MediaBox [0 0 595.28 841.89]'));
  expect(text, contains('/Filter /DCTDecode'));
  expect(text.trimRight().endsWith('%%EOF'), isTrue);
  final xref = int.parse(
    RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!,
  );
  expect(text.substring(xref, xref + 4), 'xref');
  // Her nesnenin kaydı doğru konumu gösterir.
  final entries = RegExp(
    r'(\d{10}) 00000 n',
  ).allMatches(text).map((m) => int.parse(m.group(1)!)).toList();
  expect(entries, hasLength(5));
  for (final (i, off) in entries.indexed) {
    expect(text.substring(off).startsWith('${i + 1} 0 obj'), isTrue);
  }
}
