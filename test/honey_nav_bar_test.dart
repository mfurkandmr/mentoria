import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/theme/app_theme.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/shared/widgets/honey_nav_bar.dart';

void main() {
  setUpAll(() => Motion.enabled = false);

  testWidgets(
    'alt menü: dokunulan sekme seçilir, seçili olan ekran okuyucuya bildirilir',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              bottomNavigationBar: HoneyNavBar(
                selectedIndex: selected,
                onSelected: (i) => setState(() => selected = i),
                items: const [
                  HoneyNavItem(icon: Icons.home_outlined, label: 'Ana Sayfa'),
                  HoneyNavItem(icon: Icons.timer_outlined, label: 'Süre'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Ana Sayfa')),
        matchesSemantics(
          label: 'Ana Sayfa',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text('Süre'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Süre')),
        matchesSemantics(
          label: 'Süre',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      // Dokunma alanı en az 48 piksel.
      expect(
        tester.getSize(find.bySemanticsLabel('Süre')).height,
        greaterThanOrEqualTo(48),
      );
    },
  );
}
