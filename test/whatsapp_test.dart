// Velilere WhatsApp (NOTLAR §88): müdür kurum numarasını bağlar; bağlı
// değilse toplu mesaj ekranı mesajların sırada beklediğini söyler.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_whatsapp.dart';
import 'package:mentoria/features/sms/presentation/bulk_sms_screen.dart';
import 'package:mentoria/features/whatsapp/presentation/whatsapp_connect_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  Future<void> pump(
    WidgetTester t,
    Widget screen,
    InMemoryWhatsAppRepository wa,
  ) async {
    t.view.physicalSize = const Size(1080, 3600);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(
          path: '/admin/whatsapp',
          builder: (_, _) => const WhatsAppConnectScreen(),
        ),
        GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: await buildDemoOverrides(
          'admin',
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
          null,
          wa,
        ),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
  }

  testWidgets('bağlı değilse toplu mesaj ekranı uyarır, bağlantıya götürür', (
    t,
  ) async {
    final wa = InMemoryWhatsAppRepository();
    await pump(t, const BulkSmsScreen(), wa);
    expect(find.text('WhatsApp bağlı değil'), findsOneWidget);
    expect(
      find.text('3 mesaj sırada bekliyor; WhatsApp bağlanınca gider.'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('wa-open')));
    await t.pumpAndSettle();
    expect(find.text('WhatsApp bağlantısı'), findsOneWidget);
  });

  testWidgets('müdür numarayı bağlar, anahtar ekranda kalmaz', (t) async {
    final wa = InMemoryWhatsAppRepository();
    await pump(t, const WhatsAppConnectScreen(), wa);
    await t.enterText(find.byKey(const ValueKey('wa-phone-id')), '1098765');
    await t.enterText(find.byKey(const ValueKey('wa-waba-id')), '2012345');
    await t.enterText(
      find.byKey(const ValueKey('wa-display')),
      '+90 212 555 00 00',
    );

    // Anahtarsız ilk bağlantı olmaz.
    await t.tap(find.byKey(const ValueKey('wa-save')));
    await t.pumpAndSettle();
    expect(
      find.text('İlk bağlantıda erişim anahtarı gerekli.'),
      findsOneWidget,
    );

    final token = 'EAAG${'x' * 60}';
    await t.enterText(find.byKey(const ValueKey('wa-token')), token);
    await t.tap(find.byKey(const ValueKey('wa-save')));
    await t.pumpAndSettle();
    expect(wa.token, token);
    expect(find.text('WhatsApp bağlı · +90 212 555 00 00'), findsOneWidget);
    expect(find.textContaining(token), findsNothing);
    expect(
      find.text('Kayıtlı. Değiştirmek istemiyorsan boş bırak.'),
      findsOneWidget,
    );

    // Anahtarı yazmadan güncelleme kayıtlı anahtarı korur.
    await t.enterText(find.byKey(const ValueKey('wa-display')), '+90 212 1');
    await t.tap(find.byKey(const ValueKey('wa-save')));
    await t.pumpAndSettle();
    expect(wa.token, token);
    expect(find.text('WhatsApp bağlı · +90 212 1'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('wa-disconnect')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Kaldır'));
    await t.pumpAndSettle();
    expect(wa.token, isNull);
    expect(find.text('WhatsApp bağlı değil'), findsOneWidget);
  });

  testWidgets('bağlıyken son 30 günün sayıları görünür', (t) async {
    final wa = InMemoryWhatsAppRepository(connected: true);
    await pump(t, const BulkSmsScreen(), wa);
    expect(
      find.textContaining('Son 30 gün: 42 gönderildi · 31 okundu · 2 gitmedi'),
      findsOneWidget,
    );
  });
}
