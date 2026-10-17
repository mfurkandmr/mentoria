// Sıkça sorulan sorular: profil girişi ve dört panelin SSS ekranını tek PNG'ye
// çizer (görsel kontrol için):
//   flutter test test/tool/faq_preview_test.dart
// Çıktı: build/faq_preview.png
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
import 'package:mentoria/features/auth/data/profile.dart';
import 'package:mentoria/features/help/presentation/faq_screen.dart';
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
  testWidgets('SSS önizleme', (tester) async {
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
    final theme = AppTheme.light(BrandTheme.fromBranding(Branding.mentoria));

    final frames = <ui.Image>[];
    for (final role in UserRole.values) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: await buildDemoOverrides(role.name),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
              ),
              home: FaqScreen(role: role),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // İlk soruyu aç.
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => b.toImage(pixelRatio: 1)))!);
    }

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
    File('build/faq_preview.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
