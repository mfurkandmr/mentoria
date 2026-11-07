// Web yayını (NOTLAR §65): demo rolünün adresten okunması, sunucu
// yönlendirme listesinin router ile uyumu ve web bildirim kartı.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/config/env.dart';
import 'package:mentoria/core/settings/app_settings.dart';
import 'package:mentoria/features/notifications/push/push_service.dart';
import 'package:mentoria/features/notifications/push/web_push_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('demo rolü adresten', () {
    String role(String url) => Env.demoRoleFromUri(Uri.parse(url));

    test('?rol= önce gelir', () {
      expect(role('https://x.tr/demo/panel/?rol=coach'), 'coach');
      expect(role('https://x.tr/demo/panel/student?rol=admin'), 'admin');
    });

    test('yenilenince yoldaki rol bölümü', () {
      expect(role('https://x.tr/demo/panel/coach/students/s1'), 'coach');
      expect(role('https://x.tr/demo/panel/parent/child/c1'), 'parent');
      expect(role('https://x.tr/demo/panel/platform'), 'admin');
    });

    test('tanınmayan değer: derleme varsayılanı', () {
      expect(role('https://x.tr/demo/panel/?rol=hacker'), Env.demoRole);
      expect(role('https://x.tr/demo/panel/'), Env.demoRole);
    });
  });

  test('router üst düzey yollarının hepsi sunucu yönlendirmesinde', () {
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    final tops = RegExp(
      r"path: '/([a-z-]+)",
    ).allMatches(router).map((m) => m.group(1)!).toSet();
    // accountDeletionRoute sabit olarak tanımlı.
    final constRoute = RegExp(
      r"accountDeletionRoute = '/([a-z-]+)'",
    ).firstMatch(router)!.group(1)!;
    tops.add(constRoute);

    final py = File('tool/web/build_web.py').readAsStringSync();
    final block = RegExp(
      r'APP_ROUTES = \[(.*?)\]',
      dotAll: true,
    ).firstMatch(py)!.group(1)!;
    final listed = RegExp(
      r'"([a-z-]+)"',
    ).allMatches(block).map((m) => m.group(1)!).toSet();

    expect(tops, isNotEmpty);
    expect(
      tops.difference(listed),
      isEmpty,
      reason: 'tool/web/build_web.py APP_ROUTES eksik: sayfa yenilenince 404',
    );
  });

  group('web bildirim kartı', () {
    Future<SharedPreferences> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: Scaffold(body: WebPushPrompt())),
        ),
      );
      return prefs;
    }

    tearDown(() => PushService.webAsk.value = false);

    testWidgets('izin sorulmadıysa görünür, "Şimdi değil" 14 gün gizler', (
      tester,
    ) async {
      final prefs = await pump(tester);
      expect(find.byKey(const ValueKey('web-push-prompt')), findsNothing);

      PushService.webAsk.value = true;
      await tester.pump();
      expect(find.byKey(const ValueKey('web-push-prompt')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('web-push-later')));
      await tester.pump();
      expect(find.byKey(const ValueKey('web-push-prompt')), findsNothing);
      final until = prefs.getInt('web_push_prompt_snoozed_until')!;
      expect(
        DateTime.fromMillisecondsSinceEpoch(
          until,
        ).isAfter(DateTime.now().add(const Duration(days: 13))),
        isTrue,
      );

      // Ertelenmişken yeniden istense de görünmez.
      PushService.webAsk.value = true;
      await tester.pump();
      expect(find.byKey(const ValueKey('web-push-prompt')), findsNothing);
    });
  });

  test('web bildirimi web uygulama kimliği yoksa kapalı', () {
    // Testler dart-define olmadan çalışır.
    expect(Env.webPushConfigured, isFalse);
    expect(Env.firebaseVapidKey, isNotEmpty);
  });
}
