import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/admin/presentation/admin_home_screen.dart';
import 'package:mentoria/features/avatar/data/avatar_models.dart';
import 'package:mentoria/features/avatar/data/avatar_repository.dart';
import 'package:mentoria/features/avatar/presentation/student_avatar.dart';
import 'package:mentoria/features/ranking/presentation/success_ranking_screen.dart';
import 'package:mentoria/features/student/presentation/student_home_screen.dart';
import 'package:mentoria/shared/motion.dart';

Future<Widget> _app(
  Widget screen, {
  String role = 'student',
  bool enabled = true,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: await buildDemoOverrides(role, enabled),
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

List<String> _layers(WidgetTester tester, Finder within) => tester
    .widgetList<SvgPicture>(
      find.descendant(of: within, matching: find.byType(SvgPicture)),
    )
    .map((s) => (s.bytesLoader as SvgAssetLoader).assetName)
    .toList();

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  test('ödül sırası: 1. taç, ilk 3 altın, 4–5 gümüş kanat', () {
    expect(AvatarReward.fromRank(1), AvatarReward.king);
    expect(AvatarReward.fromRank(2), AvatarReward.gold);
    expect(AvatarReward.fromRank(3), AvatarReward.gold);
    expect(AvatarReward.fromRank(4), AvatarReward.silver);
    expect(AvatarReward.fromRank(5), AvatarReward.silver);
    expect(AvatarReward.fromRank(6), isNull);
    expect(AvatarReward.fromRank(null), isNull);
    for (final r in AvatarReward.values) {
      for (final path in [r.backAsset, r.frontAsset]) {
        if (path != null) expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  testWidgets('ödül katmanları: kanat en altta, taç en üstte', (tester) async {
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
                // Seri tacı, kral tacıyla birlikte çizilmez.
                AvatarCategory.accessory: 17,
              }),
              reward: AvatarReward.king,
              size: 120,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_layers(tester, find.byType(StudentAvatar)), [
      'assets/avatar/reward/reward_wings_gold.svg',
      'assets/avatar/skin/skin_dark.svg',
      'assets/avatar/outfit/outfit_bee.svg',
      'assets/avatar/hair/hair_bun.svg',
      'assets/avatar/reward/reward_crown_king.svg',
    ]);
  });

  testWidgets('öğrenci: TYT kürsüsü, kendi tacı ve AYT alan sıralaması', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(await _app(const SuccessRankingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Başarı sıralaması'), findsOneWidget);
    expect(find.text('TYT ödülleri'), findsOneWidget);
    expect(find.text('El*** (sen)'), findsOneWidget);
    expect(find.text('84,25 net'), findsOneWidget);
    // Demo öğrencisi 1.: avatarında taç var.
    final me = find.ancestor(
      of: find.text('El*** (sen)'),
      matching: find.byType(Column),
    );
    expect(
      _layers(tester, me.first),
      contains('assets/avatar/reward/reward_crown_king.svg'),
    );
    // 6. ve 7. listede.
    await tester.scrollUntilVisible(find.text('Se***'), 200);
    expect(find.text('Me***'), findsOneWidget);
    await tester.fling(find.byType(ListView), const Offset(0, 3000), 4000);
    await tester.pumpAndSettle();

    await tester.tap(find.text('AYT'));
    await tester.pumpAndSettle();
    expect(find.text('Sayısal'), findsOneWidget);
    expect(find.text('Al***'), findsOneWidget);
    expect(find.text('54,5 net'), findsOneWidget);
    expect(find.text('Ze***'), findsNothing);

    await tester.tap(find.text('Eşit Ağırlık'));
    await tester.pumpAndSettle();
    expect(find.text('Ze***'), findsOneWidget);
    expect(find.text('Al***'), findsNothing);
  });

  testWidgets('kapalıyken öğrenci sıralamayı ve kupa düğmesini görmez', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      await _app(const SuccessRankingScreen(), enabled: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sıralama kapalı'), findsOneWidget);
    expect(find.text('El*** (sen)'), findsNothing);

    await tester.pumpWidget(
      await _app(const StudentHomeScreen(), enabled: false),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.emoji_events_rounded), findsNothing);
  });

  testWidgets('açıkken ana sayfada kart yok, üst çubukta kupa düğmesi var', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(await _app(const StudentHomeScreen()));
    await tester.pumpAndSettle();
    // Sıralama ana sayfada yer kaplamaz.
    await tester.scrollUntilVisible(find.text('Haftanın arıları'), 300);
    expect(find.text('Başarı sıralaması'), findsNothing);
    // Profilin yanındaki kupa; demo öğrencisi 1. olduğu için altın renkte.
    final cup = find.byTooltip('Başarı sıralaması · TYT\'de 1.');
    expect(cup, findsOneWidget);
    expect(
      tester
          .widget<Icon>(find.descendant(of: cup, matching: find.byType(Icon)))
          .color,
      const Color(0xFFFFC531),
    );
  });

  testWidgets('müdür: kapalıyken önizler ve anahtarla açar', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      await _app(const SuccessRankingScreen(), role: 'admin', enabled: false),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Bu bir önizleme. Öğrenciler, sen açana kadar göremez.'),
      findsOneWidget,
    );
    // Müdür öğrencilerin tam adını görür (öğrenci ve koç "El***" görür).
    expect(find.text('Elif Yılmaz'), findsOneWidget);
    expect(find.text('El***'), findsNothing);
    // Kapalıyken kimsenin avatarında ödül yok.
    expect(
      _layers(tester, find.byType(StudentAvatar)),
      isNot(contains('assets/avatar/reward/reward_crown_king.svg')),
    );

    await tester.pumpWidget(
      await _app(const AdminHomeScreen(), role: 'admin', enabled: false),
    );
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'Başarı sıralaması');
    // Genel sekmesinin listesi (diğer sekmelerin listeleri de ağaçta). Öğesi
    // bir kez bulunur; kaydırınca ilk kart ağaçtan çıkabilir.
    final overview = find
        .ancestor(
          of: find.text('Öğrenci kredisi: 120'),
          matching: find.byType(Scrollable),
        )
        .evaluate()
        .first;
    await tester.scrollUntilVisible(
      toggle,
      200,
      scrollable: find.byElementPredicate((e) => e == overview),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(
      find.text('Başarı sıralaması açıldı. Öğrenciler artık görebilir.'),
      findsOneWidget,
    );
  });
}
