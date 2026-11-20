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

  // Tanıtım sayfaları sıkı CSP ile yayınlanır (tool/web/build_web.py, NOTLAR
  // §103): satır içi script, olay işleyici ve dış kaynak olursa sayfa bozulur.
  group('tanıtım sayfaları CSP ile uyumlu', () {
    const pages = [
      'site/index.html',
      'site/_legal.html',
      'site/demo/index.html',
      'site/404.html',
    ];

    test('satır içi script ve olay işleyici yok', () {
      final inline = RegExp(
        r'<script(?![^>]*\bsrc=)[^>]*>',
        caseSensitive: false,
      );
      final handler = RegExp(
        r'\son[a-z]+\s*=\s*["'
        "'"
        r']',
        caseSensitive: false,
      );
      for (final p in pages) {
        final html = File(p).readAsStringSync();
        expect(
          inline.hasMatch(html),
          isFalse,
          reason: '$p: satır içi <script>',
        );
        expect(handler.hasMatch(html), isFalse, reason: '$p: olay işleyici');
        expect(
          html.contains('<style'),
          isFalse,
          reason: '$p: satır içi <style>',
        );
        expect(
          html.contains('javascript:'),
          isFalse,
          reason: '$p: javascript:',
        );
      }
    });

    test('dış kaynak yüklenmez', () {
      final external = RegExp(
        r'''<(?:script|link|img|iframe|source)[^>]*\s(?:src|href)=["']https?://(?!mentoria\.com\.tr)''',
        caseSensitive: false,
      );
      for (final p in pages) {
        expect(
          external.hasMatch(File(p).readAsStringSync()),
          isFalse,
          reason: '$p: üçüncü taraf kaynak',
        );
      }
      expect(
        RegExp(
          r'@import|url\(\s*["'
          "'"
          r']?https?:',
        ).hasMatch(File('site/styles.css').readAsStringSync()),
        isFalse,
      );
    });

    test('CSP yalnızca kendi kaynağına izin verir, panellere uygulanmaz', () {
      final py = File('tool/web/build_web.py').readAsStringSync();
      final csp = RegExp(
        r'CSP = \((.*?)\n\)',
        dotAll: true,
      ).firstMatch(py)!.group(1)!;
      expect(csp, contains("script-src 'self'"));
      expect(csp, contains("frame-ancestors 'none'"));
      expect(csp, isNot(contains('unsafe-eval')));
      expect(csp, isNot(contains("script-src 'self' 'unsafe-inline'")));
      final paths = RegExp(r'CSP_PATHS = \((.*?)\)').firstMatch(py)!.group(1)!;
      expect(paths, isNot(contains('/app')));
      expect(paths, isNot(contains('/demo/panel')));
    });

    test('security.txt geçerli alanları içerir', () {
      final t = File('site/.well-known/security.txt').readAsStringSync();
      expect(t, contains('Contact: mailto:'));
      expect(t, contains('Expires: '));
      final exp = RegExp(r'Expires: (\S+)').firstMatch(t)!.group(1)!;
      expect(
        DateTime.parse(exp).isAfter(DateTime.now()),
        isTrue,
        reason:
            'site/.well-known/security.txt süresi doldu: Expires tarihini bir yıl ileri alın',
      );
    });
  });
}
