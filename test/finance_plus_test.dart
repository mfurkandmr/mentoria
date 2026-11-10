import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_finance.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/finance/data/finance_repository.dart';
import 'package:mentoria/features/finance/presentation/finance_plus_ui.dart';
import 'package:mentoria/features/finance/presentation/finance_screen.dart';
import 'package:mentoria/features/finance/presentation/receipt_pdf.dart';
import 'package:mentoria/shared/motion.dart';

final _d = DateTime(2026, 11, 1);

InMemoryFinanceRepository repo() => InMemoryFinanceRepository(
  students: const {'s1': 'Elif Yılmaz', 's2': 'Can Kaya', 's3': 'Ece Ak'},
  coaches: const {},
  guardians: const {'s2': ('Ayşe Kaya', '+905321112233')},
  parentOf: const {'s1'},
);

FeeDraft draft({double total = 30000, List<FeeDiscount> d = const []}) {
  final net = total - d.fold<double>(0, (s, x) => s + x.amount);
  return FeeDraft(
    studentId: 's1',
    title: 'YKS',
    total: total,
    discounts: d,
    installments: splitInstallments(net, 3, DateTime(2026, 10, 5)),
  );
}

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  group('hesaplar', () {
    test('tahsilat dağıtımı: seçilen taksit önce, sonra en eski vade', () {
      final inst = [
        FeeInstallment(
          id: 'a',
          feeId: 'f',
          dueOn: DateTime(2026, 10, 5),
          amount: 9000,
        ),
        FeeInstallment(
          id: 'b',
          feeId: 'f',
          dueOn: DateTime(2026, 11, 5),
          amount: 9000,
          paidAmount: 2000,
        ),
        FeeInstallment(
          id: 'c',
          feeId: 'f',
          dueOn: DateTime(2026, 12, 5),
          amount: 9000,
        ),
      ];
      final a = allocatePayment(inst, 12000);
      expect(
        [for (final x in a) (x.$1.id, x.$2)],
        [('a', 9000.0), ('b', 3000.0)],
      );
      final b = allocatePayment(inst, 8000, first: 'c');
      expect([for (final x in b) (x.$1.id, x.$2)], [('c', 8000.0)]);
    });

    test('ay özeti: kısmi ödeme, iade, diğer gelir', () async {
      final r = repo();
      await r.addFee(draft());
      final fee = (await r.fetchFees()).single;
      await r.recordPayment(
        fee.id,
        amount: 5000,
        paidOn: _d,
        method: PaymentMethod.cash,
      );
      await r.cancelFee(fee.id, refund: 1000, on: _d);
      await r.recordIncome(
        IncomeDraft(
          receivedOn: _d,
          category: IncomeCategory.books,
          amount: 450,
        ),
      );
      final s = monthSummary(
        await r.fetchFees(),
        const [],
        DateTime(2026, 11),
        today: _d,
        incomes: await r.fetchIncomes(),
      );
      expect(
        (s.collected, s.refunds, s.otherIncome, s.net),
        (5000.0, 1000.0, 450.0, 4450.0),
      );
    });

    test('hesap bakiyeleri: açılış + tahsilat − gider ± virman', () {
      final b = accountBalances(
        accounts: const [
          FinanceAccount(id: 'k', name: 'Kasa', openingBalance: 100),
          FinanceAccount(id: 'b', name: 'Banka'),
        ],
        fees: [
          StudentFee(
            id: 'f',
            studentName: 'x',
            title: 'x',
            total: 1,
            createdAt: _d,
            installments: const [],
            payments: [
              FeePayment(id: '1', amount: 500, paidOn: _d, accountId: 'k'),
              FeePayment(
                id: '2',
                amount: 50,
                paidOn: _d,
                accountId: 'k',
                isRefund: true,
              ),
              FeePayment(
                id: '3',
                amount: 999,
                paidOn: _d,
                accountId: 'k',
                voidedAt: _d,
              ),
            ],
          ),
        ],
        incomes: const [],
        expenses: [
          FinanceExpense(
            id: 'e',
            spentOn: _d,
            category: ExpenseCategory.rent,
            amount: 200,
            accountId: 'b',
          ),
        ],
        transfers: [
          FinanceTransfer(
            id: 't',
            fromAccount: 'k',
            toAccount: 'b',
            amount: 300,
            movedOn: _d,
          ),
        ],
      );
      expect((b['k'], b['b']), (250.0, 100.0));
    });
  });

  group('bellekteki depo (sunucu kurallarıyla)', () {
    test('kısmi ödeme, makbuz no, iptal, indirim, iade', () async {
      final r = repo();
      await r.addFee(
        draft(d: const [FeeDiscount(kind: DiscountKind.sibling, amount: 3000)]),
      );
      var fee = (await r.fetchFees()).single;
      expect(fee.netTotal, 27000);
      final p1 = await r.recordPayment(fee.id, amount: 5000, paidOn: _d);
      fee = (await r.fetchFees()).single;
      expect(p1.receiptNo, '2026-000001');
      expect(fee.installments.first.isPartial, isTrue);
      expect(fee.remaining, 22000);
      final p2 = await r.recordPayment(fee.id, amount: 13000, paidOn: _d);
      fee = (await r.fetchFees()).single;
      expect(fee.installments.take(2).every((i) => i.isPaid), isTrue);
      expect(fee.receipts.first.lines, hasLength(2));
      await expectLater(
        r.recordPayment(fee.id, amount: 99999, paidOn: _d),
        throwsA(isA<StateError>()),
      );
      await r.voidReceipt(p2.receiptNo!);
      fee = (await r.fetchFees()).single;
      expect(fee.remaining, 22000, reason: 'iptal edilen makbuz geri alındı');
      await r.addDiscount(fee.id, DiscountKind.scholarship, 10000);
      fee = (await r.fetchFees()).single;
      expect(fee.installments.map((i) => i.amount), [9000, 8000]);
      await expectLater(r.deleteFee(fee.id), throwsA(isA<StateError>()));
      final c = await r.cancelFee(fee.id, refund: 2000, on: _d);
      fee = (await r.fetchFees()).single;
      expect(fee.isCancelled, isTrue);
      expect(fee.installments.single.amount, 5000);
      expect(fee.refunded, 2000);
      expect(c.receiptNo, '2026-000003');
      expect(fee.overdue(DateTime(2030)), isEmpty);
    });

    test(
      'toplu ücret: veli telefonu yoklamadan, aynı başlık atlanır',
      () async {
        final r = repo();
        final res = await r.addFeesBulk(['s1', 's2', 'yok'], draft());
        expect(res.created, 2);
        expect(res.skipped, ['yok']);
        final can = (await r.fetchFees()).firstWhere(
          (f) => f.studentId == 's2',
        );
        expect((can.payerName, can.payerPhone), ('Ayşe Kaya', '+905321112233'));
        final again = await r.addFeesBulk(['s1'], draft());
        expect(again.created, 0);
        final dup = await r.addFeesBulk(['s1'], draft(), allowDuplicate: true);
        expect(dup.created, 1);
        expect(dup.skipped, isEmpty);
        expect(
          (await r.fetchFees()).where((f) => f.studentId == 's1').length,
          2,
        );
      },
    );

    test('veli yalnızca kendi çocuğunu görür', () async {
      final r = repo();
      await r.addFee(draft());
      expect((await r.fetchChildFinance('s1')).fees, hasLength(1));
      await expectLater(r.fetchChildFinance('s2'), throwsA(isA<StateError>()));
    });

    test('veli görünümü JSON', () {
      final c = childFinanceFromJson(
        jsonDecode('''{
          "org_name": "Bal Akademi",
          "fees": [{"id": "f", "title": "YKS", "total": 30000, "status": "active",
            "discount": 3000, "student_name": "Elif",
            "installments": [{"due_on": "2026-10-05", "amount": 9000, "paid_amount": 5000, "paid_on": null}],
            "payments": [{"receipt_no": "2026-000001", "kind": "payment", "amount": 5000, "paid_on": "2026-10-06", "method": "cash"}]}]
        }''')
            as Map<String, dynamic>,
        's1',
      );
      final f = c.fees.single;
      expect(
        (f.netTotal, f.remaining, f.receipts.single.number),
        (27000.0, 4000.0, '2026-000001'),
      );
    });
  });

  test('varsayılan hesap ödeme şekline göre', () {
    const k = FinanceAccount(id: 'k', name: 'Kasa');
    const b = FinanceAccount(id: 'b', name: 'Banka', kind: AccountKind.bank);
    const p = FinanceAccount(id: 'p', name: 'POS', kind: AccountKind.pos);
    const eski = FinanceAccount(id: 'e', name: 'Eski', archived: true);
    expect(defaultAccountFor(const [b, k], PaymentMethod.cash)?.id, 'k');
    expect(defaultAccountFor(const [k, b], PaymentMethod.transfer)?.id, 'b');
    expect(defaultAccountFor(const [k, b, p], PaymentMethod.card)?.id, 'p');
    expect(defaultAccountFor(const [k, b], PaymentMethod.card)?.id, 'b');
    expect(defaultAccountFor(const [b], PaymentMethod.cash)?.id, 'b');
    expect(defaultAccountFor(const [eski], PaymentMethod.cash), isNull);
  });

  group('ekran', () {
    late InMemoryFinanceRepository r;
    Future<void> pump(WidgetTester t, Widget home) async {
      t.view.physicalSize = const Size(1080, 2600);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: await buildDemoOverrides('admin', true, null, null, r),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(body: home),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('kısmi ödeme alınır, makbuz listede, indirim eklenir', (
      t,
    ) async {
      r = repo();
      await r.addFee(draft());
      await pump(t, const FinanceScreen());
      DefaultTabController.of(t.element(find.byType(TabBarView))).animateTo(1);
      await t.pumpAndSettle();
      await t.tap(find.text('Elif Yılmaz'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('fee-take-payment')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('payment-amount')), '4000');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('payment-save')));
      await t.pumpAndSettle();
      final fee = (await r.fetchFees()).single;
      expect(fee.paid, 4000);
      expect(find.textContaining('4.000 ₺ ödendi'), findsOneWidget);
      expect(
        find.byKey(ValueKey('receipt-${fee.receipts.single.number}')),
        findsOneWidget,
      );

      await t.tap(find.byKey(const ValueKey('fee-discount')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('discount-value')), '2000');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('discount-save')));
      await t.pumpAndSettle();
      expect((await r.fetchFees()).single.discountTotal, 2000);
    });

    testWidgets('hesap tanımlıysa ödeme şekline uyan hesap seçilir', (t) async {
      r = repo();
      await r.saveAccount(
        const FinanceAccount(id: '', name: 'Banka', kind: AccountKind.bank),
        isNew: true,
      );
      await r.saveAccount(
        const FinanceAccount(id: '', name: 'Kasa', kind: AccountKind.cash),
        isNew: true,
      );
      final kasa = (await r.fetchAccounts()).firstWhere(
        (a) => a.name == 'Kasa',
      );
      await r.addFee(draft());
      await pump(t, const FinanceScreen());
      DefaultTabController.of(t.element(find.byType(TabBarView))).animateTo(1);
      await t.pumpAndSettle();
      await t.tap(find.text('Elif Yılmaz'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('fee-take-payment')));
      await t.pumpAndSettle();
      expect(find.text('Hesap seçilmedi'), findsNothing);
      await t.tap(find.byKey(const ValueKey('payment-save')));
      await t.pumpAndSettle();
      final fee = (await r.fetchFees()).single;
      expect(fee.payments.single.accountId, kasa.id);
    });

    testWidgets('gelirler başında bu ayın öğrenci tahsilatı görünür', (
      t,
    ) async {
      r = repo();
      await r.addFee(draft());
      var fee = (await r.fetchFees()).single;
      final now = DateTime.now();
      await r.recordPayment(fee.id, amount: 5000, paidOn: now);
      // Geçen ayın ödemesi bu ayın özetine girmez.
      await r.recordPayment(
        fee.id,
        amount: 2000,
        paidOn: DateTime(now.year, now.month - 1, 15),
      );
      await pump(t, const IncomesTab());
      expect(find.text('Bu ay öğrenci tahsilatı'), findsOneWidget);
      expect(
        t
            .widget<Text>(find.byKey(const ValueKey('income-month-collected')))
            .data,
        formatMoney(5000),
      );
      // Öğrenci ödemesi gelir listesine yazılmaz.
      expect(await r.fetchIncomes(), isEmpty);
    });

    testWidgets('gelir ve hesap eklenir', (t) async {
      r = repo();
      await pump(t, const IncomesTab());
      await t.tap(find.byKey(const ValueKey('add-income')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('income-amount')), '750');
      await t.tap(find.byKey(const ValueKey('income-save')));
      await t.pumpAndSettle();
      final inc = (await r.fetchIncomes()).single;
      expect(
        (inc.amount, inc.receiptNo),
        (750.0, '${DateTime.now().year}-000001'),
      );

      await pump(t, const AccountsTab());
      await t.tap(find.byKey(const ValueKey('add-account')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('account-name')), 'Kasa');
      await t.tap(find.byKey(const ValueKey('account-save')));
      await t.pumpAndSettle();
      expect((await r.fetchAccounts()).single.name, 'Kasa');
      expect(find.text('Kasa'), findsWidgets);
    });

    testWidgets('veli ödemeler sekmesi', (t) async {
      r = repo();
      await r.addFee(draft());
      final fee = (await r.fetchFees()).single;
      await r.recordPayment(fee.id, amount: 10000, paidOn: _d);
      await pump(t, const ChildFinanceView(studentId: 's1'));
      expect(find.text('YKS'), findsOneWidget);
      expect(find.textContaining('Kalan:'), findsOneWidget);
      expect(find.textContaining('2026-000001'), findsOneWidget);
    });

    testWidgets('makbuz PDF tek sayfa', (t) async {
      final pdf = await t.runAsync(
        () => renderReceiptPdf(
          ReceiptDoc(
            number: '2026-000001',
            date: _d,
            amount: 4000,
            orgName: 'Bal Akademi',
            studentName: 'Elif',
            lines: const [('Vade taksidi', 4000)],
            remaining: 23000,
          ),
        ),
      );
      expect(latin1.decode(pdf!.sublist(0, 5)), '%PDF-');
    });
  });
}
