// Uygulamadaki cevap kâğıtlarını yazdırılabilir hâliyle üretir (görsel
// kontrol ve deneme baskısı için):
//   flutter test test/tool/optic_form_preview_test.dart
// Her şablon için build/optik_<id>.pdf, build/optik_<id>.png ve doldurulmuş
// örnek build/optik_<id>_dolu.png; şablon çıkarma aracını denemek için
// build/cizgili_test_formu.png.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/optic/data/omr/form_painter.dart';
import 'package:mentoria/features/optic/data/omr/optic_form_print.dart';
import 'package:mentoria/features/optic/data/omr/optic_template.dart';

import '../optic/omr_reader_test.dart' show randomAnswers;
import '../optic/omr_track_test.dart' show cizgiliTestFormu, pembe;
import '../optic/optic_print_test.dart' show fillPrinted;

void main() {
  testWidgets('optik form önizleme', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('OpticNunito');
      for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
        final bytes = File(
          'assets/google_fonts/Nunito-$w.ttf',
        ).readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();

      Directory('build').createSync(recursive: true);
      for (final t in opticTemplates) {
        final png = await renderOpticFormPng(t, fontFamily: 'OpticNunito');
        File('build/optik_${t.id}.png').writeAsBytesSync(png);
        File('build/optik_${t.id}.pdf').writeAsBytesSync(
          await renderOpticFormPdf(t, fontFamily: 'OpticNunito'),
        );
        final filled = fillPrinted(
          img.decodePng(png)!,
          t,
          type: ExamType.tyt,
          answers: randomAnswers(t, 42),
          number: '1042',
          session: 'TYT',
          booklet: 'A',
        );
        File(
          'build/optik_${t.id}_dolu.png',
        ).writeAsBytesSync(img.encodePng(filled));
      }
      // Şablon çıkarma aracını denemek için çizgili (yayınevi tipi) boş form.
      File('build/cizgili_test_formu.png').writeAsBytesSync(
        img.encodePng(paintForm(cizgiliTestFormu, inkColor: pembe)),
      );
    });
  });
}
