// Tanıtım videoları için uygulama ekran görüntüleri (gerçek widget'lar, demo
// verisi, gerçek Nunito yazı tipi). Normal `flutter test` bunu çalıştırmaz:
//
//   flutter test tool/promo/promo_shots_test.dart
//
// Yazı tipleri build/promo/fonts/nunito_<ağırlık>.ttf (fonts.gstatic.com,
// google_fonts paketinin kullandığı dosyalar). Çıktı: build/promo/shots/*.png
// (1170×2532, üstte 47 pt durum çubuğu boşluğu).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/branding/branding.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/core/theme/brand_theme.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/admin/presentation/admin_home_screen.dart';
import 'package:mentoria/features/avatar/data/avatar_repository.dart';
import 'package:mentoria/features/avatar/presentation/avatar_editor_screen.dart';
import 'package:mentoria/features/coach/presentation/coach_home_screen.dart';
import 'package:mentoria/features/coach/presentation/student_detail_screen.dart';
import 'package:mentoria/features/duel/data/duel_repository.dart';
import 'package:mentoria/features/duel/presentation/duel_screens.dart';
import 'package:mentoria/features/exams/data/exam.dart';
import 'package:mentoria/features/exams/presentation/score_calculator_screen.dart';
import 'package:mentoria/features/garden/presentation/garden_screen.dart';
import 'package:mentoria/features/learn/data/daily_question_repository.dart';
import 'package:mentoria/features/learn/data/practice_repository.dart';
import 'package:mentoria/features/learn/presentation/daily_question_screen.dart';
import 'package:mentoria/features/learn/presentation/learn_screen.dart';
import 'package:mentoria/features/mistakes/presentation/mistakes_screen.dart';
import 'package:mentoria/features/parent/presentation/parent_child_screen.dart';
import 'package:mentoria/features/parent/presentation/parent_home_screen.dart';
import 'package:mentoria/features/plan/presentation/plan_widgets.dart';
import 'package:mentoria/features/recap/data/week_recap.dart';
import 'package:mentoria/features/recap/presentation/recap_card.dart';
import 'package:mentoria/features/student/presentation/student_home_screen.dart';
import 'package:mentoria/features/tenants/presentation/tenant_editor_screen.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';
import 'package:mentoria/core/theme/app_fonts.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/shared/widgets/bizz.dart';
import 'package:mentoria/shared/widgets/brand_logo.dart';

const _out = 'build/promo/shots';
bool _fontsLoaded = false;

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) throw StateError('Yazı tipi yok: $f');
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _fonts(WidgetTester tester) async {
  if (_fontsLoaded) return;
  await tester.runAsync(() async {
    // Flutter SDK kökü: FLUTTER_ROOT ya da çalışan dart'ın yolundan.
    var dir = File(Platform.resolvedExecutable).parent;
    String? icons = Platform.environment['FLUTTER_ROOT'] == null
        ? null
        : '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
    for (var i = 0; i < 8 && (icons == null || !File(icons).existsSync()); i++) {
      icons = '${dir.path}/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
      dir = dir.parent;
    }
    await _loadFont('MaterialIcons', [icons!]);
    // Renkli emoji test ortamında çizilmiyor; tek renkli sembol yazı tipi.
    const emoji = r'C:\Windows\Fonts\seguisym.ttf';
    await _loadFont('Roboto', [r'C:\Windows\Fonts\segoeui.ttf', emoji]);
    // Yazı tipi belirtilmeyen metinler test yazı tipine düşer.
    await _loadFont('SymbolsFallback', [emoji]);
    // google_fonts'un aile adları (Nunito_regular, Poppins_700 …); kurumların
    // seçebildiği 10 yazı tipinin hepsi (build/promo/fonts/all).
    for (final name in File('build/promo/fonts/all/manifest.txt').readAsLinesSync()) {
      if (name.trim().isEmpty) continue;
      await _loadFont(name, ['build/promo/fonts/all/$name.ttf', emoji]);
    }
  });
  await initializeDateFormatting('tr_TR');
  _fontsLoaded = true;
}

List<PracticeQuestion> _pool(String subject) => [
  for (final j
      in jsonDecode(
            File('assets/learn/questions/$subject.json').readAsStringSync(),
          )
          as List)
    PracticeQuestion.fromJson(j as Map<String, dynamic>),
];

