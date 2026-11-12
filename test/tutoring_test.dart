// Soru çözümü / birebir (NOTLAR §87): öğrenci talep eder, yalnızca öğretmen
// onaylar, müdür oturum açar, koç izler. Bellekteki demo deposuyla.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_tutoring.dart';
import 'package:mentoria/features/notifications/data/notification_repository.dart';
import 'package:mentoria/features/schedule_generator/presentation/my_timetable.dart';
import 'package:mentoria/features/student_schedule/presentation/student_schedule_screen.dart';
import 'package:mentoria/features/teacher/presentation/teacher_home_screen.dart';
import 'package:mentoria/features/tutoring/data/tutoring_repository.dart';
import 'package:mentoria/features/tutoring/presentation/admin_tutoring_screen.dart';
import 'package:mentoria/features/tutoring/presentation/student_tutoring_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  const names = {
    't-mehmet': 'Mehmet Arslan',
    't-ahmet': 'Ahmet Kaya',
    't-zeynep': 'Zeynep Şahin',
    't-elif': 'Elif Demir',
  };

  InMemoryTutoringRepository repo(String viewer, String role) =>
      InMemoryTutoringRepository.demo(
        viewerId: viewer,
        viewerRole: role,
        teacherNames: names,
        studentNames: const {
          'demo-student': 'Elif Yılmaz',
          'demo-can': 'Can Kaya',
        },
      );

  Future<void> pump(
    WidgetTester t,
    Widget screen, {
    required String role,
    required InMemoryTutoringRepository tutoring,
  }) async {
    t.view.physicalSize = const Size(1080, 3200);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: await buildDemoOverrides(
          role,
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
          null,
          tutoring,
        ),
        child: MaterialApp.router(
          routerConfig: router,
          // Uygulamanın teması: dolu düğmeler tam genişlik (satırı ezebilir).
          theme: AppTheme.light(),
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  group('kurallar (bellek deposu, sunucuyla aynı)', () {
    test(
      'günde 3 etkin talep, kontenjan, kararı yalnızca öğretmen verir',
      () async {
        final now = DateTime(2026, 11, 9, 8); // pazartesi sabah
        final admin = InMemoryTutoringRepository(
          viewerId: 'demo-admin',
          viewerRole: 'admin',
          teacherNames: names,
          teacherProfiles: const {'t-mehmet': 'demo-teacher'},
          now: () => now,
        );
        for (final (i, h) in [9, 10, 11, 12].indexed) {
          await admin.saveSession(
            TutoringSession(
              id: 's$i',
              teacherId: 't-mehmet',
              kind: TutoringKind.questionSolving,
              day: 2,
              start: h * 60,
              end: h * 60 + 50,
              capacity: 1,
            ),
          );
        }
        await expectLater(
          admin.saveSession(
            const TutoringSession(
              id: '',
              teacherId: 't-mehmet',
              kind: TutoringKind.etut,
              day: 2,
              start: 9 * 60 + 30,
              end: 10 * 60,
            ),
          ),
          throwsA(predicate((e) => '$e'.contains('TUTOR_SESSION_OVERLAP'))),
        );
        final tuesday = DateTime(2026, 11, 10);
        InMemoryTutoringRepository as(String id, String role) =>
            InMemoryTutoringRepository(
              viewerId: id,
              viewerRole: role,
              teacherNames: names,
              teacherProfiles: const {'t-mehmet': 'demo-teacher'},
              now: () => now,
            );
        final student = as('s-1', 'student');
        for (final (i, h) in [9, 10, 11, 12].indexed) {
          student.seedSession(
            TutoringSession(
              id: 's$i',
              teacherId: 't-mehmet',
              kind: TutoringKind.questionSolving,
              day: 2,
              start: h * 60,
              end: h * 60 + 50,
            ),
          );
        }
        await student.request('s0', tuesday);
        await student.request('s1', tuesday);
        await student.request('s2', tuesday);
        await expectLater(
          student.request('s3', tuesday),
          throwsA(predicate((e) => '$e'.contains('TUTOR_DAILY_LIMIT'))),
        );
        await expectLater(
          student.request('s0', tuesday.add(const Duration(days: 1))),
          throwsA(predicate((e) => '$e'.contains('TUTOR_BAD_DATE'))),
        );
        final mine = await student.myRequests();
        await expectLater(
          student.decide(mine.first.id, approve: true),
          throwsA(predicate((e) => '$e'.contains('NOT_ALLOWED'))),
        );
      },
    );
  });

  testWidgets('öğrenci açık oturuma talep eder, iptal edebilir', (t) async {
    final tutoring = repo('demo-student', 'student');
    await pump(
      t,
      const StudentTutoringScreen(),
      role: 'student',
      tutoring: tutoring,
    );
    expect(find.text('Taleplerim'), findsOneWidget);
    expect(find.text('Onaylandı'), findsWidgets);
    expect(find.text('Açık oturumlar'), findsOneWidget);

    final button = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key! as ValueKey).value}'.startsWith('request-ts-'),
    );
    expect(button, findsWidgets);
    await t.tap(button.first);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('request-topic')), 'Türev');
    await t.tap(find.byKey(const ValueKey('request-send')));
    await t.pumpAndSettle();
    expect(find.text('Talebin öğretmene gönderildi'), findsOneWidget);
    final mine = await tutoring.myRequests();
    expect(mine.where((r) => r.topic == 'Türev'), hasLength(1));
    expect(find.text('Onay bekliyor'), findsWidgets);

    final created = mine.firstWhere((r) => r.topic == 'Türev');
    await t.tap(find.byKey(ValueKey('cancel-${created.id}')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'İptal et'));
    await t.pumpAndSettle();
    expect(
      (await tutoring.myRequests()).where((r) => r.topic == 'Türev'),
      isEmpty,
    );
  });

  testWidgets('oturum kartı geniş ekranda da okunur (düğme satırı ezmez)', (
    t,
  ) async {
    await pump(
      t,
      const StudentTutoringScreen(),
      role: 'student',
      tutoring: repo('demo-student', 'student'),
    );
    t.view.physicalSize = const Size(3800, 2000); // ~1520 dp genişlik
    await t.pumpAndSettle();
    final button = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key! as ValueKey).value}'.startsWith('request-ts-'),
    );
    expect(button, findsWidgets);
    expect(t.getSize(button.first).width, lessThan(300));
    final card = find.ancestor(of: button.first, matching: find.byType(Card));
    final title = find.descendant(
      of: card,
      matching: find.textContaining('Soru çözümü'),
    );
    expect(t.getSize(title.first).width, greaterThan(100));
  });

  testWidgets('kurumda oturum yokken de giriş kartı görünür', (t) async {
    final empty = InMemoryTutoringRepository(
      viewerId: 'demo-student',
      viewerRole: 'student',
      teacherNames: names,
    );
    await pump(
      t,
      const Scaffold(body: TutoringHomeCard()),
      role: 'student',
      tutoring: empty,
    );
    expect(find.byKey(const ValueKey('tutoring-home-card')), findsOneWidget);
    expect(find.text('Kurumun henüz açık saat girmedi'), findsOneWidget);
  });

  testWidgets('öğretmen bekleyen talebi onaylar', (t) async {
    final tutoring = repo('demo-teacher', 'teacher');
    final pending = (await tutoring.teacherRequests(
      DateTime.now(),
    )).where((r) => r.status == TutoringStatus.pending).toList();
    expect(pending, hasLength(1));
    await pump(
      t,
      const TeacherHomeScreen(),
      role: 'teacher',
      tutoring: tutoring,
    );
    expect(find.text('1 talep onayını bekliyor'), findsOneWidget);
    expect(find.textContaining('Can Kaya'), findsWidgets);

    final approve = find.byKey(ValueKey('approve-${pending.single.id}'));
    await t.ensureVisible(approve);
    await t.tap(approve);
    await t.pumpAndSettle();
    expect(find.text('Talep onaylandı'), findsOneWidget);
    expect(find.text('Bekleyen talep yok'), findsOneWidget);
    final after = await tutoring.teacherRequests(DateTime.now());
    expect(after.every((r) => r.status == TutoringStatus.approved), isTrue);
  });

  testWidgets('öğretmen gerekçeyle reddeder', (t) async {
    final tutoring = repo('demo-teacher', 'teacher');
    final id = (await tutoring.teacherRequests(
      DateTime.now(),
    )).firstWhere((r) => r.status == TutoringStatus.pending).id;
    await pump(
      t,
      const TeacherHomeScreen(),
      role: 'teacher',
      tutoring: tutoring,
    );
    final reject = find.byKey(ValueKey('reject-$id'));
    await t.ensureVisible(reject);
    await t.tap(reject);
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('reject-reason')),
      'Bu hafta dolu',
    );
    await t.tap(find.byKey(const ValueKey('reject-confirm')));
    await t.pumpAndSettle();
    final r = (await tutoring.teacherRequests(
      DateTime.now(),
    )).firstWhere((r) => r.id == id);
    expect(r.status, TutoringStatus.rejected);
    expect(r.rejectReason, 'Bu hafta dolu');
  });

  testWidgets('müdür oturum ekler ve talepleri görür', (t) async {
    final tutoring = repo('demo-admin', 'admin');
    await pump(
      t,
      const TutoringAdminScreen(),
      role: 'admin',
      tutoring: tutoring,
    );
    expect(
      find.byKey(const ValueKey('tutoring-ts-mat-birebir')),
      findsOneWidget,
    );

    await t.tap(find.byKey(const ValueKey('add-tutoring')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tutoring-teacher')));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Elif Demir').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tutoring-save')));
    await t.pumpAndSettle();
    final sessions = await tutoring.fetchSessions();
    expect(sessions.where((s) => s.teacherId == 't-elif'), hasLength(1));

    await t.tap(find.text('Talepler'));
    await t.pumpAndSettle();
    expect(find.textContaining('Elif Yılmaz'), findsWidgets);
    expect(find.textContaining('Can Kaya'), findsWidgets);
    // Müdür karar veremez: onay düğmesi yok.
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  test('koç talepleri görmez (soru çözümü öğretmen ve müdür işi)', () async {
    final coach = repo('demo-coach', 'coach');
    expect(await coach.managedRequests(DateTime.now()), isEmpty);
  });

  testWidgets('öğretmen oturumlarını kendi ders programında görür', (t) async {
    await pump(
      t,
      const MyTimetableScreen(),
      role: 'teacher',
      tutoring: repo('demo-teacher', 'teacher'),
    );
    expect(
      find.byKey(const ValueKey('my-tutoring-ts-fizik-1')),
      findsOneWidget,
    );
  });

  testWidgets('öğrenci talebini ders programının haftasında görür', (t) async {
    await pump(
      t,
      const StudentScheduleScreen(),
      role: 'student',
      tutoring: repo('demo-student', 'student'),
    );
    await t.tap(find.text('Hafta'));
    await t.pumpAndSettle();
    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key! as ValueKey).value}'.startsWith('schedule-tutoring-'),
    );
    expect(cards, findsWidgets);
    expect(find.text('Onaylandı'), findsWidgets);
  });

  test('bildirim metinleri', () {
    AppNotification n(Map<String, dynamic> data) => AppNotification(
      id: 'n',
      kind: NotificationKind.tutoringRequest,
      createdAt: DateTime(2026, 11, 11),
      data: data,
    );
    final created = n({
      'event': 'new',
      'student': 'Ali Can',
      'branch': 'Fizik',
      'date': '2026-11-13',
      'time': '15:00',
      'route': '/teacher',
    });
    expect(created.title, 'Ali Can soru çözümü istedi');
    expect(created.body, contains('15:00 Fizik'));
    expect(created.route, '/teacher');
    final rejected = n({
      'event': 'rejected',
      'teacher': 'Selin Kaya',
      'reason': 'Dolu',
      'date': '2026-11-13',
      'time': '15:00',
    });
    expect(rejected.title, 'Talebin onaylanmadı');
    expect(rejected.body, contains('Selin Kaya · Dolu'));
    expect(rejected.route, '/student/study');
  });
}
