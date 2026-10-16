import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/settings/app_settings.dart';
import 'package:mentoria/core/sound/app_sounds.dart';
import 'package:mentoria/features/intro/intro_screen.dart';
import 'package:mentoria/features/notifications/push/push_service.dart';
import 'package:mentoria/features/student/presentation/home_sky.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/shared/widgets/bizz.dart';
import 'package:mentoria/shared/widgets/settings_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final played = <AppSound>[];

  setUpAll(() => initializeDateFormatting('tr_TR'));

  setUp(() {
    played.clear();
    AppSounds.enabled = true;
    AppSounds.debugOnPlay = played.add;
    Motion.enabled = false;
  });
  tearDown(() {
    AppSounds.debugOnPlay = null;
    AppSounds.enabled = true;
  });

  Future<ProviderContainer> container({bool? sounds}) async {
    SharedPreferences.setMockInitialValues({'sounds': ?sounds});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  testWidgets('Bızz\'a dokununca uygulamanın sesi çalar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Bizz(size: 120))),
      ),
    );
    await tester.tap(find.byType(Bizz));
    await tester.pump(const Duration(seconds: 1));
    expect(played, [AppSound.bizzTap]);
  });

  testWidgets('öğrenci panelinin gökyüzündeki Bızz\'a dokununca ses çalar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 250,
            child: SkyHeader(
              firstName: 'Elif',
              lines: ['Merhaba', 'Hadi!'],
              phase: DayPhase.day,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Bizz));
    await tester.pump(const Duration(seconds: 1));
    expect(played, [AppSound.bizzTap]);
  });

  testWidgets('açılışta Bızz uçarken açılış sesi çalar', (tester) async {
    Motion.enabled = true;
    addTearDown(() => Motion.enabled = false);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const IntroScreen()),
        GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(played, [AppSound.intro]);
    // Animasyonu bitir (sonsuz döngüler yüzünden pumpAndSettle kullanılmaz).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });

  test('ses tercihi cihazda saklanır ve çalmayı durdurur', () async {
    final c = await container();
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).sounds, isTrue, reason: 'varsayılan açık');

    c.read(settingsProvider.notifier).setSounds(false);
    expect(c.read(settingsProvider).sounds, isFalse);
    expect(AppSounds.enabled, isFalse);
    expect(c.read(sharedPreferencesProvider)!.getBool('sounds'), isFalse);

    await AppSounds.play(AppSound.bizzTap);
    expect(played, isEmpty, reason: 'kapalıyken ses çalmaz');

    // Uygulama yeniden açılınca tercih korunur.
    final again = await container(sounds: false);
    addTearDown(again.dispose);
    AppSounds.enabled = true;
    expect(again.read(settingsProvider).sounds, isFalse);
    expect(AppSounds.enabled, isFalse);
  });

  testWidgets('profildeki anahtarla sesler kapatılıp açılır', (tester) async {
    final c = await container();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AppearanceCard())),
        ),
      ),
    );
    expect(find.text('Sesler'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(c.read(settingsProvider).sounds, isFalse);
    await AppSounds.play(AppSound.bizzTap);
    expect(played, isEmpty);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(c.read(settingsProvider).sounds, isTrue);
    expect(played, [AppSound.bizzTap], reason: 'açınca örnek ses çalar');
  });

  test('her uygulama sesinin dosyası var', () {
    for (final s in AppSound.values) {
      expect(File('assets/${s.asset}').existsSync(), isTrue, reason: s.asset);
    }
  });

  test('telefon bildirimi her yerde aynı özel kanalı ve sesi kullanır', () {
    const id = PushService.channelId;
    expect(
      File('android/app/src/main/res/raw/$id.wav').existsSync(),
      isTrue,
      reason: 'kanal sesi res/raw içinde',
    );
    expect(
      File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
      contains('@raw/$id'),
      reason: 'release derlemesinde silinmesin',
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:value="$id"'),
      reason: 'FCM varsayılan kanalı',
    );
    final sendPush = File(
      'supabase/functions/send-push/index.ts',
    ).readAsStringSync();
    expect(sendPush, contains("channel_id: '$id'"));
    expect(sendPush, contains("sound: '$id.wav'"));
    expect(AppSound.notification.asset, 'sounds/$id.wav');
  });
}
