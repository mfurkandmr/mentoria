import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/learn/data/daily_question_repository.dart';
import 'package:mentoria/features/learn/data/practice_report.dart';
import 'package:mentoria/features/learn/data/practice_repository.dart';
import 'package:mentoria/features/learn/presentation/daily_question_screen.dart';
import 'package:mentoria/features/learn/presentation/learn_report_view.dart';
import 'package:mentoria/features/learn/presentation/notebook_button.dart';
import 'package:mentoria/features/mistakes/data/mistake_repository.dart';
import 'package:mentoria/shared/motion.dart';

List<PracticeQuestion> pool(String subject) => [
  for (final j
      in jsonDecode(
            File('assets/learn/questions/$subject.json').readAsStringSync(),
          )
          as List)
    PracticeQuestion.fromJson(j as Map<String, dynamic>),
];

PracticeAnswer ans(String id, bool correct, DateTime day) => PracticeAnswer(
  subject: id.split('-').first,
  questionId: id,
  correct: correct,
  answeredOn: day,
);

Future<ProviderContainer> app(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      ...await buildDemoOverrides('student'),
      for (final s in practiceSubjects)
        questionPoolProvider(s).overrideWith((ref) async => pool(s)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('Eğitim karnesi', () {
    final now = DateTime(2026, 10, 17, 15);
    final today = DateTime(2026, 10, 17);
    final topics = {
      'TYT_MAT-0001': 'Oran',
      'TYT_MAT-0002': 'Oran',
      'TYT_MAT-0003': 'Üslü sayılar',
      'TYT_MAT-0004': 'Üslü sayılar',
      'TYT_MAT-0005': 'Kümeler',
      'TYT_FIZ-0001': 'Hız',
    };

    test('ders ders sayı, isabet, en zayıf konu ve son 7 gün', () {
      final r = PracticeReport.of(
        answers: [
          ans('TYT_MAT-0001', false, today),
          ans('TYT_MAT-0002', false, today),
          ans('TYT_MAT-0003', false, today.subtract(const Duration(days: 1))),
          ans('TYT_MAT-0004', true, today.subtract(const Duration(days: 6))),
          ans('TYT_MAT-0005', true, today.subtract(const Duration(days: 9))),
          ans('TYT_FIZ-0001', true, today),
        ],
        topicOf: (id) => topics[id],
        now: now,
      );
      expect(r.subjects.map((s) => s.subject), ['TYT_MAT', 'TYT_FIZ']);
      final mat = r.subjects.first;
      expect((mat.solved, mat.correct), (5, 2));
      expect((mat.weakestTopic, mat.weakestWrong), ('Oran', 2));
      expect(r.subjects.last.weakestTopic, isNull, reason: 'yanlış yok');
      expect(r.solved, 6);
      expect(r.accuracy, closeTo(0.5, 1e-9));
      expect(r.days.first, today.subtract(const Duration(days: 6)));
      expect(r.perDay, [1, 0, 0, 0, 0, 1, 3]);
      expect(r.lastWeek, 5, reason: '9 gün önceki sayılmaz');
      expect(r.weakestSubject?.subject, 'TYT_MAT', reason: 'fizik < 5 soru');
    });

    test('eşit yanlışta konu seçimi sabittir', () {
      final r = PracticeReport.of(
        answers: [
          ans('TYT_MAT-0003', false, today),
          ans('TYT_MAT-0001', false, today),
        ],
        topicOf: (id) => topics[id],
        now: now,
      );
      expect(r.subjects.single.weakestTopic, 'Oran');
    });
  });

  group('Günün Sorusu (demo deposu)', () {
    test(
      'seri: dünden geriye doğru günler; yanlış cevap seriyi keser',
      () async {
        var clock = DateTime(2026, 10, 17, 9);
        final repo = InMemoryDailyQuestionRepository(
          myId: 'demo-student',
          pastCorrectDays: 3,
          clock: () => clock,
        );
        var s = (await repo.fetchToday())!;
        expect((s.answered, s.streak), (false, 3));
        expect(s.questionId, matches(RegExp(r'^TYT_[A-Z]{3}-\d{4}$')));
        await expectLater(
          repo.answer(
            'demo-student',
            questionId: 'TYT_XXX-0001',
            correct: true,
          ),
          throwsStateError,
        );
        await repo.answer(
          'demo-student',
          questionId: s.questionId,
          correct: true,
        );
        s = (await repo.fetchToday())!;
        expect((s.answered, s.correct, s.streak), (true, true, 4));

        clock = DateTime(2026, 10, 18, 9);
        s = (await repo.fetchToday())!;
        expect(
          (s.answered, s.streak),
          (false, 4),
          reason: 'yeni gün, yeni soru',
        );
        await repo.answer(
          'demo-student',
          questionId: s.questionId,
          correct: false,
        );
        s = (await repo.fetchToday())!;
        expect(s.streak, 0);
      },
    );

    test('dokuz gün boyunca dokuz farklı ders, hep havuz içinde', () {
      final repo = InMemoryDailyQuestionRepository(myId: 'demo-student');
      final subjects = <String>{};
      for (var k = 0; k < 9; k++) {
        final id = repo.questionFor(DateTime(2026, 10, 17 + k));
        final [subject, n] = id.split('-');
        subjects.add(subject);
        expect(
          int.parse(n),
          inInclusiveRange(1, practiceDailyLimit(subject) * 30),
        );
      }
      expect(subjects, hasLength(9));
    });

    test('hata defteri notu sunucu sınırını (500) aşmaz', () {
      for (final s in practiceSubjects) {
        for (final q in pool(s)) {
          expect(notebookNote(q).length, lessThanOrEqualTo(500), reason: q.id);
        }
      }
    });
  });

  group('ekran', () {
    setUp(() => Motion.enabled = false);
    tearDown(() => Motion.enabled = true);

    testWidgets('Günün Sorusu: yanlış cevap seriyi sıfırlar, deftere eklenir', (
      tester,
    ) async {
      final c = await app(tester, const DailyQuestionScreen());
      final repo =
          c.read(dailyQuestionRepositoryProvider)
              as InMemoryDailyQuestionRepository;
      final s = (await repo.fetchToday())!;
      final q = pool(s.subject).firstWhere((q) => q.id == s.questionId);
      expect(find.text(q.text), findsOneWidget);
      expect(find.text('🔥 4 gün'), findsOneWidget, reason: 'demo serisi');
      expect(find.text('Günlük hakkını harcamaz'), findsOneWidget);

      final wrong = (q.answer + 1) % q.options.length;
      await tester.tap(find.text(q.options[wrong]));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu sefer olmadı. Seri sıfırlandı, yarın yeniden başla!'),
        findsOneWidget,
      );
      expect(find.text('🔥 0 gün'), findsOneWidget);
      expect((await repo.fetchToday())!.answered, isTrue);

      await tester.scrollUntilVisible(
        find.text("Hata Defteri'ne ekle"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Hata Defteri'ne ekle"));
      await tester.pumpAndSettle();
      expect(
        find.text('Deftere eklendi · yarın yeniden sorulacak'),
        findsOneWidget,
      );
      final cards = await c
          .read(mistakeRepositoryProvider)
          .fetchCards('demo-student');
      expect(
        cards.where((m) => m.note?.contains(q.text) ?? false),
        hasLength(1),
      );
    });

    testWidgets('Günün Sorusu: doğru cevap seriyi büyütür', (tester) async {
      final c = await app(tester, const DailyQuestionScreen());
      final s = (await c.read(dailyQuestionRepositoryProvider).fetchToday())!;
      final q = pool(s.subject).firstWhere((q) => q.id == s.questionId);
      await tester.tap(find.text(q.options[q.answer]));
      await tester.pumpAndSettle();
      expect(find.text('Doğru! Serin 5 gün 🔥'), findsOneWidget);
      expect(find.text("Hata Defteri'ne ekle"), findsNothing);
    });

    testWidgets('koçun Eğitim karnesi demo geçmişini gösterir', (tester) async {
      await app(
        tester,
        const Scaffold(body: LearnReportView(studentId: 'demo-student')),
      );
      expect(find.text('Ders ders'), findsOneWidget);
      expect(find.text('Matematik'), findsOneWidget);
      expect(find.text('Fizik'), findsOneWidget);
      expect(find.textContaining('En zayıf ders: Fizik'), findsOneWidget);
      expect(find.textContaining('En çok yanlış:'), findsWidgets);
    });

    testWidgets('karnesi boş öğrenci', (tester) async {
      await app(
        tester,
        const Scaffold(body: LearnReportView(studentId: 'demo-can')),
      );
      expect(find.text('Henüz soru çözülmedi'), findsOneWidget);
    });
  });
}
