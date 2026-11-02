import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/guidance/data/guidance_repository.dart';
import 'package:mentoria/features/guidance/presentation/guidance_widgets.dart';
import 'package:mentoria/features/notifications/data/notification_repository.dart';
import 'package:mentoria/features/parent/data/weekly_summary_repository.dart';
import 'package:mentoria/features/parent/presentation/weekly_summary_card.dart';
import 'package:mentoria/shared/motion.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget home,
  List<Override> o,
) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: o,
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: home),
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

  group('Haftalık veli özeti', () {
    const s = WeeklySummary(
      days: 5,
      questions: 340,
      minutes: 610,
      meetingsHeld: 1,
      meetingsMissed: 1,
      homeworkTotal: 8,
      homeworkDone: 6,
      examType: 'TYT',
      lastNet: 71.25,
      prevNet: 66.5,
    );

    test('hesaplar: net değişimi ve ödev yüzdesi', () {
      expect(s.netChange, 4.75);
      expect(s.homeworkPercent, 75);
      expect(s.daysOff, 2);
      final empty = WeeklySummary.fromJson(const {});
      expect(
        (empty.homeworkPercent, empty.netChange, empty.days),
        (null, null, 0),
      );
      final j = WeeklySummary.fromJson(const {
        'days': 3,
        'homework_total': 4,
        'homework_done': 3,
        'last_net': 58,
        'prev_net': 50.5,
        'exam_type': 'TYT',
      });
      expect((j.homeworkPercent, j.netChange), (75, 7.5));
    });

    test('veliye giden metin kısa ve tek parça', () {
      final text = weeklySummaryText('Elif Yılmaz', s);
      expect(text, contains('Elif Yılmaz · haftalık özet'));
      expect(text, contains('5 / 7 gün çalıştı · 1 koç görüşmesini kaçırdı'));
      expect(text, contains('Son TYT: 71,25 net (öncekinden +4,75)'));
      expect(text, contains('Ödev: 6 / 8 tamamlandı · %75'));
      expect(text.split('\n'), hasLength(5));
    });

    test('pazar bildirimi: yeni ve eski veri', () {
      final fresh = AppNotification(
        id: '1',
        createdAt: DateTime(2026, 10, 25),
        kind: NotificationKind.weeklyReport,
        data: {
          'child': 'Elif',
          'days': 5,
          'meetings_missed': 1,
          'homework_total': 8,
          'homework_done': 6,
          'exam_type': 'TYT',
          'last_net': 71.25,
          'prev_net': 66.5,
        },
      );
      expect(
        fresh.body,
        '5/7 gün çalıştı · 1 görüşme kaçırıldı · ödev %75 · TYT 71,25 net (+4,75)',
      );
      final old = AppNotification(
        id: '2',
        createdAt: DateTime(2026, 10, 18),
        kind: NotificationKind.weeklyReport,
        data: {'child': 'Elif', 'questions': 12, 'minutes': 40, 'days': 2},
      );
      expect(
        old.body,
        'Bu hafta 12 soru çözdü, 40 dk odaklandı, 2 gün çalıştı.',
      );
    });

    testWidgets('veli kartı: devam, net trendi, ödev; gönder yok', (
      tester,
    ) async {
      await _pump(
        tester,
        const WeeklySummaryCard(studentId: 'demo-student', name: 'Elif'),
        await buildDemoOverrides('parent'),
      );
      expect(find.text('5 / 7 gün çalıştı'), findsOneWidget);
      expect(find.text('1 koç görüşmesini kaçırdı'), findsOneWidget);
      expect(find.text('Son TYT: 71,25 net'), findsOneWidget);
      expect(find.text('öncekinden +4,75'), findsOneWidget);
      expect(find.text('6 / 8 tamamlandı · %75'), findsOneWidget);
      expect(find.text('Veliye gönder'), findsNothing);
    });

    testWidgets('koç kartı: veliye gönder; boş hafta', (tester) async {
      await _pump(
        tester,
        const WeeklySummaryCard(
          studentId: 'demo-zeynep',
          name: 'Zeynep',
          canShare: true,
        ),
        await buildDemoOverrides('coach'),
      );
      expect(find.text('Veliye gönder'), findsOneWidget);
      expect(find.text('0 / 7 gün çalıştı'), findsOneWidget);
      expect(find.text('Henüz deneme yok'), findsOneWidget);
      expect(find.text('Bu hafta teslimli ödev yok'), findsOneWidget);
    });
  });

  group('Rehberlik görüşme kaydı', () {
    testWidgets('koç geçmişi görür, 2 dakikada kayıt ekler', (tester) async {
      final c = await _pump(
        tester,
        Column(
          children: [
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showAddGuidanceSheet(context, 'demo-student'),
                child: const Text('aç'),
              ),
            ),
            const Expanded(child: GuidanceTimeline(studentId: 'demo-student')),
          ],
        ),
        await buildDemoOverrides('coach'),
      );
      // Ayrılmış eski koçun kaydı kurumda kalmış.
      expect(find.text('— Zehra Aksoy'), findsOneWidget);
      expect(find.text('— Ayşe Koç'), findsOneWidget);
      // Eski kayıtlar silinemez (biri başkasının, biri 24 saatten eski).
      expect(find.byTooltip('Sil'), findsNothing);

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Telefon'));
      await tester.tap(find.widgetWithText(FilterChip, 'Motivasyon'));
      await tester.tap(find.widgetWithText(FilterChip, 'Sınav kaygısı'));
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Ne konuşuldu?',
        ),
        'Deneme sonrası moral düşük, nefes egzersizi önerdim.',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Sonraki adım (isteğe bağlı)',
        ),
        'Cuma tekrar konuş',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      final repo =
          c.read(guidanceRepositoryProvider) as InMemoryGuidanceRepository;
      final added = repo.logs.last;
      expect(
        (added.kind, added.authorName, added.nextStep),
        (GuidanceKind.phone, 'Ayşe Koç', 'Cuma tekrar konuş'),
      );
      expect(added.topics, [
        GuidanceTopic.motivation,
        GuidanceTopic.examAnxiety,
      ]);
      // En yeni üstte; yalnızca yeni kayıt silinebilir.
      expect(
        tester.getTopLeft(find.textContaining('nefes egzersizi')).dy,
        lessThan(tester.getTopLeft(find.text('— Zehra Aksoy')).dy),
      );
      expect(find.byTooltip('Sil'), findsOneWidget);
      await tester.tap(find.byTooltip('Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sil'));
      await tester.pumpAndSettle();
      expect(repo.logs.where((l) => l.id == added.id), isEmpty);
    });

    testWidgets('boş not kaydedilmez', (tester) async {
      final c = await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAddGuidanceSheet(context, 'demo-can'),
            child: const Text('aç'),
          ),
        ),
        await buildDemoOverrides('coach'),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Kısa bir not yaz.'), findsOneWidget);
      final repo =
          c.read(guidanceRepositoryProvider) as InMemoryGuidanceRepository;
      expect(repo.logs.where((l) => l.studentId == 'demo-can'), isEmpty);
    });

    testWidgets('müdür her kaydı silebilir', (tester) async {
      await _pump(
        tester,
        const GuidanceTimeline(studentId: 'demo-student'),
        await buildDemoOverrides('admin'),
      );
      expect(find.byTooltip('Sil'), findsNWidgets(2));
    });

    test('silme kuralı: yazan 24 saat, müdür her zaman', () {
      final now = DateTime(2026, 10, 31, 12);
      final log = GuidanceLog(
        id: 'g',
        studentId: 's',
        authorId: 'coach',
        authorName: 'Ayşe',
        metOn: DateTime(2026, 10, 31),
        kind: GuidanceKind.inPerson,
        topics: const [],
        note: 'x',
        createdAt: now.subtract(const Duration(hours: 23)),
      );
      expect(log.deletableBy('coach', isAdmin: false, now: now), isTrue);
      expect(
        log.deletableBy(
          'coach',
          isAdmin: false,
          now: now.add(const Duration(hours: 2)),
        ),
        isFalse,
      );
      expect(log.deletableBy('other', isAdmin: false, now: now), isFalse);
      expect(log.deletableBy('admin', isAdmin: true, now: now), isTrue);
    });
  });
}
