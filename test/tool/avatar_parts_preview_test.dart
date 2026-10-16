// Her avatar parçasını tek tek, varsayılan bir avatarın üstünde çizer
// (yeni parçaları görsel kontrol için):
//   flutter test test/tool/avatar_parts_preview_test.dart
// Çıktı: build/avatar_parts_preview.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Avatar parçaları önizleme', (tester) async {
    const order = ['skin', 'outfit', 'hair', 'accessory'];
    const base = {
      'skin': 'skin_light',
      'outfit': 'outfit_tee',
      'hair': 'hair_short',
    };
    final parts = <(String, String)>[
      for (final cat in order)
        for (final f
            in (Directory('assets/avatar/$cat').listSync()
                  ..sort((a, b) => a.path.compareTo(b.path)))
                .whereType<File>())
          (cat, f.uri.pathSegments.last.replaceAll('.svg', '')),
    ];
    const cell = 150.0;
    const cols = 8;
    final rows = (parts.length / cols).ceil();
    tester.view.physicalSize = Size(cell * cols, cell * rows);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // SVG'leri önceden yükle (asset okuma gerçek G/Ç).
    final cache = <String, String>{};
    await tester.runAsync(() async {
      for (final cat in order) {
        for (final f in Directory('assets/avatar/$cat').listSync()) {
          if (f is File) {
            cache[f.path.replaceAll('\\', '/')] = await f.readAsString();
          }
        }
      }
    });
    Widget layer(String cat, String name) =>
        SvgPicture.string(cache['assets/avatar/$cat/$name.svg']!);

    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFFFF8DE),
            child: Wrap(
              children: [
                for (final (cat, name) in parts)
                  SizedBox.square(
                    dimension: cell,
                    child: Stack(
                      children: [
                        for (final c in order)
                          if (c == cat)
                            layer(c, name)
                          else if (base[c] != null &&
                              !(cat == 'hair' && c == 'hair'))
                            layer(c, base[c]!),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync(recursive: true);
      File(
        'build/avatar_parts_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
