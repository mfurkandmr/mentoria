// Müdür kokpiti (NOTLAR §59). Envanter: docs/admin_panel_envanter.md —
// eski paneldeki her özelliğin yeni yerinde durduğu burada doğrulanır.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/core/router/app_router.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/dev/demo_cockpit.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/admin/data/admin_repository.dart';
import 'package:mentoria/features/admin/data/cockpit_repository.dart';
import 'package:mentoria/features/admin/presentation/admin_home_screen.dart';
import 'package:mentoria/features/admin/presentation/cockpit/cockpit_motion.dart';
import 'package:mentoria/features/admin/presentation/cockpit/cockpit_pages.dart';
import 'package:mentoria/features/admin/presentation/cockpit/cockpit_theme.dart';
import 'package:mentoria/features/admin/presentation/cockpit/exam_plans_screen.dart';
import 'package:mentoria/features/admin/presentation/cockpit/metric_card.dart';
import 'package:mentoria/features/admin/presentation/cockpit/org_settings_card.dart';
import 'package:mentoria/features/admin/presentation/cockpit/section_states.dart';
import 'package:mentoria/features/credits/data/org_credits_repository.dart';
import 'package:mentoria/features/notifications/data/notification_repository.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/shared/widgets/bizz.dart';
import 'package:mentoria/shared/widgets/common.dart';
import 'package:mentoria/shared/widgets/corporate_look.dart';
import 'package:mentoria/shared/widgets/effects.dart';
import 'package:mentoria/shared/widgets/tool_strip.dart';

