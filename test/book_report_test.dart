import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_rich.dart';
import 'package:mentoria/features/student_books/data/books_repository.dart';
import 'package:mentoria/features/student_books/presentation/book_report_screen.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  setUp(() {
    demoRichEnabled = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => demoRichEnabled = false);

  test('müdür kurumu, koç yalnızca kendi öğrencilerini görür', () async {
    final admin = ProviderContainer(
      overrides: await buildDemoOverrides('admin'),
    );
    addTearDown(admin.dispose);
    final rows = await admin.read(booksRepositoryProvider).questionReport();
    final elif = rows.singleWhere(
      (r) => r.studentId == 'demo-student' && r.bookId == 'b-345',
    );
    expect(
      (elif.questions, elif.subjectCode, elif.studentName),
      (239, 'AYT_MAT', 'Elif Yılmaz'),
    );
    expect(rows.map((r) => r.studentId).toSet().length, greaterThan(15));

    final coach = ProviderContainer(
      overrides: await buildDemoOverrides('coach'),
    );
    addTearDown(coach.dispose);
    final mine = await coach.read(booksRepositoryProvider).questionReport();
    expect(mine.map((r) => r.studentId), contains('demo-student'));
    expect(mine.map((r) => r.studentId), isNot(contains('demo-emre')));

    final student = ProviderContainer(
      overrides: await buildDemoOverrides('student'),
    );
    addTearDown(student.dispose);
    expect(
      await student.read(booksRepositoryProvider).questionReport(),
      isEmpty,
    );
  });

  testWidgets('öğrenci ve kitap görünümü, arama', (t) async {
    t.view.physicalSize = const Size(1080, 2600);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: await buildDemoOverrides('admin'),
        child: const MaterialApp(
          locale: Locale('tr', 'TR'),
          supportedLocales: [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: BookReportScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.enterText(find.byKey(const ValueKey('book-report-search')), 'Elif');
    await t.pumpAndSettle();
    await t.tap(find.text('Elif Yılmaz'));
    await t.pumpAndSettle();
    expect(find.text('3-4-5 AYT Matematik'), findsOneWidget);
    expect(find.text('239 soru'), findsOneWidget);

    await t.tap(find.text('Kitaba göre'));
    await t.pumpAndSettle();
    expect(find.text('3-4-5 AYT Matematik'), findsOneWidget);

    await t.enterText(
      find.byKey(const ValueKey('book-report-search')),
      'olmayan kayıt',
    );
    await t.pumpAndSettle();
    expect(find.text('Bu süzgeçle kayıt yok.'), findsOneWidget);
  });
}
