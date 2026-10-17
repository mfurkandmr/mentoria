import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/coach/data/exam_trends.dart';
import 'package:mentoria/features/coach/presentation/exam_trends_card.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/features/exams/data/yks_score.dart';
import 'package:mentoria/features/exams/presentation/score_calculator_screen.dart';
import 'package:mentoria/features/plan/data/plan_repository.dart';
import 'package:mentoria/features/plan/presentation/plan_widgets.dart';
import 'package:mentoria/shared/motion.dart';

Map<String, double> full(ScoreType t) => {
  for (final c in scoreSubjects(t)) c: maxNet(c).toDouble(),
};

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('YKS puanı', () {
    test('tam net her türde ≈ 500, sıfır net 100', () {
      for (final t in ScoreType.values) {
        expect(
          computeScore(t, full(t)).raw,
          closeTo(500, 0.5),
          reason: t.label,
        );
        expect(computeScore(t, const {}).raw, 100, reason: t.label);
      }
    });

    test('OBP: diploma × 5 × 0,12; geçen yıl yerleştiyse yarısı', () {
      final s = computeScore(ScoreType.tyt, const {}, diploma: 80);
      expect(s.obpBonus, closeTo(48, 1e-9));
      expect(s.placement, closeTo(148, 1e-9));
      expect(
        computeScore(
          ScoreType.tyt,
          const {},
          diploma: 80,
          placedLastYear: true,
        ).obpBonus,
        closeTo(24, 1e-9),
      );
      expect(
        computeScore(ScoreType.tyt, const {}, diploma: 120).obpBonus,
        closeTo(60, 1e-9),
        reason: 'en çok 100',
      );
    });

    test('eksi net sıfır, soru sayısını aşan net kırpılır', () {
      expect(computeScore(ScoreType.tyt, const {'TYT_MAT': -5}).raw, 100);
      expect(
        computeScore(ScoreType.tyt, const {'TYT_MAT': 99}).raw,
        closeTo(100 + 40 * 3.3, 1e-9),
      );
    });

    test('SAY puanında TYT %40, AYT tam katsayı', () {
      final s = computeScore(ScoreType.say, const {
        'TYT_MAT': 10,
        'AYT_MAT': 10,
      });
      expect(s.raw, closeTo(100 + 10 * 3.3 * 0.4 + 10 * 3.0, 1e-9));
    });

    test('hedef açığı: en verimli dersler önce, dolu ders atlanır', () {
      final nets = {'TYT_TUR': 40.0};
      final g = gainsFor(ScoreType.tyt, nets, 34);
      expect(g.any((x) => x.subject == 'TYT_TUR'), isFalse, reason: 'tam net');
      expect(g.first.coefficient, 3.4);
      expect(g.first.netsNeeded, closeTo(10, 1e-9));
      final mat = g.firstWhere((x) => x.subject == 'TYT_MAT');
      expect(mat.reachable, isTrue);
      final fiz = g.firstWhere((x) => x.subject == 'TYT_FIZ');
      expect(fiz.reachable, isFalse, reason: '7 soruda 10 net olmaz');
    });

    test('netler her türün en son denemesinden', () {
      Exam e(String id, ExamType t, int day, String code, int c) => Exam(
        id: id,
        examType: t,
        name: id,
        takenOn: DateTime(2026, 10, day),
        results: [SubjectResult(code: code, correct: c, wrong: 4, blank: 0)],
      );
      final n = netsFromExams([
        e('a', ExamType.tyt, 1, 'TYT_MAT', 20),
        e('b', ExamType.tyt, 9, 'TYT_MAT', 30),
        e('c', ExamType.ayt, 5, 'AYT_MAT', 12),
      ]);
      expect(n, {'TYT_MAT': 29.0, 'AYT_MAT': 11.0});
    });
  });

  test('en çok yükselen / düşen 5', () {
    ExamTrend t(String id, double a, double b) => ExamTrend(
      studentId: id,
      name: id,
      examCount: 5,
      firstNet: a,
      lastNet: b,
    );
    final m = topMovers([
      for (var i = 0; i < 8; i++) t('up$i', 50, 50.0 + i + 1),
      for (var i = 0; i < 7; i++) t('down$i', 50, 50.0 - i - 1),
      t('flat', 60, 60),
    ]);
    expect(m.rising.map((x) => x.studentId), [
      'up7',
      'up6',
      'up5',
      'up4',
      'up3',
    ]);
    expect(m.falling.map((x) => x.studentId), [
      'down6',
      'down5',
      'down4',
      'down3',
      'down2',
    ]);
  });

  group('ekran', () {
    setUp(() => Motion.enabled = false);
    tearDown(() => Motion.enabled = true);

    Future<ProviderContainer> pump(
      WidgetTester tester,
      Widget home,
      String role,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: await buildDemoOverrides(role));
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(home: home),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('puan hesaplayıcı: son denemelerle dolar, hedef söyler', (
      tester,
    ) async {
      await pump(tester, const ScoreCalculatorScreen(), 'student');
      expect(find.textContaining('yerleştirme puanın'), findsOneWidget);
      await tester.tap(find.text('TYT').first);
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'TYT hedef puanı',
      );
      await tester.enterText(field, '499');
      await tester.pumpAndSettle();
      expect(find.textContaining('Hedefe'), findsOneWidget);
      await tester.enterText(field, '101');
      await tester.pumpAndSettle();
      expect(find.textContaining('puan üstündesin'), findsOneWidget);
    });

    testWidgets('öğrenci planı işaretler, oran artar', (tester) async {
      final c = await pump(tester, const StudentPlanScreen(), 'student');
      final repo = c.read(planRepositoryProvider) as InMemoryPlanRepository;
      final before = repo.items.where((i) => i.done).length;
      expect(find.textContaining('madde · %'), findsOneWidget);
      final open = find.byWidgetPredicate(
        (w) => w is Checkbox && w.value == false,
      );
      await tester.scrollUntilVisible(
        open.first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(open.first);
      await tester.pumpAndSettle();
      expect(repo.items.where((i) => i.done).length, before + 1);
    });

    testWidgets('koç plana madde ekler', (tester) async {
      final c = await pump(
        tester,
        const Scaffold(
          body: WeeklyPlanView(
            studentId: 'demo-can',
            canEdit: true,
            canTick: true,
          ),
        ),
        'coach',
      );
      expect(find.text('Bu hafta için plan yok'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Madde ekle').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Madde ekle').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Konu (isteğe bağlı)',
        ),
        'Problemler',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Soru hedefi',
        ),
        '40',
      );
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();
      final repo = c.read(planRepositoryProvider) as InMemoryPlanRepository;
      final added = repo.items.where((i) => i.studentId == 'demo-can').single;
      expect(
        (added.subject, added.topic, added.questionCount),
        ('TYT_MAT', 'Problemler', 40),
      );
      expect(added.day, weekStartOf(DateTime.now()), reason: 'pazartesi');
      expect(find.text('TYT Matematik · Problemler'), findsOneWidget);
    });

    testWidgets('yükselen / düşen kartı', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: ExamTrendsCard(basePath: '/coach'),
          ),
        ),
        'coach',
      );
      expect(find.text('En çok yükselen'), findsOneWidget);
      expect(find.text('En çok düşen'), findsOneWidget);
      expect(find.textContaining('net ·'), findsWidgets);
    });
  });
}
