import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/settings/app_settings.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/admin/presentation/admin_home_screen.dart';
import 'package:mentoria/features/auth/data/auth_repository.dart';
import 'package:mentoria/features/auth/data/profile.dart';
import 'package:mentoria/features/auth/presentation/invite_signup_screen.dart';
import 'package:mentoria/features/coach/presentation/coach_home_screen.dart';
import 'package:mentoria/features/coach/presentation/invite_sheet.dart';
import 'package:mentoria/features/credits/data/org_credits_repository.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget home, List<Override> o) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b/:c', builder: (_, _) => const Scaffold()),
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

class _NoCreditAuth implements AuthRepository {
  @override
  Future<InviteInfo?> checkInvite(String code) async => const InviteInfo(
    role: UserRole.student,
    orgName: 'Bal Kurs',
    noCredits: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  setUp(() => Motion.enabled = false);
  tearDown(() => Motion.enabled = true);

  test('kredi kuralları: 50 altı uyarı, 0 ya da kapalı kurumda ekleme yok', () {
    expect(const OrgCredits(balance: 50).low, isFalse);
    expect(const OrgCredits(balance: 49).low, isTrue);
    expect(const OrgCredits(balance: 1).canAddStudent, isTrue);
    expect(const OrgCredits(balance: 0).canAddStudent, isFalse);
    expect(
      const OrgCredits(balance: 10, isActive: false).canAddStudent,
      isFalse,
    );
    final c = OrgCredits.fromJson({'credit_balance': 7, 'is_active': true});
    expect((c.balance, c.isActive), (7, true));
  });

  test('uygulamada fiyat, satın alma ya da ödeme yok', () {
    // Ders içeriği (soru kartları) hariç: orada fiyat bir matematik konusu.
    final banned = [
      RegExp(r'₺|(?<!\p{L})TL(?!\p{L})', unicode: true),
      RegExp(
        r'satın al|ödeme yap|fiyat|in_app_purchase|purchases_flutter',
        caseSensitive: false,
      ),
    ];
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('strings_en.dart') ||
          f.path.contains('learn_cards.dart')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (final (i, l) in lines.indexed) {
        final t = l.trimLeft();
        if (t.startsWith('//')) continue;
        if (banned.any((r) => r.hasMatch(l))) {
          hits.add('${f.path}:${i + 1}: $t');
        }
      }
    }
    expect(hits, isEmpty);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('in_app_purchase')));
  });

  testWidgets('koç: kredi 50 altındaysa uyarı, fiyatsız', (tester) async {
    await _pump(tester, const CoachHomeScreen(), [
      ...await buildDemoOverrides(
        'coach',
        true,
        null,
        InMemoryOrgCreditsRepository(balance: 12),
      ),
    ]);
    expect(find.text('Öğrenci krediniz azalıyor: 12 kaldı'), findsOneWidget);
    expect(find.text('Yöneticinizle iletişime geçin.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('koç: kredi yeterliyse uyarı yok', (tester) async {
    await _pump(tester, const CoachHomeScreen(), [
      ...await buildDemoOverrides('coach'),
    ]);
    expect(find.textContaining('Öğrenci krediniz'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('koç: kredi 0 iken "Kod oluştur" kapalı', (tester) async {
    await _pump(tester, const Scaffold(body: InviteSheet()), [
      ...await buildDemoOverrides(
        'coach',
        true,
        null,
        InMemoryOrgCreditsRepository(balance: 0),
      ),
    ]);
    expect(find.text('Öğrenci krediniz bitti'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Kod oluştur'),
    );
    expect(button.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('koç: kredi varken "Kod oluştur" açık', (tester) async {
    await _pump(tester, const Scaffold(body: InviteSheet()), [
      ...await buildDemoOverrides(
        'coach',
        true,
        null,
        InMemoryOrgCreditsRepository(balance: 3),
      ),
    ]);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Kod oluştur'),
    );
    expect(button.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('müdür: kurum kodu görünür ve yenilenir; kredi kartta', (
    tester,
  ) async {
    final credits = InMemoryOrgCreditsRepository(balance: 120, isAdmin: true);
    await _pump(tester, const AdminHomeScreen(), [
      ...await buildDemoOverrides('admin', true, null, credits),
    ]);
    expect(find.text('MENTORIA-BAL2K7'), findsOneWidget);
    expect(find.text('Öğrenci kredisi: 120'), findsOneWidget);
    expect(find.textContaining('Öğrenci krediniz'), findsNothing);

    await tester.tap(find.byTooltip('Kodu yenile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yenile'));
    await tester.pumpAndSettle();
    expect(find.text('MENTORIA-YEN001'), findsOneWidget);
    expect(find.text('MENTORIA-BAL2K7'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('müdür: kredi 0 iken öğrenci davetinde "Kod oluştur" kapalı', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                showInviteCodeDialog(context, ref, role: UserRole.student),
            child: const Text('aç'),
          ),
        ),
      ),
      [
        ...await buildDemoOverrides(
          'admin',
          true,
          null,
          InMemoryOrgCreditsRepository(balance: 0, isAdmin: true),
        ),
      ],
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('Öğrenci krediniz bitti'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Kod oluştur'),
    );
    expect(button.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('kayıt: kredisi biten kurumun koduyla devam edilmez', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4500);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(_NoCreditAuth()),
        ],
        child: const MaterialApp(
          home: InviteSignupScreen(initialCode: 'MENTORIA-BAL2K7'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Kurumunun öğrenci kredisi bitti. Kurum yöneticinle iletişime geç.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ad Soyad'), findsNothing, reason: 'form açılmaz');
  });
}
