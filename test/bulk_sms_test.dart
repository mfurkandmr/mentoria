import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_sms.dart';
import 'package:mentoria/features/sms/data/bulk_sms_repository.dart';
import 'package:mentoria/features/sms/presentation/bulk_sms_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  test('SMS sayısı', () {
    expect(smsSegments(''), 0);
    expect(smsSegments('a' * 155), 1);
    expect(smsSegments('ğ' * 156), 2);
    expect(smsSegments('Merhaba 😀'), 1);
    expect(smsSegments('😀' * 40), 2);
  });

  late InMemoryBulkSmsRepository repo;

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 3600);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    repo = InMemoryBulkSmsRepository(
      phoneOf: const {
        's1': '+905321112233',
        's2': '+905321112233', // kardeş
        's3': '+905334445566',
        's4': null,
      },
      classOf: (s) => s == 's3' ? 'c-ea' : 'c-say',
      orgName: 'Bal Akademi',
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
          repo,
        ),
        child: const MaterialApp(
          locale: Locale('tr', 'TR'),
          supportedLocales: [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: BulkSmsScreen(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
  }

  testWidgets('tüm velilere: kardeşlere tek SMS, metin kurum adıyla', (
    t,
  ) async {
    await pump(t);
    expect(find.text('2 veliye gidecek'), findsOneWidget);
    expect(find.text('1 öğrencinin veli telefonu yok'), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('sms-body')),
      '29 Ekim nedeniyle kurumumuz kapalıdır.',
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('sms-send')));
    await t.pumpAndSettle();
    expect(find.text('2 veliye SMS gönderilsin mi?'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sms-confirm')));
    await t.pumpAndSettle();
    expect(repo.outbox, [
      ('+905321112233', 'Bal Akademi: 29 Ekim nedeniyle kurumumuz kapalıdır.'),
      ('+905334445566', 'Bal Akademi: 29 Ekim nedeniyle kurumumuz kapalıdır.'),
    ]);
    expect(find.text('2 veliye SMS sırasına alındı.'), findsOneWidget);
    expect(find.textContaining('2 sırada'), findsOneWidget);

    // 10 dakika dolmadan ikinci gönderim olmaz.
    await t.enterText(find.byKey(const ValueKey('sms-body')), 'Tekrar');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('sms-send')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('sms-confirm')));
    await t.pumpAndSettle();
    expect(find.textContaining('10 dakika'), findsOneWidget);
    expect(repo.outbox, hasLength(2));
  });

  testWidgets('sınıf ve öğrenci seçimi', (t) async {
    await pump(t);
    await t.tap(find.text('Sınıflar'));
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.text('0 veliye gidecek'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sms-class-c-ea')));
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.text('1 veliye gidecek'), findsOneWidget);

    await t.tap(find.text('Öğrenciler'));
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.text('Öğrenci seç (0)'), findsOneWidget);
    expect(
      tester(
        t,
      ).widget<FilledButton>(find.byKey(const ValueKey('sms-send'))).onPressed,
      isNull,
    );
  });

  testWidgets('hazır metin seçilir', (t) async {
    await pump(t);
    await t.tap(find.text('Resmi tatil'));
    await t.pump();
    expect(find.textContaining('Resmi tatil nedeniyle'), findsOneWidget);
  });
}

WidgetTester tester(WidgetTester t) => t;
