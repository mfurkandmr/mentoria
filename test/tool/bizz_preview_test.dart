// Bızz'ın duygularını tek bir PNG'ye çizer (görsel kontrol için):
//   flutter test test/tool/bizz_preview_test.dart
// Çıktı: build/bizz_preview.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/shared/widgets/bizz.dart';

void main() {
  testWidgets('Bızz önizleme', (tester) async {
    Motion.enabled = false;
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1200, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget cell(String label, Widget child) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFFFF8DE),
            child: Wrap(
              children: [
                cell('idle', const Bizz(size: 200)),
                cell('happy', const Bizz(size: 200, mood: BizzMood.happy)),
                cell('sad', const Bizz(size: 200, mood: BizzMood.sad)),
                cell(
                  'closed',
                  const Bizz(size: 200, mood: BizzMood.eyesClosed),
                ),
                cell('peek', const Bizz(size: 200, mood: BizzMood.peek)),
                cell('head', const Bizz(size: 200, headOnly: true)),
                cell(
                  'head happy',
                  const Bizz(size: 200, headOnly: true, mood: BizzMood.happy),
                ),
                cell('small', const Bizz(size: 48)),
              ],
            ),
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
        'build/bizz_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
