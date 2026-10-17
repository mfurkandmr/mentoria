import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/avatar/data/avatar_models.dart';
import 'package:mentoria/features/avatar/data/avatar_repository.dart';
import 'package:mentoria/features/duel/data/duel_repository.dart';
import 'package:mentoria/features/duel/presentation/duel_screens.dart';
import 'package:mentoria/features/learn/data/practice_repository.dart';
import 'package:mentoria/shared/motion.dart';

List<PracticeQuestion> pool(String subject) => [
  for (final j
      in jsonDecode(
            File('assets/learn/questions/$subject.json').readAsStringSync(),
          )
          as List)
    PracticeQuestion.fromJson(j as Map<String, dynamic>),
];

const _op = DuelOpponent(
  id: 'o',
  name: 'Can K.',
  avatar: AvatarConfig.fallback,
);

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('kazanan kuralı', () {
    Future<Duel> play({
      required int mine,
      required int myMs,
      required int theirs,
      required int theirMs,
    }) async {
      var now = DateTime(2026, 10, 17, 12);
      final repo = InMemoryDuelRepository(
        opponents: const [_op],
        loadPool: (s) async => pool(s),
        clock: () => now,
      );
      final ids = [for (final q in pool('TYT_MAT').take(10)) q.id];
      repo.seed(
        opponentId: 'o',
        subject: 'TYT_MAT',
        questionIds: ids,
        theirCorrect: theirs,
        theirMs: theirMs,
        createdAt: now,
      );
      final id = (await repo.fetchDuels()).single.id;
      await repo.start(id);
      now = now.add(Duration(milliseconds: myMs));
      final p = pool('TYT_MAT');
      await repo.finish(id, [
        for (var i = 0; i < 10; i++) i < mine ? p[i].answer : -1,
      ]);
      return (await repo.fetchDuels()).single;
    }

    test('daha çok doğru yapan kazanır (yavaş olsa da)', () async {
      final d = await play(mine: 8, myMs: 300000, theirs: 6, theirMs: 60000);
      expect((d.myCorrect, d.result), (8, DuelResult.won));
    });

    test('doğrular eşitse daha hızlı bitiren kazanır', () async {
      expect(
        (await play(mine: 7, myMs: 80000, theirs: 7, theirMs: 95000)).result,
        DuelResult.won,
      );
      expect(
        (await play(mine: 7, myMs: 99000, theirs: 7, theirMs: 95000)).result,
        DuelResult.lost,
      );
    });

    test('doğru ve süre aynıysa berabere', () async {
      expect(
        (await play(mine: 5, myMs: 90000, theirs: 5, theirMs: 90000)).result,
        DuelResult.draw,
      );
    });

    test('rakibin puanı ben bitirmeden görünmez', () async {
      final repo = InMemoryDuelRepository(
        opponents: const [_op],
        loadPool: (s) async => pool(s),
      );
      repo.seed(
        opponentId: 'o',
        subject: 'TYT_MAT',
        questionIds: [for (final q in pool('TYT_MAT').take(10)) q.id],
        theirCorrect: 9,
        theirMs: 50000,
      );
      final d = (await repo.fetchDuels()).single;
      expect(d.status, DuelStatus.yourTurn);
      expect(d.theirFinished, isTrue);
      expect(d.theirCorrect, isNull);
    });

    test('süre biçimi', () {
      expect(formatDuelTime(95200), '1:35,2');
      expect(formatDuelTime(5000), '0:05,0');
    });
  });

  group('ekran', () {
    setUp(() => Motion.enabled = false);
    tearDown(() => Motion.enabled = true);

    Future<ProviderContainer> app(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          ...await buildDemoOverrides('student'),
          for (final s in practiceSubjects)
            questionPoolProvider(s).overrideWith((ref) async => pool(s)),
        ],
      );
      addTearDown(container.dispose);
      (container.read(duelRepositoryProvider) as InMemoryDuelRepository)
          .loadPool = (s) async =>
          pool(s);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DuelsScreen()),
        ),
      );
      await tester.runAsync(() => container.read(duelsProvider.future));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('davet → kurallar → 10 soru → sonuç ve avatar ödülü', (
      tester,
    ) async {
      final c = await app(tester);
      expect(find.text('Sıra sende'), findsOneWidget);
      expect(find.text('Can K. bitirdi, sıra sende'), findsOneWidget);
      expect(
        find.text('Kazandın 🏆'),
        findsOneWidget,
        reason: 'Zeynep düellosu',
      );

      await tester.tap(find.text('Kabul et'));
      await tester.pumpAndSettle();
      // Başlamadan önce kurallar, özellikle eşitlik kuralı gösterilir.
      expect(
        find.text(
          'Doğru sayınız eşitse testi daha kısa sürede bitiren kazanır.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('30 dakika içinde bitirmelisin'),
        findsOneWidget,
      );
      expect(
        find.text('Can K. testi bitirdi. Sonucu sen bitirince görünecek.'),
        findsOneWidget,
      );

      final ids = [
        for (var i = 11; i <= 20; i++) 'TYT_MAT-${'$i'.padLeft(4, '0')}',
      ];
      final byId = {for (final q in pool('TYT_MAT')) q.id: q};
      await tester.scrollUntilVisible(
        find.text('Başla'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Başla'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        expect(find.text('Soru ${i + 1} / 10'), findsOneWidget);
        final q = byId[ids[i]]!;
        await tester.tap(find.text(q.options[q.answer]).first);
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      // Demo deposu cevap anahtarını asset'ten okur (gerçek G/Ç).
      for (
        var t = 0;
        t < 100 && find.text('Kazandın!').evaluate().isEmpty;
        t++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Kazandın!'), findsOneWidget);
      expect(find.text('10 / 10'), findsOneWidget);
      expect(find.text('7 / 10'), findsOneWidget, reason: 'Can artık görünür');
      await tester.scrollUntilVisible(
        find.text('Cevapların'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cevapların'), findsOneWidget);
      final avatars =
          c.read(avatarRepositoryProvider) as InMemoryAvatarRepository;
      expect(
        avatars.pendingUnlocks,
        contains(44),
        reason: 'ilk galibiyet: madalya',
      );
    });

    testWidgets('yeni düello: ders ve rakip seçilir, kurallar açılır', (
      tester,
    ) async {
      await app(tester);
      await tester.tap(find.text('Düello başlat'));
      await tester.pumpAndSettle();
      expect(find.text('Rakibini seç'), findsOneWidget);
      await tester.tap(find.text('Zeynep A.').last, warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.text('Davet et'));
      for (var t = 0; t < 100 && find.text('Düello').evaluate().isEmpty; t++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Düello'), findsOneWidget, reason: 'kurallar ekranı');
      await tester.scrollUntilVisible(
        find.text('Başla'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Başla'), findsOneWidget);
    });
  });
}
