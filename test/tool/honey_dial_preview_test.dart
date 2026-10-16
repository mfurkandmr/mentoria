// Zamanlayıcının bal kavanozunu farklı seviyelerde tek bir PNG'ye çizer
// (görsel kontrol için):
//   flutter test test/tool/honey_dial_preview_test.dart
// Çıktı: build/honey_dial_preview.png (üst sıra açık, alt sıra koyu tema)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/features/tracking/presentation/honey_dial.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  testWidgets('bal kavanozu önizleme', (tester) async {
    Motion.enabled = false;
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1200, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget row(ThemeData theme) => Theme(
      data: theme,
      child: Builder(
        builder: (context) => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final (level, label) in [
                (1.0, '25:00'),
                (0.62, '15:30'),
                (0.3, '07:30'),
                (0.04, '01:00'),
                (0.0, '00:00'),
              ])
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: HoneyDial(
                    level: level,
                    ring: 1 - level,
                    ringColor: const Color(0xFFE0A100),
                    size: 220,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Column(
            children: [row(AppTheme.light()), row(AppTheme.dark())],
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync(recursive: true);
      File(
        'build/honey_dial_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
