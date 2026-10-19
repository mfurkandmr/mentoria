import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/coach/presentation/coach_home_screen.dart';
import 'package:mentoria/features/coach/presentation/manager_widgets.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  setUp(() => Motion.enabled = false);
  tearDown(() => Motion.enabled = true);

  testWidgets('koç listesinde silme talebi olan öğrenci rozetle görünür', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const CoachHomeScreen()),
        GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/:a/:b/:c', builder: (_, _) => const Scaffold()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: await buildDemoOverrides('coach'),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Demoda yalnızca Can hesabının silinmesini istedi.
    final badge = find.text('Silme talebi');
    expect(badge, findsOneWidget);
    expect(
      find.ancestor(of: badge, matching: find.byType(StudentCard)),
      findsOneWidget,
    );
    final canCard = find.ancestor(
      of: find.text('Can Kaya'),
      matching: find.byType(StudentCard),
    );
    expect(
      find.descendant(of: canCard, matching: badge),
      findsOneWidget,
      reason: 'rozet Can\'ın kartında',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
