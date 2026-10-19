import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mentoria/core/theme/app_fonts.dart';

/// KVKK: yazı tipleri uygulamanın içinde (assets/google_fonts); çalışırken
/// Google'dan indirilmez. Her yazı tipi ve uygulamada kullanılan her kalınlık
/// internetsiz yüklenebilmeli. google_fonts eksik dosyayı yalnızca
/// debugPrint ile bildirdiği için o çıktı yakalanır.
void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => GoogleFonts.config.allowRuntimeFetching = true);

  /// [styles] yüklenirken google_fonts'un bildirdiği hatalar.
  Future<List<String>> loadErrors(
    WidgetTester tester,
    List<TextStyle> styles,
  ) async {
    final errors = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null && message.contains('unable to load font')) {
        errors.add(message);
      }
    };
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [for (final s in styles) Text('Çığ öğün İş', style: s)],
          ),
        ),
      );
      await tester.runAsync(() async {
        try {
          await GoogleFonts.pendingFonts();
        } catch (_) {
          // Ayrıntı debugPrint ile yakalandı.
        }
      });
    } finally {
      debugPrint = original;
    }
    return errors;
  }

  const weights = [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ];

  for (final font in AppFont.values) {
    testWidgets('${font.family}: tüm kalınlıklar uygulamadan yüklenir', (
      tester,
    ) async {
      final errors = await loadErrors(tester, [
        for (final w in weights) font.style(fontWeight: w),
      ]);
      expect(errors, isEmpty);
    });
  }

  testWidgets('varsayılan yazı tipinde eğik yazı da var', (tester) async {
    final errors = await loadErrors(tester, [
      GoogleFonts.nunito(fontStyle: FontStyle.italic),
      GoogleFonts.nunito(
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w800,
      ),
    ]);
    expect(errors, isEmpty);
  });
}
