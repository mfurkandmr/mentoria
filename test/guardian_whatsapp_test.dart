// Veliye WhatsApp (NOTLAR §89): ödev gönderilince PDF'i veliye gider; koç
// öğrenci sayfasından veliye mesaj yazar. Bellekteki demo deposuyla.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_guardian_messaging.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/assignments/data/assignment_repository.dart';
import 'package:mentoria/features/assignments/presentation/assign_homework_screen.dart';
import 'package:mentoria/features/assignments/presentation/homework_pdf.dart';
import 'package:mentoria/features/whatsapp/presentation/guardian_message_sheet.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  Future<void> pump(
    WidgetTester t,
    Widget screen,
    InMemoryGuardianMessagingRepository guardian,
  ) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: await buildDemoOverrides(
          'coach',
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
          null,
          guardian,
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

  testWidgets('ödev PDF\'i tek sayfa A4 olarak üretilir', (t) async {
    final pdf = await t.runAsync(
      () => renderHomeworkPdf(
        orgName: 'Bal Akademi',
        senderName: 'Selin Hoca',
        studentName: 'Ahmet Çelik',
        title: 'Türev haftası',
        dueOn: DateTime(2026, 11, 20),
        note: 'Önce konu tekrarı, sonra test.',
        items: const [
          AssignmentItemDraft(
            subjectCode: 'AYT_MAT',
            topicName: 'Türev',
            questionCount: 40,
            note: 'Zor sorular sona',
          ),
          AssignmentItemDraft(subjectCode: 'TYT_TUR', questionCount: 30),
        ],
      ),
    );
    final head = latin1.decode(pdf!.sublist(0, 8));
    expect(head, startsWith('%PDF-'));
    expect(RegExp('/Type /Page[^s]').allMatches(latin1.decode(pdf)).length, 1);
  });

  testWidgets('koç ödevi gönderince PDF veliye gider', (t) async {
    final guardian = InMemoryGuardianMessagingRepository(
      phoneOf: const {'demo-student': '+905321112233'},
    );
    await pump(t, const AssignHomeworkScreen(), guardian);
    await t.tap(find.text('Elif Yılmaz'));
    await t.pumpAndSettle();
    await t.tap(find.text('AYT'));
    await t.pumpAndSettle();
    await t.tap(find.text('Parabol'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sepeti gör'));
    await t.pumpAndSettle();
    await t.tap(find.text('Öğrenciye gönder'));
    await t.pumpAndSettle();
    // PDF gerçek motorla çizilir: sahte saatin dışında bekle.
    for (var i = 0; i < 20 && guardian.uploads.isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
    }
    expect(guardian.uploads, hasLength(1));
    expect(guardian.uploads.keys.single, endsWith('.pdf'));
    // Önce "ödev gönderildi" bildirimi, ardından veli bildirimi.
    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(seconds: 1));
    expect(
      find.text("Ödev PDF'i veliye WhatsApp'tan gönderiliyor."),
      findsOneWidget,
    );
    final history = await guardian.history('demo-student');
    expect(history.single.body, 'Ödev gönderildi');
  });

  testWidgets('veli telefonu yoksa PDF üretilmez, koça söylenir', (t) async {
    final guardian = InMemoryGuardianMessagingRepository();
    await pump(t, const AssignHomeworkScreen(), guardian);
    await t.tap(find.text('Elif Yılmaz'));
    await t.pumpAndSettle();
    await t.tap(find.text('AYT'));
    await t.pumpAndSettle();
    await t.tap(find.text('Parabol'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sepeti gör'));
    await t.pumpAndSettle();
    await t.tap(find.text('Öğrenciye gönder'));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(seconds: 1));
    expect(guardian.uploads, isEmpty);
    expect(
      find.text('Veli telefonu kayıtlı olmadığı için ödev veliye gitmedi.'),
      findsOneWidget,
    );
  });

  testWidgets('koç veliye mesaj yazar, geçmişte görür, sınıra takılır', (
    t,
  ) async {
    final guardian = InMemoryGuardianMessagingRepository(
      phoneOf: const {'demo-student': '+905321112233'},
    )..seedRead('demo-student', 'Geçen haftaki mesaj');
    await pump(
      t,
      const Scaffold(
        body: GuardianMessageSheet(
          studentId: 'demo-student',
          studentName: 'Elif Yılmaz',
        ),
      ),
      guardian,
    );
    expect(find.text('Geçen haftaki mesaj'), findsOneWidget);
    expect(find.textContaining('Okundu'), findsOneWidget);

    final send = find.byKey(const ValueKey('guardian-msg-send'));
    expect(t.widget<FilledButton>(send).onPressed, isNull);
    for (var i = 0; i < 5; i++) {
      await t.enterText(
        find.byKey(const ValueKey('guardian-msg-body')),
        'Mesaj $i',
      );
      await t.pump();
      await t.tap(send);
      await t.pumpAndSettle();
    }
    expect(find.text('Mesaj 4'), findsOneWidget);
    expect(find.textContaining('Sırada'), findsNWidgets(5));

    await t.enterText(find.byKey(const ValueKey('guardian-msg-body')), 'Altı');
    await t.pump();
    await t.tap(send);
    await t.pumpAndSettle();
    expect(
      find.text('Bu veliye 24 saatte en çok 5 mesaj gönderilebilir.'),
      findsOneWidget,
    );
  });

  testWidgets('veli telefonu yoksa koç mesajı gitmez', (t) async {
    final guardian = InMemoryGuardianMessagingRepository();
    await pump(
      t,
      const Scaffold(
        body: GuardianMessageSheet(
          studentId: 'demo-student',
          studentName: 'Elif Yılmaz',
        ),
      ),
      guardian,
    );
    await t.enterText(find.byKey(const ValueKey('guardian-msg-body')), 'Selam');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('guardian-msg-send')));
    await t.pumpAndSettle();
    expect(
      find.text('Öğrencinin veli telefonu kayıtlı değil.'),
      findsOneWidget,
    );
    expect(find.text('Henüz veliye mesaj gitmedi.'), findsOneWidget);
  });
}
