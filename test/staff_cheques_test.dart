import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_finance.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_staff.dart';
import 'package:mentoria/features/finance/data/finance_repository.dart';
import 'package:mentoria/features/finance/presentation/cheques_ui.dart';
import 'package:mentoria/features/staff/data/staff_repository.dart';
import 'package:mentoria/features/staff/presentation/staff_screen.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

InMemoryFinanceRepository _finance() => InMemoryFinanceRepository(
  students: const {'s1': 'Elif Yılmaz'},
  coaches: const {'c1': 'Ayşe Koç'},
  staffLookup: (id) => id == 'k1' ? 'Hale Yurt' : null,
);

void main() {
  final today = DateUtils.dateOnly(DateTime.now());

  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  group('personel listesi', () {
    test('koç, öğretmen ve kart tek satırda birleşir', () {
      final people = mergePersonnel(
        staff: const [
          StaffMember(
            id: 'k1',
            fullName: 'Ayşe Koç',
            job: StaffJob.coach,
            profileId: 'c1',
          ),
          StaffMember(id: 'k2', fullName: 'Hale Yurt'),
        ],
        coaches: const {'c1': 'Ayşe Koç', 'c2': 'Burak Yıldız'},
        teachers: const [
          TeacherRef(id: 't1', name: 'Ayşe Koç', profileId: 'c1'),
          TeacherRef(id: 't2', name: 'Burak Yıldız', profileId: 'c2'),
          TeacherRef(id: 't3', name: 'Can Yurt'),
        ],
      );
      expect(people.map((p) => p.name), [
        'Ayşe Koç',
        'Burak Yıldız',
        'Can Yurt',
        'Hale Yurt',
      ]);
      final ayse = people.first;
      expect(
        (ayse.staff?.id, ayse.coachId, ayse.teacherId),
        ('k1', 'c1', 't1'),
      );
      final burak = people[1];
      expect((burak.staff, burak.coachId, burak.teacherId), (null, 'c2', 't2'));
      expect(people[2].key, 't_t3');
    });

    test('yıl sonunu aşan izin iki yıla bölünür', () {
      final leave = StaffLeave(
        staffId: 'k',
        startOn: DateTime(2026, 12, 30),
        endOn: DateTime(2027, 1, 2),
      );
      expect(leave.days, 4);
      expect(annualLeaveUsed([leave], 'k', 2026), 2);
      expect(annualLeaveUsed([leave], 'k', 2027), 2);
      expect(annualLeaveUsed([leave], 'baskası', 2026), 0);
    });

    test(
      'demo deposu çakışan izni reddeder, maaş ödemesi karta bağlanır',
      () async {
        final repo = InMemoryStaffRepository.demo();
        await expectLater(
          repo.addLeave(
            StaffLeave(staffId: 'staff-sevim', startOn: today, endOn: today),
          ),
          throwsA(isA<StateError>()),
        );
        final finance = _finance();
        await finance.addExpense(
          ExpenseDraft(
            spentOn: today,
            category: ExpenseCategory.salary,
            amount: 100,
            staffId: 'k1',
          ),
        );
        expect((await finance.fetchExpenses()).single.payeeName, 'Hale Yurt');
        await expectLater(
          finance.addExpense(
            ExpenseDraft(
              spentOn: today,
              category: ExpenseCategory.salary,
              amount: 100,
              staffId: 'yok',
            ),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('çek akışı', () {
    late InMemoryFinanceRepository r;

    Future<FinanceCheque> add({
      ChequeDirection direction = ChequeDirection.received,
      String? fee,
      String? student,
      double amount = 1000,
      DateTime? due,
    }) async {
      await r.addCheque(
        ChequeDraft(
          direction: direction,
          partyName: 'Hasan',
          studentId: student,
          feeId: fee,
          amount: amount,
          dueOn: due ?? today,
        ),
      );
      return (await r.fetchCheques()).last;
    }

    setUp(() => r = _finance());

    test('tahsil gelir yazar, karşılıksız iptal eder', () async {
      final c = await add();
      expect(c.status, ChequeStatus.portfolio);
      await r.setChequeStatus(c.id, ChequeStatus.collected, on: today);
      var income = (await r.fetchIncomes()).single;
      expect((income.amount, income.isVoided), (1000.0, false));
      await r.setChequeStatus(c.id, ChequeStatus.bounced, on: today);
      income = (await r.fetchIncomes()).single;
      expect(income.isVoided, isTrue);
      expect((await r.fetchCheques()).single.receiptNo, isNull);
    });

    test('ücrete bağlı çek taksiti kapatır, geri alınınca açar', () async {
      await r.addFee(
        FeeDraft(
          studentId: 's1',
          title: 'YKS',
          total: 3000,
          installments: splitInstallments(3000, 3, today),
        ),
      );
      final fee = (await r.fetchFees()).single;
      final c = await add(fee: fee.id, student: 's1');
      await r.setChequeStatus(c.id, ChequeStatus.collected, on: today);
      expect((await r.fetchFees()).single.remaining, 2000);
      expect(await r.fetchIncomes(), isEmpty);
      await r.setChequeStatus(c.id, ChequeStatus.portfolio, on: today);
      expect((await r.fetchFees()).single.remaining, 3000);
    });

    test('verilen çek ödenince gider, geri alınınca silinir', () async {
      final c = await add(direction: ChequeDirection.given);
      expect(c.status, ChequeStatus.issued);
      await r.setChequeStatus(c.id, ChequeStatus.paid, on: today);
      expect((await r.fetchExpenses()).single.amount, 1000);
      await r.setChequeStatus(c.id, ChequeStatus.issued, on: today);
      expect(await r.fetchExpenses(), isEmpty);
    });

    test(
      'geçersiz geçiş, cirosuz ciro ve işlem görmüş silme reddedilir',
      () async {
        final c = await add();
        await expectLater(
          r.setChequeStatus(c.id, ChequeStatus.paid),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          r.setChequeStatus(c.id, ChequeStatus.endorsed),
          throwsA(isA<StateError>()),
        );
        await r.setChequeStatus(c.id, ChequeStatus.deposited, on: today);
        await expectLater(r.deleteCheque(c.id), throwsA(isA<StateError>()));
      },
    );

    test('özet açık kayıtları sayar', () {
      FinanceCheque cheque(
        String id,
        ChequeDirection d,
        double amount,
        DateTime due,
        ChequeStatus s,
      ) => FinanceCheque(
        id: id,
        direction: d,
        partyName: 'X',
        amount: amount,
        dueOn: due,
        status: s,
      );
      final s = chequeSummary([
        cheque(
          'a',
          ChequeDirection.received,
          100,
          today.subtract(const Duration(days: 3)),
          ChequeStatus.portfolio,
        ),
        cheque(
          'b',
          ChequeDirection.received,
          200,
          today.add(const Duration(days: 3)),
          ChequeStatus.deposited,
        ),
        cheque(
          'c',
          ChequeDirection.received,
          999,
          today,
          ChequeStatus.collected,
        ),
        cheque('d', ChequeDirection.given, 50, today, ChequeStatus.issued),
      ], today);
      expect(s.portfolio, 300);
      expect((s.overdueAmount, s.overdueCount), (100.0, 1));
      expect(s.soonCount, 2);
    });
  });

  group('ekran', () {
    Future<void> pump(WidgetTester t, Widget home) async {
      t.view.physicalSize = const Size(1080, 2600);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      await t.pumpWidget(
        ProviderScope(
          overrides: await buildDemoOverrides('admin'),
          child: MaterialApp(
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: DefaultTabController(length: 7, child: Scaffold(body: home)),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('personel listesi birleşik; yeni kart eklenir', (t) async {
      await pump(t, const StaffScreen());
      expect(find.text('Hale Yurt'), findsOneWidget);
      expect(
        find.text('Ahmet Kaya'),
        findsOneWidget,
      ); // Yalnızca ders programında.
      expect(find.text('Burak Yıldız'), findsOneWidget); // Yalnızca koç hesabı.
      expect(
        find.text('Ayşe Koç'),
        findsOneWidget,
      ); // Kart + koç + öğretmen tek satır.
      expect(find.textContaining('Bugün izinde'), findsWidgets);

      await t.tap(find.byKey(const ValueKey('staff-add')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('staff-name')), 'Nur Sever');
      await t.enterText(find.byKey(const ValueKey('staff-phone')), '123');
      final save = find.byKey(const ValueKey('staff-save'));
      await t.ensureVisible(save);
      await t.pumpAndSettle();
      await t.tap(save);
      await t.pump();
      expect(find.textContaining('biçiminde yaz'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('staff-phone')),
        '0555 000 11 22',
      );
      await t.pump(const Duration(seconds: 5));
      await t.ensureVisible(save);
      await t.pumpAndSettle();
      await t.tap(save);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('staff-save')), findsNothing);
      await t.dragUntilVisible(
        find.text('Nur Sever'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      expect(find.text('Nur Sever'), findsOneWidget);
    });

    testWidgets('kartı olmayan koça izin girilince kart açılır', (t) async {
      await pump(t, const StaffDetailScreen(personKey: 'c_demo-coach-2'));
      expect(find.text('Burak Yıldız'), findsOneWidget);
      expect(find.textContaining('Henüz kart açılmadı'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('leave-add')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('leave-save')));
      await t.pumpAndSettle();
      expect(find.textContaining('Henüz kart açılmadı'), findsNothing);
      expect(find.textContaining('Yıllık izin · 1 gün'), findsOneWidget);
    });

    testWidgets('alınan çek eklenir ve tahsil edilir', (t) async {
      await pump(t, const ChequesTab());
      expect(find.text('Portföyde'), findsWidgets);
      expect(find.text('Vadesi geçti'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('cheque-add')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('cheque-party')),
        'Yeni Veli',
      );
      await t.enterText(find.byKey(const ValueKey('cheque-amount')), '4000');
      final save = find.byKey(const ValueKey('cheque-save'));
      await t.ensureVisible(save);
      await t.pumpAndSettle();
      await t.tap(save);
      await t.pumpAndSettle();

      final row = find.textContaining('Yeni Veli');
      await t.dragUntilVisible(
        row,
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await t.pumpAndSettle();
      await t.tap(row);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('cheque-to-collected')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('cheque-status-save')));
      await t.pumpAndSettle();
      await t.dragUntilVisible(
        find.textContaining('Yeni Veli'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await t.pumpAndSettle();
      expect(find.text('Tahsil edildi'), findsOneWidget);
    });
  });
}
