import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/config/app_version.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/shared/widgets/update_required_screen.dart';

void main() {
  test('pubspec sürümü koddaki appVersion / appBuild ile aynı', () {
    final line = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final m = RegExp(r'version:\s*([\d.]+)\+(\d+)').firstMatch(line)!;
    expect(m.group(1), appVersion, reason: 'pubspec: $line');
    expect(int.parse(m.group(2)!), appBuild, reason: 'pubspec: $line');
  });

  test('zorunlu güncelleme kararı', () {
    const gate = UpdateGate(minBuild: 5);
    expect(gate.requiredFor(4), isTrue);
    expect(gate.requiredFor(5), isFalse);
    expect(gate.requiredFor(6), isFalse);
    expect(
      UpdateGate.fromJson(const {'min_build': 1}).requiredFor(appBuild),
      isFalse,
      reason: 'varsayılan ayar hiçbir sürümü kilitlemez',
    );
  });

  testWidgets('güncelleme ekranı', (tester) async {
    Motion.enabled = false;
    addTearDown(() => Motion.enabled = true);
    await tester.pumpWidget(
      const MaterialApp(
        home: UpdateRequiredScreen(
          gate: UpdateGate(minBuild: 99, updateUrl: 'https://example.com'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Yeni sürüm gerekli'), findsOneWidget);
    expect(find.text('Güncelle'), findsOneWidget);
    expect(find.textContaining('$appBuild'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: UpdateRequiredScreen(
          gate: UpdateGate(minBuild: 99, message: 'Sunucu bakımı'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Sunucu bakımı'), findsOneWidget);
    expect(find.text('Güncelle'), findsNothing);
    expect(find.textContaining('kurumundan ya da koçundan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
