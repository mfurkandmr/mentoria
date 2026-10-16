import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/admin/presentation/admin_home_screen.dart';
import 'package:mentoria/features/coach/presentation/coach_home_screen.dart';
import 'package:mentoria/features/coach/presentation/student_detail_screen.dart';
import 'package:mentoria/features/meetings/presentation/meeting_widgets.dart';
import 'package:mentoria/features/parent/presentation/parent_home_screen.dart';
import 'package:mentoria/features/student/presentation/student_home_screen.dart';
import 'package:mentoria/shared/motion.dart';

Future<Widget> _app(String role, Widget screen) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b/:c', builder: (_, _) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: await buildDemoOverrides(role),
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    // Yatay sekme çubuğunu değil, sayfanın dikey listesini kaydır.
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('koç bu haftaki görüşmeleri görür ve iptal eder', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('coach', const CoachHomeScreen()));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Bu haftaki görüşmeler'));
    // Ayşe Koç'un iki öğrencisiyle haftalık rutini var (Elif, Can);
    // başka koçun öğrencisi (Zeynep) görünmez.
    expect(find.byType(MeetingTile), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(MeetingTile),
        matching: find.text('Zeynep Arslan'),
      ),
      findsNothing,
    );

    final can = find.ancestor(
      of: find.descendant(
        of: find.byType(MeetingTile),
        matching: find.text('Can Kaya'),
      ),
      matching: find.byType(MeetingTile),
    );
    await _scrollTo(tester, can);
    await tester.tap(can);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bu haftalık iptal'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: can, matching: find.text('İptal')),
      findsOneWidget,
    );
  });

  testWidgets('koç öğrencisine haftalık rutin görüşme ekler', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      await _app('coach', const StudentDetailScreen(studentId: 'demo-can')),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Görüşme ekle'));
    await tester.tap(find.text('Görüşme ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Her hafta'), findsOneWidget);
    expect(find.textContaining('24 saat önce bildirim gider'), findsOneWidget);
    await tester.tap(find.text('Görüşmeyi kaydet'));
    await tester.pumpAndSettle();

    // Varsayılan: bugünün günü, 16:00.
    final day = DateFormat('EEEE', 'tr').format(DateTime.now());
    await _scrollTo(tester, find.text('Her $day 16:00'));
    expect(find.text('Her $day 16:00'), findsOneWidget);
    // Demo'daki perşembe rutini de duruyor.
    expect(find.textContaining('16:30'), findsWidgets);
  });

  testWidgets('öğrenci ana sayfasında sıradaki görüşmeyi görür', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(await _app('student', const StudentHomeScreen()));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byType(NextMeetingCard));
    expect(find.text('Ayşe Koç ile görüşme'), findsOneWidget);
    expect(find.textContaining('Her Salı 11:00'), findsOneWidget);
  });

  testWidgets('veli çocuğunun görüşmelerini salt okunur görür', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('parent', const ParentHomeScreen()));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Her Salı 11:00'));
    expect(find.text('Görüşmeler'), findsOneWidget);
    expect(find.text('Görüşme ekle'), findsNothing);
    expect(find.byTooltip('Rutini bitir'), findsNothing);
  });

  testWidgets('müdür koçların haftalık görüşmelerini görür', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('admin', const AdminHomeScreen()));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Koç görüşmeleri'));
    final report = find.byType(CoachMeetingsReport);
    await _scrollTo(
      tester,
      find.descendant(
        of: report,
        matching: find.textContaining('Zeynep Arslan', findRichText: true),
      ),
    );
    for (final name in [
      'Ayşe Koç',
      'Burak Yıldız',
      'Elif Yılmaz',
      'Can Kaya',
    ]) {
      expect(
        find.descendant(
          of: report,
          matching: find.textContaining(name, findRichText: true),
        ),
        findsWidgets,
        reason: name,
      );
    }

    // Önceki hafta: demo verisinde Elif ve Zeynep'inki yapıldı, Can'ınki
    // yapılmadı.
    await tester.tap(find.byTooltip('Önceki hafta'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: report, matching: find.text('Yapılmadı')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: report, matching: find.text('Yapıldı')),
      findsNWidgets(2),
    );
  });
}
