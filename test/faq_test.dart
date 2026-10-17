import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/account/presentation/profile_screen.dart';
import 'package:mentoria/features/auth/data/profile.dart';
import 'package:mentoria/features/help/data/faq.dart';
import 'package:mentoria/features/help/presentation/faq_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  test('her panelin kendi soruları var, tekrar yok', () {
    final seen = <UserRole, Set<String>>{};
    for (final role in UserRole.values) {
      final qs = [
        for (final s in faqFor(role))
          for (final i in s.items) i.question,
      ];
      expect(qs.length, greaterThanOrEqualTo(10), reason: role.name);
      expect(qs.toSet().length, qs.length, reason: '${role.name}: tekrar');
      seen[role] = qs.toSet();
    }
    // Ortak sorular dışında paneller birbirinden farklı.
    final common = seen.values.reduce((a, b) => a.intersection(b));
    expect(common, contains('Şifremi nasıl değiştiririm?'));
    expect(seen[UserRole.student], contains('Arkadaş düellosu nasıl oynanır?'));
    expect(
      seen[UserRole.coach],
      isNot(contains('Arkadaş düellosu nasıl oynanır?')),
    );
    expect(seen[UserRole.coach], contains('Öğrenciyi nasıl eklerim?'));
    expect(seen[UserRole.admin], contains('Lisans ve koltuk sayısı ne demek?'));
    expect(seen[UserRole.parent], contains('Haftalık rapor ne zaman gelir?'));
  });

  test('platform soruları yalnızca süper admine', () {
    bool has(bool superAdmin) =>
        faqFor(UserRole.admin, superAdmin: superAdmin).any(
          (s) =>
              s.items.any((i) => i.question == 'Yeni dershane nasıl eklenir?'),
        );
    expect(has(false), isFalse);
    expect(has(true), isTrue);
  });

  group('ekran', () {
    setUp(() => Motion.enabled = false);
    tearDown(() => Motion.enabled = true);

    Future<void> pump(WidgetTester tester, Widget home, String role) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: await buildDemoOverrides(role),
          child: MaterialApp(home: home),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('profilden açılır, aranır', (tester) async {
      await pump(tester, const ProfileScreen(), 'student');
      await tester.scrollUntilVisible(
        find.text('Sıkça sorulan sorular'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Öğrenci paneli hakkında'), findsOneWidget);
      await tester.tap(find.text('Sıkça sorulan sorular'));
      await tester.pumpAndSettle();
      expect(find.text('Nasıl kayıt olurum?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'düello');
      await tester.pumpAndSettle();
      expect(find.text('Arkadaş düellosu nasıl oynanır?'), findsOneWidget);
      expect(find.text('Nasıl kayıt olurum?'), findsNothing);
      expect(
        find.textContaining('eşitlikte testi daha kısa sürede bitiren kazanır'),
        findsOneWidget,
        reason: 'aramada cevaplar açık gelir',
      );

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Sonuç yok'), findsOneWidget);
    });

    testWidgets('soruya dokununca cevap açılır (koç paneli)', (tester) async {
      await pump(tester, const FaqScreen(role: UserRole.coach), 'coach');
      expect(find.text('Koç paneli hakkında'), findsOneWidget);
      expect(find.textContaining('okul numarasıyla eşleşir'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Deneme sonuçlarını toplu nasıl yüklerim?'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deneme sonuçlarını toplu nasıl yüklerim?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('okul numarasıyla eşleşir'), findsOneWidget);
    });
  });
}
