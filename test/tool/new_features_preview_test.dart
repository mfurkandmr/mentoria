// Odak Bahçesi, Hata Defteri ve veli Bal Raporu ekranlarını tek PNG'ye
// çizer (Windows yazı tipleriyle):
//   flutter test test/tool/new_features_preview_test.dart
// Çıktı: build/new_features_preview.png
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/garden/presentation/garden_screen.dart';
import 'package:mentoria/features/mistakes/data/mistake_repository.dart';
import 'package:mentoria/features/mistakes/presentation/mistake_widgets.dart';
import 'package:mentoria/features/mistakes/presentation/mistakes_screen.dart';
import 'package:mentoria/features/parent/presentation/parent_child_screen.dart';
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
  testWidgets('Yeni özellikler önizleme', (tester) async {
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

    const phone = Size(390, 844);
    tester.view.physicalSize = phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // Bahçe için 6 haftalık uydurma oturumlar.
    final rnd = math.Random(4);
    const subjects = [
      'TYT_MAT',
      'TYT_TUR',
      'TYT_FIZ',
      'AYT_TAR1',
      'TYT_BIY',
      null,
    ];
    final now = DateTime.now();
    final sessions = [
      for (var i = 0; i < 64; i++)
        StudySession(
          id: 'g$i',
          type: rnd.nextDouble() < 0.12
              ? SessionType.pomodoro
              : SessionType.free,
          startedAt: now.subtract(Duration(hours: i * 15 + rnd.nextInt(10))),
          durationSec: [8, 15, 25, 25, 30, 45, 55, 70, 12][rnd.nextInt(9)] * 60,
          subjectCode: subjects[rnd.nextInt(subjects.length)],
        ),
    ];

    final key = GlobalKey();
    final frames = <ui.Image>[];
    Future<void> shot(
      Widget home,
      List<Object> overrides, {
      Future<void> Function()? then,
    }) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            key: UniqueKey(),
            overrides: [
              ...await buildDemoOverrides(overrides.first as String),
              ...overrides.skip(1).cast(),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light().copyWith(
                textTheme: AppTheme.light().textTheme.apply(
                  fontFamily: 'Roboto',
                ),
              ),
              home: home,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (then != null) await then();
      await tester.pump(const Duration(milliseconds: 300));
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => b.toImage(pixelRatio: 1)))!);
    }

    final gardenOverride = allSessionsProvider.overrideWith(
      (ref, id) async => sessions,
    );
    await shot(const GardenScreen(), ['student', gardenOverride]);
    await shot(const MistakesScreen(), ['student']);
    await shot(
      Scaffold(
        body: Builder(
          builder: (context) => Consumer(
            builder: (context, ref, _) {
              final cards =
                  ref.watch(mistakeCardsProvider('demo-student')).value ??
                  const [];
              final due = cards.where((c) => c.isDue(DateTime.now())).toList();
              return due.isEmpty
                  ? const SizedBox()
                  : MistakeReviewScreen(studentId: 'demo-student', cards: due);
            },
          ),
        ),
      ),
      ['student'],
    );
    await shot(
      const ParentChildScreen(childId: 'demo-student', initialTab: 4),
      ['parent'],
    );
    await shot(
      const ParentChildScreen(childId: 'demo-student', initialTab: 5),
      ['parent'],
    );

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
        'build/new_features_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
  });
}
