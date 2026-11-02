import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/coach/data/coach_repository.dart';
import 'package:mentoria/features/exams/data/exam_repository.dart';
import 'package:mentoria/features/optic/data/answer_key.dart';
import 'package:mentoria/features/optic/data/omr/omr_reader.dart';
import 'package:mentoria/features/optic/data/optic_repository.dart';
import 'package:mentoria/features/optic/presentation/answer_key_screens.dart';
import 'package:mentoria/features/optic/presentation/exam_answers_view.dart';
import 'package:mentoria/features/optic/presentation/optic_scan_screens.dart';
import 'package:mentoria/shared/motion.dart';

Future<Widget> _app(Widget home) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/coach/optic/:id',
        builder: (_, s) => OpticKeyScreen(keyId: s.pathParameters['id']!),
      ),
    ],
  );
  return ProviderScope(
    overrides: await buildDemoOverrides('coach'),
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(Scaffold).first));

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('boş kâğıt indirme: koç formu seçer, standart form ilk', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(await _app(const OpticKeysScreen()));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Boş cevap kâğıdını indir (PDF)'));
    await t.pumpAndSettle();
    expect(find.text('Hangi cevap kâğıdı?'), findsOneWidget);
    final standart = find.text('Standart YKS optik formu (kenar çizgili)');
    final mentoria = find.text('Mentoria YKS cevap kâğıdı');
    expect(standart, findsOneWidget);
    expect(mentoria, findsOneWidget);
    expect(t.getTopLeft(standart).dy, lessThan(t.getTopLeft(mentoria).dy));
  });

  testWidgets('demo anahtarı listelenir, okunan optikler nete göre', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(await _app(const OpticKeysScreen()));
    await t.pumpAndSettle();
    expect(find.text('Kasım TYT-1 (optik)'), findsOneWidget);
    expect(find.textContaining('2 optik okundu'), findsOneWidget);

    await t.tap(find.text('Kasım TYT-1 (optik)'));
    await t.pumpAndSettle();
    expect(find.text('Optik oku'), findsOneWidget);
    expect(find.text('Elif Yılmaz'), findsOneWidget);
    expect(find.text('Zeynep Arslan'), findsOneWidget);
    expect(find.text('En çok yanlış yapılan kazanımlar'), findsOneWidget);
    // Elif daha çok doğru yaptı: listede önce.
    expect(
      t.getTopLeft(find.text('Elif Yılmaz')).dy,
      lessThan(t.getTopLeft(find.text('Zeynep Arslan')).dy),
    );
  });

  testWidgets(
    'okunan optik: numaradan öğrenci bulunur, belirsiz soru seçilir, kaydedilir',
    (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 1;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(await _app(const Scaffold()));
      await t.pumpAndSettle();
      final c = _container(t);
      final repo = c.read(opticRepositoryProvider);
      final key = (await repo.fetchKeys()).single;
      final full = await repo.fetchKey(key.id);
      // Zeynep'in optiği: tüm sorular doğru, Türkçe 1 belirsiz (A ve C).
      final answers = {
        for (final s in subjectsFor(ExamType.tyt))
          s.code: [
            for (final i in full.items.where((i) => i.subject == s.code))
              i.correct,
          ],
      };
      answers['TYT_TUR']![0] = null;
      final result = OmrResult(
        answers: answers,
        uncertain: const [
          UncertainMark(subject: 'TYT_TUR', number: 1, candidates: 'AC'),
        ],
        studentNumber: '1077',
      );
      await c.read(studentSummariesProvider.future);
      await c.read(opticSheetsProvider(key.id).future);

      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      final saved = nav.push<bool>(
        MaterialPageRoute(
          builder: (_) => OpticReviewScreen(answerKey: full, result: result),
        ),
      );
      await t.pumpAndSettle();
      // 1077 → Zeynep (demo).
      expect(
        find.textContaining('Formdaki numaradan bulundu: 1077'),
        findsOneWidget,
      );
      expect(find.textContaining('Zeynep Arslan'), findsWidgets);
      expect(find.textContaining('daha önce okunmuştu'), findsOneWidget);
      expect(find.textContaining('1 soru boş sayılacak'), findsOneWidget);

      final correct = full.items
          .firstWhere((i) => i.subject == 'TYT_TUR' && i.number == 1)
          .correct!;
      await t.tap(find.widgetWithText(ChoiceChip, correct));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Kaydet'));
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();
      expect(await saved, isTrue);

      final sheets = await repo.fetchSheets(key.id);
      final zeynep = sheets.singleWhere((s) => s.studentId == 'demo-zeynep');
      final score = scoreOptic(full.items, zeynep.answers, ExamType.tyt);
      expect(score.wrong + score.blank, 0);
      // Yeniden okuma güncelledi: Zeynep'in bu denemesi tek.
      final exams = await c
          .read(examRepositoryProvider)
          .fetchExams(studentId: 'demo-zeynep');
      expect(exams.where((e) => e.name == key.name), hasLength(1));
    },
  );

  testWidgets(
    'B kitapçığı: anahtarda B yoksa kaydedilemez; farklı oturum uyarısı',
    (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(await _app(const Scaffold()));
      await t.pumpAndSettle();
      final c = _container(t);
      final repo = c.read(opticRepositoryProvider);
      final key = await repo.fetchKey((await repo.fetchKeys()).single.id);
      await c.read(studentSummariesProvider.future);

      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(
        nav.push<bool>(
          MaterialPageRoute(
            builder: (_) => OpticReviewScreen(
              answerKey: key,
              result: const OmrResult(
                answers: {},
                uncertain: [],
                studentNumber: '1042',
                session: 'AYT',
                booklet: 'B',
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Formda AYT işaretli'), findsOneWidget);
      expect(find.text('Formdan okundu: B'), findsOneWidget);
      expect(find.textContaining('B kitapçığı numaraları yok'), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Kaydet');
      expect(t.widget<FilledButton>(save).onPressed, isNull);

      // Koç A'yı seçince kaydedilebilir.
      await t.tap(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('A'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('B kitapçığı numaraları yok'), findsNothing);
      expect(t.widget<FilledButton>(save).onPressed, isNotNull);
    },
  );

  testWidgets('öğrenci denemesinde yanlışlar kazanımlarıyla görünür', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(await _app(const Scaffold()));
    await t.pumpAndSettle();
    final c = _container(t);
    final repo = c.read(opticRepositoryProvider);
    final key = (await repo.fetchKeys()).single;
    final sheet = (await repo.fetchSheets(
      key.id,
    )).firstWhere((s) => s.studentId == 'demo-student');
    final answers = await repo.fetchExamAnswers(sheet.examId);
    final mistakes = answers.where((a) => !a.isCorrect && !a.isCancelled);
    expect(mistakes, isNotEmpty);

    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    // Bekletilmez: sayfa kapanınca tamamlanır.
    // ignore: unawaited_futures
    nav.push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(body: ExamAnswersView(examId: sheet.examId)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Yanlışların ve boşların'), findsOneWidget);
    final first = mistakes.first;
    expect(find.textContaining('${first.number}. soru'), findsWidgets);
    if (first.outcome != null) {
      expect(find.text(first.outcome!), findsWidgets);
    }
    // Demo anahtarında her sorunun kazanımı var: konu özeti görünür.
    final top = mistakesByOutcome(answers);
    expect(top, isNotEmpty);
    expect(find.text('En çok kaçırılan konular'), findsOneWidget);
    expect(find.textContaining(top.first.outcome), findsWidgets);
  });
}
