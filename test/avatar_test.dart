import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/avatar/data/avatar_models.dart';
import 'package:mentoria/features/avatar/data/avatar_repository.dart';
import 'package:mentoria/features/avatar/presentation/avatar_editor_screen.dart';
import 'package:mentoria/features/avatar/presentation/avatar_rule_text.dart';
import 'package:mentoria/features/avatar/presentation/leaderboard_screen.dart';
import 'package:mentoria/features/avatar/presentation/student_avatar.dart';
import 'package:mentoria/shared/motion.dart';

Future<Widget> _app(Widget screen, {List<Override> extra = const []}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: [...await buildDemoOverrides('student'), ...extra],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  group('AvatarConfig', () {
    test('JSON okuma/yazma ve geçersiz alanların atlanması', () {
      final c = AvatarConfig.fromJson({
        'hair': 3,
        'skin': 7,
        'outfit': 10,
        'accessory': 15,
        'face_photo': 'x',
        'skin_tone': 'koyu',
      });
      expect(c.toJson(), {'hair': 3, 'skin': 7, 'outfit': 10, 'accessory': 15});
      expect(AvatarConfig.fromJson(null), AvatarConfig.fallback);
      expect(AvatarConfig.fromJson({'hair': 'üç'}), AvatarConfig.fallback);
    });

    test('parça değiştirme ve eşitlik', () {
      const a = AvatarConfig.fallback;
      final b = a.withPart(AvatarCategory.accessory, 15);
      expect(b[AvatarCategory.accessory], 15);
      expect(b == a, isFalse);
      expect(b.withPart(AvatarCategory.accessory, null), a);
    });

    test('asset yolu tek yerden üretilir', () {
      expect(
        AvatarAssets.path(AvatarCategory.hair, 'hair_bun'),
        'assets/avatar/hair/hair_bun.svg',
      );
    });

    test('kilit metinleri kural verisinden üretilir', () {
      expect(
        const AvatarRule({'type': 'streak', 'days': 7}).describe(),
        '7 gün üst üste çalış',
      );
      expect(
        const AvatarRule({
          'type': 'net',
          'exam_type': 'TYT',
          'value': 60,
        }).describe(),
        'TYT denemesinde 60 net yap',
      );
      expect(
        const AvatarRule({
          'type': 'badge',
          'badge': 'questions_1000',
        }).describe(),
        '"Bin soru" rozetini aç',
      );
      expect(
        const AvatarRule({'type': 'questions', 'count': 500}).describe(),
        'Toplam 500 soru çöz',
      );
      expect(
        const AvatarRule({'type': 'study_minutes', 'minutes': 3000}).describe(),
        'Toplam 50 saat odaklan',
      );
      expect(
        const AvatarRule({'type': 'topics', 'count': 25}).describe(),
        '25 konuyu bitir',
      );
      expect(
        const AvatarRule({'type': 'exams', 'count': 5}).describe(),
        '5 denemeye gir',
      );
      expect(
        const AvatarRule({'type': 'duel_wins', 'count': 5}).describe(),
        '5 düello kazan',
      );
      expect(const AvatarRule({'type': 'uzaylı'}).describe(), 'Yakında');
    });
  });

  test('veritabanındaki her parçanın asset dosyası uygulamada var', () {
    final sql = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('avatars') || f.path.contains('duels'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    final rows = RegExp(
      r"\(\s*\d+,\s*'(hair|skin|outfit|accessory)',\s*'([a-z0-9_]+)'",
    ).allMatches(sql).toList();
    expect(rows.length, 46, reason: 'başlangıç 17 + 26 + düello ödülleri 3');
    final counts = <String, int>{};
    for (final m in rows) {
      counts[m.group(1)!] = (counts[m.group(1)!] ?? 0) + 1;
      final category = AvatarCategory.fromDb(m.group(1)!)!;
      final path = AvatarAssets.path(category, m.group(2)!);
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    expect(counts, {'hair': 14, 'skin': 6, 'outfit': 12, 'accessory': 14});
    // Demo kataloğu veritabanıyla aynı.
    expect(
      InMemoryAvatarRepository.catalog.map((i) => i.assetName).toSet(),
      rows.map((m) => m.group(2)).toSet(),
    );
  });

  testWidgets('avatar katmanları üst üste çizilir', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarRepositoryProvider.overrideWithValue(
            InMemoryAvatarRepository(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: StudentAvatar(
              config: AvatarConfig({
                AvatarCategory.hair: 3,
                AvatarCategory.skin: 9,
                AvatarCategory.outfit: 13,
                AvatarCategory.accessory: 16,
              }),
              size: 120,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final layers = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((s) => (s.bytesLoader as SvgAssetLoader).assetName)
        .toList();
    // Sıra: ten → kıyafet → saç → aksesuar.
    expect(layers, [
      'assets/avatar/skin/skin_dark.svg',
      'assets/avatar/outfit/outfit_bee.svg',
      'assets/avatar/hair/hair_bun.svg',
      'assets/avatar/accessory/acc_headphones.svg',
    ]);
  });

  testWidgets('editör: yeni açılan parça, kilitli parça ve kaydetme', (
    tester,
  ) async {
    _phone(tester);
    // Demo öğrencisi: saç 4 ve kıyafet 12 açık, pelerin (14) açılmayı bekliyor.
    await tester.pumpWidget(await _app(const AvatarEditorScreen()));
    await tester.pumpAndSettle();
    final repo =
        ProviderScope.containerOf(
              tester.element(find.byType(AvatarEditorScreen)),
            ).read(avatarRepositoryProvider)
            as InMemoryAvatarRepository;

    expect(find.text('1 yeni avatar parçası açıldı! 🎉'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(AvatarEditorScreen)),
    ).clearSnackBars();
    expect(find.text('Kaydedildi'), findsOneWidget);

    // Kilitli gökkuşağı saç: koşul gösterilir, seçilmez.
    await tester.tap(find.bySemanticsLabel(RegExp('Kilitli.*60 net')));
    await tester.pumpAndSettle();
    expect(find.text('Kilitli parça'), findsOneWidget);
    expect(find.text('Açmak için: TYT denemesinde 60 net yap'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Ücretsiz kıvırcık saç (2. kutu) seçilir ve kaydedilir.
    final tiles = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(InkWell),
    );
    await tester.tap(tiles.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Avatarın kaydedildi 🐝'), findsOneWidget);
    expect(repo.myAvatar?['hair'], 2);
  });

  testWidgets('sıralama: avatarlar ve "sen" işareti', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app(const LeaderboardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Zeynep A.'), findsOneWidget);
    expect(find.text('Elif Y. (sen)'), findsOneWidget);
    expect(find.byType(StudentAvatar), findsNWidgets(5));
  });
}
