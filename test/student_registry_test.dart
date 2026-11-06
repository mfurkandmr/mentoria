import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_students.dart';
import 'package:mentoria/dev/demo_timetable.dart';
import 'package:mentoria/features/auth/data/profile.dart';
import 'package:mentoria/features/schedule_generator/data/timetable_repository.dart';
import 'package:mentoria/features/student_management/data/student_management_repository.dart';
import 'package:mentoria/features/student_management/presentation/classes_screen.dart';
import 'package:mentoria/features/student_management/presentation/students_screen.dart';
import 'package:mentoria/features/student_registration/data/registration_repository.dart';
import 'package:mentoria/features/student_registration/domain/roster_import.dart';
import 'package:mentoria/features/student_registration/presentation/registration_screens.dart';
import 'package:mentoria/features/student_schedule/data/student_schedule.dart';
import 'package:mentoria/features/student_schedule/presentation/student_schedule_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  group('liste içe aktarma', () {
    test('sütunlar başlıktan tahmin edilir', () {
      expect(guessColumns(['Öğrenci No', 'Adı Soyadı', 'Şube', 'Veli Tel']), {
        RosterColumn.number: 0,
        RosterColumn.name: 1,
        RosterColumn.className: 2,
        RosterColumn.phone: 3,
      });
      expect(guessColumns(['Numara', 'Ad', 'Soyad']), {
        RosterColumn.number: 0,
        RosterColumn.name: 1,
        RosterColumn.surname: 2,
      });
    });

    test('doğrulama raporu: mükerrer, hatalı, eksik, telefon', () {
      final report = parseRoster([
        ['No', 'Ad Soyad', 'Sınıf', 'Veli'],
        ['1001.0', 'Elif Yılmaz', 'Sayısal-1', '0532 111 22 33'],
        ['1002', 'Can Kaya', '', '123'],
        ['1002', 'Deniz Ak', '', ''],
        ['12A', 'Ali Veli', '', ''],
        ['', 'Numarasız', '', ''],
        ['1005', '', '', ''],
        ['', '', '', ''],
      ], guessColumns(['No', 'Ad Soyad', 'Sınıf', 'Veli']));
      expect(report.total, 6);
      expect(report.valid.map((r) => r.number), ['1001']);
      expect(report.valid.single.phone, '+905321112233');
      expect(report.valid.single.className, 'Sayısal-1');
      expect(report.count(RowProblem.duplicateInFile), 2);
      expect(report.count(RowProblem.badNumber), 1);
      expect(report.count(RowProblem.missingNumber), 1);
      expect(report.count(RowProblem.missingName), 1);
      expect(report.count(RowProblem.badPhone), 1);
    });
  });

  test('şüpheli: işaretli, numarasız, sınıfsız, benzer ad', () {
    final list = suspiciousStudents(const [
      ManagedStudent(
        id: 'a',
        fullName: 'Elif Yılmaz',
        studentNumber: '1',
        classroomId: 'c',
      ),
      ManagedStudent(
        id: 'b',
        fullName: 'Elif Yilmaz',
        studentNumber: '2',
        classroomId: 'c',
      ),
      ManagedStudent(
        id: 'c',
        fullName: 'Can Kaya',
        classroomId: 'c',
        flag: NumberFlag.duplicate,
        attemptedNumber: '1',
      ),
      ManagedStudent(
        id: 'd',
        fullName: 'Deniz Ak',
        studentNumber: '4',
        classroomId: 'c',
      ),
    ]);
    expect(list.map((s) => s.student.id), ['a', 'b', 'c']);
    expect(list.last.reasons.first, contains('1 numarasını denedi'));
    expect(list.first.reasons.single, contains('Elif Yilmaz'));
  });

  test('davet: kayıt modu okunur', () {
    final info = InviteInfo.fromJson({
      'role': 'student',
      'org_name': 'Bal',
      'number_mode': 'list',
    });
    expect(info.numberFromList, isTrue);
  });

  Future<void> pump(
    WidgetTester t,
    Widget home, {
    String role = 'admin',
    InMemoryTimetableRepository? timetable,
    StudentManagementRepository? students,
    RegistrationRepository? registration,
  }) async {
    t.view.physicalSize = const Size(1080, 3200);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
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
          students,
          registration,
        ),
        child: MaterialApp(
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('sınıf yokken atama ekranı boş durum gösterir', (t) async {
    final timetable = InMemoryTimetableRepository();
    await pump(
      t,
      const StudentsScreen(basePath: '/admin'),
      timetable: timetable,
    );
    expect(find.text('Önce sınıf oluşturmalısınız'), findsOneWidget);
    expect(find.byKey(const ValueKey('empty-add-class')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('empty-add-class')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('class-name')), 'Sayısal-1');
    await t.tap(find.byKey(const ValueKey('class-save')));
    await t.pumpAndSettle();
    expect(
      (await timetable.fetchSetup()).classrooms.single.classroom.name,
      'Sayısal-1',
    );
    expect(find.text('Önce sınıf oluşturmalısınız'), findsNothing);
  });

  testWidgets('toplu atama: seçilenler sınıfa gider, programa yansır', (
    t,
  ) async {
    final timetable = InMemoryTimetableRepository.demo();
    await pump(
      t,
      const StudentsScreen(basePath: '/admin'),
      timetable: timetable,
    );
    // Demo: Elif ve Can Sayısal-1'de; kalanlar sınıfsız.
    final unassigned = demoStudents().keys
        .where((id) => timetable.classOf(id) == null)
        .toList();
    expect(unassigned, isNotEmpty);
    expect(
      find.textContaining('Sınıfı olmayanlar (${unassigned.length})'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('select-all')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('assign-selected')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pick-c-ea')));
    await t.pumpAndSettle();
    for (final id in unassigned) {
      expect(timetable.classOf(id)?.$1, 'c-ea');
    }
    expect(find.textContaining('Sınıfı olmayanlar (0)'), findsOneWidget);
  });

  testWidgets('öğrenci detayı: numara benzersiz, değişiklik kaydedilir', (
    t,
  ) async {
    final timetable = InMemoryTimetableRepository.demo();
    final repo = InMemoryStudentManagementRepository(
      timetable: timetable,
      students: const {'s1': ('Elif Yılmaz', '1042'), 's2': ('Can Kaya', null)},
      flags: const {'s2': NumberFlag.duplicate},
    );
    await pump(
      t,
      const StudentsScreen(basePath: '/coach'),
      role: 'coach',
      timetable: timetable,
      students: repo,
    );
    // Serbest modda şüpheli sekmesi var; Can işaretli.
    expect(find.textContaining('Şüpheli numaralar'), findsOneWidget);
    await t.tap(find.text('Can Kaya').first);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('edit-number')), '1042');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    expect(find.text('Bu numara zaten kullanımda.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('edit-number')), '2001');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    expect(find.text('Numara kullanılabilir'), findsOneWidget);
    expect(
      find.text('Bu değişiklik kayıt altına alınacaktır.'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('student-save')));
    await t.pumpAndSettle();
    expect(repo.numberHistory, [('s2', null, '2001')]);
    final s2 = (await repo.fetchStudents()).firstWhere((s) => s.id == 's2');
    expect(s2.studentNumber, '2001');
    expect(s2.flag, isNull);
  });

  testWidgets('liste modu: henüz kayıt olmayanlar sekmesi', (t) async {
    final registration = InMemoryRegistrationRepository(
      mode: RegistrationMode.list,
      expected: const [
        ExpectedStudent(number: '1042', fullName: 'Elif Yılmaz', matched: true),
        ExpectedStudent(number: '3001', fullName: 'Bekleyen Öğrenci'),
      ],
    );
    await pump(
      t,
      const StudentsScreen(basePath: '/admin'),
      registration: registration,
    );
    await t.ensureVisible(find.textContaining('Henüz kayıt olmayanlar (1)'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Henüz kayıt olmayanlar (1)'));
    await t.pumpAndSettle();
    expect(find.text('Bekleyen Öğrenci'), findsOneWidget);
    expect(find.text('Elif Yılmaz'), findsNothing);
  });

  testWidgets('kayıt modu değiştirilir, liste yüklenir', (t) async {
    final registration = InMemoryRegistrationRepository();
    await pump(
      t,
      const RegistrationSettingsScreen(),
      registration: registration,
    );
    await t.tap(find.byKey(const ValueKey('mode-list')));
    await t.pumpAndSettle();
    expect(find.textContaining('liste boş'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mode-confirm')));
    await t.pumpAndSettle();
    expect(registration.mode, RegistrationMode.list);

    await t.pumpWidget(const SizedBox());
    await pump(
      t,
      const RosterImportScreen(
        initialFile: {
          'Sayfa1': [
            ['Öğrenci No', 'Ad Soyad', 'Sınıf'],
            ['3001', 'Ayşe Demir', 'Sayısal-1'],
            ['30O2', 'Mehmet Can', ''],
          ],
        },
      ),
      registration: registration,
    );
    await t.tap(find.byKey(const ValueKey('roster-check')));
    await t.pumpAndSettle();
    expect(find.text('2 satır okundu'), findsOneWidget);
    expect(find.text('İçe aktar (1 satır)'), findsOneWidget);
    // Hatalı satırı düzelt.
    await t.tap(find.byKey(const ValueKey('bad-row-3')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('fix-number')), '3002');
    await t.tap(find.byKey(const ValueKey('fix-save')));
    await t.pumpAndSettle();
    expect(find.text('İçe aktar (2 satır)'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('import-go')));
    await t.pumpAndSettle();
    final list = await registration.fetchExpected();
    expect(list.map((e) => e.number), ['3001', '3002']);
    expect(list.first.className, 'Sayısal-1');
  });

  group('öğrenci ders programı', () {
    testWidgets('sınıfı yoksa boş durum', (t) async {
      final timetable = InMemoryTimetableRepository.demo(
        viewerId: 'demo-student',
        viewerRole: 'student',
      )..moveStudent('demo-student', null);
      await pump(
        t,
        const StudentScheduleScreen(),
        role: 'student',
        timetable: timetable,
      );
      expect(find.text('Henüz bir sınıfa atanmadın'), findsWidgets);
    });

    testWidgets('bugün: süren ders vurgulu; sınıf değişince yeni dersler', (
      t,
    ) async {
      final timetable = InMemoryTimetableRepository.demo(
        viewerId: 'demo-student',
        viewerRole: 'student',
      );
      final items = await timetable.myTimetable();
      final first = items.first;
      // İlk dersin günü, ders başladıktan 5 dakika sonra.
      final monday = DateTime(2026, 11, 2); // pazartesi
      final now = monday.add(
        Duration(days: first.day - 1, minutes: first.start + 5),
      );
      await pump(
        t,
        StudentScheduleScreen(now: now),
        role: 'student',
        timetable: timetable,
      );
      expect(find.textContaining('Sayısal-1'), findsWidgets);
      expect(find.text('Şimdi'), findsOneWidget);
      expect(find.text(first.branch), findsWidgets);

      // Sınıf değişti: yenileyince Eşit Ağırlık-1'in dersleri.
      timetable.moveStudent('demo-student', 'c-ea');
      final container = ProviderScope.containerOf(
        t.element(find.byType(StudentScheduleScreen)),
      );
      container.invalidate(studentScheduleProvider);
      await t.pumpAndSettle();
      expect(find.textContaining('Eşit Ağırlık-1'), findsWidgets);
      final eaToday = (await timetable.myTimetable())
          .where((i) => i.day == now.weekday)
          .map((i) => i.branch)
          .toSet();
      for (final b in eaToday) {
        expect(find.text(b), findsWidgets);
      }
    });

    testWidgets('sınıf var, program yayında değil', (t) async {
      final timetable = InMemoryTimetableRepository.demo(
        viewerId: 'demo-student',
        viewerRole: 'student',
      );
      await timetable.unpublish('sch-demo');
      await pump(
        t,
        const StudentScheduleScreen(),
        role: 'student',
        timetable: timetable,
      );
      expect(find.text('Programın henüz yayınlanmadı'), findsWidgets);
    });
  });

  testWidgets('sınıflar: içinde öğrenci olan sınıf silinmeden taşınır', (
    t,
  ) async {
    final timetable = InMemoryTimetableRepository.demo();
    await pump(
      t,
      const ClassesScreen(basePath: '/admin'),
      timetable: timetable,
    );
    expect(find.text('Sayısal-1'), findsOneWidget);
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('class-c-say')),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Sil').last);
    await t.pumpAndSettle();
    // Önce taşıma sorulur.
    expect(find.textContaining('nereye taşınsın'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('pick-c-ea')));
    await t.pumpAndSettle();
    await t.tap(find.text('Sil').last);
    await t.pumpAndSettle();
    final setup = await timetable.fetchSetup();
    expect(
      setup.classrooms.map((c) => c.classroom.id),
      isNot(contains('c-say')),
    );
    expect(timetable.classOf('demo-student')?.$1, 'c-ea');
  });

  test('sınıf değişince öğrenci görünümü güncellenir (depo)', () async {
    final timetable = InMemoryTimetableRepository.demo(
      viewerId: 'demo-student',
      viewerRole: 'student',
    );
    expect((await timetable.myClassroom())?.$2, 'Sayısal-1');
    timetable.moveStudent('demo-student', 'c-soz');
    expect((await timetable.myClassroom())?.$2, 'Sözel-1');
    final items = await timetable.myTimetable();
    expect(items.every((i) => i.classroomName == 'Sözel-1'), isTrue);
    expect(const TimetableSetup().isEmpty, isTrue);
  });
}
