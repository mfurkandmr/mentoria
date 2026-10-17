// Arkadaş düellosu: liste, kurallar, soru ve sonuç ekranlarını tek PNG'ye
// çizer (görsel kontrol için):
//   flutter test test/tool/duel_preview_test.dart
// Çıktı: build/duel_preview.png
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
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/duel/data/duel_repository.dart';
import 'package:mentoria/features/duel/presentation/duel_screens.dart';
import 'package:mentoria/features/learn/data/practice_repository.dart';
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
  testWidgets('Düello önizleme', (tester) async {
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
    (container.read(duelRepositoryProvider) as InMemoryDuelRepository)
        .loadPool = (s) async =>
        _pool(s);
    final theme = AppTheme.light(BrandTheme.fromBranding(Branding.mentoria));

    final key = GlobalKey();
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
            home: const DuelsScreen(),
          ),
        ),
      ),
    );
    await tester.runAsync(() => container.read(duelsProvider.future));
    await tester.pumpAndSettle();

    final frames = <ui.Image>[];
    Future<void> grab() async {
      await tester.pump(const Duration(milliseconds: 900));
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => b.toImage(pixelRatio: 1)))!);
    }

    await grab();
    await tester.tap(find.text('Kabul et'));
    await tester.pumpAndSettle();
    await grab();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başla'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    final byId = {for (final q in _pool('TYT_MAT')) q.id: q};
    final ids = [
      for (var i = 11; i <= 20; i++) 'TYT_MAT-${'$i'.padLeft(4, '0')}',
    ];
    for (var i = 0; i < 3; i++) {
      final q = byId[ids[i]]!;
      await tester.tap(find.text(q.options[q.answer]).first);
      await tester.pump(const Duration(seconds: 7));
    }
    await grab();
    for (var i = 3; i < 10; i++) {
      final q = byId[ids[i]]!;
      // Biri yanlış: 9 doğru.
      final pick = i == 6 ? (q.answer + 1) % 5 : q.answer;
      await tester.tap(find.text(q.options[pick]).first);
      await tester.pump(const Duration(seconds: 6));
    }
    for (var t = 0; t < 100 && find.text('Kazandın!').evaluate().isEmpty; t++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
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
    final image = await tester.runAsync(
      () => recorder.endRecording().toImage(
        (w * n + 8 * (n + 1)).round(),
        (h + 16).round(),
      ),
    );
    final png = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File('build/duel_preview.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