/// Uygulamanın teması; emoji için sembol yazı tipi yedek olarak eklenir.
ThemeData _theme([Branding brand = Branding.mentoria]) {
  final t = AppTheme.light(BrandTheme.fromBranding(brand));
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFamilyFallback: const ['SymbolsFallback']);
  final tt = t.textTheme;
  return t.copyWith(
    textTheme: tt.copyWith(
      displayLarge: f(tt.displayLarge), displayMedium: f(tt.displayMedium), displaySmall: f(tt.displaySmall),
      headlineLarge: f(tt.headlineLarge), headlineMedium: f(tt.headlineMedium), headlineSmall: f(tt.headlineSmall),
      titleLarge: f(tt.titleLarge), titleMedium: f(tt.titleMedium), titleSmall: f(tt.titleSmall),
      bodyLarge: f(tt.bodyLarge), bodyMedium: f(tt.bodyMedium), bodySmall: f(tt.bodySmall),
      labelLarge: f(tt.labelLarge), labelMedium: f(tt.labelMedium), labelSmall: f(tt.labelSmall),
    ),
  );
}

/// Ekranı açar, [interact] ile hazırlar ve PNG olarak kaydeder.
Future<void> shoot(
  WidgetTester tester,
  String name,
  String role,
  Widget home, {
  Future<void> Function(ProviderContainer c)? interact,
  Future<void> Function(ProviderContainer c)? prepare,
  Branding brand = Branding.mentoria,
}) async {
  await _fonts(tester);
  Motion.enabled = false;
  addTearDown(() => Motion.enabled = true);
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);

  final c = ProviderContainer(
    overrides: [
      ...await buildDemoOverrides(role),
      for (final s in practiceSubjects)
        questionPoolProvider(s).overrideWith((ref) async => _pool(s)),
    ],
  );
  addTearDown(c.dispose);
  // Demo'nun "yeni avatar parçası" bildirimi çekimleri kapatmasın.
  final avatars = c.read(avatarRepositoryProvider);
  if (avatars is InMemoryAvatarRepository) avatars.pendingUnlocks = const [];
  final duels = c.read(duelRepositoryProvider);
  if (duels is InMemoryDuelRepository) duels.loadPool = (s) async => _pool(s);
  if (prepare != null) await tester.runAsync(() => prepare(c));

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b/:c', builder: (_, _) => const Scaffold()),
    ],
  );
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: _theme(brand),
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    ),
  );
  await settle(tester);
  if (interact != null) await interact(c);
  await settle(tester);
  final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = (await tester.runAsync(() => b.toImage(pixelRatio: 3)))!;
  final png = (await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.png),
  ))!;
  File('$_out/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png.buffer.asUint8List());
}

/// Gerçek G/Ç (asset okuma) bitene kadar bekler.
Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder f, {double extra = 0}) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  if (extra != 0) {
    await tester.drag(find.byType(Scrollable).first, Offset(0, -extra));
  }
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settle(tester, 3);
}

