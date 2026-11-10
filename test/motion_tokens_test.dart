import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/design/motion.dart';
import 'package:mentoria/shared/widgets/skeleton.dart';

/// Sabit süre / eğri kullanmasına bilinçli izin verilen dosyalar.
const _allowed = <String, String>{
  // Oyunsu, bilinçli sabitler (NOTLAR §84).
  'features/intro/intro_screen.dart': 'açılış animasyonu',
  'features/recap/presentation/recap_story_screen.dart': 'haftalık özet',
  'features/recap/presentation/recap_card.dart': 'haftalık özet kartı',
  'features/garden/presentation/garden_screen.dart': 'bahçe',
  'features/student/presentation/home_sky.dart': 'gökyüzü başlığı',
  'features/student/presentation/home_cards.dart': 'alev, kavanoz, rozet',
  'features/tracking/presentation/honey_dial.dart': 'bal kadranı dalgası',
  'features/tracking/presentation/study_view.dart': 'sayaç ve dalga',
  'shared/widgets/bizz.dart': 'maskot',
  'shared/widgets/bizz_swap.dart': 'maskot değişimi',
  'shared/widgets/effects.dart': 'konfeti',
  // Animasyon değil: zamanlayıcı, gecikme, süre hesabı.
  'core/config/app_version.dart': 'ağ zaman aşımı',
  'features/auth/presentation/invite_signup_screen.dart': 'kod sayacı',
  'features/auth/presentation/login_screen.dart': 'maskot tepkisi',
  'features/duel/presentation/duel_screens.dart': 'süre ölçümü',
  'features/notifications/presentation/notification_widgets.dart':
      'kartın kapanma süresi',
  'features/sms/presentation/bulk_sms_screen.dart': 'arama gecikmesi',
  'features/student_management/presentation/students_screen.dart':
      'arama gecikmesi',
  'shared/widgets/exit_guard.dart': 'çift geri tuşu aralığı',
};

void main() {
  test('süre ölçeği 400 ms sınırının altında', () {
    for (final d in [
      AppMotion.instant,
      AppMotion.fast,
      AppMotion.base,
      AppMotion.slow,
    ]) {
      expect(d, lessThanOrEqualTo(const Duration(milliseconds: 400)));
    }
    for (final s in [
      AppMotion.slideSmall,
      AppMotion.slide,
      AppMotion.slidePage,
      AppMotion.slideLarge,
    ]) {
      expect(s, inInclusiveRange(8, 24));
    }
  });

  test('sıralı giriş: en çok 30 ms, ilk 8 öğeden sonra gecikme yok', () {
    expect(AppMotion.stagger(0), Duration.zero);
    expect(AppMotion.stagger(1), const Duration(milliseconds: 30));
    expect(AppMotion.stagger(7), const Duration(milliseconds: 210));
    expect(AppMotion.stagger(8), Duration.zero);
    expect(AppMotion.stagger(40), Duration.zero);
  });

  test('widget kodunda sabit süre ve eğri yok (istisnalar dışında)', () {
    final pattern = RegExp(
      r'Duration\((milliseconds|seconds|microseconds):|Curves\.\w+|Cubic\(',
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/').substring('lib/'.length);
      if (path.startsWith('core/design/') ||
          path.startsWith('dev/') ||
          path.contains('/data/') ||
          _allowed.containsKey(path)) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Süre ve eğriler AppMotion üzerinden gelmeli.',
    );
  });

  test('yaylanan / taşan eğriler yalnızca oyunsu istisnalarda', () {
    final banned = RegExp(r'Curves\.(elastic\w+|bounce\w+|\w+Back)\b');
    final playful = _allowed.keys.take(11).toSet();
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/').substring('lib/'.length);
      if (playful.contains(path)) continue;
      if (banned.hasMatch(f.readAsStringSync())) offenders.add(path);
    }
    expect(offenders, isEmpty);
  });

  testWidgets('iskelet en az 300 ms görünür, sonra içerik gelir', (
    tester,
  ) async {
    final previous = Motion.enabled;
    Motion.enabled = true;
    addTearDown(() => Motion.enabled = previous);

    Widget app(bool loading) => MaterialApp(
      home: LoadSwitcher(
        loading: loading,
        skeleton: const SkeletonList(rows: 2),
        builder: (_) => const Text('içerik'),
      ),
    );

    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(app(false));
    await tester.pump(const Duration(milliseconds: 100));
    // Veri 50 ms'de geldi ama iskelet hâlâ ekranda.
    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.text('içerik'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('içerik'), findsOneWidget);
    expect(find.byType(SkeletonList), findsNothing);
  });

  testWidgets('veri hazırsa iskelet hiç görünmez', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoadSwitcher(
          loading: false,
          skeleton: const SkeletonList(),
          builder: (_) => const Text('içerik'),
        ),
      ),
    );
    expect(find.text('içerik'), findsOneWidget);
    expect(find.byType(SkeletonList), findsNothing);
  });
}
