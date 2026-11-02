import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/assignments/data/assignment_repository.dart';
import 'package:mentoria/features/assignments/presentation/prescription_card.dart';
import 'package:mentoria/features/coach/data/risk_repository.dart';
import 'package:mentoria/features/coach/presentation/risk_card.dart';
import 'package:mentoria/features/notifications/data/notification_repository.dart';
import 'package:mentoria/shared/motion.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget home,
  List<Override> o,
) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: o,
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: SingleChildScrollView(child: home)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byWidget(home)));
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  setUp(() => Motion.enabled = false);
  tearDown(() => Motion.enabled = true);

  group('Risk erken uyarısı', () {
    test('nedenler kısa ve yalnızca skoru yükseltenler', () {
      const r = RiskEntry(
        studentId: 's',
        name: 'Can',
        score: 68,
        days: 2,
        meetingsMissed: 2,
        netDrop: 4.5,
        examType: 'TYT',
        homeworkTotal: 4,
        homeworkDone: 1,
      );
      expect(r.reasons, [
        '5 gün çalışmadı',
        '2 görüşme kaçırdı',
        'TYT 4,5 net düştü',
        'ödev %25',
      ]);
      const ok = RiskEntry(
        studentId: 's',
        name: 'Ece',
        score: 0,
        days: 7,
        meetingsMissed: 0,
        netDrop: 0,
        homeworkTotal: 3,
        homeworkDone: 3,
      );
      expect(ok.reasons, isEmpty);
      final j = RiskEntry.fromJson(
        const {
          'student_id': 's',
          'full_name': 'Bora',
          'score': 49,
          'days': 4,
          'meetings_missed': 0,
          'net_drop': '8.00',
          'exam_type': 'TYT',
          'homework_total': 4,
          'homework_done': 2,
        }.map((k, v) => MapEntry(k, k == 'net_drop' ? 8.0 : v)),
      );
      expect((j.score, j.netDrop, j.reasons.length), (49, 8.0, 3));
    });

    testWidgets('koç kartı: en riskli üstte, skor ve nedenler', (tester) async {
      await _pump(
        tester,
        const RiskCard(basePath: '/coach'),
        await buildDemoOverrides('coach'),
      );
      expect(find.text('Bu hafta konuşulacaklar'), findsOneWidget);
      final can = tester.getTopLeft(find.text('Can Kaya')).dy;
      final elif = tester.getTopLeft(find.text('Elif Yılmaz')).dy;
      expect(can, lessThan(elif));
      expect(find.text('68'), findsOneWidget);
      expect(
        find.text(
          '5 gün çalışmadı · 2 görüşme kaçırdı · TYT 4,5 net düştü · ödev %25',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Skor nasıl hesaplanır?'));
      await tester.pumpAndSettle();
      expect(find.text('Risk skoru'), findsOneWidget);
    });

    test('pazartesi bildirimi metni', () {
      final n = AppNotification(
        id: '1',
        kind: NotificationKind.riskDigest,
        createdAt: DateTime(2026, 11, 2),
        data: const {
          'count': 3,
          'names': ['Can', 'Elif', 'Ali'],
          'route': '/coach',
        },
      );
      expect(n.title, 'Bu hafta 3 öğrenciyle konuş');
      expect(n.body, startsWith('Can, Elif, Ali: '));
      expect(n.route, '/coach');
    });
  });

  group('Konu reçetesi', () {
    testWidgets('taslağı düzenle, tek tuşla ödev olarak gönder', (
      tester,
    ) async {
      final c = await _pump(
        tester,
        const PrescriptionCard(studentId: 'demo-student'),
        await buildDemoOverrides('coach'),
      );
      // 4 konu; ilk ikisi tekrar eden yanlışlardan, kazanımlarıyla.
      expect(find.byType(Checkbox), findsNWidgets(4));
      expect(find.text('3 denemede 5 yanlış'), findsOneWidget);
      expect(find.text('• Cümleler arası anlam ilişkileri'), findsOneWidget);
      // 5 yanlış → 40, 4 → 40, 2 → 25, 1 → 15.
      expect(find.text('Onayla ve gönder · 4 konu, 120 soru'), findsOneWidget);

      // Son konuyu çıkar, ilk konunun sorusunu 5 artır.
      await tester.tap(find.byType(Checkbox).last);
      await tester.tap(find.byTooltip('Artır').first);
      await tester.pumpAndSettle();
      expect(find.text('Onayla ve gönder · 3 konu, 110 soru'), findsOneWidget);

      final repo = c.read(assignmentRepositoryProvider);
      final before = (await repo.fetchAssignments('demo-student')).length;
      await tester.tap(find.textContaining('Onayla ve gönder'));
      await tester.pumpAndSettle();
      final list = await repo.fetchAssignments('demo-student');
      expect(list.length, before + 1);
      final sent = list.firstWhere((a) => a.title.startsWith('Konu reçetesi'));
      expect(sent.items.length, 3);
      expect(sent.items.first.questionCount, 45);
      expect(sent.items[1].note, contains('Cümleler arası anlam ilişkileri'));
      expect(sent.dueOn, isNotNull);
      // Ödevi verilen konular taslaktan düşer; çıkarılan kalır.
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Reçete ödev olarak gönderildi.'), findsOneWidget);
    });

    testWidgets('önerilecek konu yoksa açıklama', (tester) async {
      await _pump(
        tester,
        const PrescriptionCard(studentId: 'demo-can'),
        await buildDemoOverrides('coach'),
      );
      expect(find.textContaining('Önerilecek konu yok'), findsOneWidget);
      expect(find.textContaining('Onayla ve gönder'), findsNothing);
    });
  });
}
