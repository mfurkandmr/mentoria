import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/finance/data/finance_excel.dart';
import 'package:mentoria/features/finance/data/finance_repository.dart';
import 'package:mentoria/features/finance/presentation/finance_screen.dart';
import 'package:mentoria/shared/motion.dart';

FeeInstallment _i(String id, DateTime due, {DateTime? paid}) => FeeInstallment(
  id: id,
  feeId: 'f',
  dueOn: due,
  amount: 1000,
  paidOn: paid,
  method: paid == null ? null : PaymentMethod.transfer,
);

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  final fees = [
    StudentFee(
      id: 'f',
      studentId: 's',
      studentName: 'Elif Yılmaz',
      title: 'YKS kursu',
      total: 3000,
      createdAt: DateTime(2026),
      payerName: 'Selin Yılmaz',
      installments: [
        _i('a', DateTime(2026, 9, 5), paid: DateTime(2026, 9, 4)),
        _i('b', DateTime(2026, 10, 5)),
        _i('c', DateTime(2026, 11, 5), paid: DateTime(2026, 10, 20)),
      ],
    ),
  ];
  final expenses = [
    FinanceExpense(
      id: 'e1',
      spentOn: DateTime(2026, 10, 1),
      category: ExpenseCategory.rent,
      amount: 400,
    ),
    FinanceExpense(
      id: 'e2',
      spentOn: DateTime(2026, 11, 1),
      category: ExpenseCategory.rent,
      amount: 400,
    ),
  ];
  final today = DateTime(2026, 11, 10);

  List<List<String>> rows(xl.Excel book, String sheet) => [
    for (final r in book.tables[sheet]!.rows)
      [for (final c in r) c?.value.toString() ?? ''],
  ];

  test('aylık: o ayın tahsilatı, vadesi ve gideri', () {
    final book = xl.Excel.decodeBytes(
      buildFinanceWorkbook(
        fees: fees,
        expenses: expenses,
        period: const FinancePeriod.month(2026, 10),
        today: today,
      ),
    );
    expect(
      book.tables.keys,
      containsAll([
        'Özet',
        'Tahsilatlar',
        'Taksitler',
        'Giderler',
        'Öğrenci bakiyeleri',
      ]),
    );
    final summary = rows(book, 'Özet');
    String value(String label) => summary.firstWhere((r) => r[0] == label)[1];
    expect(value('Dönem'), 'Ekim 2026');
    expect(double.parse(value('Tahsilat (₺)')), 1000); // c, 20 Ekim'de ödendi
    expect(double.parse(value('Beklenen: vadesi dönemde (₺)')), 1000); // b
    expect(double.parse(value('Gider (₺)')), 400);
    expect(
      double.parse(value('Net: tahsilat + gelir − iade − gider (₺)')),
      600,
    );
    expect(double.parse(value('Diğer gelir (₺)')), 0);
    final overdue = summary.firstWhere((r) => r[0] == 'Bugün geciken taksit');
    expect(overdue[1], '1');

    final paid = rows(book, 'Tahsilatlar');
    expect(paid, hasLength(2));
    expect(
      [paid[1][0], paid[1][2], paid[1][3]],
      ['20.10.2026', 'Elif Yılmaz', 'YKS kursu'],
    );
    final due = rows(book, 'Taksitler');
    expect(due, hasLength(2));
    expect(due[1][4], 'Gecikti');
    expect(rows(book, 'Giderler'), hasLength(2));
    final balance = rows(book, 'Öğrenci bakiyeleri')[1];
    expect(
      [for (final v in balance.skip(2).take(6)) double.parse(v)],
      [3000, 0, 2000, 0, 1000, 1000],
    );
  });

  test('yıllık: ay ay tablo ve toplam', () {
    final book = xl.Excel.decodeBytes(
      buildFinanceWorkbook(
        fees: fees,
        expenses: expenses,
        period: const FinancePeriod.year(2026),
        today: today,
      ),
    );
    final summary = rows(book, 'Özet');
    final months = summary.indexWhere((r) => r[0] == 'Ay');
    expect(months, greaterThan(0));
    expect(summary[months + 1][0], 'Ocak');
    expect(summary[months + 12][0], 'Aralık');
    final total = summary[months + 13];
    expect(total[0], 'Toplam');
    expect(double.parse(total[1]), 2000); // tahsilat
    expect(double.parse(total[2]), 3000); // beklenen
    expect(double.parse(total[3]), 800); // gider
    expect(rows(book, 'Tahsilatlar'), hasLength(3));
  });

  testWidgets('finans ekranında aylık / yıllık seçimi', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: await buildDemoOverrides('admin'),
        child: const MaterialApp(
          locale: Locale('tr', 'TR'),
          supportedLocales: [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: FinanceScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('finance-export')));
    await t.pumpAndSettle();
    expect(find.text('Excel olarak indir'), findsWidgets);
    expect(find.byKey(const ValueKey('export-month')), findsOneWidget);
    await t.tap(find.text('Yıllık'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('export-month')), findsNothing);
    expect(find.byKey(const ValueKey('export-year')), findsOneWidget);
  });
}
