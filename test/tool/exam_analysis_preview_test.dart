// Deneme analizi ekranını üç parça halinde tek PNG'ye çizer (Windows yazı
// tipleriyle):
//   flutter test test/tool/exam_analysis_preview_test.dart
// Çıktı: build/exam_analysis_preview.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/features/exams/presentation/exam_analysis_view.dart';
import 'package:mentoria/shared/motion.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  var any = false;
  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    any = true;
  }
  if (any) await loader.load();
}

void main() {
  testWidgets('Deneme analizi önizleme', (tester) async {
    await initializeDateFormatting('tr_TR');
    await tester.runAsync(() async {
      final sdk = Platform.environment['FLUTTER_ROOT'] ?? '';
      await _loadFont('MaterialIcons', [
        '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ]);
      await _loadFont('Roboto', [
        r'C:\Windows\Fonts\segoeuib.ttf',
        r'C:\Windows\Fonts\seguiemj.ttf',
      ]);
    });
    Motion.enabled = false;
    addTearDown(() => Motion.enabled = true);
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // Altı TYT denemesi: matematik yükseliyor, Türkçe hafif düşüyor,
    // fizik dalgalı, kimya istikrarlı.
    const mat = [(14, 10), (17, 9), (19, 8), (22, 7), (25, 6), (28, 5)];
    const tur = [(33, 5), (32, 5), (33, 6), (31, 6), (30, 7), (30, 8)];
    const fiz = [(3, 1), (6, 0), (2, 2), (5, 1), (3, 2), (6, 1)];
    const kim = [(4, 1), (4, 1), (5, 0), (4, 1), (4, 1), (5, 1)];
    const biy = [(3, 1), (3, 1), (4, 1), (4, 0), (5, 1), (5, 0)];
    const sos = [(12, 4), (13, 3), (12, 4), (14, 3), (14, 2), (15, 2)];
    final exams = [
      for (var i = 0; i < 6; i++)
        Exam(
          id: 'e$i',
          examType: ExamType.tyt,
          name: 'TYT Deneme ${i + 1}',
          takenOn: DateTime(2026, 8, 10 + i * 10),
          results: [
            SubjectResult(
              code: 'TYT_TUR',
              correct: tur[i].$1,
              wrong: tur[i].$2,
              blank: 40 - tur[i].$1 - tur[i].$2,
            ),
            SubjectResult(
              code: 'TYT_TAR',
              correct: sos[i].$1 ~/ 4,
              wrong: 1,
              blank: 0,
            ),
            SubjectResult(
              code: 'TYT_MAT',
              correct: mat[i].$1,
              wrong: mat[i].$2,
              blank: 40 - mat[i].$1 - mat[i].$2,
            ),
            SubjectResult(
              code: 'TYT_FIZ',
              correct: fiz[i].$1,
              wrong: fiz[i].$2,
              blank: 7 - fiz[i].$1 - fiz[i].$2,
            ),
            SubjectResult(
              code: 'TYT_KIM',
              correct: kim[i].$1,
              wrong: kim[i].$2,
              blank: 7 - kim[i].$1 - kim[i].$2,
            ),
            SubjectResult(
              code: 'TYT_BIY',
              correct: biy[i].$1,
              wrong: biy[i].$2,
              blank: 6 - biy[i].$1 - biy[i].$2,
            ),
          ],
        ),
    ];

    final key = GlobalKey();
    final controller = ScrollController();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light().copyWith(
            textTheme: AppTheme.light().textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: Scaffold(
            body: SafeArea(
              child: PrimaryScrollController(
                controller: controller,
                child: ExamAnalysisView(exams: exams),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final frames = <ui.Image>[];
    final list = find.byType(Scrollable).first;
    for (final dy in [0.0, 700.0, 1400.0]) {
      final state = tester.state<ScrollableState>(list);
      state.position.jumpTo(dy.clamp(0, state.position.maxScrollExtent));
      await tester.pumpAndSettle();
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => b.toImage(pixelRatio: 1)))!);
    }

    final w = frames.first.width.toDouble();
    final h = frames.first.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, w * 3 + 32, h + 16),
        Paint()..color = const Color(0xFF111111),
      );
    for (var i = 0; i < frames.length; i++) {
      canvas.drawImage(frames[i], Offset(8 + i * (w + 8), 8), Paint());
    }
    final sheet = await tester.runAsync(
      () => recorder.endRecording().toImage(
        (w * 3 + 32).toInt(),
        (h + 16).toInt(),
      ),
    );
    await tester.runAsync(() async {
      final bytes = await sheet!.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync(recursive: true);
      File(
        'build/exam_analysis_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
