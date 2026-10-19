import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/privacy/data/consent_repository.dart';
import 'package:mentoria/features/privacy/presentation/legal_text_screen.dart';
import 'package:mentoria/features/privacy/presentation/privacy_screen.dart';
import 'package:mentoria/shared/motion.dart';

Future<(Widget, InMemoryConsentRepository)> _app(
  String role,
  Widget screen, {
  Map<String, ConsentStatus>? seed,
}) async {
  final myId = switch (role) {
    'parent' => 'demo-parent',
    'coach' => 'demo-coach',
    _ => 'demo-student',
  };
  final consents = InMemoryConsentRepository(
    myId: myId,
    parentOf: const {
      'demo-parent': {'demo-student'},
    },
    seed:
        seed ??
        {
          'demo-student': ConsentStatus(
            birthYear: DateTime.now().year - 17,
            minor: true,
            privacyNotice: true,
            ranking: true,
            guardianApproval: true,
            guardianSource: 'institution',
            rankingVisible: true,
            hasParent: true,
          ),
        },
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
    ],
  );
  return (
    ProviderScope(
      overrides: await buildDemoOverrides(role, true, consents),
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
    consents,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  setUp(() => Motion.enabled = false);
  tearDown(() => Motion.enabled = true);

  group('KVKK metinleri', () {
    test('uygulamadaki metinler üretilmiş ve avukat notları ayıklanmış', () {
      for (final d in LegalDoc.values) {
        final f = File(d.asset);
        expect(f.existsSync(), isTrue, reason: d.asset);
        final s = f.readAsStringSync();
        expect(
          s.split('\n').where((l) => l.startsWith('>')),
          isEmpty,
          reason: '${d.asset}: avukat notu kalmış',
        );
        expect(s, isNot(contains('(taslak)')));
        expect(s, isNot(contains('Uygulamadaki görünüm')));
      }
      final notice = File(LegalDoc.privacyNotice.asset).readAsStringSync();
      expect(notice, contains('Haklarınız (KVKK md. 11)'));
      final consent = File(LegalDoc.explicitConsent.asset).readAsStringSync();
      expect(consent, isNot(contains('Yurt dışına aktarım')));
      expect(consent, isNot(contains('kampanya')));
    });

    test('küçük Markdown çözücü', () {
      final blocks = parseLegalMarkdown('''
# Başlık

İlk satır
devamı **kalın**.

- madde bir
  ikinci satır
- madde iki

| A | B |
|---|---|
| 1 | 2 |

---
''');
      expect(blocks.first, isA<LegalHeading>());
      expect((blocks[1] as LegalParagraph).text, 'İlk satır devamı **kalın**.');
      expect((blocks[2] as LegalBullet).text, 'madde bir ikinci satır');
      expect(blocks[3], isA<LegalBullet>());
      expect((blocks[4] as LegalTableRow).header, isTrue);
      expect((blocks[5] as LegalTableRow).cells, ['1', '2']);
      expect(blocks.last, isA<LegalRule>());
      final spans = legalSpans('a **b** *c*', null);
      expect(spans.length, 4);
    });

    test('yaş yalnızca doğum yılından; o yıl 18 olanlar küçük sayılır', () {
      final now = DateTime(2026, 6, 1);
      expect(isMinorBirthYear(null, now: now), isTrue);
      expect(isMinorBirthYear(2010, now: now), isTrue);
      expect(isMinorBirthYear(2008, now: now), isTrue);
      expect(isMinorBirthYear(2007, now: now), isFalse);
    });
  });

  testWidgets('aydınlatma metni ekranda açılır', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalTextScreen(doc: LegalDoc.privacyNotice)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aydınlatma Metni'), findsOneWidget);
    expect(find.textContaining('Veri sorumlusu'), findsWidgets);
  });

  testWidgets('öğrenci: kurum onayı görünür, sıralama izni kapatılır', (
    tester,
  ) async {
    final (app, consents) = await _app('student', const PrivacyScreen());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Veli onayın kurumun tarafından alındı.'), findsOneWidget);
    expect(
      find.text('Velim çalışmalarımı görebilsin'),
      findsNothing,
      reason: '18 altında veli izni ayrıca sorulmaz',
    );
    await tester.tap(find.text('Başarı sıralamasında görün'));
    await tester.pumpAndSettle();
    expect(consents.statusOf('demo-student').ranking, isFalse);
    expect(consents.statusOf('demo-student').history.first.granted, isFalse);
    await tester.scrollUntilVisible(
      find.byIcon(Icons.download_rounded),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Verilerimi indir'), findsWidgets);
  });

  testWidgets('yetişkin öğrenci velinin erişimini kaldırırken onay sorulur', (
    tester,
  ) async {
    final (app, consents) = await _app(
      'student',
      const PrivacyScreen(),
      seed: {
        'demo-student': const ConsentStatus(
          birthYear: 2000,
          minor: false,
          parentView: true,
          hasParent: true,
        ),
      },
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Velim çalışmalarımı görebilsin'), findsOneWidget);
    await tester.tap(find.text('Velim çalışmalarımı görebilsin'));
    await tester.pumpAndSettle();
    expect(find.text('Velinin erişimi kaldırılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();
    final s = consents.statusOf('demo-student');
    expect(s.parentView, isFalse);
    expect(s.hasParent, isFalse);
  });

  testWidgets('doğum yılı yoksa sorulur ve bir kez kaydedilir', (tester) async {
    final (app, consents) = await _app(
      'student',
      const Scaffold(body: KvkkHomeCard()),
      seed: {'demo-student': const ConsentStatus()},
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Doğum yılını gir'), findsOneWidget);
    await tester.tap(find.text('Doğum yılını gir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    final s = consents.statusOf('demo-student');
    expect(s.birthYear, DateTime.now().year - 17);
    expect(s.awaitingGuardian, isTrue);
    expect(
      find.text('Veli onayı bekleniyor'),
      findsOneWidget,
      reason: '17 yaşında ve veli onayı yok',
    );
  });

  testWidgets('kurum onayı varken ana sayfa kartı görünmez', (tester) async {
    final (app, _) = await _app(
      'student',
      const Scaffold(body: KvkkHomeCard()),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('veli: çocuğunun onayını geri çekerken uyarılır', (tester) async {
    final (app, consents) = await _app(
      'parent',
      const PrivacyScreen(),
      seed: {
        'demo-student': ConsentStatus(
          birthYear: DateTime.now().year - 16,
          minor: true,
          guardianApproval: true,
          guardianSource: 'parent',
          ranking: true,
          rankingVisible: true,
        ),
      },
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Elif Yılmaz'), findsOneWidget);
    await tester.tap(find.text('Mentoria\'yı kullanmasına onay veriyorum'));
    await tester.pumpAndSettle();
    expect(find.text('Onayını geri çekmek istiyor musun?'), findsOneWidget);
    await tester.tap(find.text('Onayı geri çek'));
    await tester.pumpAndSettle();
    final s = consents.statusOf('demo-student');
    expect(s.guardianApproval, isFalse);
    expect(s.rankingVisible, isFalse, reason: 'onay yoksa sıralamada görünmez');
  });
}
