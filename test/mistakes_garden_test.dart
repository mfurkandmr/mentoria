import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/garden/data/garden.dart';
import 'package:mentoria/features/garden/presentation/garden_screen.dart';
import 'package:mentoria/features/mistakes/data/mistake_repository.dart';
import 'package:mentoria/features/mistakes/presentation/mistake_widgets.dart';
import 'package:mentoria/features/notifications/data/notification_repository.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('hata defteri: tekrar kuralı (sunucuyla aynı)', () {
    final now = DateTime(2026, 10, 18, 9);
    MistakeCard card(int stage) => MistakeCard(
      id: 'c',
      studentId: 's',
      subjectCode: 'TYT_MAT',
      stage: stage,
      dueOn: DateTime(2026, 10, 18),
      createdAt: now,
    );

    test('doğru: 1 → 3 → 7 → 21 gün, sonra öğrenildi', () {
      var c = card(0).reviewed(solved: true, now: now);
      expect((c.stage, c.dueOn), (1, DateTime(2026, 10, 21)));
      c = c.reviewed(solved: true, now: now);
      expect((c.stage, c.dueOn), (2, DateTime(2026, 10, 25)));
      c = c.reviewed(solved: true, now: now);
      expect((c.stage, c.dueOn), (3, DateTime(2026, 11, 8)));
      c = c.reviewed(solved: true, now: now);
      expect(c.mastered, isTrue);
    });

    test('yanlış: başa döner, yarın, hata sayısı artar', () {
      final c = card(2).reviewed(solved: false, now: now);
      expect((c.stage, c.fails, c.dueOn), (0, 1, DateTime(2026, 10, 19)));
    });

    test('tekrar zamanı gelmiş mi', () {
      expect(card(0).isDue(now), isTrue);
      expect(card(0).isDue(DateTime(2026, 10, 17)), isFalse);
    });
  });

  testWidgets('öğrenci: defter, tekrar oturumu ve sonuç', (tester) async {
    Motion.enabled = false;
    addTearDown(() => Motion.enabled = true);
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final overrides = await buildDemoOverrides('student');
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    final repo =
        container.read(mistakeRepositoryProvider) as InMemoryMistakeRepository;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: MistakesView(studentId: 'demo-student')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Demo: 2 bugün, 2 yolda, 1 öğrenildi.
    expect(find.text('Bugün tekrar · 2'), findsOneWidget);
    expect(find.text('Yaklaşan tekrarlar · 2'), findsOneWidget);
    expect(find.text('Öğrenildi · 1'), findsOneWidget);

    await tester.tap(find.text('2 soruyu şimdi tekrar et'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.text('Çözdüm'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.text('Yine yapamadım'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2 soruyu çözdün'), findsOneWidget);

    final reviewed = repo.cards.where((c) => c.id == 'demo-mistake-1').single;
    expect(reviewed.stage, 1, reason: 'ilk kart bir basamak ilerledi');
    final failed = repo.cards.where((c) => c.id == 'demo-mistake-2').single;
    expect(
      (failed.stage, failed.fails),
      (0, 1),
      reason: 'ikinci kart başa döndü',
    );

    await tester.tap(find.text('Deftere dön'));
    await tester.pumpAndSettle();
    expect(find.text('Bugün tekrar · 0'), findsNothing);
    expect(find.text('Bugünlük tekrar yok. Harika! 🎉'), findsOneWidget);
  });

  testWidgets('koç: salt okunur defter ve en çok takıldığı yerler', (
    tester,
  ) async {
    Motion.enabled = false;
    addTearDown(() => Motion.enabled = true);
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final overrides = await buildDemoOverrides('coach');
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: Scaffold(
            body: MistakesView(studentId: 'demo-student', readOnly: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('En çok takıldığı yerler'), findsOneWidget);
    expect(find.textContaining('şimdi tekrar et'), findsNothing);
    // Matematik 2 kart + 1 tekrarda yanlış = en üstte.
    expect(find.text('3'), findsOneWidget);
  });

  group('odak bahçesi', () {
    StudySession s(
      String id,
      int min, {
      String? subject,
      SessionType type = SessionType.pomodoro,
    }) => StudySession(
      id: id,
      type: type,
      startedAt: DateTime(2026, 10, 1, 10),
      durationSec: min * 60,
      subjectCode: subject,
    );

    test('çiçek türü dersten, büyüklüğü süreden', () {
      expect(FlowerKind.of('TYT_MAT'), FlowerKind.daisy);
      expect(FlowerKind.of('AYT_EDB'), FlowerKind.tulip);
      expect(FlowerKind.of('TYT_BIY'), FlowerKind.bell);
      expect(FlowerKind.of('AYT_TAR1'), FlowerKind.sunflower);
      expect(FlowerKind.of(null), FlowerKind.cosmos);
      expect(
        FlowerSize.of(s('a', 12)),
        FlowerSize.wilted,
        reason: 'yarıda kalan pomodoro',
      );
      expect(
        FlowerSize.of(s('a', 5, type: SessionType.free)),
        FlowerSize.sprout,
      );
      expect(FlowerSize.of(s('a', 15, type: SessionType.free)), FlowerSize.bud);
      expect(FlowerSize.of(s('a', 25)), FlowerSize.bloom);
      expect(FlowerSize.of(s('a', 60)), FlowerSize.grand);
    });

    test('yerleşim her açılışta aynı ve tarlanın içinde', () {
      final sessions = [for (var i = 0; i < 40; i++) s('s$i', 25 + i)];
      final a = GardenLayout.of(sessions, 390);
      final b = GardenLayout.of(sessions.reversed.toList(), 390);
      expect(
        a.flowers.map((f) => f.position),
        b.flowers.map((f) => f.position),
      );
      for (final f in a.flowers) {
        expect(f.position.dx, inInclusiveRange(18, 372));
        expect(f.position.dy, lessThan(a.size.height));
      }
      final f = a.flowers.first;
      expect(a.hit(f.position - const Offset(0, 26))?.session.id, isNotNull);
    });

    testWidgets('ekran: demo çiçekleri, dönem seçimi', (tester) async {
      Motion.enabled = false;
      addTearDown(() => Motion.enabled = true);
      final overrides = await buildDemoOverrides('student');
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(home: GardenScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Odak Bahçem'), findsOneWidget);
      expect(find.text('çiçek'), findsOneWidget);
      await tester.tap(find.text('Bu hafta'));
      await tester.pumpAndSettle();
      expect(find.text('Bu hafta'), findsOneWidget);
    });
  });

  test('yeni bildirim türleri: metin ve rota', () {
    final review = AppNotification(
      id: '1',
      kind: NotificationKind.review,
      createdAt: DateTime(2026),
      data: const {'count': 3},
    );
    expect(review.title, 'Tekrar zamanı! 🔁');
    expect(review.body, contains('3 soru'));
    expect(review.route, '/student/mistakes');
    final report = AppNotification(
      id: '2',
      kind: NotificationKind.weeklyReport,
      createdAt: DateTime(2026),
      data: const {
        'child': 'Ahmet',
        'questions': 80,
        'minutes': 50,
        'days': 3,
        'route': '/parent/child/x?tab=4',
      },
    );
    expect(
      NotificationKind.tryDb('weekly_report'),
      NotificationKind.weeklyReport,
    );
    expect(report.title, 'Ahmet için haftalık Bal Raporu 🐝');
    expect(
      report.body,
      'Bu hafta 80 soru çözdü, 50 dk odaklandı, 3 gün çalıştı.',
    );
    expect(report.route, '/parent/child/x?tab=4');
  });
}