void main() {
  spriteTests();
  // ------------------------------------------------------------ Öğrenci
  testWidgets('s01_home', (t) => shoot(t, 's01_home', 'student', const StudentHomeScreen()));

  testWidgets('s02_home_cards', (t) => shoot(t, 's02_home_cards', 'student', const StudentHomeScreen(),
      interact: (_) => scrollTo(t, find.text('Günün Sorusu'), extra: 120)));

  testWidgets('s03_learn', (t) => shoot(t, 's03_learn', 'student', const LearnScreen()));

  testWidgets('s04_learn_ayt', (t) => shoot(t, 's04_learn_ayt', 'student', const LearnScreen(),
      interact: (_) => tapText(t, 'AYT')));

  testWidgets('s05_quiz', (t) => shoot(t, 's05_quiz', 'student', const LearnScreen(),
      prepare: (c) async =>
          (c.read(practiceRepositoryProvider) as InMemoryPracticeRepository).answers.clear(),
      interact: (_) async {
        await tapText(t, 'Fizik');
        await tapText(t, 'Soru çöz');
        final q = SubjectPractice.of(
          subject: 'TYT_FIZ',
          studentId: 'demo-student',
          pool: _pool('TYT_FIZ'),
          answers: const [],
          now: DateTime.now(),
        ).todaysQuestions.first;
        await tapText(t, q.options[q.answer]);
      }));

  testWidgets('s06_daily', (t) => shoot(t, 's06_daily', 'student', const DailyQuestionScreen(),
      interact: (c) async {
        final s = (await t.runAsync(() => c.read(dailyQuestionRepositoryProvider).fetchToday()))!;
        final q = _pool(s.subject).firstWhere((q) => q.id == s.questionId);
        await tapText(t, q.options[q.answer]);
      }));

  testWidgets('s07_duels', (t) => shoot(t, 's07_duels', 'student', const DuelsScreen()));

  testWidgets('s08_duel_intro', (t) => shoot(t, 's08_duel_intro', 'student', const DuelsScreen(),
      interact: (_) => tapText(t, 'Kabul et')));

  testWidgets('s09_duel_play', (t) => shoot(t, 's09_duel_play', 'student', const DuelsScreen(),
      interact: (_) async {
        await tapText(t, 'Kabul et');
        await scrollTo(t, find.text('Başla'));
        await tapText(t, 'Başla');
        final byId = {for (final q in _pool('TYT_MAT')) q.id: q};
        for (var i = 11; i <= 13; i++) {
          final q = byId['TYT_MAT-${'$i'.padLeft(4, '0')}']!;
          await t.tap(find.text(q.options[q.answer]).first);
          await t.pump(const Duration(seconds: 9));
        }
      }));

  testWidgets('s10_duel_result', (t) => shoot(t, 's10_duel_result', 'student', const DuelsScreen(),
      interact: (_) async {
        await tapText(t, 'Kabul et');
        await scrollTo(t, find.text('Başla'));
        await tapText(t, 'Başla');
        final byId = {for (final q in _pool('TYT_MAT')) q.id: q};
        for (var i = 11; i <= 20; i++) {
          final q = byId['TYT_MAT-${'$i'.padLeft(4, '0')}']!;
          await t.tap(find.text(q.options[i == 15 ? (q.answer + 1) % 5 : q.answer]).first);
          await settle(t, 1);
        }
        await settle(t, 10);
      }));

  testWidgets('s11_score', (t) => shoot(t, 's11_score', 'student', const ScoreCalculatorScreen(),
      interact: (_) async {
        await tapText(t, 'SAY');
        final f = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'SAY hedef puanı',
        );
        await t.enterText(f, '360');
        await settle(t, 2);
        await t.drag(find.byType(Scrollable).first, const Offset(0, -330));
      }));

  testWidgets('s12_mistakes', (t) => shoot(t, 's12_mistakes', 'student', const MistakesScreen()));

  testWidgets('s13_garden', (t) => shoot(t, 's13_garden', 'student', const GardenScreen()));

  testWidgets('s14_plan', (t) => shoot(t, 's14_plan', 'student', const StudentPlanScreen()));

  testWidgets('s15_avatar', (t) => shoot(t, 's15_avatar', 'student', const AvatarEditorScreen()));

  testWidgets('s16_recap', (t) {
    final now = DateTime.now();
    QuestionLog log(int d, String code, int c, int w) => QuestionLog(
      id: '$d$code',
      subjectCode: code,
      correct: c,
      wrong: w,
      blank: 0,
      loggedOn: DateTime(now.year, now.month, now.day - d),
    );
    StudySession s(int d, int hour, int min) => StudySession(
      id: '$d$hour',
      type: SessionType.pomodoro,
      startedAt: DateTime(now.year, now.month, now.day - d, hour),
      durationSec: min * 60,
    );
    final recap = WeekRecap.compute(
      logs: [
        log(0, 'TYT_MAT', 60, 12), log(1, 'TYT_TUR', 45, 5), log(2, 'TYT_MAT', 110, 18),
        log(3, 'TYT_FIZ', 30, 10), log(4, 'TYT_MAT', 70, 9), log(5, 'TYT_TUR', 40, 8),
        log(6, 'TYT_KIM', 35, 6),
      ],
      sessions: [s(0, 22, 50), s(1, 23, 45), s(2, 21, 60), s(3, 22, 40), s(5, 16, 50), s(6, 19, 55)],
      exams: [
        Exam(
          id: 'e',
          examType: ExamType.tyt,
          name: 'TYT Deneme 7',
          takenOn: DateTime(now.year, now.month, now.day - 1),
          results: const [
            SubjectResult(code: 'TYT_MAT', correct: 33, wrong: 4, blank: 3),
            SubjectResult(code: 'TYT_TUR', correct: 34, wrong: 6, blank: 0),
          ],
        ),
      ],
      now: now,
    );
    return shoot(t, 's16_recap', 'student', Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [RecapCard(recap: recap, firstName: 'Elif')]),
        ),
      ),
    ), interact: (_) async {
      await tapText(t, 'Haftanın Bal Raporu');
    });
  });

  // ------------------------------------------------------------ Beyaz etiket
  final yildiz = demoTenants()[1];
  const zirve = Branding(
    name: 'Zirve Akademi',
    primary: Color(0xFF34D399),
    secondary: Color(0xFFF97316),
    font: AppFont.baloo2,
  );
  for (final (tag, brand) in [('mentoria', Branding.mentoria), ('yildiz', yildiz), ('zirve', zirve)]) {
    testWidgets('w_home_$tag', (t) => shoot(t, 'w_home_$tag', 'student', const StudentHomeScreen(), brand: brand,
        interact: (_) => scrollTo(t, find.text('Günün Sorusu'), extra: 60)));
    testWidgets('w_learn_$tag', (t) => shoot(t, 'w_learn_$tag', 'student', const LearnScreen(), brand: brand));
  }
  testWidgets('w_editor', (t) => shoot(t, 'w_editor', 'admin', const TenantEditorScreen(selfService: true)));
  testWidgets('w_editor_fonts', (t) => shoot(t, 'w_editor_fonts', 'admin', const TenantEditorScreen(selfService: true),
      interact: (_) => scrollTo(t, find.text('Baloo 2'), extra: 120)));

  // ------------------------------------------------------------ Veli
  testWidgets('p01_parent_home', (t) => shoot(t, 'p01_parent_home', 'parent', const ParentHomeScreen()));

  testWidgets('p02_parent_child', (t) => shoot(t, 'p02_parent_child', 'parent',
      const ParentChildScreen(childId: 'demo-student')));

  testWidgets('p03_parent_plan', (t) => shoot(t, 'p03_parent_plan', 'parent',
      const ParentChildScreen(childId: 'demo-student', initialTab: 6)));

  // ------------------------------------------------------------ Koç
  testWidgets('c01_coach_home', (t) => shoot(t, 'c01_coach_home', 'coach', const CoachHomeScreen()));

  testWidgets('c02_coach_trends', (t) => shoot(t, 'c02_coach_trends', 'coach', const CoachHomeScreen(),
      interact: (_) => scrollTo(t, find.text('En çok düşen'), extra: 60)));

  testWidgets('c03_detail', (t) => shoot(t, 'c03_detail', 'coach',
      const StudentDetailScreen(studentId: 'demo-student', basePath: '/coach')));

  for (final (name, tab) in [
    ('c04_detail_exams', 'Denemeler'),
    ('c05_detail_learn', 'Eğitim'),
    ('c06_detail_plan', 'Plan'),
    ('c07_detail_mistakes', 'Hata Defteri'),
  ]) {
    testWidgets(name, (t) => shoot(t, name, 'coach',
        const StudentDetailScreen(studentId: 'demo-student', basePath: '/coach'),
        interact: (_) async {
          final tabFinder = find.widgetWithText(Tab, tab);
          await t.ensureVisible(tabFinder);
          await t.pumpAndSettle();
          await t.tap(tabFinder);
          await settle(t, 4);
        }));
  }

  // ------------------------------------------------------------ Müdür
  testWidgets('a01_admin_home', (t) => shoot(t, 'a01_admin_home', 'admin', const AdminHomeScreen()));

  testWidgets('a02_admin_more', (t) => shoot(t, 'a02_admin_more', 'admin', const AdminHomeScreen(),
      interact: (_) => scrollTo(t, find.text('En çok yükselen'), extra: 40)));

  testWidgets('a03_admin_inactive', (t) => shoot(t, 'a03_admin_inactive', 'admin', const AdminHomeScreen(),
      interact: (_) => scrollTo(t, find.text('Bu hafta hareketsiz öğrenciler'), extra: 0)));
}

/// Şeffaf zeminde tek bir widget'ı (maskot, logo) PNG'ye çizer.
Future<void> sprite(WidgetTester tester, String name, Size size, Widget child) async {
  await _fonts(tester);
  Motion.enabled = false;
  addTearDown(() => Motion.enabled = true);
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final c = ProviderContainer(overrides: await buildDemoOverrides('student'));
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme().copyWith(scaffoldBackgroundColor: Colors.transparent),
        home: Material(
          type: MaterialType.transparency,
          child: Center(child: RepaintBoundary(key: key, child: child)),
        ),
      ),
    ),
  );
  await settle(tester, 3);
  final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = (await tester.runAsync(() => b.toImage(pixelRatio: 3)))!;
  final png = (await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.png),
  ))!;
  File('$_out/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png.buffer.asUint8List());
}

void spriteTests() {
  for (final mood in [BizzMood.idle, BizzMood.happy]) {
    testWidgets('bizz_${mood.name}', (t) => sprite(t, 'bizz_${mood.name}', const Size(320, 320),
        Bizz(size: 300, mood: mood, interactive: false)));
  }
  testWidgets('logo', (t) => sprite(t, 'logo', const Size(420, 120), const BrandLogo(fontSize: 56)));
}
