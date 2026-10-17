import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/features/recap/data/week_recap.dart';
import 'package:mentoria/features/recap/presentation/recap_card.dart';
import 'package:mentoria/features/recap/presentation/recap_story_screen.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';
import 'package:mentoria/shared/motion.dart';

final now = DateTime(2026, 10, 18, 20); // Pazar akşamı

QuestionLog log(int daysAgo, String code, int c, int w, [int b = 0]) =>
    QuestionLog(
      id: '$daysAgo$code$c',
      subjectCode: code,
      correct: c,
      wrong: w,
      blank: b,
      loggedOn: DateTime(now.year, now.month, now.day - daysAgo),
    );

StudySession session(int daysAgo, int hour, int minutes) => StudySession(
  id: '$daysAgo-$hour',
  type: SessionType.pomodoro,
  startedAt: DateTime(now.year, now.month, now.day - daysAgo, hour),
  durationSec: minutes * 60,
);

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('haftalık özet hesabı', () {
    test('son 7 gün, önceki haftayla karşılaştırma, en iyi gün ve ders', () {
      final r = WeekRecap.compute(
        logs: [
          log(0, 'TYT_MAT', 40, 10), // bugün
          log(2, 'TYT_MAT', 80, 20), // en iyi gün (100)
          log(2, 'TYT_TUR', 30, 5),
          log(6, 'TYT_TUR', 20, 0), // haftanın ilk günü
          log(7, 'TYT_MAT', 50, 50), // önceki hafta
          log(20, 'TYT_MAT', 999, 0), // çok eski
        ],
        sessions: [session(1, 15, 50), session(3, 16, 40)],
        exams: [
          Exam(
            id: 'e1',
            examType: ExamType.tyt,
            name: 'Deneme',
            takenOn: DateTime(2026, 10, 15),
            results: const [
              SubjectResult(code: 'TYT_MAT', correct: 30, wrong: 8, blank: 2),
            ],
          ),
        ],
        now: now,
      );
      expect(r.start, DateTime(2026, 10, 12));
      expect(r.end, DateTime(2026, 10, 18));
      expect(r.questions, 205);
      expect(r.previousQuestions, 100);
      expect(r.changePercent, 105);
      expect(r.dailyQuestions, [20, 0, 0, 0, 135, 0, 50]);
      expect(r.bestDayIndex, 4);
      expect(r.activeDays, 5, reason: 'soru 4 gün + oturum olan 2 gün');
      expect(r.topSubjectCode, 'TYT_MAT');
      expect(r.topSubjectQuestions, 150);
      expect(r.topSubjectAccuracy, 0.8);
      expect(r.studyMinutes, 90);
      expect(r.pomodoros, 3);
      expect(r.exams, 1);
      expect(r.bestExamNet, 28);
      expect(r.isEmpty, isFalse);
    });

    test('arı tipi', () {
      BeePersona of({
        List<QuestionLog> logs = const [],
        List<StudySession> sessions = const [],
      }) => WeekRecap.compute(
        logs: logs,
        sessions: sessions,
        exams: const [],
        now: now,
      ).persona;

      expect(
        of(logs: [for (var d = 0; d < 7; d++) log(d, 'TYT_MAT', 5, 5)]),
        BeePersona.steady,
      );
      expect(of(logs: [log(0, 'TYT_MAT', 90, 5)]), BeePersona.sharpshooter);
      expect(
        of(
          sessions: [
            session(0, 22, 30),
            session(1, 23, 30),
            session(2, 10, 30),
          ],
        ),
        BeePersona.nightOwl,
      );
      expect(
        of(
          sessions: [session(0, 6, 30), session(1, 7, 30), session(2, 15, 30)],
        ),
        BeePersona.earlyBird,
      );
      expect(
        of(
          sessions: [
            session(0, 14, 60),
            session(1, 15, 50),
            session(2, 16, 50),
          ],
        ),
        BeePersona.marathoner,
      );
      expect(of(logs: [log(0, 'TYT_MAT', 20, 30)]), BeePersona.hunter);
    });

    test('boş hafta', () {
      final r = WeekRecap.compute(
        logs: [log(20, 'TYT_MAT', 10, 0)],
        sessions: const [],
        exams: const [],
        now: now,
      );
      expect(r.isEmpty, isTrue);
      expect(r.bestDayIndex, isNull);
      expect(r.changePercent, isNull);
    });
  });

  group('hikaye ekranı', () {
    setUp(() => Motion.enabled = false);
    tearDown(() => Motion.enabled = true);

    final full = WeekRecap.compute(
      logs: [log(0, 'TYT_MAT', 40, 10), log(2, 'TYT_TUR', 80, 20)],
      sessions: [session(1, 15, 50)],
      exams: const [],
      now: now,
    );

    Future<void> open(WidgetTester tester, WeekRecap r) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecapCard(recap: r, firstName: 'Elif'),
          ),
        ),
      );
      await tester.tap(find.text('Haftanın Bal Raporu'));
      await tester.pumpAndSettle();
    }

    testWidgets('kart hikayeyi açar; dokundukça sayfalar ilerler', (
      tester,
    ) async {
      await open(tester, full);
      expect(find.text('Elif, haftanın Bal Raporu hazır!'), findsOneWidget);

      final pages = <String>[
        'soru çözdün',
        'odaklandın',
        'Haftanın ritmi'.toUpperCase(),
        'Türkçe',
        full.persona.title,
      ];
      for (final marker in pages) {
        await tester.tap(find.bySemanticsLabel('Sonraki'));
        await tester.pumpAndSettle();
        expect(find.text(marker), findsOneWidget, reason: marker);
      }
      // Geri dokunma bir önceki sayfaya döner.
      await tester.tap(find.bySemanticsLabel('Önceki'));
      await tester.pumpAndSettle();
      expect(find.text('Türkçe'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Sonraki'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Sonraki'));
      await tester.pumpAndSettle();

      // Son sayfa: paylaşılabilir özet kartı.
      expect(find.byType(RecapShareCard), findsOneWidget);
      expect(find.text('Paylaş'), findsOneWidget);
      await tester.tap(find.text('Yeniden izle'));
      await tester.pumpAndSettle();
      expect(find.text('Elif, haftanın Bal Raporu hazır!'), findsOneWidget);
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(find.byType(RecapStoryScreen), findsNothing);
    });

    testWidgets('boş haftada tek, cesaretlendiren sayfa', (tester) async {
      await open(
        tester,
        WeekRecap.compute(
          logs: const [],
          sessions: const [],
          exams: const [],
          now: now,
        ),
      );
      expect(find.text('Bu hafta kovan biraz sessizdi, Elif.'), findsOneWidget);
      expect(find.bySemanticsLabel('Sonraki'), findsNothing);
    });
  });
}
