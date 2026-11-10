// Koç paneli, müdür kokpitiyle aynı dilde (NOTLAR §60). Envanter:
// docs/admin_panel_envanter.md "Koç paneli" — her eski özelliğin yerinde
// durduğu burada doğrulanır.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_cockpit.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/admin/data/cockpit_repository.dart';
import 'package:mentoria/features/admin/presentation/cockpit/activity_trend_card.dart';
import 'package:mentoria/features/admin/presentation/cockpit/cockpit_theme.dart';
import 'package:mentoria/features/admin/presentation/cockpit/metric_card.dart';
import 'package:mentoria/features/coach/presentation/coach_home_screen.dart';
import 'package:mentoria/features/coach/presentation/invite_sheet.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/shared/widgets/bizz.dart';
import 'package:mentoria/shared/widgets/tool_strip.dart';
import 'package:mentoria/shared/widgets/panel.dart';
import 'package:mentoria/shared/widgets/tool_tile.dart';

final _visited = <String>[];

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  List<Override> o, {
  Size size = const Size(1080, 6000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  _visited.clear();
  Widget page(GoRouterState s) {
    _visited.add(s.uri.toString());
    return Scaffold(body: Text('sayfa ${s.uri}'));
  }

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(path: '/:a', builder: (_, s) => page(s)),
      GoRoute(path: '/:a/:b', builder: (_, s) => page(s)),
      GoRoute(path: '/:a/:b/:c', builder: (_, s) => page(s)),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: o,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<List<Override>> _coach({CockpitRepository? cockpit}) =>
    buildDemoOverrides(
      'coach',
      true,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      cockpit,
    );

Future<void> _show(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('coach-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(f.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  GoRouter.of(tester.element(find.textContaining('sayfa /'))).pop();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  setUp(() => Motion.enabled = false);
  tearDown(() => Motion.enabled = true);

  testWidgets('tek açık tema; maskot, selamlama ve bal peteği yok', (
    tester,
  ) async {
    await _pump(tester, const CoachHomeScreen(), await _coach());
    final ctx = tester.element(
      find.byKey(const ValueKey('coach-metric-students')),
    );
    expect(Theme.of(ctx).brightness, Brightness.light);
    expect(
      Theme.of(ctx).scaffoldBackgroundColor,
      CockpitColors.light.background,
    );
    expect(find.byType(Bizz), findsNothing);
    expect(find.textContaining('Günaydın'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('Profil'), findsOneWidget);
    // Kurum adı üst çubukta.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('cockpit-org-name'))).data,
      'Bal Akademi',
    );
  });

  testWidgets('özet şeridi: öğrencilerim, aktif, soru, bekleyen görev', (
    tester,
  ) async {
    await _pump(tester, const CoachHomeScreen(), await _coach());
    Finder inCard(String key, Finder f) =>
        find.descendant(of: find.byKey(ValueKey(key)), matching: f);
    // Öğrenci sayısı ile "aktif" kartının paydası aynı.
    final total = tester
        .widget<MetricCard>(find.byKey(const ValueKey('coach-metric-students')))
        .value;
    expect(int.parse(total), greaterThan(0));
    expect(
      inCard('coach-metric-active', find.text('/ $total')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('coach-metric-questions')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('coach-metric-pending')), findsOneWidget);
    // Değişim oku eğilim verisinden (demo: geçen hafta 3, bu hafta 2 aktif).
    expect(inCard('coach-metric-active', find.text('−1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coach-metric-active')));
    await tester.pumpAndSettle();
    expect(_visited.last, '/coach/activity');
    await _back(tester);
    await tester.tap(find.byKey(const ValueKey('coach-metric-pending')));
    await tester.pumpAndSettle();
    expect(_visited.last, '/coach/homework');
  });

  testWidgets('alt çubuk sekmeleri: öğrenciler, sınavlar, iletişim', (
    tester,
  ) async {
    await _pump(tester, const CoachHomeScreen(), await _coach());
    final nav = find.byType(NavigationBar);
    Future<void> tab(String label) async {
      await tester.tap(find.descendant(of: nav, matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    // Öğrenciler: davet (yüzen düğme), ödev (şerit), öğrenci listesi.
    await tab('Öğrenciler');
    await tester.tap(find.text('Davet et'));
    await tester.pumpAndSettle();
    expect(find.byType(InviteSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(InviteSheet))).pop();
    await tester.pumpAndSettle();
    // Şerit yana kayar; ödev en sonda.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('strip-tool-homework')),
      find.byType(ToolStrip),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('strip-tool-homework')));
    await tester.pumpAndSettle();
    expect(_visited.last, '/coach/homework');
    await _back(tester);

    // Sınavlar: bütün yüklemeler kurum sınavından.
    await tab('Sınavlar');
    expect(find.byKey(const ValueKey('tool-import')), findsNothing);
    for (final (id, route) in [('org-exams-card', '/coach/org-exams')]) {
      await tester.tap(find.byKey(ValueKey(id)));
      await tester.pumpAndSettle();
      expect(_visited.last, route, reason: id);
      await _back(tester);
    }

    // İletişim: duyurular ve öğrenci daveti.
    await tab('İletişim');
    await tester.tap(find.byKey(const ValueKey('tool-announcements')));
    await tester.pumpAndSettle();
    expect(_visited.last, '/coach/announcements');
  });

  testWidgets('eski kartların hepsi yerinde: risk, görüşme, kısayollar', (
    tester,
  ) async {
    await _pump(tester, const CoachHomeScreen(), await _coach());
    await _show(tester, find.text('Bu hafta konuşulacaklar'));
    await _show(tester, find.text('Bu haftaki görüşmeler'));
    await _show(tester, find.text('Son 8 hafta'));
    for (final (title, route) in [
      ('Yoklama', '/coach/attendance'),
      ('Sınıflar ve öğrenciler', '/coach/roster'),
      ('Kurum sınavları', '/coach/org-exams'),
      ('Deneme trendleri', '/coach/trends'),
      ('Kitap havuzu', '/coach/books'),
    ]) {
      final f = find.descendant(
        of: find.byType(ToolGrid),
        matching: find.text(title),
      );
      await _show(tester, f);
      await tester.tap(f);
      await tester.pumpAndSettle();
      expect(_visited.last, route, reason: title);
      await _back(tester);
    }
    await _show(tester, find.text('Duyurular'));
    expect(find.text('Yeni duyuru'), findsOneWidget);
  });

  testWidgets('öğrenci listesi nötr; karta dokununca detay', (tester) async {
    await _pump(tester, const CoachHomeScreen(), await _coach());
    await _show(tester, find.text('Öğrencilerin'));
    await _show(tester, find.text('Can Kaya').last);
    final avatars = tester.widgetList<InitialsAvatar>(
      find.byType(InitialsAvatar),
    );
    expect(avatars, isNotEmpty);
    expect(avatars.every((a) => a.plain), isTrue);
    await tester.tap(find.text('Elif Yılmaz').last);
    await tester.pumpAndSettle();
    expect(_visited.last, '/coach/students/demo-student');
  });

  testWidgets('liste sonunda alt çubuk + 16 boşluk', (tester) async {
    await _pump(tester, const CoachHomeScreen(), await _coach());
    final pad = tester.widget<SliverPadding>(
      find
          .descendant(
            of: find.byKey(const ValueKey('coach-scroll')),
            matching: find.byType(SliverPadding),
          )
          .first,
    );
    expect(
      (pad.padding as EdgeInsets).bottom,
      greaterThanOrEqualTo(cockpitNavHeight + 16),
    );
  });

  group('8 haftalık eğilim', () {
    testWidgets('aktif öğrenci ve soru arasında geçer; değerler yazılı', (
      tester,
    ) async {
      await _pump(tester, const CoachHomeScreen(), await _coach());
      await _show(tester, find.byKey(const ValueKey('section-trend')));
      expect(find.text('Haftalık aktif öğrenci'), findsOneWidget);
      expect(find.text('Bu hafta'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('trend-questions')));
      await tester.pumpAndSettle();
      expect(find.text('Haftalık çözülen soru'), findsOneWidget);
      expect(find.textContaining('1,2'), findsOneWidget);
    });

    testWidgets('öğrenci yoksa boş hal ve davet düğmesi', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: CockpitThemed(
            child: SingleChildScrollView(
              child: ActivityTrendCard(onInviteStudent: _noop),
            ),
          ),
        ),
        await _coach(cockpit: InMemoryCockpitRepository(weeks: const [])),
      );
      expect(
        find.text('Öğrenci kaydı olunca haftalık eğilim burada görünür.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Öğrenci davet et'),
        findsOneWidget,
      );
    });

    test('yanıt çözülür', () {
      final w = ActivityWeek.fromJson({
        'start': '2026-10-31',
        'end': '2026-11-06',
        'students': 410,
        'active': 312,
        'questions': 51000,
      });
      expect((w.students, w.active, w.questions), (410, 312, 51000));
      expect(w.end, DateTime(2026, 11, 6));
    });
  });
}

void _noop() {}
