import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/exam_comparison/presentation/exam_comparison_screen.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/features/exams/data/exam_repository.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('2 deneme tablo, 5 deneme özet, tür karışınca uyarı', (t) async {
    t.view.physicalSize = const Size(1080, 3600);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: await buildDemoOverrides('student'),
        child: const MaterialApp(
          locale: Locale('tr', 'TR'),
          supportedLocales: [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ExamComparisonScreen(studentId: 'demo-student'),
        ),
      ),
    );
    await t.pumpAndSettle();
    final container = ProviderScope.containerOf(
      t.element(find.byType(ExamComparisonScreen)),
    );
    final all = await container.read(
      examsForStudentProvider('demo-student').future,
    );
    final tyt = [...all.where((e) => e.examType.db == 'TYT')]
      ..sort((a, b) => Exam.byDate(b, a));
    final ayt = all.where((e) => e.examType.db != 'TYT').toList();
    expect(tyt.length, greaterThanOrEqualTo(5));

    Future<void> pick(String id) async {
      final f = find.byKey(ValueKey('pick-$id'));
      await t.ensureVisible(f);
      await t.tap(f);
      await t.pumpAndSettle();
    }

    await pick(tyt[0].id);
    await pick(tyt[1].id);
    expect(find.text('2/4 seçildi'), findsOneWidget);
    await t.tap(find.text('Karşılaştırma'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('compare-table')), findsOneWidget);
    expect(find.text('Toplam net'), findsWidgets);

    await t.tap(find.text('Denemeler'));
    await t.pumpAndSettle();
    for (final e in tyt.skip(2).take(3)) {
      await pick(e.id);
    }
    expect(find.text('5 seçildi · özet'), findsOneWidget);
    expect(
      find.text('5 ve üzeri deneme için özet görünümü gösteriliyor.'),
      findsOneWidget,
    );
    await t.tap(find.text('Karşılaştırma'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('compare-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-table')), findsNothing);

    if (ayt.isNotEmpty) {
      await t.tap(find.text('Denemeler'));
      await t.pumpAndSettle();
      await pick(ayt.first.id);
      expect(find.textContaining('Farklı türde denemeler'), findsOneWidget);
    }
  });
}
