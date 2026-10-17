import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/learn/data/learn_cards.dart';
import 'package:mentoria/features/learn/data/practice_repository.dart';
import 'package:mentoria/features/learn/presentation/learn_screen.dart';
import 'package:mentoria/shared/motion.dart';

List<PracticeQuestion> pool(String subject) => [
  for (final j
      in jsonDecode(
            File('assets/learn/questions/$subject.json').readAsStringSync(),
          )
          as List)
    PracticeQuestion.fromJson(j as Map<String, dynamic>),
];

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('soru havuzu (telifsiz, özgün)', () {
    test('her ders: havuz = günlük hak × 30, geçerli ve benzersiz sorular', () {
      final idPattern = RegExp(
        r'^TYT_[A-Z]{3}-[0-9]{4}$',
      ); // sunucudaki CHECK ile aynı
      var total = 0;
      for (final s in practiceSubjects) {
        final qs = pool(s);
        expect(qs.length, practiceDailyLimit(s) * 30, reason: s);
        expect(
          qs.map((q) => q.id).toSet().length,
          qs.length,
          reason: '$s: benzersiz kimlik',
        );
        expect(
          qs
              .map((q) => '${q.text}|${(q.options.toList()..sort()).join('|')}')
              .toSet()
              .length,
          qs.length,
          reason: '$s: aynı soru iki kez yok',
        );
        for (final q in qs) {
          expect(
            idPattern.hasMatch(q.id) && q.subject == s,
            isTrue,
            reason: q.id,
          );
          expect(q.options.length, 5, reason: q.id);
          expect(q.options.toSet().length, 5, reason: '${q.id}: şıklar farklı');
          expect(q.answer, inInclusiveRange(0, 4), reason: q.id);
          expect(q.text.trim(), isNotEmpty);
          expect(q.explanation.trim(), isNotEmpty);
        }
        total += qs.length;
      }
      expect(total, 3300);
    });

    test('her dersin bilgi kartları var', () {
      for (final s in practiceSubjects) {
        expect(learnCards[s], isNotNull, reason: s);
        expect(learnCards[s]!.length, greaterThanOrEqualTo(10), reason: s);
      }
    });

    test('doğru şıklar A-E arasında dengeli dağılmış', () {
      for (final s in practiceSubjects) {
        final counts = List.filled(5, 0);
        for (final q in pool(s)) {
          counts[q.answer]++;
        }
        final n = pool(s).length;
        for (final c in counts) {
          expect(c, greaterThan(n * 0.1), reason: '$s: $counts');
        }
      }
    });
  });

  group('günlük soru seçimi', () {
    final qs = pool('TYT_FIZ');
    final today = DateTime(2026, 10, 17, 10);

    test('ilk gün: 10 hak, sorular günlük sabit sırayla', () {
      final a = SubjectPractice.of(
        subject: 'TYT_FIZ',
        studentId: 's1',
        pool: qs,
        answers: const [],
        now: today,
      );
      final b = SubjectPractice.of(
        subject: 'TYT_FIZ',
        studentId: 's1',
        pool: qs,
        answers: const [],
        now: today,
      );
      expect(a.remaining, 10);
      expect(a.todaysQuestions.length, 10);
      expect(
        a.todaysQuestions.map((q) => q.id),
        b.todaysQuestions.map((q) => q.id),
      );
      final other = SubjectPractice.of(
        subject: 'TYT_FIZ',
        studentId: 's2',
        pool: qs,
        answers: const [],
        now: today,
      );
      expect(
        other.todaysQuestions.map((q) => q.id),
        isNot(a.todaysQuestions.map((q) => q.id)),
        reason: 'öğrenciye göre farklı sıra',
      );
    });

    test(
      '30 gün boyunca hiçbir soru tekrar gelmez, sonra en eskiler döner',
      () {
        final answers = <PracticeAnswer>[];
        final seen = <String>{};
        for (var d = 0; d < 30; d++) {
          final now = today.add(Duration(days: d));
          final p = SubjectPractice.of(
            subject: 'TYT_FIZ',
            studentId: 's1',
            pool: qs,
            answers: answers,
            now: now,
          );
          expect(p.remaining, 10);
          for (final q in p.todaysQuestions) {
            expect(
              seen.add(q.id),
              isTrue,
              reason: 'gün $d: ${q.id} tekrar geldi',
            );
            answers.add(
              PracticeAnswer(
                subject: 'TYT_FIZ',
                questionId: q.id,
                correct: true,
                answeredOn: DateTime(now.year, now.month, now.day),
              ),
            );
          }
        }
        expect(seen.length, 300, reason: 'havuzun tamamı görüldü');
        final day31 = SubjectPractice.of(
          subject: 'TYT_FIZ',
          studentId: 's1',
          pool: qs,
          answers: answers,
          now: today.add(const Duration(days: 30)),
        );
        final firstDay = answers.take(10).map((a) => a.questionId).toSet();
        expect(
          day31.todaysQuestions.map((q) => q.id).toSet(),
          firstDay,
          reason: 'en uzun süredir görülmeyenler',
        );
      },
    );

    test('bugün çözülenler hakkı azaltır', () {
      final p0 = SubjectPractice.of(
        subject: 'TYT_FIZ',
        studentId: 's1',
        pool: qs,
        answers: const [],
        now: today,
      );
      final answers = [
        for (final q in p0.todaysQuestions.take(4))
          PracticeAnswer(
            subject: 'TYT_FIZ',
            questionId: q.id,
            correct: q.answer == 0,
            answeredOn: DateTime(2026, 10, 17),
          ),
      ];
      final p = SubjectPractice.of(
        subject: 'TYT_FIZ',
        studentId: 's1',
        pool: qs,
        answers: answers,
        now: today,
      );
      expect((p.usedToday, p.remaining), (4, 6));
      expect(
        p.todaysQuestions
            .map((q) => q.id)
            .toSet()
            .intersection(answers.map((a) => a.questionId).toSet()),
        isEmpty,
      );
    });
  });

  group('ekran', () {
    setUp(() => Motion.enabled = false);
    tearDown(() => Motion.enabled = true);

    testWidgets('dersler, bilgi kartı çevirme, soru çözme ve günlük sınır', (
      tester,
    ) async {
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
      final repo =
          container.read(practiceRepositoryProvider)
              as InMemoryPracticeRepository;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LearnScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bugünkü çalışman'), findsOneWidget);
      expect(find.text('0 / 110'), findsOneWidget, reason: '2×20 + 7×10');
      expect(find.text('Matematik'), findsOneWidget);
      expect(find.text('20 soru hakkın var'), findsNWidgets(2));
      expect(find.text('10 soru hakkın var'), findsNWidgets(7));

      // Fizik: önce 9 soruyu doğrudan çöz (sınıra yaklaş).
      final fiz = pool('TYT_FIZ');
      final start = SubjectPractice.of(
        subject: 'TYT_FIZ',
        studentId: 'demo-student',
        pool: fiz,
        answers: const [],
        now: DateTime.now(),
      );
      for (final q in start.todaysQuestions.take(9)) {
        await repo.submit(
          'demo-student',
          subject: 'TYT_FIZ',
          questionId: q.id,
          correct: true,
        );
      }

      container.invalidate(practiceAnswersProvider('demo-student'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fizik'));
      await tester.pumpAndSettle();
      expect(find.text('Hız ve ivme'), findsOneWidget);
      await tester.tap(find.text('Hız ve ivme'));
      await tester.pumpAndSettle();
      expect(
        find.text('v = x / t   ·   a = Δv / t'),
        findsOneWidget,
        reason: 'kart çevrildi',
      );

      await tester.tap(find.text('Soru çöz'));
      await tester.pumpAndSettle();
      expect(find.text('Soru 10 / 10'), findsOneWidget);
      final q = start.todaysQuestions[9];
      expect(find.text(q.text), findsOneWidget);
      await tester.tap(find.text(q.options[q.answer]));
      await tester.pumpAndSettle();
      expect(find.text('Doğru!'), findsOneWidget);
      expect(find.text(q.explanation), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Bitir'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bitir'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 1 doğru'), findsOneWidget);
      expect((await repo.fetchAnswers('demo-student')).length, 10);
      await expectLater(
        repo.submit(
          'demo-student',
          subject: 'TYT_FIZ',
          questionId: 'TYT_FIZ-0001',
          correct: true,
        ),
        throwsA(isA<DailyLimitReached>()),
      );
    });
  });
}
