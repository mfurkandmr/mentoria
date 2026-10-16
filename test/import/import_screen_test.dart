import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/import/presentation/import_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  testWidgets(
    'kapak sayfalı, adında tür olmayan AYT dosyası: doğru sayfa ve tür seçilir',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final sheets = {
        'Kapak': [
          ['Deneme Sonuçları'],
          ['Yayınevi', 'Test Yayınları'],
        ],
        'Liste': [
          [
            'Öğrenci No',
            'Ad Soyad',
            'Fizik D',
            'Fizik Y',
            'Kimya D',
            'Kimya Y',
          ],
          ['01042', 'Elif Yılmaz', '10', '2', '9', '3'],
          ['1077', 'Zeynep Arslan', '8', '4', '7', '2'],
        ],
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: await buildDemoOverrides('coach'),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: ImportScreen(
              initialSheets: sheets,
              initialFileName: 'Deneme 4 sonuçları.xls',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ders sütunları bulunan sayfa ve tür (AYT) kendiliğinden seçilir.
      expect(find.textContaining('2 ders otomatik bulundu'), findsOneWidget);
      expect(
        find.textContaining('Bu sayfada ders sütunları bulunamadı'),
        findsNothing,
      );
      // Fizik/Kimya TYT'de de var; 10 doğru TYT Fizik (7 soru) için
      // imkânsız olduğundan AYT seçilir: soru sayısı uyarısı çıkmaz.
      expect(find.textContaining('soru sayısını aşıyor'), findsNothing);
      final segmented = tester.widget<SegmentedButton<ExamType>>(
        find.byType(SegmentedButton<ExamType>),
      );
      expect(segmented.selected, {ExamType.ayt});
      // Deneme adı, uzantısı atılarak dosya adından gelir.
      expect(find.text('Deneme 4 sonuçları'), findsOneWidget);
    },
  );
}
