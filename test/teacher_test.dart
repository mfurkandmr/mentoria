// Öğretmen rolü (NOTLAR §86): öğretmen paneli, branş düzenleme, müdürün
// öğretmenler ekranı, davet ve birleştirme. Bellekteki depolarla.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_timetable.dart';
import 'package:mentoria/features/auth/presentation/role_gate_screen.dart';
import 'package:mentoria/features/auth/data/profile.dart';
import 'package:mentoria/features/schedule_generator/domain/models.dart';
import 'package:mentoria/features/teacher/data/teacher_repository.dart';
import 'package:mentoria/features/teacher/presentation/admin_teachers_screen.dart';
import 'package:mentoria/features/teacher/presentation/teacher_home_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  Future<void> pump(
    WidgetTester t,
    Widget screen, {
    required String role,
    InMemoryTimetableRepository? timetable,
  }) async {
    t.view.physicalSize = const Size(1080, 3200);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/:a/:b/:c', builder: (_, _) => const Scaffold()),
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
          timetable,
        ),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  test('öğretmen rolü /teacher paneline gider', () {
    expect(RoleGateScreen.homeFor(UserRole.teacher), '/teacher');
    expect(UserRole.fromName('teacher'), UserRole.teacher);
  });

  test('birleştirme adayları: aynı ad, biri hesapsız biri hesaplı', () {
    final pairs = teacherMergeCandidates([
      (id: 'm1', name: 'Ayşe  Demir', hasAccount: false),
      (id: 'a1', name: 'ayşe demir', hasAccount: true),
      (id: 'a2', name: 'Can Er', hasAccount: true),
      (id: 'm2', name: 'Deniz Ak', hasAccount: false),
    ]);
    expect(pairs, hasLength(1));
    expect(pairs.single.keepId, 'm1');
    expect(pairs.single.fromId, 'a1');
  });

  testWidgets('öğretmen paneli: haftalık ders saati ve branşlar', (t) async {
    final timetable = InMemoryTimetableRepository.demo(
      viewerId: 'demo-teacher',
      viewerRole: 'teacher',
    );
    final mine = await timetable.myTimetable();
    expect(mine, isNotEmpty, reason: 'demo öğretmenin yayında dersi var');

    await pump(
      t,
      const TeacherHomeScreen(),
      role: 'teacher',
      timetable: timetable,
    );
    expect(find.text('Merhaba, Mehmet'), findsOneWidget);
    final week = find.byKey(const ValueKey('teacher-week'));
    expect(
      find.descendant(of: week, matching: find.text('${mine.length}')),
      findsOneWidget,
    );
    expect(find.text('Branşlarım'), findsOneWidget);
    expect(find.text('Fizik'), findsWidgets);
    // Öğrenci takibi yok.
    expect(find.textContaining('Kayıtlı öğrenci'), findsNothing);
  });

  testWidgets('öğretmen branşını kendisi değiştirir', (t) async {
    final timetable = InMemoryTimetableRepository.demo(
      viewerId: 'demo-teacher',
      viewerRole: 'teacher',
    );
    await pump(
      t,
      const TeacherHomeScreen(),
      role: 'teacher',
      timetable: timetable,
    );
    await t.tap(find.byKey(const ValueKey('teacher-edit-branches')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('branch-Kimya')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('teacher-save-branches')));
    await t.pumpAndSettle();
    expect(timetable.teacherOf('demo-teacher')!.teacher.branches, {
      'Fizik',
      'Kimya',
    });
    expect(find.text('Kimya'), findsOneWidget);
  });

  testWidgets('müdür öğretmenleri görür ve öğretmen daveti oluşturur', (
    t,
  ) async {
    await pump(t, const AdminTeachersScreen(), role: 'admin');
    expect(find.text('Mehmet Arslan'), findsOneWidget);
    expect(find.text('Hesabı var'), findsWidgets);
    expect(find.text('Hesap yok'), findsWidgets);

    await t.tap(find.byKey(const ValueKey('invite-teacher')));
    await t.pumpAndSettle();
    expect(find.text('Öğretmen davet et'), findsWidgets);
    expect(find.text('Bağlanacağı koç'), findsNothing);
    await t.tap(find.text('Kod oluştur'));
    await t.pumpAndSettle();
    expect(find.textContaining('OGT'), findsOneWidget);
  });

  testWidgets('müdür elle eklenen öğretmeni hesabıyla birleştirir', (t) async {
    final timetable = InMemoryTimetableRepository.demo();
    // Kayıt olan "Selin Kaya" hesabı ve müdürün daha önce elle eklediği kayıt.
    await timetable.saveTeacher(
      const Teacher(
        id: 't-selin-manual',
        name: 'Selin Kaya',
        branches: {'Kimya'},
      ),
    );
    await timetable.saveTeacher(
      const Teacher(
        id: 't-selin-auto',
        name: 'Selin Kaya',
        branches: {'Genel'},
      ),
      profileId: 'p-selin',
    );
    await pump(
      t,
      const AdminTeachersScreen(),
      role: 'admin',
      timetable: timetable,
    );
    expect(find.byKey(const ValueKey('merge-t-selin-auto')), findsOneWidget);

    await t.tap(find.text('Birleştir').first);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Birleştir').last);
    await t.pumpAndSettle();

    final setup = await timetable.fetchSetup();
    final selins = setup.teachers.where((r) => r.teacher.name == 'Selin Kaya');
    expect(selins, hasLength(1));
    expect(selins.single.teacher.id, 't-selin-manual');
    expect(selins.single.profileId, 'p-selin');
    expect(selins.single.teacher.branches, {'Kimya'});
    expect(find.byKey(const ValueKey('merge-t-selin-auto')), findsNothing);
  });
}
