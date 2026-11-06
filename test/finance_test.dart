import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_finance.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/coach/data/coach_repository.dart';
import 'package:mentoria/features/finance/data/finance_repository.dart';
import 'package:mentoria/features/finance/presentation/finance_screen.dart';
import 'package:mentoria/shared/motion.dart';

FeeInstallment _inst(String id, DateTime due, {DateTime? paidOn}) =>
    FeeInstallment(
      id: id,
      feeId: 'f',
      dueOn: due,
      amount: 1000,
      paidOn: paidOn,
      method: paidOn == null ? null : PaymentMethod.cash,
    );

StudentFee _fee(List<FeeInstallment> list) => StudentFee(
  id: 'f',
  studentId: 'demo-student',
  studentName: 'Elif Yılmaz',
  title: 'YKS kursu',
  total: 1000.0 * list.length,
  createdAt: DateTime(2026),
  installments: list,
);

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  group('hesaplar', () {
    test('taksitler tam lira, kuruş farkı sonda, ay sonu kayar', () {
      final plan = splitInstallments(10000, 3, DateTime(2026, 1, 31));
      expect([for (final p in plan) p.$2], [3333, 3333, 3334]);
      expect(
        [for (final p in plan) p.$1],
        [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31)],
      );
      expect(splitInstallments(999.5, 1, DateTime(2026, 5, 5)), [
        (DateTime(2026, 5, 5), 999.5),
      ]);
      final odd = splitInstallments(100.5, 2, DateTime(2026, 12, 15));
      expect(odd.fold<double>(0, (s, p) => s + p.$2), 100.5);
      expect(odd.last.$1, DateTime(2027, 1, 15));
    });

    test('tutar yazımı', () {
      expect(parseMoney('12.500'), 12500);
      expect(parseMoney('12500,50'), 12500.5);
      expect(parseMoney('1.250,75 ₺'), 1250.75);
      expect(parseMoney(' 1 250 '), 1250);
      expect(parseMoney('99.5'), 99.5);
      expect(parseMoney('0'), isNull);
      expect(parseMoney('-5'), isNull);
      expect(parseMoney('abc'), isNull);
    });

    test('aylık özet: tahsilat ödendiği aya, gecikme bugüne göre', () {
      final fees = [
        _fee([
          _inst('a', DateTime(2026, 10, 5), paidOn: DateTime(2026, 11, 2)),
          _inst('b', DateTime(2026, 11, 5)),
          _inst('c', DateTime(2026, 12, 5)),
        ]),
      ];
      final expenses = [
        FinanceExpense(
          id: 'e1',
          spentOn: DateTime(2026, 11, 1),
          category: ExpenseCategory.rent,
          amount: 400,
        ),
        FinanceExpense(
          id: 'e2',
          spentOn: DateTime(2026, 10, 1),
          category: ExpenseCategory.rent,
          amount: 400,
        ),
      ];
      final s = monthSummary(
        fees,
        expenses,
        DateTime(2026, 11),
        today: DateTime(2026, 11, 20),
      );
      expect(
        (s.collected, s.expected, s.expenses, s.net),
        (1000.0, 1000.0, 400.0, 600.0),
      );
      expect((s.overdueAmount, s.overdueCount), (1000.0, 1));
      expect(fees.single.paid, 1000);
      expect(fees.single.remaining, 2000);
      expect(fees.single.nextDue?.id, 'b');
      expect(fees.single.settled, isFalse);
    });

    test('koç ödemesi: maaş + öğrenci × prim, bu ay ödendi mi', () {
      const rate = CoachPayRate(
        coachId: 'c',
        monthlySalary: 20000,
        perStudent: 500,
      );
      expect(rate.suggested(4), 22000);
      final paid = [
        FinanceExpense(
          id: 'e',
          spentOn: DateTime(2026, 11, 28),
          category: ExpenseCategory.salary,
          amount: 22000,
          coachId: 'c',
        ),
      ];
      expect(coachPaidIn(paid, 'c', DateTime(2026, 11)), isTrue);
      expect(coachPaidIn(paid, 'c', DateTime(2026, 12)), isFalse);
      expect(coachPaidIn(paid, 'x', DateTime(2026, 11)), isFalse);
    });
  });

  test('telefon ve vadesi bugün olanlar', () {
    expect(normalizePhone('0532 123 45 67'), '+905321234567');
    expect(normalizePhone('5321234567'), '+905321234567');
    expect(normalizePhone('+90 (532) 123-45-67'), '+905321234567');
    expect(normalizePhone('0212 123 45 67'), isNull);
    expect(normalizePhone('12345'), isNull);
    expect(formatPhone('+905321234567'), '0532 123 45 67');

    final fee = _fee([
      _inst('a', DateTime(2026, 11, 10)),
      _inst('b', DateTime(2026, 11, 10), paidOn: DateTime(2026, 11, 9)),
      _inst('c', DateTime(2026, 12, 10)),
    ]);
    expect(
      [
        for (final (_, i) in unpaidDueOn([fee], DateTime(2026, 11, 10))) i.id,
      ],
      ['a'],
    );
    final now = DateTime(2026, 11, 10, 12);
    expect(
      _inst('x', now).copyWith(remindedAt: now).remindedRecently(now),
      isTrue,
    );
    expect(
      _inst('x', now)
          .copyWith(remindedAt: now.subtract(const Duration(hours: 21)))
          .remindedRecently(now),
      isFalse,
    );
  });

  group('ekran', () {
    // Sekme çubuğu kayar; dar ekranda sekmeye dokunmak yerine doğrudan geç.
    Future<void> openTab(WidgetTester t, int i) async {
      DefaultTabController.of(t.element(find.byType(TabBarView))).animateTo(i);
      await t.pumpAndSettle();
    }

    late InMemoryFinanceRepository repo;

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    Future<ProviderContainer> pump(
      WidgetTester t, {
      Widget home = const FinanceScreen(),
    }) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      repo = InMemoryFinanceRepository(
        students: const {'demo-student': 'Elif Yılmaz', 'demo-can': 'Can Kaya'},
        coaches: const {'demo-coach': 'Ayşe Koç'},
        fees: [
          _fee([
            _inst('late', DateTime(2020, 1, 10)),
            _inst('later', DateTime(2099, 1, 10)),
          ]),
          StudentFee(
            id: 'g',
            studentId: 'demo-can',
            studentName: 'Can Kaya',
            title: 'YKS kursu',
            total: 1000,
            createdAt: DateTime(2026),
            dueDay: today.day > 28 ? 28 : today.day,
            payerName: 'Ayşe Kaya',
            payerPhone: '+905321234567',
            installments: [
              FeeInstallment(
                id: 'today',
                feeId: 'g',
                dueOn: today,
                amount: 1000,
              ),
            ],
          ),
        ],
        rates: const {
          'demo-coach': CoachPayRate(
            coachId: 'demo-coach',
            monthlySalary: 20000,
            perStudent: 500,
          ),
        },
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: await buildDemoOverrides('admin', true, null, null, repo),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: home,
          ),
        ),
      );
      await t.pumpAndSettle();
      return ProviderScope.containerOf(t.element(find.byType(FinanceScreen)));
    }

    testWidgets('özet gecikeni gösterir; taksit ödendi işaretlenir', (t) async {
      await pump(t);
      expect(find.text('Geciken taksitler'), findsOneWidget);
      expect(find.text('Elif Yılmaz'), findsOneWidget);

      await openTab(t, 1);
      expect(find.text('1 gecikmiş'), findsOneWidget);
      await t.tap(find.text('Elif Yılmaz'));
      await t.pumpAndSettle();
      expect(find.textContaining('Gecikti'), findsOneWidget);

      // Geciken taksite dokununca o taksidin kalanıyla ödeme penceresi açılır.
      await t.tap(find.textContaining('Gecikti'));
      await t.pumpAndSettle();
      expect(find.text('Ödeme al'), findsWidgets);
      await t.tap(find.text('Nakit').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Havale / EFT').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('payment-save')));
      await t.pumpAndSettle();

      final fee = (await repo.fetchFees()).firstWhere((f) => f.id == 'f');
      final late = fee.installments.firstWhere((i) => i.id == 'late');
      expect(late.isPaid, isTrue);
      expect(late.method, PaymentMethod.transfer);
      expect(find.textContaining('Gecikti'), findsNothing);
    });

    testWidgets('bildirimden açılınca bugünkü taksitler için SMS sorulur', (
      t,
    ) async {
      await pump(t, home: FinanceScreen(remindDay: today));
      expect(find.text('Taksit hatırlatması gönderilsin mi?'), findsOneWidget);
      expect(find.textContaining('Can Kaya'), findsWidgets);
      await t.tap(find.text('Gönder (1)'));
      await t.pumpAndSettle();
      expect(repo.sentSms, [('+905321234567', 'today')]);
      expect(find.text('1 hatırlatma SMS sırasına alındı.'), findsOneWidget);
    });

    testWidgets('telefonsuz ücrete veli telefonu eklenir, sonra SMS gider', (
      t,
    ) async {
      await pump(t);
      await openTab(t, 1);
      await t.tap(find.text('Elif Yılmaz'));
      await t.pumpAndSettle();
      expect(find.textContaining('Veli telefonu yok'), findsOneWidget);

      await t.tap(find.byTooltip('Veliye hatırlat').first);
      await t.pumpAndSettle();
      expect(find.text('Ödeme günü ve veli'), findsOneWidget);
      await t.enterText(
        find.widgetWithText(TextField, 'Veli cep telefonu'),
        '0533 765 43 21',
      );
      await t.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await t.pumpAndSettle();
      final fee = (await repo.fetchFees()).firstWhere((f) => f.id == 'f');
      expect(fee.payerPhone, '+905337654321');
      expect(find.textContaining('0533 765 43 21'), findsOneWidget);

      await t.tap(find.byTooltip('Veliye hatırlat').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Gönder'));
      await t.pumpAndSettle();
      expect(repo.sentSms, [('+905337654321', 'late')]);
    });

    testWidgets('koç sekmesi önerilen ödemeyi gösterir ve kaydeder', (t) async {
      final c = await pump(t);
      final students = await c.read(studentSummariesProvider.future);
      final n = students.where((s) => s.coachId == 'demo-coach').length;
      final amount = 20000.0 + 500 * n;

      await openTab(t, 5);
      expect(find.text('Bu ay: ${formatMoney(amount)}'), findsOneWidget);
      // Demo kurumunda iki koç var; ilki Ayşe Koç (oranı tanımlı).
      await t.tap(find.text('Ödemeyi kaydet').first);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await t.pumpAndSettle();

      final e = (await repo.fetchExpenses()).single;
      expect(
        (e.category, e.coachId, e.amount),
        (ExpenseCategory.salary, 'demo-coach', amount),
      );
      expect(find.text('Bu ay ödendi'), findsOneWidget);
    });
  });
}