/// Testin gezindiği adresler (alt sayfalar boş Scaffold).
final _visited = <String>[];

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  List<Override> o, {
  Size size = const Size(1080, 6000),
  bool dark = false,
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
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<List<Override>> _overrides({
  CockpitRepository? cockpit,
  OrgCreditsRepository? credits,
}) => buildDemoOverrides(
  'admin',
  true,
  null,
  credits ?? InMemoryOrgCreditsRepository(balance: 120, isAdmin: true),
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

CockpitData _empty({int students = 3, List<CoachStat> coaches = const []}) =>
    CockpitData(
      students: students,
      studentsPrev: students,
      active: 0,
      activePrev: 0,
      questions: 0,
      questionsPrev: 0,
      minutes: 0,
      minutesPrev: 0,
      coaches: coaches,
    );

/// Kaydırılabilir listede görünür olana kadar kaydırır.
Future<void> _show(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('cockpit-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  // Üstteki sabit çubuğun altında kalmasın.
  await Scrollable.ensureVisible(tester.element(f.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

/// Açılan alt sayfadan geri döner.
Future<void> _back(WidgetTester tester) async {
  GoRouter.of(tester.element(find.textContaining('sayfa /'))).pop();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  setUp(() => Motion.enabled = false);
  tearDown(() => Motion.enabled = true);

  group('üst çubuk ve özet şeridi', () {
    testWidgets('kurum adı, tarih; maskot ve selamlama yok', (tester) async {
      await _pump(tester, const AdminHomeScreen(), await _overrides());
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('cockpit-org-name')))
            .data,
        'Bal Akademi',
      );
      expect(find.textContaining(DateTime.now().year.toString()), findsWidgets);
      expect(find.byType(Bizz), findsNothing);
      expect(find.textContaining('Günaydın'), findsNothing);
      // Eski kısayollar üst çubukta.
      expect(find.byTooltip('Sınav yükle'), findsOneWidget);
      expect(find.byTooltip('Profil'), findsOneWidget);
      await tester.tap(find.byTooltip('Sınav yükle'));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/org-exams');
    });

    testWidgets('dört kart: değerler ve geçen haftaya göre değişim', (
      tester,
    ) async {
      await _pump(tester, const AdminHomeScreen(), await _overrides());
      Finder inCard(String key, Finder f) =>
          find.descendant(of: find.byKey(ValueKey(key)), matching: f);
      expect(inCard('metric-students', find.text('3')), findsOneWidget);
      expect(inCard('metric-active', find.text('2')), findsOneWidget);
      expect(inCard('metric-active', find.text('/ 3')), findsOneWidget);
      // Katılım halkası: %67.
      expect(inCard('metric-active', find.text('%67')), findsOneWidget);
      expect(inCard('metric-active', find.text('katılım')), findsOneWidget);
      // 3 → 2 aktif: aşağı ok, −1.
      expect(inCard('metric-active', find.text('−1')), findsOneWidget);
      expect(inCard('metric-questions', find.text('1.240')), findsOneWidget);
      // 1105 → 1240: %12 artış.
      expect(inCard('metric-questions', find.text('+%12')), findsOneWidget);
      expect(
        inCard('metric-questions', find.text('25 sa 30 dk çalışma')),
        findsOneWidget,
      );
      expect(inCard('metric-exam', find.text('3')), findsOneWidget);
      expect(inCard('metric-exam', find.text('gün sonra')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Geçen haftaya göre 1 azaldı',
        ),
        findsOneWidget,
      );
    });

    testWidgets('kartlar ilgili listeye gider', (tester) async {
      await _pump(tester, const AdminHomeScreen(), await _overrides());
      await tester.tap(find.byKey(const ValueKey('metric-active')));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/activity');
      await _back(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('metric-questions')));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/activity?sort=questions');
      await _back(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('metric-exam')));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/exam-plans');
      await _back(tester);
      await tester.pumpAndSettle();
      // Kayıtlı öğrenci: Öğrenciler sekmesine geçer.
      await tester.tap(find.byKey(const ValueKey('metric-students')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Öğrenciler'), findsOneWidget);
    });

    testWidgets('yükleniyor: iskelet kartlar', (tester) async {
      final pending = Completer<CockpitData>();
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(cockpit: _PendingCockpit(pending.future)),
      );
      expect(find.byType(MetricSkeleton), findsNWidgets(4));
      expect(find.byType(SectionSkeleton), findsWidgets);
      pending.complete(demoCockpitData());
      await tester.pumpAndSettle();
      expect(find.byType(MetricSkeleton), findsNothing);
    });

    testWidgets('hata: bölüm içinde "Tekrar dene"', (tester) async {
      final repo = InMemoryCockpitRepository(error: Exception('ağ'));
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(cockpit: repo),
      );
      expect(find.byType(SectionError), findsWidgets);
      repo.error = null;
      // Özet, dikkat ve koç bölümleri aynı veriden: biri yeterli.
      await tester.tap(find.text('Tekrar dene').first);
      await tester.pumpAndSettle();
      // Eğilim grafiği kendi verisini ayrı yükler.
      final trendRetry = find.descendant(
        of: find.byKey(const ValueKey('section-trend')),
        matching: find.text('Tekrar dene'),
      );
      await tester.ensureVisible(trendRetry);
      await tester.pumpAndSettle();
      await tester.tap(trendRetry);
      await tester.pumpAndSettle();
      expect(find.byType(SectionError), findsNothing);
      expect(find.byKey(const ValueKey('section-trend')), findsOneWidget);
      expect(find.text('Son 8 hafta'), findsOneWidget);
    });
  });

  group('dikkat gerektirenler', () {
    testWidgets('üç grup, sebep ve koç; koça bildirim ve arama', (
      tester,
    ) async {
      final repo = InMemoryCockpitRepository();
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(cockpit: repo),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kind-inactive')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(find.text('9 gündür giriş yapmadı'), findsOneWidget);
      expect(find.text('Koçu: Ayşe Koç'), findsWidgets);
      // Ayşe Koç telefonu kayıtlı: ara düğmesi var.
      expect(
        find.byKey(const ValueKey('call-InactiveStudent-demo-can')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('notify-InactiveStudent-demo-can')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ayşe Koç bilgilendirilsin'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('notify-send')));
      await tester.pumpAndSettle();
      expect(repo.notified, [('demo-can', '9 gündür giriş yapmadı')]);
      expect(find.text('Ayşe Koç bilgilendirildi.'), findsOneWidget);

      // Aynı öğrenci için hemen ikinci bildirim gitmez.
      await tester.tap(
        find.byKey(const ValueKey('notify-InactiveStudent-demo-can')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notify-send')));
      await tester.pumpAndSettle();
      expect(repo.notified, hasLength(1));
      expect(
        find.text(
          'Bu öğrenci için koça son 6 saat içinde zaten bildirim gönderildi.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('kind-netDrop')));
      await tester.pumpAndSettle();
      expect(find.text('Zeynep Arslan'), findsOneWidget);
      expect(find.text('TYT neti 68 → 61,5 (−6,5)'), findsOneWidget);
      // Burak Yıldız telefonu yok: ara düğmesi yok.
      expect(
        find.byKey(const ValueKey('call-NetDropStudent-demo-zeynep')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('org-tyt-average')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kind-overdue')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 taksit gecikti'), findsOneWidget);
      expect(find.textContaining('12 gündür'), findsOneWidget);

      // Satıra dokununca öğrenci detayı.
      await tester.tap(find.text('Can Kaya'));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/students/demo-can');
    });

    testWidgets('kimse yoksa tek sade satır', (tester) async {
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(cockpit: InMemoryCockpitRepository(data: _empty())),
      );
      expect(find.text('Şu an dikkat gerektiren öğrenci yok.'), findsOneWidget);
      expect(find.byKey(const ValueKey('attention-kinds')), findsNothing);
    });

    testWidgets('öğrenci yoksa "Öğrenci davet et"', (tester) async {
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(
          cockpit: InMemoryCockpitRepository(data: _empty(students: 0)),
        ),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Öğrenci davet et'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AlertDialog, 'Öğrenci davet et'),
        findsOneWidget,
      );
    });

    testWidgets('risk listesi bağlantısı', (tester) async {
      await _pump(tester, const AdminHomeScreen(), await _overrides());
      await tester.tap(find.text('Risk listesi'));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/risk');
    });
  });

  group('koç performansı', () {
    testWidgets('öğrenci, görüşme, aktiflik; ayrıntı sayfası', (tester) async {
      await _pump(tester, const AdminHomeScreen(), await _overrides());
      await _show(tester, find.text('Haftalık ayrıntı'));
      Finder inRow(String id, String t) => find.descendant(
        of: find.byKey(ValueKey('coach-$id')),
        matching: find.text(t),
      );
      expect(inRow('demo-coach', '2'), findsOneWidget);
      expect(inRow('demo-coach', '3 / 4'), findsOneWidget);
      expect(inRow('demo-coach', '1 / 2'), findsOneWidget);
      expect(inRow('demo-coach-2', '0 / 2'), findsOneWidget);
      expect(inRow('demo-coach-2', '1 / 1'), findsOneWidget);
      await tester.tap(find.text('Haftalık ayrıntı'));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/meetings');
    });

    testWidgets('telefon ekle: kokpitte arama düğmesi çıkar', (tester) async {
      final repo = InMemoryCockpitRepository();
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(cockpit: repo),
      );
      await _show(tester, find.byKey(const ValueKey('coach-demo-coach-2')));
      await tester.tap(find.byKey(const ValueKey('coach-menu-demo-coach-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Telefon ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('coach-phone-field')),
        '123',
      );
      await tester.tap(find.byKey(const ValueKey('coach-phone-save')));
      await tester.pumpAndSettle();
      expect(find.text('Geçerli bir cep telefonu yaz.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('coach-phone-field')),
        '0533 444 55 66',
      );
      await tester.tap(find.byKey(const ValueKey('coach-phone-save')));
      await tester.pumpAndSettle();
      final d = await repo.fetch();
      expect(
        d.coaches.firstWhere((c) => c.coachId == 'demo-coach-2').phone,
        '+905334445566',
      );
    });

    testWidgets('koç yoksa "Koç davet et"', (tester) async {
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(cockpit: InMemoryCockpitRepository(data: _empty())),
      );
      await _show(tester, find.widgetWithText(OutlinedButton, 'Koç davet et'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Koç davet et'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AlertDialog, 'Koç davet et'), findsOneWidget);
    });
  });

  group('kurum araçları (eski kartların hepsi)', () {
    testWidgets('her modül kartı yerinde ve açılıyor', (tester) async {
      await _pump(tester, const AdminHomeScreen(), await _overrides());
      for (final (title, route) in [
        ('Yoklama', '/admin/attendance'),
        ('Ders programı', '/admin/schedule'),
        ('Sınıflar ve öğrenciler', '/admin/roster'),
        ('Finans', '/admin/finance'),
        ('Kurum sınavları', '/admin/org-exams'),
        ('Deneme trendleri', '/admin/trends'),
        ('Kitap havuzu', '/admin/books'),
        ('Velilere SMS', '/admin/sms'),
      ]) {
        // Kompakt ızgaradaki kutu.
        final f = find.descendant(
          of: find.byKey(const ValueKey('section-tools')),
          matching: find.text(title),
        );
        await _show(tester, f);
        await tester.tap(f);
        await tester.pumpAndSettle();
        expect(_visited.last, route, reason: title);
        await _back(tester);
        await tester.pumpAndSettle();
      }
      await _show(tester, find.text('Duyurular'));
      expect(find.text('Yeni duyuru'), findsOneWidget);
      // Başarı sıralaması anahtarı kurum ayarlarında.
      await _show(tester, find.byKey(const ValueKey('settings-ranking')));
      expect(
        find.byKey(const ValueKey('success-ranking-switch')),
        findsOneWidget,
      );
    });

    testWidgets(
      'okul numarası eksikse satır çıkar, Öğrenciler sekmesine gider',
      (tester) async {
        await _pump(tester, const AdminHomeScreen(), await _overrides());
        final f = find.byKey(const ValueKey('tool-missing-numbers'));
        await _show(tester, f);
        expect(find.text('1 öğrencinin okul numarası eksik'), findsOneWidget);
        await tester.tap(f);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Öğrenciler'), findsOneWidget);
      },
    );
  });

  group('kurum ayarları', () {
    testWidgets('kredi, lisans, kod, ad, hesaplar, görünüm', (tester) async {
      await _pump(tester, const AdminHomeScreen(), await _overrides());
      await _show(tester, find.byKey(const ValueKey('settings-branding')));
      expect(find.text('Kurum ayarları'), findsOneWidget);
      expect(find.text('120 kaldı'), findsOneWidget);
      expect(find.text('MENTORIA-BAL2K7'), findsOneWidget);
      expect(find.text('3 öğrenci · 2 koç · 1 veli'), findsOneWidget);
      expect(find.textContaining('tarihine kadar'), findsOneWidget);
      // Bilgi tonunda: uyarı bandı yok, "yöneticinizle" yok.
      expect(find.byKey(const ValueKey('org-alert-risk')), findsNothing);
      expect(find.byKey(const ValueKey('org-alert-warn')), findsNothing);
      expect(find.textContaining('öneticinizle'), findsNothing);

      await tester.tap(find.byTooltip('Kodu yenile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yenile'));
      await tester.pumpAndSettle();
      expect(find.text('MENTORIA-YEN001'), findsOneWidget);

      await tester.tap(find.byTooltip('Kurum adını değiştir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('org-name-field')),
        'Bal Akademi Merkez',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Bal Akademi Merkez'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('settings-branding')));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/branding');
    });

    testWidgets('kredi bitince kırmızı bant, müdüre destek ekibi denir', (
      tester,
    ) async {
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(
          credits: InMemoryOrgCreditsRepository(balance: 0, isAdmin: true),
        ),
      );
      expect(find.byKey(const ValueKey('org-alert-risk')), findsOneWidget);
      expect(find.text('Öğrenci krediniz bitti'), findsOneWidget);
      expect(find.textContaining('destek ekibiyle görüşün'), findsWidgets);
      expect(find.textContaining('öneticinizle'), findsNothing);
    });

    test('eşikler: kredi %10, lisans 14 gün', () {
      final now = DateTime(2026, 11, 6);
      OrgInfo org([DateTime? exp]) =>
          OrgInfo(id: 'o', name: 'K', seatLimit: 0, licenseExpiresAt: exp);
      List<Tone> tones(OrgInfo o, int credits, int students) => [
        for (final a in orgAlerts(
          org: o,
          credits: OrgCredits(balance: credits),
          students: students,
          now: now,
        ))
          a.tone,
      ];
      // %10 = 41 kredi: 41 uyarı değil, 40 uyarı.
      expect(tones(org(), 41, 410), isEmpty);
      expect(tones(org(), 40, 410), [Tone.warn]);
      expect(tones(org(), 0, 410), [Tone.risk]);
      expect(tones(org(), 5, 0), isEmpty);
      expect(tones(org(DateTime(2026, 11, 21)), 200, 410), isEmpty);
      expect(tones(org(DateTime(2026, 11, 20)), 200, 410), [Tone.warn]);
      expect(tones(org(DateTime(2026, 11, 1)), 200, 410), [Tone.risk]);
      expect(
        orgAlerts(
          org: org(),
          credits: const OrgCredits(balance: 100, isActive: false),
          students: 10,
          now: now,
        ).single.title,
        'Kurum hesabı kapalı',
      );
    });
  });

  group('hareket açıkken', () {
    testWidgets('açılış, sayaç, kayan seçim ve grafik hatasız oynar', (
      tester,
    ) async {
      Motion.enabled = true;
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const AdminHomeScreen()),
          GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _overrides(),
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
          ),
        ),
      );
      // Sonsuz animasyon olmadığından birkaç saniyede biter.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Reveal), findsWidgets);
      expect(find.text('3'), findsWidgets); // sayaç son değere geldi
      await tester.tap(find.byKey(const ValueKey('kind-netDrop')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.text('Zeynep Arslan'), findsWidgets);
      expect(tester.takeException(), isNull);
      // Kaydırınca büyük başlık küçülür (hata yok).
      await tester.drag(
        find.byKey(const ValueKey('cockpit-scroll')),
        const Offset(0, -400),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(tester.takeException(), isNull);
      Motion.enabled = false;
    });
  });

  group('düzen ve tema', () {
    testWidgets('uygulama koyu temadaysa kokpit de koyu', (tester) async {
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(),
        dark: true,
      );
      final ctx = tester.element(find.byKey(const ValueKey('metric-students')));
      expect(Theme.of(ctx).brightness, Brightness.dark);
      expect(
        Theme.of(ctx).scaffoldBackgroundColor,
        CockpitColors.dark.background,
      );
      expect(ctx.cockpit, CockpitColors.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kurum panelinde yükleniyor ve boş durum maskotsuz', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CockpitThemed(
            child: Scaffold(
              body: Column(
                children: [
                  Builder(builder: (c) => Text('kurumsal: ${isCorporate(c)}')),
                  const SizedBox(height: 80, child: BizzLoader()),
                  const EmptyState(title: 'Boş', message: 'Kayıt yok'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('kurumsal: true'), findsOneWidget);
      expect(find.byType(Bizz), findsNothing);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    test('koç / müdür alt sayfaları kokpit temasıyla açılır', () {
      final router = ProviderContainer(overrides: []).read(routerProvider);
      addTearDown(router.dispose);
      for (final home in ['/admin', '/coach']) {
        final root = router.configuration.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == home);
        void check(GoRoute r) {
          expect(
            r.pageBuilder,
            isNotNull,
            reason: '$home/${r.path} kokpit sayfası olmalı',
          );
          r.routes.whereType<GoRoute>().forEach(check);
        }

        root.routes.whereType<GoRoute>().forEach(check);
      }
    });

    testWidgets('tek açık tema; alt gezinme üstünde boşluk', (tester) async {
      await _pump(tester, const AdminHomeScreen(), await _overrides());
      final ctx = tester.element(find.byKey(const ValueKey('metric-students')));
      expect(Theme.of(ctx).brightness, Brightness.light);
      expect(
        Theme.of(ctx).scaffoldBackgroundColor,
        CockpitColors.light.background,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      final pad = tester.widget<SliverPadding>(
        find.descendant(
          of: find.byKey(const ValueKey('cockpit-scroll')),
          matching: find.byType(SliverPadding),
        ),
      );
      expect(
        (pad.padding as EdgeInsets).bottom,
        greaterThanOrEqualTo(cockpitNavHeight + 16),
      );
    });

    testWidgets('geniş ekranda yan menü, alt çubuk yok', (tester) async {
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(),
        size: const Size(3600, 3000),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('öteki sekmeler: öğrenci arama, koç telefonu, davetler', (
      tester,
    ) async {
      final repo = InMemoryCockpitRepository();
      await _pump(
        tester,
        const AdminHomeScreen(),
        await _overrides(cockpit: repo),
      );
      await tester.tap(find.text('Öğrenciler').last);
      await tester.pumpAndSettle();
      expect(find.text('Ad veya okul numarası ara'), findsOneWidget);
      await tester.tap(find.text('Koçlar').last);
      await tester.pumpAndSettle();
      expect(find.text('Koç davet et'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('coach-phone-demo-coach')));
      await tester.pumpAndSettle();
      expect(find.text('0532 111 22 33'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('coach-phone-field')),
        '',
      );
      await tester.tap(find.byKey(const ValueKey('coach-phone-save')));
      await tester.pumpAndSettle();
      expect(
        (await repo.fetch()).coaches
            .firstWhere((c) => c.coachId == 'demo-coach')
            .phone,
        isNull,
      );
      // Davetler: Koçlar sekmesindeki şeritten ayrı sayfa.
      await tester.tap(find.byKey(const ValueKey('strip-tool-invites')));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/invites');
    });

    testWidgets('alt çubuk: 6 sekme, gruplanmış araçlar', (tester) async {
      await _pump(tester, const AdminHomeScreen(), await _overrides());
      final nav = find.byType(NavigationBar);
      expect(
        find.descendant(of: nav, matching: find.byType(NavigationDestination)),
        findsNWidgets(6),
      );
      Future<void> tab(String label) async {
        await tester.tap(find.descendant(of: nav, matching: find.text(label)));
        await tester.pumpAndSettle();
      }

      // Öğrenciler: şerit (sınıflar, yoklama, ders programı, kitap havuzu)
      // ve öğrenci daveti.
      await tab('Öğrenciler');
      expect(
        tester.widget<ToolStrip>(find.byType(ToolStrip)).tools.map((t) => t.id),
        [
          'students-home-card',
          'attendance-home-card',
          'timetable-admin-card',
          'book-pool-card',
          'tool-book-report',
        ],
      );
      expect(find.text('Öğrenci daveti'), findsOneWidget);

      await tab('Sınavlar');
      for (final id in ['org-exams-card', 'tool-trends', 'tool-exam-plans']) {
        expect(find.byKey(ValueKey(id)), findsOneWidget, reason: id);
      }
      // Eski yükleme yolları yok: her sınav anahtar ve kazanımla yüklenir.
      expect(find.byKey(const ValueKey('tool-import')), findsNothing);
      expect(find.byKey(const ValueKey('tool-optic')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('org-exams-card')));
      await tester.pumpAndSettle();
      expect(_visited.last, '/admin/org-exams');
      GoRouter.of(tester.element(find.textContaining('sayfa /'))).pop();
      await tester.pumpAndSettle();

      // Finans tek başına: ekranın kendisi.
      await tab('Finans');
      expect(find.text('Özet'), findsOneWidget);

      await tab('İletişim');
      expect(find.byKey(const ValueKey('bulk-sms-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool-announcements')), findsOneWidget);
    });
  });

  group('alt sayfalar', () {
    testWidgets('deneme takvimi: boş, ekle, sil', (tester) async {
      final repo = InMemoryCockpitRepository(data: _empty());
      await _pump(
        tester,
        const ExamPlansScreen(),
        await _overrides(cockpit: repo),
      );
      expect(find.text('Planlı deneme yok.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('exam-plan-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('exam-plan-name')),
        'TYT Genel Deneme 7',
      );
      await tester.tap(find.text('AYT'));
      await tester.tap(find.byKey(const ValueKey('exam-plan-save')));
      await tester.pumpAndSettle();
      expect(find.text('TYT Genel Deneme 7'), findsOneWidget);
      expect(find.textContaining('7 gün sonra'), findsOneWidget);
      expect((await repo.fetch()).nextExam!.examType, ExamType.ayt);

      await tester.tap(find.byTooltip('Planı sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('Planlı deneme yok.'), findsOneWidget);
    });

    testWidgets('haftanın çalışması: çalışmayanlar ve soru sırası', (
      tester,
    ) async {
      await _pump(tester, const WeekActivityPage(), await _overrides());
      expect(find.textContaining('Çalışmayanlar ·'), findsOneWidget);
      await tester.tap(find.text('Soru sırası'));
      await tester.pumpAndSettle();
      for (final n in ['Elif Yılmaz', 'Can Kaya', 'Zeynep Arslan']) {
        expect(find.text(n), findsOneWidget);
      }
    });

    testWidgets('risk, trend ve görüşme sayfaları eski kartları gösterir', (
      tester,
    ) async {
      await _pump(tester, const RiskPage(), await _overrides());
      expect(find.text('Bu hafta konuşulacaklar'), findsOneWidget);
      await _pump(tester, const TrendsPage(), await _overrides());
      expect(find.text('Son 5 denemede değişim'), findsOneWidget);
      await _pump(tester, const MeetingsPage(), await _overrides());
      expect(find.text('Koç görüşmeleri'), findsWidgets);
    });
  });

  group('veri', () {
    test('admin_cockpit yanıtı çözülür', () {
      final d = CockpitData.fromJson({
        'students': 410,
        'students_prev': 400,
        'active': 312,
        'active_prev': 300,
        'questions': 51000,
        'questions_prev': 50000,
        'minutes': 9000,
        'minutes_prev': 8000,
        'exam_plans': [
          {
            'id': 'p',
            'name': 'TYT 1',
            'exam_type': 'AYT',
            'planned_on': '2026-11-09',
          },
        ],
        'inactive': [
          {'student_id': 's1', 'full_name': 'A', 'seen_at': null},
        ],
        'net_drops': [
          {
            'student_id': 's2',
            'full_name': 'B',
            'exam_type': 'TYT',
            'last_net': 60.5,
            'prev_net': 66,
          },
        ],
        'overdue': [
          {
            'student_id': 's3',
            'full_name': 'C',
            'count': 2,
            'amount': 4500,
            'oldest_due': '2026-10-20',
          },
        ],
        'coaches': [
          {
            'coach_id': 'c',
            'full_name': 'K',
            'phone': null,
            'students': 10,
            'active': 7,
            'meetings_planned': 4,
            'meetings_held': 3,
          },
        ],
      });
      expect(d.attentionCount, 3);
      expect(d.nextExam!.examType, ExamType.ayt);
      expect((d.netDrops.single.drop), 5.5);
      expect(d.coaches.single.activeRatio, 0.7);
      expect(MetricDelta.between(51000, 50000, percent: true)!.rounded, 2);
      expect(MetricDelta.between(5, 0, percent: true), isNull);
    });

    test('koça bildirim metni', () {
      final n = AppNotification.fromJson({
        'id': 'n',
        'kind': 'coach_alert',
        'data': {
          'student': 'Can Kaya',
          'from': 'Mehmet Demir',
          'reason': '9 gündür giriş yapmadı',
          'route': '/coach/students/demo-can',
        },
        'created_at': '2026-11-06T08:00:00Z',
      });
      expect(n.title, 'Can Kaya ile ilgilenir misin?');
      expect(n.body, 'Mehmet Demir yazdı: 9 gündür giriş yapmadı');
      expect(n.route, '/coach/students/demo-can');
    });
  });
}

/// Hiç bitmeyen (ya da testin bitirdiği) yükleme.
class _PendingCockpit extends InMemoryCockpitRepository {
  _PendingCockpit(this._future);

  final Future<CockpitData> _future;

  @override
  Future<CockpitData> fetch() => _future;
}
