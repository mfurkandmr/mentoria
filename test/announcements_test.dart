import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/announcements/data/announcement_repository.dart';
import 'package:mentoria/features/announcements/presentation/announcement_widgets.dart';
import 'package:mentoria/features/auth/data/profile.dart';
import 'package:mentoria/features/notifications/data/notification_repository.dart';
import 'package:mentoria/shared/motion.dart';

Future<Widget> _app(String role, Widget screen) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
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

Widget _home() =>
    const Scaffold(body: SingleChildScrollView(child: AnnouncementsHomeCard()));

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  setUp(() => Motion.enabled = false);
  tearDown(() => Motion.enabled = true);

  group('kitleler ve görünürlük', () {
    test('müdür kurum geneline, koç kendi öğrencilerine gönderebilir', () {
      expect(AnnouncementAudience.forRole(UserRole.admin), [
        AnnouncementAudience.everyone,
        AnnouncementAudience.students,
        AnnouncementAudience.parents,
        AnnouncementAudience.coaches,
      ]);
      expect(AnnouncementAudience.forRole(UserRole.coach), [
        AnnouncementAudience.myStudents,
        AnnouncementAudience.myParents,
      ]);
      expect(AnnouncementAudience.forRole(UserRole.student), isEmpty);
      expect(AnnouncementAudience.forRole(UserRole.parent), isEmpty);
    });

    test(
      'demo: veli kurum duyurusunu görür, koçun öğrenci duyurusunu görmez',
      () async {
        InMemoryAnnouncementRepository repo(UserRole role, String name) {
          final r = InMemoryAnnouncementRepository(role: role, myName: name);
          seedDemoAnnouncements(r);
          return r;
        }

        final parent = await repo(UserRole.parent, 'Selin Yılmaz').fetch();
        expect(parent.map((a) => a.title), ['Cumartesi TYT denemesi']);
        expect(parent.single.recipients, isNull);

        final student = await repo(UserRole.student, 'Elif Yılmaz').fetch();
        expect(student, hasLength(2));

        final coach = await repo(UserRole.coach, 'Ayşe Koç').fetch();
        final own = coach.firstWhere((a) => a.sentByMe);
        expect(own.recipients, 3);
        expect(coach, hasLength(2));

        final admin = await repo(UserRole.admin, 'Mehmet Demir').fetch();
        expect(admin.every((a) => a.recipients != null), isTrue);
      },
    );

    test('yetkisiz kitle ve boş metin reddedilir', () async {
      final coach = InMemoryAnnouncementRepository(
        role: UserRole.coach,
        myName: 'Ayşe Koç',
      );
      expect(
        () => coach.send(AnnouncementAudience.everyone, 'Başlık', 'Metin'),
        throwsA(
          isA<AnnouncementException>().having(
            (e) => e.error,
            'error',
            AnnouncementError.notAllowed,
          ),
        ),
      );
      expect(
        () => coach.send(AnnouncementAudience.myStudents, 'Başlık', '  '),
        throwsA(isA<AnnouncementException>()),
      );
    });

    test('duyuru bildirimi: başlık, metin ve role göre rota', () {
      final n = AppNotification(
        id: 'n',
        kind: NotificationKind.announcement,
        createdAt: DateTime(2026, 10, 19),
        data: const {
          'title': 'Tatil',
          'body': 'Pazartesi kurum kapalı.',
          'route': '/parent/announcements',
        },
      );
      expect(n.title, '📣 Tatil');
      expect(n.body, 'Pazartesi kurum kapalı.');
      expect(n.route, '/parent/announcements');
      expect(
        NotificationKind.tryDb('announcement'),
        NotificationKind.announcement,
      );
    });
  });

  testWidgets('müdür duyuru gönderir, listede alıcı sayısıyla görünür', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await _app('admin', const AnnouncementsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Cumartesi TYT denemesi'), findsOneWidget);

    await tester.tap(find.text('Yeni duyuru'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Veliler'));
    await tester.pumpAndSettle();
    expect(find.text('Kurumdaki öğrencilerin velileri'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Başlık'),
      'Veli toplantısı',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Duyuru metni'),
      'Cuma 18.00 veli toplantısı var.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Gönder'));
    await tester.pumpAndSettle();
    expect(find.text('Duyuru gönderilsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Gönder'));
    await tester.pumpAndSettle();

    expect(find.text('Duyuru 14 kişiye gönderildi 📣'), findsOneWidget);
    expect(find.text('Veli toplantısı'), findsOneWidget);
    expect(find.text('Sen · Veliler · 14 kişi · az önce'), findsOneWidget);
  });

  testWidgets('koç yalnızca kendi kitlelerini görür', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await _app('coach', _home()));
    await tester.pumpAndSettle();
    expect(find.text('Duyurular'), findsOneWidget);
    await tester.tap(find.text('Yeni duyuru'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Öğrencilerim'), findsOneWidget);
    expect(
      find.widgetWithText(ChoiceChip, 'Öğrencilerimin velileri'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ChoiceChip, 'Herkes'), findsNothing);
  });

  testWidgets('öğrenci ana sayfasında son duyuru görünür, gönderme yok', (
    tester,
  ) async {
    await tester.pumpWidget(await _app('student', _home()));
    await tester.pumpAndSettle();
    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Cumartesi TYT denemesi'), findsOneWidget);
    expect(find.text('Yeni duyuru'), findsNothing);
  });
}
