// Eğitim bölümünü (dersler, bilgi kartı ön/arka yüz, soru ve cevap) tek
// PNG'ye çizer (Windows yazı tipleriyle):
//   flutter test test/tool/learn_preview_test.dart
// Çıktı: build/learn_preview.png
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/learn/data/practice_repository.dart';
import 'package:mentoria/features/learn/presentation/learn_screen.dart';
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

List<PracticeQuestion> _pool(String s) => [
  for (final j
      in jsonDecode(File('assets/learn/questions/$s.json').readAsStringSync())
          as List)
    PracticeQuestion.fromJson(j as Map<String, dynamic>),
];

void main() {
  testWidgets('Eğitim önizleme', (tester) async {
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

    final container = ProviderContainer(
      overrides: [
        ...await buildDemoOverrides('student'),
        for (final s in practiceSubjects)
          questionPoolProvider(s).overrideWith((ref) async => _pool(s)),
      ],
    );
    addTearDown(container.dispose);
    final repo = container.read(practiceRepositoryProvider);
    // Biraz geçmiş: Türkçe ve Kimyada birkaç soru çözülmüş.
    final tur = SubjectPractice.of(
      subject: 'TYT_TUR',
      studentId: 'demo-student',
      pool: _pool('TYT_TUR'),
      answers: const [],
      now: DateTime.now(),
    );
    for (final q in tur.todaysQuestions.take(12)) {
      await repo.submit(
        'demo-student',
        subject: 'TYT_TUR',
        questionId: q.id,
        correct: true,
      );
    }
    final kim = SubjectPractice.of(
      subject: 'TYT_KIM',
      studentId: 'demo-student',
      pool: _pool('TYT_KIM'),
      answers: const [],
      now: DateTime.now(),
    );
    for (final q in kim.todaysQuestions) {
      await repo.submit(
        'demo-student',
        subject: 'TYT_KIM',
        questionId: q.id,
        correct: true,
      );
    }

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light().copyWith(
              textTheme: AppTheme.light().textTheme.apply(fontFamily: 'Roboto'),
            ),
            home: const LearnScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final frames = <ui.Image>[];
    Future<void> grab() async {
      await tester.pumpAndSettle();
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => b.toImage(pixelRatio: 1)))!);
    }

    await grab();
    await tester.tap(find.text('Matematik'));
    await grab();
    await tester.drag(find.byType(PageView).last, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Köklü sayılar'));
    await grab();
    await tester.tap(find.text('Soru çöz'));
    await grab();
    // İlk sorunun yanlış şıkkına dokun → çözüm görünür.
    final p = SubjectPractice.of(
      subject: 'TYT_MAT',
      studentId: 'demo-student',
      pool: _pool('TYT_MAT'),
      answers: const [],
      now: DateTime.now(),
    );
    final q = p.todaysQuestions.first;
    await tester.tap(find.text(q.options[(q.answer + 1) % 5]));
    await grab();

    // AYT sekmesi ve bir AYT sorusu.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('AYT'));
    await grab();
    await tester.tap(find.text('Fizik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soru çöz'));
    await grab();

    final w = frames.first.width.toDouble();
    final h = frames.first.height.toDouble();
    final n = frames.length;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, w * n + 8 * (n + 1), h + 16),
        Paint()..color = const Color(0xFF111111),
      );
    for (var i = 0; i < n; i++) {
      canvas.drawImage(frames[i], Offset(8 + i * (w + 8), 8), Paint());
    }
    final sheet = await tester.runAsync(
      () => recorder.endRecording().toImage(
        (w * n + 8 * (n + 1)).toInt(),
        (h + 16).toInt(),
      ),
    );
    await tester.runAsync(() async {
      final bytes = await sheet!.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync(recursive: true);
      File(
        'build/learn_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
