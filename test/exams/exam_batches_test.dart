import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/features/exams/data/exam_repository.dart';
import 'package:mentoria/features/exams/presentation/exam_batches_screen.dart';
import 'package:mentoria/features/exams/presentation/exam_detail_sheet.dart';
import 'package:mentoria/shared/motion.dart';

ExamDraft _draft(String name, {String? batchId}) => ExamDraft(
  examType: ExamType.tyt,
  name: name,
  takenOn: DateTime(2026, 10, 16),
  imported: batchId != null,
  batchId: batchId,
  results: const [
    SubjectResult(code: 'TYT_MAT', correct: 20, wrong: 0, blank: 0),
  ],
);

Future<(Widget, ProviderContainer Function(WidgetTester))> _app(
  Widget screen,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
    ],
  );
  final app = ProviderScope(
    overrides: await buildDemoOverrides('coach'),
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
  return (
    app,
    (WidgetTester t) =>
        ProviderScope.containerOf(t.element(find.byType(Scaffold).first)),
  );
}

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  group('deneme paketleri (bellek)', () {
    test('tek yükleme tek paket; 7 günden eski silinemez', () async {
      final repo = InMemoryExamRepository();
      final batch = newBatchId();
      await repo.createExam(
        studentId: 'a',
        draft: _draft('X', batchId: batch),
      );
      await repo.createExam(
        studentId: 'b',
        draft: _draft('X', batchId: batch),
      );
      await repo.createExam(studentId: 'a', draft: _draft('Elle'));
      repo.seedMine(
        'a',
        _draft('Eski'),
        batchId: 'old',
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      );

      final batches = await repo.fetchMyBatches();
      expect(batches, hasLength(3));
      final x = batches.firstWhere((b) => b.id == batch);
      expect(x.studentCount, 2);
      expect(x.editable, isTrue);
      expect(batches.firstWhere((b) => b.id == 'old').editable, isFalse);

      expect(await repo.deleteBatch(batch), 2);
      expect(
        (await repo.fetchExams(studentId: 'b')).where((e) => e.name == 'X'),
        isEmpty,
      );
      expect(
        () => repo.deleteBatch('old'),
        throwsA(isA<ExamLockedException>()),
      );
      final old = (await repo.fetchExams(
        studentId: 'a',
      )).firstWhere((e) => e.name == 'Eski');
      expect(
        () => repo.deleteExam(old.id),
        throwsA(isA<ExamLockedException>()),
      );
    });

    test('paket kimliği UUID v4 biçiminde ve her seferinde yeni', () {
      final a = newBatchId();
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(a),
        isTrue,
      );
      expect(newBatchId(), isNot(a));
    });
  });

  testWidgets('koç son yüklenen denemeyi herkesten siler; eskisi kilitli', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final (app, container) = await _app(const ExamBatchesScreen());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Son yüklenen deneme'), findsOneWidget);
    expect(find.text('Bilgi Sarmal TYT-6'), findsNWidgets(2)); // kart + liste
    expect(find.text('Bilgi Sarmal TYT-5'), findsOneWidget);
    expect(find.text('Kilitli'), findsOneWidget);
    expect(find.text('2 öğrenci'), findsNWidgets(2));

    await tester.tap(find.text('Son denemeyi herkesten sil'));
    await tester.pumpAndSettle();
    expect(
      find.text('Son yüklenen deneme herkesten silinsin mi?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Herkesten sil'));
    await tester.pumpAndSettle();

    expect(
      find.text('"Bilgi Sarmal TYT-6" 2 öğrenciden silindi.'),
      findsOneWidget,
    );
    expect(find.text('Bilgi Sarmal TYT-6'), findsNothing);
    // Kalan tek yükleme kilitli: "son denemeyi sil" kartı çıkmaz.
    expect(find.text('Son yüklenen deneme'), findsNothing);
    expect(find.text('Bilgi Sarmal TYT-5'), findsOneWidget);

    final repo = container(tester).read(examRepositoryProvider);
    for (final s in ['demo-student', 'demo-can']) {
      final names = (await repo.fetchExams(studentId: s)).map((e) => e.name);
      expect(names, isNot(contains('Bilgi Sarmal TYT-6')), reason: s);
      expect(names, contains('Bilgi Sarmal TYT-5'), reason: s);
    }
  });

  testWidgets('deneme detayı: 7 günden eski denemede silme yerine kilit', (
    tester,
  ) async {
    Widget sheet(Exam exam) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ExamDetailSheet(exam: exam, studentId: 's', canDelete: true),
        ),
      ),
    );
    Exam exam(Duration age) => Exam(
      id: 'e',
      examType: ExamType.tyt,
      name: 'Deneme',
      takenOn: DateTime(2026, 10, 1),
      createdAt: DateTime.now().subtract(age),
      results: const [],
    );

    await tester.pumpWidget(sheet(exam(const Duration(days: 8))));
    await tester.pumpAndSettle();
    expect(find.text('Denemeyi sil'), findsNothing);
    expect(
      find.text('Bu deneme 7 günden eski; silinemez ve değiştirilemez.'),
      findsOneWidget,
    );

    await tester.pumpWidget(sheet(exam(const Duration(days: 2))));
    await tester.pumpAndSettle();
    expect(find.text('Denemeyi sil'), findsOneWidget);
  });
}
