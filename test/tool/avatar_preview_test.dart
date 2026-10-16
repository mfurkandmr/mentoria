// Avatar parçalarını ve sıralama ödüllerini tek bir PNG'ye çizer (görsel
// kontrol için):
//   flutter test test/tool/avatar_preview_test.dart
// Çıktı: build/avatar_preview.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/avatar/data/avatar_models.dart';
import 'package:mentoria/features/avatar/data/avatar_repository.dart';
import 'package:mentoria/features/avatar/presentation/student_avatar.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  testWidgets('Avatar önizleme', (tester) async {
    Motion.enabled = false;
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    AvatarConfig c(int hair, int skin, int outfit, [int? acc]) => AvatarConfig({
      AvatarCategory.hair: hair,
      AvatarCategory.skin: skin,
      AvatarCategory.outfit: outfit,
      // ignore: use_null_aware_elements
      if (acc != null) AvatarCategory.accessory: acc,
    });

    final cells = <(AvatarConfig, AvatarReward?)>[
      // Her saç / ten / kıyafet en az bir kez.
      (c(1, 6, 10), null),
      (c(2, 7, 11, 15), null),
      (c(3, 8, 12), null),
      (c(4, 9, 13, 16), null),
      (c(5, 6, 14, 17), null),
      (c(1, 9, 11, 15), null),
      // Ödüller.
      (c(3, 7, 12), AvatarReward.king),
      (c(4, 8, 14), AvatarReward.gold),
      (c(2, 6, 13), AvatarReward.silver),
      (c(5, 9, 10, 16), AvatarReward.king),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarRepositoryProvider.overrideWithValue(
            InMemoryAvatarRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFFFFF8DE),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (cfg, reward) in cells)
                    StudentAvatar(config: cfg, reward: reward, size: 236),
                  for (final (cfg, reward) in cells.take(5))
                    StudentAvatar(config: cfg, reward: reward, size: 48),
                  StudentAvatar(
                    config: c(3, 7, 12),
                    reward: AvatarReward.king,
                    size: 48,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // SVG'ler zaman uyumsuz yüklenir.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }
    expect(find.byType(SvgPicture), findsWidgets);

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync(recursive: true);
      File(
        'build/avatar_preview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
