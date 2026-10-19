import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/settings/app_settings.dart';
import 'package:mentoria/core/sound/app_sounds.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/tracking/data/pomodoro_alarm.dart';
import 'package:mentoria/features/tracking/data/tracking_repository.dart';
import 'package:mentoria/features/tracking/presentation/study_view.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final log = <String>[];
  final assets = <String>[];

  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });
  setUp(() {
    log.clear();
    assets.clear();
    PomodoroAlarm.debugLog = log.add;
    AppSounds.debugOnPlayAsset = assets.add;
  });
  tearDown(() {
    PomodoroAlarm.debugLog = null;
    AppSounds.debugOnPlayAsset = null;
  });

  Future<(Widget, ProviderContainer)> app(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        ...await buildDemoOverrides('student'),
        sharedPreferencesProvider.overrideWithValue(p),
      ],
    );
    return (
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('tr', 'TR'),
          supportedLocales: [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudyTimerCard(studentId: 'demo-student'),
            ),
          ),
        ),
      ),
      c,
    );
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('pomodoro başlayınca bitiş alarmı kurulur, duraklatınca iptal', (
    tester,
  ) async {
    phone(tester);
    final (w, c) = await app({});
    addTearDown(c.dispose);
    await tester.pumpWidget(w);
    await tester.pump();

    expect(find.textContaining('Bal Kavanozu'), findsOneWidget);
    final before = DateTime.now();
    await tester.tap(find.text('Başlat'));
    await tester.pump();

    final schedule = log.firstWhere((e) => e.startsWith('schedule '));
    expect(schedule, startsWith('schedule work bal '));
    final at = DateTime.parse(schedule.split(' ').last);
    expect(
      at.difference(before).inMinutes,
      inInclusiveRange(24, 25),
      reason: 'varsayılan 25 dakika sonra çalar',
    );
    expect(log.any((e) => e.startsWith('running ')), isTrue);
    expect(
      find.textContaining('Uygulamadan çıksan da süre bitince'),
      findsOneWidget,
    );
    // Durum cihazda saklanır (uygulama kapanırsa geri yüklenir).
    final saved = jsonDecode(
      c.read(sharedPreferencesProvider)!.getString('pomodoro_state')!,
    );
    expect(saved['phase'], 'work');

    log.clear();
    await tester.tap(find.text('Duraklat'));
    await tester.pump();
    expect(log, contains('cancel'));
    await tester.tap(find.text('Bitir ve kaydet'));
    await tester.pump();
    expect(
      c.read(sharedPreferencesProvider)!.getString('pomodoro_state'),
      isNull,
    );
  });

  testWidgets('zil seçilir, dinletilir ve saklanır; titreşim seçilebilir', (
    tester,
  ) async {
    phone(tester);
    final (w, c) = await app({});
    addTearDown(c.dispose);
    await tester.pumpWidget(w);
    await tester.pump();

    await tester.tap(find.textContaining('Bitiş sesi'));
    await tester.pumpAndSettle();
    for (final t in AlarmTone.values) {
      expect(find.text(t.label), findsOneWidget);
    }
    await tester.tap(find.text('Gong'));
    await tester.pump();
    expect(assets, ['sounds/pomodoro_gong.wav'], reason: 'dokununca dinletir');
    await tester.ensureVisible(find.text('Yalnızca titreşim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yalnızca titreşim'));
    await tester.pump();
    await tester.ensureVisible(find.text('Seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();

    expect(c.read(settingsProvider).pomodoroTone, AlarmTone.vibrate);
    expect(
      c.read(sharedPreferencesProvider)!.getString('pomodoro_tone'),
      'vibrate',
    );
    expect(find.textContaining('Yalnızca titreşim'), findsOneWidget);

    await tester.tap(find.text('Başlat'));
    await tester.pump();
    expect(log.first, startsWith('schedule work vibrate '));
    await tester.tap(find.text('Bitir ve kaydet'));
    await tester.pump();
  });

  testWidgets(
    'uygulama kapalıyken süre dolduysa açılınca oturum kaydedilir ve mola sürer',
    (tester) async {
      phone(tester);
      final now = DateTime.now();
      // 25 dakikalık odak 27 dakika önce başlamış; mola (5 dk) 3 dk daha sürer.
      final started = now.subtract(const Duration(minutes: 27));
      final (w, c) = await app({
        'pomodoro_state': jsonEncode({
          'phase': 'work',
          'mode': 'pomodoro',
          'work': 25,
          'rest': 5,
          'subject': null,
          'sessionStart': started.toIso8601String(),
          'segmentStart': started.toIso8601String(),
          'accumulatedMs': 0,
          'restEnd': null,
          'alarmSet': true,
        }),
      });
      addTearDown(c.dispose);
      final before =
          (await c
                  .read(trackingRepositoryProvider)
                  .fetchSessions('demo-student', since: DateTime(2000)))
              .length;
      await tester.pumpWidget(w);
      await tester.pump();
      await tester.pump();

      final sessions = await c
          .read(trackingRepositoryProvider)
          .fetchSessions('demo-student', since: DateTime(2000));
      expect(sessions.length, before + 1, reason: 'oturum kaydedildi');
      expect(sessions.any((s) => s.durationSec == 25 * 60), isTrue);
      expect(
        log.where((e) => e.startsWith('ring ')),
        isEmpty,
        reason: 'bildirim zaten çaldı; uygulama ikinci kez çalmaz',
      );
      expect(
        log,
        contains('fireIfLate work'),
        reason: 'sistem zili ertelediyse uygulama fark edince hemen çalsın',
      );
      expect(find.text('Mola'), findsWidgets, reason: 'mola sürüyor');
      final rest = log.firstWhere((e) => e.startsWith('schedule rest '));
      final restAt = DateTime.parse(rest.split(' ').last);
      expect(
        restAt.difference(now).inMinutes,
        inInclusiveRange(2, 3),
        reason: 'mola odağın bittiği andan sayılır',
      );
      await tester.tap(find.text('Molayı atla'));
      await tester.pump();
    },
  );

  testWidgets('bildirim kurulamadıysa süre bitince zil uygulamada çalar', (
    tester,
  ) async {
    phone(tester);
    final started = DateTime.now().subtract(const Duration(minutes: 40));
    final (w, c) = await app({
      'pomodoro_tone': 'kristal',
      'pomodoro_state': jsonEncode({
        'phase': 'work',
        'mode': 'pomodoro',
        'work': 25,
        'rest': 5,
        'subject': null,
        'sessionStart': started.toIso8601String(),
        'segmentStart': started.toIso8601String(),
        'accumulatedMs': 0,
        'restEnd': null,
        'alarmSet': false,
      }),
    });
    addTearDown(c.dispose);
    await tester.pumpWidget(w);
    await tester.pump();
    await tester.pump();
    expect(log, contains('ring kristal'));
    expect(assets, contains('sounds/pomodoro_kristal.wav'));
    // Mola da çoktan bitmiş: zamanlayıcı başa döner.
    expect(find.text('Başlat'), findsOneWidget);
  });
}
