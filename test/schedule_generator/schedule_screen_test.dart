import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_timetable.dart';
import 'package:mentoria/features/schedule_generator/domain/constraints.dart';
import 'package:mentoria/features/schedule_generator/domain/schedule_generator.dart';
import 'package:mentoria/features/schedule_generator/presentation/my_timetable.dart';
import 'package:mentoria/features/schedule_generator/presentation/schedule_screen.dart';
import 'package:mentoria/features/schedule_generator/presentation/setup_wizard_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  late InMemoryTimetableRepository repo;

  Future<void> pump(
    WidgetTester t,
    Widget home, {
    String role = 'admin',
    String viewer = 'demo-admin',
  }) async {
    t.view.physicalSize = const Size(1440, 3000);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    repo = InMemoryTimetableRepository.demo(viewerId: viewer, viewerRole: role);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...await buildDemoOverrides(role, true, null, null, null, null, repo),
          // Testte isolate yok: üretici doğrudan çalışır.
          scheduleGeneratorProvider.overrideWithValue(
            (input) async => ScheduleGenerator.generate(input),
          ),
        ],
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

  testWidgets('yeni program oluşturulur, kaydedilir ve kurallara uyar', (
    t,
  ) async {
    // Önce depoyu kur, sonra yeni programı o depoda aç.
    await pump(t, const SizedBox());
    final sid = await repo.createSchedule('Bahar');
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...await buildDemoOverrides(
            'admin',
            true,
            null,
            null,
            null,
            null,
            repo,
          ),
          scheduleGeneratorProvider.overrideWithValue(
            (input) async => ScheduleGenerator.generate(input),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ScheduleScreen(scheduleId: sid, autoGenerate: true),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Program oluşturuldu'), findsOneWidget);
    expect(find.text('Çakışmalar ve eksikler'), findsNothing);

    await t.tap(find.byKey(const ValueKey('save-schedule')));
    await t.pumpAndSettle();
    final entries = await repo.fetchEntries(sid);
    final setup = await repo.fetchSetup();
    expect(entries, isNotEmpty);
    expect(validateHard(setup.toInput(), entries), isEmpty);

    // Bir derse dokun → kilitle → kaydet: kilit depoya yazılır.
    await t.tap(
      find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey &&
                '${(w.key! as ValueKey).value}'.startsWith('entry-'),
          )
          .first,
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('entry-lock')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('save-schedule')));
    await t.pumpAndSettle();
    final locked = (await repo.fetchEntries(sid)).where((e) => e.locked);
    expect(locked, hasLength(1));

    // Yeniden oluştur: kilitli ders yerinde kalır.
    await t.tap(find.byKey(const ValueKey('regenerate')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('save-schedule')));
    await t.pumpAndSettle();
    expect(await repo.fetchEntries(sid), contains(locked.single));
  });

  testWidgets('sürükle-bırak: çakışan saate taşınmaz, uyarı çıkar', (t) async {
    await pump(t, const ScheduleScreen(scheduleId: 'sch-demo'));
    final before = await repo.fetchEntries('sch-demo');
    // Sınıfın iki dersi: birini ötekinin üstüne bırak (sınıf çakışması).
    final cells = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key! as ValueKey).value}'.startsWith('entry-'),
    );
    expect(cells, findsWidgets);
    final from = t.getCenter(cells.at(0));
    final to = t.getCenter(cells.at(1));
    final g = await t.startGesture(from);
    await t.pump(const Duration(milliseconds: 700));
    await g.moveTo(to);
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(find.textContaining('Taşınamadı:'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-schedule')), findsNothing);
    expect(await repo.fetchEntries('sch-demo'), before);
  });

  testWidgets('kurulum: ders saati şablonu kaydedilir', (t) async {
    await pump(t, const TimetableSetupScreen());
    expect(find.text('Ders saatleri'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('save-slots')));
    await t.pumpAndSettle();
    expect(find.text('Ders saatleri kaydedildi.'), findsOneWidget);
    final setup = await repo.fetchSetup();
    expect(setup.slots, hasLength(36));
    // Demo programdaki saatlerin kimliği korunur (aynı gün + sıra).
    expect(setup.slots.first.id, 'slot-1-1');
  });

  testWidgets('öğrenci yayındaki programı görür', (t) async {
    await pump(
      t,
      const Scaffold(body: MyTimetableCard()),
      role: 'student',
      viewer: 'demo-student',
    );
    expect(find.text('Ders programı'), findsOneWidget);
    await t.tap(find.text('Ders programı'));
    await t.pumpAndSettle();
    expect(find.text('Güz dönemi'), findsOneWidget);
    expect(find.text('Pazartesi'), findsOneWidget);
    expect(find.textContaining('Matematik'), findsWidgets);
  });

  testWidgets('programı olmayan kurumda kart görünmez', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...await buildDemoOverrides(
            'student',
            true,
            null,
            null,
            null,
            null,
            InMemoryTimetableRepository(viewerRole: 'student'),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MyTimetableCard())),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Ders programı'), findsNothing);
  });
}
