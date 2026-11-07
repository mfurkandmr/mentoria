import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/shared/widgets/bizz.dart';
import 'package:mentoria/shared/widgets/brand_logo.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('varsayılan markada logo M (lacivert kare) ve ad', (
    tester,
  ) async {
    await pump(tester, const BrandLogo());
    expect(find.byType(MentoriaMark), findsOneWidget);
    expect(find.text('Mentoria'), findsOneWidget);
    expect(find.byType(Bizz), findsNothing);
  });

  testWidgets('öğrenci panelinde logo yalnızca arı', (tester) async {
    await pump(tester, const BrandLogo(student: true, onDark: true));
    expect(find.byType(Bizz), findsOneWidget);
    expect(find.byType(MentoriaMark), findsNothing);
  });
}
