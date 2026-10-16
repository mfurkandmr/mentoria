// Telefonu sallayınca gelen Bızz değişimini kare kare tek PNG'ye çizer:
//   flutter test test/tool/bizz_swap_preview_test.dart
// Çıktı: build/bizz_swap_preview.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/shared/widgets/bizz_swap.dart';

void main() {
  testWidgets('Bızz değişimi önizleme', (tester) async {
    Motion.enabled = true;
    addTearDown(() => Motion.enabled = true);
    tester.view.physicalSize = const Size(520, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final swap = BizzSwapController();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5BB8FF),
                  Color(0xFFA9DDFF),
                  Color(0xFFFFF1C2),
                ],
              ),
            ),
            alignment: const Alignment(0.75, 0.7),
            child: BizzSwap(controller: swap, size: 120),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final frames = <(String, ui.Image)>[];
    Future<void> grab(String label) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage());
      frames.add((label, image!));
    }

    await grab('önce');
    final done = swap.swap();
    var at = 0;
    for (final ms in [250, 480, 560, 700, 900, 1150, 1500]) {
      await tester.pump(Duration(milliseconds: ms - at));
      at = ms;
      await grab('$ms ms');
    }
    await tester.pump(const Duration(milliseconds: 600));
    await done;
    await tester.pump(const Duration(milliseconds: 400));
    await grab('sonra');

    // Kareleri 3 sütunlu bir ızgarada birleştir (soldan sağa, yukarıdan
    // aşağı; testlerin yazı tipi kutu çizdiği için etiket yok).
    const cols = 3;
    final w = frames.first.$2.width.toDouble();
    final h = frames.first.$2.height.toDouble();
    final rows = (frames.length / cols).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < frames.length; i++) {
      final (_, image) = frames[i];
      final o = Offset((i % cols) * w, (i ~/ cols) * h);
      canvas.drawImage(image, o, Paint());
      canvas.drawRect(
        o & Size(w, h),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white,
      );
    }
    final sheet = await tester.runAsync(
      () => recorder.endRecording().toImage(
        (w * cols).toInt(),
        (h * rows).toInt(),
      ),
    );
    await tester.runAsync(() async {
      final bytes = await sheet!.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync(recursive: true);
      File(
        'build/bizz_swap_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
  });
}
