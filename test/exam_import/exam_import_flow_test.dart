import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_exam_center.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/exam_analysis/presentation/exam_report_screen.dart';
import 'package:mentoria/features/exam_analysis/presentation/report_card_screen.dart';
import 'package:mentoria/features/exam_import/domain/import_plan.dart';
import 'package:mentoria/features/exam_import/presentation/import_wizard_screen.dart';
import 'package:mentoria/features/exam_import/presentation/org_exams_screen.dart';
import 'package:mentoria/shared/motion.dart';

InMemoryExamCenter center() => InMemoryExamCenter.demo(
  roster: const [
    RosterStudent(id: 'demo-student', name: 'Elif Yılmaz', number: '1042'),
    RosterStudent(id: 'demo-can', name: 'Can Kaya'),
    RosterStudent(id: 'demo-zeynep', name: 'Zeynep Arslan', number: '1077'),
  ],
);

Future<void> pumpApp(WidgetTester t, InMemoryExamCenter c, Widget home) async {
  t.view.physicalSize = const Size(1200, 2600);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: await buildDemoOverrides(
        'admin',
        true,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        c,
      ),
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('Excel: kayıtlı şablon, doğrulama raporu, aktarım', (t) async {
    final c = center();
    await pumpApp(
      t,
      c,
      const ImportWizardScreen(
        examId: 'org-exam-3',
        rows: [
          [
            'ogrenci_no',
            'ad_soyad',
            'sinif',
            'kitapcik',
            'TURKCE_CEVAP',
            'MAT_CEVAP',
          ],
          ['1042', 'ELİF YILMAZ', '12-A', 'A', 'ABCDEABCDE', 'ABCDE-*.  '],
          ['1077', 'Zeynep Arslan', '12-A', '', 'AAAAAAAAAA', 'BBBBB'],
          ['9999', 'Kayıtsız Öğrenci', '12-A', 'A', 'AAAAAAAAAA', 'AAAAAAAAAA'],
        ],
      ),
    );
    expect(find.text('Sütunları eşleştir'), findsOneWidget);
    expect(
      find.text('Şablonu kullan: Okul optik okuyucusu'),
      findsOneWidget,
      reason: 'başlıklara uyan kayıtlı şablon önerilir',
    );
    await t.ensureVisible(find.byKey(const ValueKey('validate-import')));
    await t.tap(find.byKey(const ValueKey('validate-import')));
    await t.pumpAndSettle();
    expect(find.text('Doğrulama raporu'), findsOneWidget);
    expect(find.text('Eşleşmeyen numaralar'), findsOneWidget);
    expect(find.byKey(const ValueKey('unmatched-4')), findsOneWidget);
    expect(find.textContaining('cevap metni kısa'), findsOneWidget);
    expect(find.text('2 öğrenciyi aktar'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('run-import')));
    await t.pumpAndSettle();
    expect(find.text('2 öğrencinin optiği kaydedildi'), findsOneWidget);
    expect(await c.sheetCount('org-exam-3'), 2);
    expect(c.imports.single['unmatched'], 1);
    expect(await c.fetchCards('demo-student'), hasLength(2), reason: 'taslak');
  });

  testWidgets('aynı sınava ikinci yüklemede üzerine yazma sorulur', (t) async {
    final c = center();
    await pumpApp(
      t,
      c,
      const ImportWizardScreen(
        examId: 'org-exam-2',
        rows: [
          [
            'ogrenci_no',
            'ad_soyad',
            'sinif',
            'kitapcik',
            'TURKCE_CEVAP',
            'MAT_CEVAP',
          ],
          ['1042', 'Elif Yılmaz', '12-A', 'A', 'ABCDEABCDE', 'ABCDEABCDE'],
        ],
      ),
    );
    await t.ensureVisible(find.byKey(const ValueKey('validate-import')));
    await t.tap(find.byKey(const ValueKey('validate-import')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('run-import')));
    await t.pumpAndSettle();
    expect(find.text('Üzerine yazılsın mı?'), findsOneWidget);
    await t.tap(find.text('Üzerine yaz'));
    await t.pumpAndSettle();
    expect(find.text('1 öğrencinin optiği kaydedildi'), findsOneWidget);
    expect(await c.sheetCount('org-exam-2'), 3, reason: 'kopya yok');
  });

  testWidgets('karne: özet, konu analizi, soru soru', (t) async {
    final c = center();
    await pumpApp(
      t,
      c,
      const ReportCardScreen(examId: 'org-exam-2/demo-student'),
    );
    expect(find.text('Toplam net'), findsWidgets);
    expect(find.text('Kurum sırası'), findsOneWidget);
    expect(find.byKey(const ValueKey('card-subjects')), findsOneWidget);
    await t.tap(find.text('Konu analizi'));
    await t.pumpAndSettle();
    expect(find.text('Net kaybı haritası'), findsOneWidget);
    await t.tap(find.text('Soru soru'));
    await t.pumpAndSettle();
    expect(find.textContaining('doğru cevap'), findsWidgets);
  });

  testWidgets('karne listesi: kazanım gidişatı', (t) async {
    final c = center();
    await pumpApp(t, c, const ReportCardsScreen(studentId: 'demo-zeynep'));
    expect(find.text('Kurum Denemesi 2'), findsOneWidget);
    expect(find.text('Kurum Denemesi 1'), findsOneWidget);
    expect(find.text('Kurum Denemesi 3 (taslak)'), findsNothing);
  });

  testWidgets('sınav raporu: özet ve sıralama tablosu', (t) async {
    final c = center();
    await pumpApp(
      t,
      c,
      const ExamReportScreen(examId: 'org-exam-2', title: 'Kurum Denemesi 2'),
    );
    expect(find.text('Ders ortalamaları ve dağılım'), findsOneWidget);
    await t.tap(find.text('Kazanımlar'));
    await t.pumpAndSettle();
    expect(find.text('Kurumun en zayıf 10 kazanımı'), findsOneWidget);
    await t.tap(find.text('Sıralama'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('ranking-table')), findsOneWidget);
    expect(find.textContaining('Elif Yılmaz'), findsOneWidget);
  });

  testWidgets('yeni sınav: ad, cevap anahtarı, kaydet', (t) async {
    final c = center();
    await pumpApp(t, c, const OrgExamScreen(basePath: '/admin'));
    await t.enterText(find.byKey(const ValueKey('exam-name')), 'Mart Denemesi');
    await t.pumpAndSettle();
    await t.tap(find.text('Cevap anahtarı'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'abc\nde-');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('save-org-exam')));
    await t.pumpAndSettle();
    final saved = c.exams.values.firstWhere((e) => e.name == 'Mart Denemesi');
    expect(saved.isDraft, isTrue);
    final first = saved.subjects.first.code;
    final key = [
      for (var n = 1; n <= 6; n++) saved.question(first, n)?.correct ?? '-',
    ].join();
    expect(key, 'ABCDE-', reason: 'Excel\'den yapıştırılan sütun temizlendi');
  });
}
