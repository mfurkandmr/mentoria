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
import 'package:mentoria/features/student/presentation/student_home_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  testWidgets(
    'ana sayfa: aynı gün girilen 3 denemeden en son gireni gösterir',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const StudentHomeScreen()),
          GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: await buildDemoOverrides('student'),
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudentHomeScreen)),
      );
      final repo = container.read(examRepositoryProvider);
      final today = DateTime.now();
      for (final (name, correct) in [
        ('Sabah', 20),
        ('Öğle', 25),
        ('Akşam', 30),
      ]) {
        await repo.createExam(
          studentId: 'demo-student',
          draft: ExamDraft(
            examType: ExamType.tyt,
            name: 'Bugün $name',
            takenOn: DateTime(today.year, today.month, today.day),
            results: [
              SubjectResult(
                code: 'TYT_MAT',
                correct: correct,
                wrong: 0,
                blank: 0,
              ),
            ],
          ),
        );
        // Giriş saatleri birbirinden ayrılsın.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      container.invalidate(examsForStudentProvider('demo-student'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Bugün Akşam'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Bugün Akşam'), findsOneWidget);
      expect(find.text('Bugün Sabah'), findsNothing);
    },
  );
}
