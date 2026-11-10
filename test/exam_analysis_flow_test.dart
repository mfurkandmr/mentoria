import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/dev/demo_exam_center.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_rich.dart';
import 'package:mentoria/features/exam_analysis/presentation/report_card_screen.dart';
import 'package:mentoria/features/exam_import/domain/exam_definition.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

ExamDefinition _exam(List<KeyQuestion> questions) => ExamDefinition(
  name: 'Deneme',
  examType: ExamType.tyt,
  takenOn: DateTime(2026, 11, 1),
  subjects: const [ExamSubjectDef(code: 'TYT_MAT', questionCount: 3)],
  questions: questions,
);

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  group('yayın kontrolü', () {
    test('cevabı ve kazanımı eksik sorular bulunur; iptal sayılmaz', () {
      final gaps = _exam(const [
        KeyQuestion(
          subject: 'TYT_MAT',
          number: 1,
          correct: 'A',
          outcome: 'Trigonometri',
        ),
        KeyQuestion(subject: 'TYT_MAT', number: 2, correct: 'B'),
        KeyQuestion(subject: 'TYT_MAT', number: 3, cancelled: true),
      ]).keyGaps;
      expect(gaps.noAnswer, isEmpty);
      expect(gaps.noOutcome, {
        'TYT_MAT': [2],
      });
      expect(gaps.isComplete, isFalse);
    });

    test('hiç girilmemiş soru iki listede de eksiktir', () {
      final gaps = _exam(const []).keyGaps;
      expect(gaps.answerCount, 3);
      expect(gaps.outcomeCount, 3);
    });

    test('anahtar ve kazanım tamsa eksik yok', () {
      final gaps = _exam(const [
        KeyQuestion(
          subject: 'TYT_MAT',
          number: 1,
          correct: 'A',
          outcomeId: 'o',
        ),
        KeyQuestion(
          subject: 'TYT_MAT',
          number: 2,
          correct: 'B',
          outcomeId: 'o',
        ),
        KeyQuestion(
          subject: 'TYT_MAT',
          number: 3,
          correct: 'C',
          outcomeId: 'o',
        ),
      ]).keyGaps;
      expect(gaps.isComplete, isTrue);
    });

    test('kazanımsız sınav yayınlanamaz', () async {
      final c = InMemoryExamCenter(roster: const []);
      final id = await c.saveExam(
        _exam(const [
          KeyQuestion(subject: 'TYT_MAT', number: 1, correct: 'A'),
          KeyQuestion(subject: 'TYT_MAT', number: 2, correct: 'A'),
          KeyQuestion(subject: 'TYT_MAT', number: 3, correct: 'A'),
        ]),
      );
      await expectLater(c.publishExam(id), throwsA(isA<StateError>()));
    });
  });

  group('öğrenci ekranı', () {
    setUp(() => demoRichEnabled = true);
    tearDown(() => demoRichEnabled = false);

    testWidgets('son sınav kartından yanlışlara ve konuya geçilir', (t) async {
      t.view.physicalSize = const Size(1080, 2600);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      await t.pumpWidget(
        ProviderScope(
          overrides: await buildDemoOverrides('student'),
          child: const MaterialApp(
            locale: Locale('tr', 'TR'),
            supportedLocales: [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: LastExamAnalysisCard(studentId: 'demo-student'),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Son sınav analizi'), findsOneWidget);
      expect(find.textContaining('Trigonometri'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('last-exam-wrong')));
      await t.pumpAndSettle();
      // Yalnızca yanlış ve boşlar: konu adı ve doğru cevap görünür.
      expect(find.textContaining('Yanlış ve boşlar'), findsOneWidget);
      expect(find.text('Trigonometri'), findsWidgets);
      expect(find.textContaining('doğrusu'), findsWidgets);
      final before = t.widgetList(find.byType(ListTile)).length;

      await t.tap(find.byKey(const ValueKey('questions-all')));
      await t.pumpAndSettle();
      expect(find.textContaining('Doğru · cevap'), findsWidgets);
      expect(before, greaterThan(0));
    });

    testWidgets('kurum sınavı yoksa kart görünmez', (t) async {
      demoRichEnabled = false;
      SharedPreferences.setMockInitialValues({});
      await t.pumpWidget(
        ProviderScope(
          overrides: await buildDemoOverrides('student'),
          child: const MaterialApp(
            home: Scaffold(body: LastExamAnalysisCard(studentId: 'kimse-yok')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('last-exam-analysis')), findsNothing);
    });
  });
}
