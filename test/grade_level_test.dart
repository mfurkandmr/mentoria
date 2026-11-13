// Sınıf seviyesi (NOTLAR §91): konular sınıfa göre süzülür; eşlemedeki her
// konu seed'de vardır; öğrenci / koç sınıfı değiştirince liste değişir.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/core/constants/grade_levels.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';
import 'package:mentoria/features/tracking/data/tracking_repository.dart';
import 'package:mentoria/features/tracking/presentation/grade_level_card.dart';
import 'package:mentoria/features/tracking/presentation/topics_view.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  test('eşlemedeki her konu seed dosyalarında var', () {
    final sql =
        File('supabase/seed.sql').readAsStringSync() +
        File('supabase/seed_ayt_ydt_topics.sql').readAsStringSync();
    final seed = <String>{
      for (final m in RegExp(
        r"\('([A-Z0-9_]+)',\s*\d+,\s*'((?:[^']|'')*)'\)",
      ).allMatches(sql))
        '${m[1]}|${m[2]!.replaceAll("''", "'")}',
    };
    final missing = [
      for (final e in topicGrades.entries)
        for (final name in e.value.keys)
          if (!seed.contains('${e.key}|$name')) '${e.key}|$name',
    ];
    expect(missing, isEmpty);
    for (final grades in topicGrades.values.expand((m) => m.values)) {
      expect(grades.every((g) => g >= 9 && g <= 11), isTrue);
    }
  });

  test('9. sınıf yalnızca 9. sınıf konularını, 12 / mezun hepsini görür', () {
    const topics = [
      Topic(id: 1, subjectCode: 'TYT_MAT', name: 'Mantık', sort: 1),
      Topic(id: 2, subjectCode: 'TYT_MAT', name: 'Polinomlar', sort: 2),
      Topic(id: 3, subjectCode: 'AYT_MAT', name: 'Trigonometri', sort: 3),
      Topic(id: 4, subjectCode: 'AYT_MAT', name: 'Türev', sort: 4),
    ];
    List<int> ids(int? g) => [for (final t in topicsForGrade(topics, g)) t.id];
    expect(ids(9), [1]);
    expect(ids(10), [2]);
    expect(ids(11), [3]);
    expect(ids(12), [1, 2, 3, 4]);
    expect(ids(null), [1, 2, 3, 4], reason: 'seçmeyen eski hesap');
    expect(gradeLabel(12), '12. sınıf / mezun');
    expect(gradeLabel(9), '9. sınıf');
  });

  testWidgets('sınıf seçilince konu ekranı o sınıfa göre listelenir', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 4200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: await buildDemoOverrides('student', true),
        child: const MaterialApp(
          locale: Locale('tr', 'TR'),
          supportedLocales: [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Column(
              children: [
                GradeLevelCard(studentId: 'demo-student'),
                Expanded(child: TopicsView(studentId: 'demo-student')),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    // Seçilmemiş: sınav türü sekmeleri ve AYT'deki Türev de var.
    expect(find.text('Seçilmedi · bütün konular görünür'), findsOneWidget);
    expect(find.byType(SegmentedButton<ExamType>), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('grade-level-card')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('grade-9')));
    await t.pumpAndSettle();
    expect(find.text('9. sınıf'), findsOneWidget);
    expect(find.byType(SegmentedButton<ExamType>), findsNothing);
    final container = ProviderScope.containerOf(
      t.element(find.byType(TopicsView)),
    );
    expect(
      await container
          .read(trackingRepositoryProvider)
          .fetchGradeLevel('demo-student'),
      9,
    );
    final shown = await container.read(
      studentTopicsProvider('demo-student').future,
    );
    expect(shown, isNotEmpty);
    expect(shown.every((x) => topicVisibleForGrade(x, 9)), isTrue);
    expect(shown.any((x) => x.name == 'Türev'), isFalse);
  });
}
