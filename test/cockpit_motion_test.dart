import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/features/admin/presentation/cockpit/cockpit_header.dart';
import 'package:mentoria/features/admin/presentation/cockpit/cockpit_motion.dart';
import 'package:mentoria/features/admin/presentation/cockpit/cockpit_theme.dart';
import 'package:mentoria/features/auth/data/auth_repository.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUp(() {
    final previous = Motion.enabled;
    Motion.enabled = true;
    addTearDown(() => Motion.enabled = previous);
  });

  group('Reveal', () {
    double opacityOf(WidgetTester tester, int i) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(ValueKey('section-$i')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    Future<ScrollController> pumpList(WidgetTester tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomScrollView(
            controller: controller,
            slivers: [
              SliverList.builder(
                itemCount: 30,
                itemBuilder: (_, i) => Reveal(
                  index: i,
                  child: SizedBox(height: 400, key: ValueKey('section-$i')),
                ),
              ),
            ],
          ),
        ),
      );
      return controller;
    }

    testWidgets('sayfa açılışında süzülerek belirir', (tester) async {
      await pumpList(tester);
      expect(opacityOf(tester, 0), 0);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(opacityOf(tester, 0), 1);
    });

    testWidgets('kaydırınca ilk kez kurulan bölüm anında görünür', (
      tester,
    ) async {
      final controller = await pumpList(tester);
      controller.jumpTo(8000);
      await tester.pump();
      expect(opacityOf(tester, 20), 1);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('geri dönülen bölüm animasyonu yeniden oynatmaz', (
      tester,
    ) async {
      final controller = await pumpList(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      controller.jumpTo(8000);
      await tester.pump();
      expect(find.byKey(const ValueKey('section-0')), findsNothing);
      controller.jumpTo(100);
      await tester.pump();
      expect(opacityOf(tester, 0), 1);
    });
  });

  group('Pressable', () {
    double scaleOf(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    Future<void> pumpPressable(WidgetTester tester) => tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: Pressable(
            // Boş SizedBox dokunma almaz; gerçek kart gibi dolu bir yüzey.
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ),
    );

    testWidgets('basınca küçülür, bırakınca döner', (tester) async {
      await pumpPressable(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pump();
      expect(scaleOf(tester), 0.97);
      await gesture.up();
      await tester.pump();
      expect(scaleOf(tester), 1);
    });

    testWidgets('titreyen parmak basılı kalır', (tester) async {
      await pumpPressable(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump();
      expect(scaleOf(tester), 0.97);
      await gesture.up();
    });

    testWidgets('parmak kayınca kart eski boyuna döner', (tester) async {
      await pumpPressable(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(scaleOf(tester), 1);
      // Parmak geri gelse de basılı sayılmaz.
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(scaleOf(tester), 1);
      await gesture.up();
    });
  });

  testWidgets('başlık açıkken buzlu cam filtresi yok, kapanınca var', (
    tester,
  ) async {
    await initializeDateFormatting();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentProfileProvider.overrideWith((ref) async => null)],
        child: MaterialApp(
          home: CockpitThemed(
            child: Scaffold(
              body: CustomScrollView(
                controller: controller,
                slivers: const [
                  CockpitHeader(
                    title: 'Kurum',
                    examActions: false,
                    showPending: false,
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 3000)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);

    controller.jumpTo(40);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsOneWidget);

    controller.jumpTo(0);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
