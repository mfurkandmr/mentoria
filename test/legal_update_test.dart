import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/auth/presentation/role_gate_screen.dart';
import 'package:mentoria/features/privacy/data/consent_repository.dart';
import 'package:mentoria/shared/motion.dart';

/// Girişte KVKK metin sürümü kontrolü: yayımlanan sürüm onaylanmadıysa
/// panele girmeden önce yeniden onay istenir.
Future<void> _pump(WidgetTester tester, List<Override> o) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: RoleGateScreen()),
      ),
      GoRoute(
        path: '/:a',
        builder: (_, _) => const Scaffold(body: Text('PANEL')),
      ),
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

InMemoryConsentRepository _consents(String? version) =>
    InMemoryConsentRepository(
      myId: 'demo-coach',
      seed: {
        'demo-coach': ConsentStatus(
          minor: false,
          privacyNotice: version != null,
          privacyVersion: version,
        ),
      },
    );

void main() {
  setUpAll(() => Motion.enabled = false);

  for (final version in ['1.1', null]) {
    testWidgets('sürüm $version: önce onay, sonra panel', (tester) async {
      final repo = _consents(version);
      await _pump(tester, await buildDemoOverrides('coach', true, repo));

      expect(find.text('Metinlerimiz güncellendi'), findsOneWidget);
      expect(find.text('PANEL'), findsNothing);
      final accept = find.widgetWithText(FilledButton, 'Onayla ve devam et');
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();

      expect(repo.statusOf('demo-coach').privacyVersion, legalVersion);
      expect(find.text('Metinlerimiz güncellendi'), findsNothing);
      expect(find.text('PANEL'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('güncel sürümü onaylayan doğrudan panele girer', (tester) async {
    await _pump(
      tester,
      await buildDemoOverrides('coach', true, _consents(legalVersion)),
    );
    expect(find.text('Metinlerimiz güncellendi'), findsNothing);
    expect(find.text('PANEL'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
