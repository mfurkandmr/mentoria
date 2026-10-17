// Günün Sorusu kartı, soru ekranı (cevap öncesi / yanlış sonrası) ve koçun
// Eğitim karnesini tek PNG'ye çizer (görsel kontrol için):
//   flutter test test/tool/daily_question_preview_test.dart
// Çıktı: build/daily_question_preview.png
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/branding/branding.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/core/theme/brand_theme.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/learn/data/daily_question_repository.dart';
import 'package:mentoria/features/learn/data/practice_repository.dart';
import 'package:mentoria/features/learn/presentation/daily_question_screen.dart';
import 'package:mentoria/features/learn/presentation/learn_report_view.dart';
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

List<PracticeQuestion> _pool(String subject) => [
  for (final j
      in jsonDecode(
            File('assets/learn/questions/$subject.json').readAsStringSync(),
          )
          as List)
    PracticeQuestion.fromJson(j as Map<String, dynamic>),
];

void main() {
  testWidgets('Günün Sorusu önizleme', (tester) async {
    await initializeDateFormatting('tr_TR');
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

    const phone = Size(390, 844);
    tester.view.physicalSize = phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        ...await buildDemoOverrides('student'),
        for (final s in practiceSubjects)
          questionPoolProvider(s).overrideWith((ref) async => _pool(s)),
      ],
    );
    addTearDown(container.dispose);
    final theme = AppTheme.light(BrandTheme.fromBranding(Branding.mentoria));

    final key = GlobalKey();
    Future<void> show(Widget home) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
              ),
              home: home,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final frames = <ui.Image>[];
    Future<void> grab() async {
      await tester.pump(const Duration(milliseconds: 900));
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => b.toImage(pixelRatio: 1)))!);
    }

    await show(
      const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [DailyQuestionCard()]),
          ),
        ),
      ),
    );
    await grab();

    await show(const DailyQuestionScreen());
    await grab();
    final s = (await container
        .read(dailyQuestionRepositoryProvider)
        .fetchToday())!;
    final q = _pool(s.subject).firstWhere((q) => q.id == s.questionId);
    await tester.tap(find.text(q.options[(q.answer + 1) % 5]));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await grab();

    await show(
      Scaffold(
        appBar: AppBar(title: const Text('Eğitim karnesi')),
        body: const LearnReportView(studentId: 'demo-student'),
      ),
    );
    await grab();

    final w = frames.first.width.toDouble();
    final h = frames.first.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(
          0,
          0,
          w * frames.length + 8 * (frames.length + 1),
          h + 16,
        ),
        Paint()..color = const Color(0xFF111111),
      );
    for (var i = 0; i < frames.length; i++) {
      canvas.drawImage(frames[i], Offset(8 + i * (w + 8), 8), Paint());
    }
    final image = await tester.runAsync(
      () => recorder.endRecording().toImage(
        (w * frames.length + 8 * (frames.length + 1)).round(),
        (h + 16).round(),
      ),
    );
    final png = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File('build/daily_question_preview.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
