import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/sound/app_sounds.dart';
import 'package:mentoria/features/student/data/bizz_shake.dart';
import 'package:mentoria/features/student/presentation/home_sky.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/shared/widgets/bizz.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Accel = ({double x, double y, double z});

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('sallama algılama', () {
    late DateTime now;
    late StreamController<Accel> sensor;
    late int shakes;
    late ShakeDetector detector;

    setUp(() {
      now = DateTime(2026, 10, 16, 12);
      sensor = StreamController<Accel>(sync: true);
      shakes = 0;
      detector = ShakeDetector(
        onShake: () => shakes++,
        source: sensor.stream,
        clock: () => now,
      );
    });
    tearDown(() => detector.dispose());

    void jolt(double g, {int afterMs = 200}) {
      now = now.add(Duration(milliseconds: afterMs));
      sensor.add((x: g, y: 0, z: 0));
    }

    test('kısa sürede üç güçlü sarsıntı = bir sallama', () {
      jolt(20);
      jolt(-18);
      expect(shakes, 0);
      jolt(22);
      expect(shakes, 1);
    });

    test('tek sarsıntı, yavaş hareket ve aralıklı darbeler sayılmaz', () {
      for (var i = 0; i < 10; i++) {
        jolt(6); // yürüme
      }
      jolt(25); // cebe koyma
      jolt(25, afterMs: 1500);
      jolt(25, afterMs: 1500);
      expect(shakes, 0);
    });

    test('aynı darbenin ardışık örnekleri tek sayılır', () {
      jolt(20);
      jolt(20, afterMs: 30);
      jolt(20, afterMs: 30);
      expect(shakes, 0);
    });

    test('algıladıktan sonra kısa süre bekler', () {
      jolt(20);
      jolt(20);
      jolt(20);
      jolt(20);
      jolt(20);
      jolt(20);
      expect(shakes, 1);
      now = now.add(const Duration(seconds: 3));
      jolt(20);
      jolt(20);
      jolt(20);
      expect(shakes, 2);
    });
  });

  group('saatte en fazla iki değişim', () {
    test(
      'üçüncüsü bir saat dolana kadar bekler, uygulama yeniden açılsa da',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        var now = DateTime(2026, 10, 16, 12);
        BizzSwapLimit limit() => BizzSwapLimit(prefs, clock: () => now);

        expect(limit().tryUse(), isTrue);
        now = now.add(const Duration(minutes: 10));
        expect(limit().tryUse(), isTrue);
        now = now.add(const Duration(minutes: 5));
        expect(limit().tryUse(), isFalse);
        // İlk kullanımın üstünden 1 saat geçince bir hak açılır.
        expect(limit().waitTime(), const Duration(minutes: 45));
        now = now.add(const Duration(minutes: 45));
        expect(limit().waitTime(), isNull);
        expect(limit().tryUse(), isTrue);
        expect(limit().tryUse(), isFalse);
      },
    );
  });

  group('gökyüzü başlığında', () {
    final played = <AppSound>[];
    var fakeNow = DateTime(2026, 10, 16, 12);
    setUp(() {
      played.clear();
      AppSounds.debugOnPlay = played.add;
    });
    tearDown(() {
      AppSounds.debugOnPlay = null;
      Motion.enabled = true;
    });

    Future<StreamController<Accel>> pumpSky(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
      bool withLimit = true,
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final p = await SharedPreferences.getInstance();
      final sensor = StreamController<Accel>();
      // Dinlenmeyen akışın kapanışı beklenmez.
      addTearDown(() => unawaited(sensor.close()));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 260,
              child: SkyHeader(
                firstName: 'Elif',
                lines: const ['Merhaba'],
                phase: DayPhase.day,
                swapLimit: withLimit ? BizzSwapLimit(p) : null,
                shakeSource: sensor.stream,
                shakeClock: () => fakeNow,
              ),
            ),
          ),
        ),
      );
      return sensor;
    }

    Future<void> shake(WidgetTester tester, StreamController<Accel> s) async {
      for (var i = 0; i < 3; i++) {
        fakeNow = fakeNow.add(const Duration(milliseconds: 200));
        s.add((x: 25, y: 0, z: 0));
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('sallayınca yeni arı gelir, çarpar, yerine geçer ve konuşur', (
      tester,
    ) async {
      Motion.enabled = true;
      final sensor = await pumpSky(tester);
      expect(find.byType(Bizz), findsOneWidget);

      await shake(tester, sensor);
      expect(played, [AppSound.bizzBump]);
      // Animasyon ortası: iki arı birden.
      expect(find.byType(Bizz), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump();
      expect(find.byType(Bizz), findsOneWidget, reason: 'eski arı gitti');
      expect(
        find.textContaining(RegExp('Nöbet|çarptım|Yeni arı|Vızz!')),
        findsOneWidget,
      );
      // Dokununca normal konuşmaya döner.
      await tester.tap(find.byType(Bizz));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Merhaba'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hak dolduysa arı başını sallar, ne zaman açılacağını söyler', (
      tester,
    ) async {
      Motion.enabled = false;
      final now = DateTime.now();
      final sensor = await pumpSky(
        tester,
        prefs: {
          'bizz_swap_times': [
            '${now.subtract(const Duration(minutes: 50)).millisecondsSinceEpoch}',
            '${now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch}',
          ],
        },
      );
      await shake(tester, sensor);
      expect(played, isEmpty);
      expect(
        find.text('Arılar dinleniyor 😴 10 dk sonra yine salla.'),
        findsOneWidget,
      );
    });

    testWidgets('koç / müdür başlığında sallama kapalı', (tester) async {
      Motion.enabled = false;
      final sensor = await pumpSky(tester, withLimit: false);
      await shake(tester, sensor);
      await tester.pump(const Duration(seconds: 2));
      expect(played, isEmpty);
      expect(find.text('Merhaba'), findsOneWidget);
    });
  });
}
