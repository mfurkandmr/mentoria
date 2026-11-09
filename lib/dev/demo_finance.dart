import '../features/finance/data/finance_repository.dart';

/// Bellekte tutulan kurum finansı (demo ve testler için). Sunucudaki
/// kurallarla: tahsilat taksitlere dağıtılır, makbuz no kurum + yıl başına
/// sıralı, taksidin ödenen tutarı tahsilatlardan hesaplanır.
class InMemoryFinanceRepository implements FinanceRepository {
  InMemoryFinanceRepository({
    required this.students,
    required this.coaches,
    List<StudentFee> fees = const [],
    List<FinanceExpense> expenses = const [],
    Map<String, CoachPayRate> rates = const {},
    this.teachers = const {},
    this.guardians = const {},
    this.parentOf = const {},
    this.orgName = 'Demo Kurum',
  }) : _fees = [...fees],
       _expenses = [...expenses],
       _rates = {...rates};

  /// Kurumdaki öğrenci ve koçlar: kimlik → ad.
  final Map<String, String> students;
  final Map<String, String> coaches;

  /// Ders programındaki öğretmenler: kimlik → ad.
  final Map<String, String> teachers;

  /// Öğrenci → (veli adı, telefon) — yoklamadaki kayıt (toplu ücrette).
  final Map<String, (String?, String)> guardians;

  /// Velinin çocukları (fetchChildFinance yetkisi); boşsa herkes.
  final Set<String> parentOf;
  final String orgName;

  final List<StudentFee> _fees;
  final List<FinanceExpense> _expenses;
  final Map<String, CoachPayRate> _rates;
  final _teacherRates = <String, TeacherPayRate>{};
  final _incomes = <FinanceIncome>[];
  final _accounts = <FinanceAccount>[];
  final _transfers = <FinanceTransfer>[];
  final _plans = <FeePlan>[];
  final _receiptSeq = <int, int>{};
  int _id = 0;

  /// Sıraya alınan SMS'ler (telefon, taksit, tutar) — testler için.
  final sentSms = <(String, String)>[];

  String _next(String p) => '$p-${_id++}';

  String _receipt(DateTime on) {
    final n = (_receiptSeq[on.year] ?? 0) + 1;
    _receiptSeq[on.year] = n;
    return '${on.year}-${n.toString().padLeft(6, '0')}';
  }

