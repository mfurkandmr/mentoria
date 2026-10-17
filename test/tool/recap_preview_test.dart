// "Haftanın Bal Raporu" hikayesinin tüm sayfalarını tek PNG'ye çizer
// (görsel kontrol için; gerçek yazı tipiyle):
//   flutter test test/tool/recap_preview_test.dart
// Çıktı: build/recap_preview.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/features/recap/data/week_recap.dart';
import 'package:mentoria/features/recap/presentation/recap_card.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';
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
  testWidgets('Bal Raporu önizleme', (tester) async {
    await initializeDateFormatting('tr_TR');
    // Windows yazı tipleri varsa gerçek görünüm (yoksa kutular çizilir).
    await tester.runAsync(() async {
      final sdk = File(
        Platform.resolvedExecutable,
      ).parent.parent.parent.parent.parent.path;
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

    final now = DateTime(2026, 10, 18, 20);
    QuestionLog log(int d, String code, int c, int w) => QuestionLog(
      id: '$d$code',
      subjectCode: code,
      correct: c,
      wrong: w,
      blank: 0,
      loggedOn: DateTime(now.year, now.month, now.day - d),
    );
    StudySession s(int d, int hour, int min) => StudySession(
      id: '$d$hour',
      type: SessionType.pomodoro,
      startedAt: DateTime(now.year, now.month, now.day - d, hour),
      durationSec: min * 60,
    );
    final recap = WeekRecap.compute(
      logs: [
        log(0, 'TYT_MAT', 60, 12),
        log(1, 'TYT_TUR', 45, 5),
        log(2, 'TYT_MAT', 110, 18),
        log(3, 'TYT_FIZ', 30, 10),
        log(4, 'TYT_MAT', 70, 9),
        log(5, 'TYT_TUR', 40, 8),
        log(9, 'TYT_MAT', 150, 30),
      ],
      sessions: [
        s(0, 22, 50),
        s(1, 23, 45),
        s(2, 21, 60),
        s(3, 22, 40),
        s(5, 16, 50),
      ],
      exams: [
        Exam(
          id: 'e',
          examType: ExamType.tyt,
          name: 'TYT Deneme 7',
          takenOn: DateTime(2026, 10, 17),
          results: const [
            SubjectResult(code: 'TYT_MAT', correct: 33, wrong: 4, blank: 3),
            SubjectResult(code: 'TYT_TUR', correct: 34, wrong: 6, blank: 0),
          ],
        ),
      ],
      now: now,
    );

    const phone = Size(390, 844);
    tester.view.physicalSize = phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            backgroundColor: const Color(0xFFFFF8E7),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [RecapCard(recap: recap, firstName: 'Elif')],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final frames = <ui.Image>[];
    Future<void> grab() async {
      await tester.pump(const Duration(milliseconds: 900));
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => b.toImage(pixelRatio: 1)))!);
    }

    await grab(); // ana sayfa kartı
    await tester.tap(find.text('Haftanın Bal Raporu'));
    await tester.pumpAndSettle();
    await grab();
    while (find.bySemanticsLabel('Sonraki').evaluate().isNotEmpty) {
      await tester.tap(find.bySemanticsLabel('Sonraki'));
      await tester.pumpAndSettle();
      await grab();
    }

    const cols = 5;
    final w = frames.first.width.toDouble();
    final h = frames.first.height.toDouble();
    final rows = (frames.length / cols).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(
          0,
          0,
          w * cols + 8 * (cols + 1),
          h * rows + 8 * (rows + 1),
        ),
        Paint()..color = const Color(0xFF111111),
      );
    for (var i = 0; i < frames.length; i++) {
      canvas.drawImage(
        frames[i],
        Offset(8 + (i % cols) * (w + 8), 8 + (i ~/ cols) * (h + 8)),
        Paint(),
      );
    }
    final sheet = await tester.runAsync(
      () => recorder.endRecording().toImage(
        (w * cols + 8 * (cols + 1)).toInt(),
        (h * rows + 8 * (rows + 1)).toInt(),
      ),
    );
    await tester.runAsync(() async {
      final bytes = await sheet!.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync(recursive: true);
      File(
        'build/recap_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    expect(frames.length, greaterThanOrEqualTo(9));
    await tester.pumpWidget(const SizedBox());
  });
}