  /// Demo kurumu: birkaç öğrencinin taksitleri (biri gecikmiş, biri kısmi),
  /// bu ay ve geçen ayın giderleri, koç oranları, kasa ve banka.
  factory InMemoryFinanceRepository.demo({
    required Map<String, String> students,
    required Map<String, String> coaches,
    Map<String, String> teachers = const {},
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final month = DateTime(today.year, today.month);
    DateTime m(int add, int day) =>
        DateTime(month.year, month.month + add, day);
    final repo = InMemoryFinanceRepository(
      students: students,
      coaches: coaches,
      parentOf: {...students.keys.take(1)},
    );
    repo._accounts.addAll(const [
      FinanceAccount(id: 'acc-kasa', name: 'Kasa', openingBalance: 5000),
      FinanceAccount(
        id: 'acc-banka',
        name: 'Ziraat Bankası',
        kind: AccountKind.bank,
        iban: 'TR120001000000000000000001',
      ),
    ]);
    repo._plans.add(
      const FeePlan(
        id: 'plan-1',
        name: '2026-2027 YKS kursu',
        total: 36000,
        installmentCount: 6,
      ),
    );
    var n = 0;
    for (final e in students.entries.take(3)) {
      final id = repo._next('fee');
      final discount = n == 1 ? 3600.0 : 0.0;
      final plan = splitInstallments(36000 - discount, 6, m(-2, 5));
      final inst = [
        for (final (due, amount) in plan)
          FeeInstallment(
            id: repo._next('inst'),
            feeId: id,
            dueOn: due,
            amount: amount,
          ),
      ];
      final payments = <FeePayment>[];
      for (final (i, x) in inst.indexed) {
        // Geçmiş aylar ödendi; bu ayınkini ilk öğrenci ödemedi (gecikmiş),
        // ikinci öğrenci yarısını ödedi, üçüncüsü tamamını.
        final paid = x.dueOn.isBefore(m(0, 1))
            ? x.amount
            : i == 2 && n == 1
            ? (x.amount / 2).floorToDouble()
            : i == 2 && n == 2
            ? x.amount
            : 0.0;
        if (paid == 0) continue;
        final on = x.dueOn.add(const Duration(days: 2));
        payments.add(
          FeePayment(
            id: repo._next('pay'),
            feeId: id,
            installmentId: x.id,
            amount: paid,
            paidOn: on,
            method: PaymentMethod.transfer,
            accountId: 'acc-banka',
            receiptNo: repo._receipt(on),
          ),
        );
      }
      repo._fees.add(
        _synced(
          StudentFee(
            id: id,
            studentId: e.key,
            studentName: e.value,
            title: '2026-2027 YKS kursu',
            total: 36000,
            createdAt: m(-2, 1),
            dueDay: 5,
            payerName: n == 0 ? 'Selin Yılmaz' : null,
            payerPhone: n == 0 ? '+905321234567' : null,
            discounts: [
              if (discount > 0)
                FeeDiscount(kind: DiscountKind.sibling, amount: discount),
            ],
            installments: inst,
            payments: payments,
          ),
        ),
      );
      n++;
    }
    final coach = coaches.entries.firstOrNull;
    for (final add in [-1, 0]) {
      repo._expenses.addAll([
        FinanceExpense(
          id: repo._next('exp'),
          spentOn: m(add, 1),
          category: ExpenseCategory.rent,
          amount: 45000,
          accountId: 'acc-banka',
        ),
        FinanceExpense(
          id: repo._next('exp'),
          spentOn: m(add, 10),
          category: ExpenseCategory.bills,
          amount: 6200,
          note: 'Elektrik, su, internet',
          accountId: 'acc-kasa',
        ),
        if (coach != null && add < 0)
          FinanceExpense(
            id: repo._next('exp'),
            spentOn: m(add, 28),
            category: ExpenseCategory.salary,
            amount: 28000,
            coachId: coach.key,
            coachName: coach.value,
          ),
      ]);
    }
    repo._expenses.sort((a, b) => b.spentOn.compareTo(a.spentOn));
    repo._incomes.add(
      FinanceIncome(
        id: repo._next('inc'),
        receivedOn: m(0, 3),
        category: IncomeCategory.books,
        amount: 850,
        method: PaymentMethod.cash,
        accountId: 'acc-kasa',
        studentId: students.keys.firstOrNull,
        studentName: students.values.firstOrNull,
        note: 'Deneme seti',
        receiptNo: repo._receipt(m(0, 3)),
      ),
    );
    if (coach != null) {
      repo._rates[coach.key] = CoachPayRate(
        coachId: coach.key,
        monthlySalary: 25000,
        perStudent: 1000,
      );
    }
    // Biri saat başına, biri sabit: iki ödeme şekli de görünsün.
    final teacherIds = teachers.keys.toList();
    if (teacherIds.isNotEmpty) {
      repo._teacherRates[teacherIds.first] = TeacherPayRate(
        teacherId: teacherIds.first,
        amount: 400,
        note: 'Ödeme ayın 5. günü havaleyle',
      );
    }
    if (teacherIds.length > 2) {
      repo._teacherRates[teacherIds[2]] = TeacherPayRate(
        teacherId: teacherIds[2],
        type: TeacherPayType.fixed,
        amount: 22000,
      );
    }
    return repo;
  }

  /// Taksitlerin ödenen tutarı ve ödendi günü tahsilatlardan.
  static StudentFee _synced(StudentFee f) => f.copyWith(
    installments: [
      for (final i in f.installments)
        () {
          final rows = [
            for (final p in f.payments)
              if (p.installmentId == i.id && !p.isRefund && !p.isVoided) p,
          ]..sort((a, b) => b.paidOn.compareTo(a.paidOn));
          final paid = rows.fold<double>(0, (s, p) => s + p.amount);
          final full = paid >= i.amount - 0.004;
          return i.copyWith(
            paidAmount: paid,
            paidOn: full && rows.isNotEmpty ? rows.first.paidOn : null,
            method: full && rows.isNotEmpty ? rows.first.method : null,
          );
        }(),
    ],
  );

  int _index(String feeId) {
    final i = _fees.indexWhere((f) => f.id == feeId);
    if (i < 0) throw StateError('FINANCE_NOT_ADMIN');
    return i;
  }

  void _checkAccount(String? id) {
    if (id != null && _accounts.every((a) => a.id != id)) {
      throw StateError('FINANCE_BAD_ACCOUNT');
    }
  }

  @override
  Future<List<StudentFee>> fetchFees() async => [..._fees];

  StudentFee _newFee(FeeDraft d, String studentId, {FeePayer? payer}) {
    final name = students[studentId];
    if (name == null) throw StateError('FINANCE_BAD_STUDENT');
    final sum = d.installments.fold<double>(0, (s, x) => s + x.$2);
    if ((sum - d.netTotal).abs() > 0.01) throw StateError('FINANCE_BAD_TOTAL');
    final id = _next('fee');
    final p = payer ?? d.payer;
    return StudentFee(
      id: id,
      studentId: studentId,
      studentName: name,
      title: d.title.trim(),
      total: d.total,
      note: d.note,
      createdAt: DateTime.now(),
      dueDay: p.dueDay ?? d.payer.dueDay,
      payerName: p.name,
      payerPhone: p.phone,
      discounts: d.discounts,
      installments: [
        for (final (due, amount) in d.installments)
          FeeInstallment(
            id: _next('inst'),
            feeId: id,
            dueOn: due,
            amount: amount,
          ),
      ],
    );
  }

  @override
  Future<void> addFee(FeeDraft d) async =>
      _fees.insert(0, _newFee(d, d.studentId));

  @override
  Future<BulkFeeResult> addFeesBulk(
    List<String> ids,
    FeeDraft d, {
    bool allowDuplicate = false,
  }) async {
    var created = 0;
    final skipped = <String>[];
    String key(String s) => s.trim().toLowerCase();
    for (final s in ids) {
      final dup =
          !allowDuplicate &&
          _fees.any(
            (f) =>
                f.studentId == s &&
                !f.isCancelled &&
                key(f.title) == key(d.title),
          );
      if (!students.containsKey(s) || dup) {
        skipped.add(s);
        continue;
      }
      final g = guardians[s];
      _fees.insert(
        0,
        _newFee(
          d,
          s,
          payer: FeePayer(dueDay: d.payer.dueDay, name: g?.$1, phone: g?.$2),
        ),
      );
      created++;
    }
    return BulkFeeResult(created: created, skipped: skipped);
  }

  @override
  Future<void> deleteFee(String id) async {
    final f = _fees[_index(id)];
    if (f.payments.any((p) => !p.isVoided)) {
      throw StateError('FINANCE_HAS_PAYMENTS');
    }
    _fees.removeWhere((f) => f.id == id);
  }

  @override
  Future<PaymentResult> recordPayment(
    String feeId, {
    required double amount,
    required DateTime paidOn,
    PaymentMethod? method,
    String? accountId,
    String? note,
    String? installmentId,
  }) async {
    final k = _index(feeId);
    final f = _fees[k];
    if (f.isCancelled) throw StateError('FINANCE_CANCELLED');
    if (amount <= 0) throw StateError('FINANCE_BAD_AMOUNT');
    if (amount > f.remaining + 0.001) throw StateError('FINANCE_OVERPAYMENT');
    _checkAccount(accountId);
    final no = _receipt(paidOn);
    final rows = [
      for (final (i, part) in allocatePayment(
        f.installments,
        amount,
        first: installmentId,
      ))
        FeePayment(
          id: _next('pay'),
          feeId: feeId,
          installmentId: i.id,
          amount: part,
          paidOn: paidOn,
          method: method,
          accountId: accountId,
          receiptNo: no,
          note: note,
        ),
    ];
    _fees[k] = _synced(f.copyWith(payments: [...rows, ...f.payments]));
    return PaymentResult(receiptNo: no, remaining: _fees[k].remaining);
  }

  @override
  Future<void> voidReceipt(String receiptNo) async {
    var found = 0;
    final now = DateTime.now();
    FeePayment v(FeePayment p) => FeePayment(
      id: p.id,
      feeId: p.feeId,
      installmentId: p.installmentId,
      isRefund: p.isRefund,
      amount: p.amount,
      paidOn: p.paidOn,
      method: p.method,
      accountId: p.accountId,
      receiptNo: p.receiptNo,
      note: p.note,
      voidedAt: now,
    );
    for (final (k, f) in _fees.indexed) {
      if (!f.payments.any((p) => p.receiptNo == receiptNo && !p.isVoided)) {
        continue;
      }
      found++;
      _fees[k] = _synced(
        f.copyWith(
          payments: [
            for (final p in f.payments)
              p.receiptNo == receiptNo && !p.isVoided ? v(p) : p,
          ],
        ),
      );
    }
    for (final (k, i) in _incomes.indexed) {
      if (i.receiptNo != receiptNo || i.isVoided) continue;
      found++;
      _incomes[k] = FinanceIncome(
        id: i.id,
        receivedOn: i.receivedOn,
        category: i.category,
        amount: i.amount,
        method: i.method,
        accountId: i.accountId,
        studentId: i.studentId,
        studentName: i.studentName,
        payerName: i.payerName,
        note: i.note,
        receiptNo: i.receiptNo,
        voidedAt: now,
      );
    }
    if (found == 0) throw StateError('FINANCE_RECEIPT_NOT_FOUND');
  }

  @override
  Future<void> addDiscount(
    String feeId,
    DiscountKind kind,
    double amount, {
    String? note,
  }) async {
    final k = _index(feeId);
    final f = _fees[k];
    if (f.isCancelled) throw StateError('FINANCE_CANCELLED');
    if (amount <= 0) throw StateError('FINANCE_BAD_AMOUNT');
    if (amount > f.remaining + 0.001) {
      throw StateError('FINANCE_DISCOUNT_TOO_BIG');
    }
    var left = amount;
    final list = [...f.installments]
      ..sort((a, b) => b.dueOn.compareTo(a.dueOn));
    final out = <FeeInstallment>[];
    for (final i in list) {
      if (left <= 0 || i.open <= 0) {
        out.add(i);
        continue;
      }
      final cut = left < i.open ? left : i.open;
      left -= cut;
      if (i.amount - cut > 0.004) out.add(i.copyWith(amount: i.amount - cut));
    }
    out.sort((a, b) => a.dueOn.compareTo(b.dueOn));
    _fees[k] = _synced(
      f.copyWith(
        installments: out,
        discounts: [
          ...f.discounts,
          FeeDiscount(kind: kind, amount: amount, note: note),
        ],
      ),
    );
  }

  @override
  Future<PaymentResult> cancelFee(
    String feeId, {
    double refund = 0,
    required DateTime on,
    PaymentMethod? method,
    String? accountId,
    String? note,
  }) async {
    final k = _index(feeId);
    final f = _fees[k];
    if (f.isCancelled) throw StateError('FINANCE_CANCELLED');
    _checkAccount(accountId);
    final net =
        f.payments
            .where((p) => !p.isVoided && !p.isRefund)
            .fold<double>(0, (s, p) => s + p.amount) -
        f.refunded;
    if (refund < 0 || refund > net + 0.001) {
      throw StateError('FINANCE_REFUND_TOO_BIG');
    }
    final no = refund > 0 ? _receipt(on) : null;
    _fees[k] = _synced(
      f.copyWith(
        status: FeeStatus.cancelled,
        cancelledOn: on,
        installments: [
          for (final i in f.installments)
            if (i.isPaid)
              i
            else if (i.paidAmount > 0)
              i.copyWith(amount: i.paidAmount),
        ],
        payments: [
          if (no != null)
            FeePayment(
              id: _next('pay'),
              feeId: feeId,
              isRefund: true,
              amount: refund,
              paidOn: on,
              method: method,
              accountId: accountId,
              receiptNo: no,
              note: note,
            ),
          ...f.payments,
        ],
      ),
    );
    return PaymentResult(receiptNo: no);
  }

  @override
  Future<void> updatePayer(String feeId, FeePayer payer) async {
    final i = _fees.indexWhere((f) => f.id == feeId);
    if (i >= 0) _fees[i] = _fees[i].copyWith(payer: payer);
  }

  @override
  Future<ReminderResult> sendReminders(List<String> ids) async {
    final now = DateTime.now();
    var queued = 0, noPhone = 0, skipped = 0;
    for (final (k, f) in _fees.indexed) {
      final list = [...f.installments];
      for (final (j, inst) in list.indexed) {
        if (!ids.contains(inst.id)) continue;
        if (inst.isPaid || inst.remindedRecently(now)) {
          skipped++;
        } else if (f.payerPhone == null) {
          noPhone++;
        } else {
          sentSms.add((f.payerPhone!, inst.id));
          list[j] = inst.copyWith(
            paidOn: inst.paidOn,
            method: inst.method,
            remindedAt: now,
            paidAmount: inst.paidAmount,
          );
          queued++;
        }
      }
      _fees[k] = f.copyWith(installments: list);
    }
    return ReminderResult(queued: queued, noPhone: noPhone, skipped: skipped);
  }

  @override
  Future<List<FinanceExpense>> fetchExpenses() async => [..._expenses];

  @override
  Future<void> addExpense(ExpenseDraft d) async {
    if (d.coachId != null && !coaches.containsKey(d.coachId)) {
      throw StateError('FINANCE_BAD_COACH');
    }
    if (d.teacherId != null && !teachers.containsKey(d.teacherId)) {
      throw StateError('FINANCE_BAD_TEACHER');
    }
    _checkAccount(d.accountId);
    _expenses
      ..add(
        FinanceExpense(
          id: _next('exp'),
          spentOn: d.spentOn,
          category: d.category,
          amount: d.amount,
          note: d.note,
          coachId: d.coachId,
          coachName: coaches[d.coachId],
          teacherId: d.teacherId,
          teacherName: teachers[d.teacherId],
          accountId: d.accountId,
        ),
      )
      ..sort((a, b) => b.spentOn.compareTo(a.spentOn));
  }

  @override
  Future<void> deleteExpense(String id) async =>
      _expenses.removeWhere((e) => e.id == id);

  @override
  Future<Map<String, CoachPayRate>> fetchPayRates() async => {..._rates};

  @override
  Future<void> savePayRate(CoachPayRate rate) async {
    if (!coaches.containsKey(rate.coachId)) {
      throw StateError('FINANCE_BAD_COACH');
    }
    _rates[rate.coachId] = rate;
  }

  @override
  Future<Map<String, TeacherPayRate>> fetchTeacherPayRates() async => {
    ..._teacherRates,
  };

  @override
  Future<void> saveTeacherPayRate(TeacherPayRate rate) async {
    if (!teachers.containsKey(rate.teacherId)) {
      throw StateError('FINANCE_BAD_TEACHER');
    }
    _teacherRates[rate.teacherId] = rate;
  }

  @override
  Future<List<FinanceIncome>> fetchIncomes() async =>
      [..._incomes]..sort((a, b) => b.receivedOn.compareTo(a.receivedOn));

  @override
  Future<String> recordIncome(IncomeDraft d) async {
    if (d.amount <= 0) throw StateError('FINANCE_BAD_AMOUNT');
    _checkAccount(d.accountId);
    if (d.studentId != null && !students.containsKey(d.studentId)) {
      throw StateError('FINANCE_BAD_STUDENT');
    }
    final no = _receipt(d.receivedOn);
    _incomes.add(
      FinanceIncome(
        id: _next('inc'),
        receivedOn: d.receivedOn,
        category: d.category,
        amount: d.amount,
        method: d.method,
        accountId: d.accountId,
        studentId: d.studentId,
        studentName: students[d.studentId],
        payerName: d.payerName,
        note: d.note,
        receiptNo: no,
      ),
    );
    return no;
  }

  @override
  Future<List<FinanceAccount>> fetchAccounts() async => [..._accounts];

  @override
  Future<void> saveAccount(FinanceAccount a, {bool isNew = false}) async {
    final dup = _accounts.any(
      (x) =>
          x.id != a.id &&
          x.name.trim().toLowerCase() == a.name.trim().toLowerCase(),
    );
    if (dup) throw StateError('finance_accounts_name');
    if (isNew) {
      _accounts.add(
        FinanceAccount(
          id: _next('acc'),
          name: a.name.trim(),
          kind: a.kind,
          iban: a.iban,
          openingBalance: a.openingBalance,
        ),
      );
    } else {
      final i = _accounts.indexWhere((x) => x.id == a.id);
      if (i >= 0) _accounts[i] = a;
    }
  }

  @override
  Future<List<FinanceTransfer>> fetchTransfers() async =>
      [..._transfers]..sort((a, b) => b.movedOn.compareTo(a.movedOn));

  @override
  Future<void> addTransfer({
    required String from,
    required String to,
    required double amount,
    required DateTime on,
    String? note,
  }) async {
    _checkAccount(from);
    _checkAccount(to);
    if (from == to || amount <= 0) throw StateError('FINANCE_BAD_ACCOUNT');
    _transfers.add(
      FinanceTransfer(
        id: _next('tr'),
        fromAccount: from,
        toAccount: to,
        amount: amount,
        movedOn: on,
        note: note,
      ),
    );
  }

  @override
  Future<void> deleteTransfer(String id) async =>
      _transfers.removeWhere((t) => t.id == id);

  @override
  Future<List<FeePlan>> fetchPlans() async => [..._plans];

  @override
  Future<void> savePlan(FeePlan p, {bool isNew = false}) async {
    if (isNew) {
      _plans.add(
        FeePlan(
          id: _next('plan'),
          name: p.name.trim(),
          total: p.total,
          installmentCount: p.installmentCount,
          note: p.note,
        ),
      );
    } else {
      final i = _plans.indexWhere((x) => x.id == p.id);
      if (i >= 0) _plans[i] = p;
    }
  }

  @override
  Future<void> deletePlan(String id) async =>
      _plans.removeWhere((p) => p.id == id);

  @override
  Future<ChildFinance> fetchChildFinance(String studentId) async {
    if (parentOf.isNotEmpty && !parentOf.contains(studentId)) {
      throw StateError('NOT_ALLOWED');
    }
    return ChildFinance(
      orgName: orgName,
      fees: [
        for (final f in _fees)
          if (f.studentId == studentId)
            f.copyWith(
              payments: [
                for (final p in f.payments)
                  if (!p.isVoided) p,
              ],
            ),
      ],
    );
  }
}
