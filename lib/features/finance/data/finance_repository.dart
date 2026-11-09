import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';

/// Kurum finansı: yalnızca kurum müdürü görür. Uygulama ödeme almaz; ödeme
/// elden / havaleyle yapılır, müdür işaretler (kayıt defteri).

/// 12500 → "12.500 ₺", 99.5 → "99,5 ₺".
String formatMoney(num value) =>
    '${NumberFormat('#,##0.##', localeTag).format(value)} ₺';

/// Kullanıcının yazdığı tutar: "12.500", "12500,50", "1 250" → sayı.
/// Geçersiz ya da sıfır / negatifse null.
double? parseMoney(String text) {
  var t = text.replaceAll(RegExp(r'[\s₺]'), '');
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', '');
  }
  final v = double.tryParse(t);
  return v == null || v <= 0 ? null : v;
}

/// Türkiye cep telefonu → "+905XXXXXXXXX" (SMS için). "0532 123 45 67",
/// "5321234567", "+90 532 ..." kabul edilir; geçersizse null.
String? normalizePhone(String text) {
  var d = text.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('90') && d.length == 12) d = d.substring(2);
  if (d.startsWith('0') && d.length == 11) d = d.substring(1);
  return RegExp(r'^5\d{9}$').hasMatch(d) ? '+90$d' : null;
}

/// "+905321234567" → "0532 123 45 67".
String formatPhone(String e164) {
  final d = e164.replaceFirst('+90', '0');
  if (d.length != 11) return e164;
  return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7, 9)} ${d.substring(9)}';
}

enum PaymentMethod {
  cash('cash'),
  transfer('transfer'),
  card('card'),
  other('other');

  const PaymentMethod(this.db);
  final String db;

  static PaymentMethod? fromDb(String? v) =>
      values.where((m) => m.db == v).firstOrNull;

  String get label => switch (this) {
    cash => tr('Nakit'),
    transfer => tr('Havale / EFT'),
    card => tr('Kart'),
    other => tr('Diğer'),
  };
}

enum ExpenseCategory {
  rent('rent'),
  salary('salary'),
  bonus('bonus'),
  bills('bills'),
  materials('materials'),
  marketing('marketing'),
  tax('tax'),
  other('other');

  const ExpenseCategory(this.db);
  final String db;

  static ExpenseCategory fromDb(String v) =>
      values.firstWhere((c) => c.db == v, orElse: () => other);

  String get label => switch (this) {
    rent => tr('Kira'),
    salary => tr('Maaş'),
    bonus => tr('Prim'),
    bills => tr('Faturalar'),
    materials => tr('Kitap / materyal'),
    marketing => tr('Reklam'),
    tax => tr('Vergi / SGK'),
    other => tr('Diğer'),
  };
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
bool _sameMonth(DateTime d, DateTime month) =>
    d.year == month.year && d.month == month.month;
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
double _num(Object? v) => (v as num).toDouble();

class FeeInstallment {
  const FeeInstallment({
    required this.id,
    required this.feeId,
    required this.dueOn,
    required this.amount,
    this.paidOn,
    this.method,
    this.remindedAt,
    double? paidAmount,
  }) : paidAmount = paidAmount ?? (paidOn != null ? amount : 0);

  factory FeeInstallment.fromJson(Map<String, dynamic> j) => FeeInstallment(
    id: j['id'] as String,
    feeId: j['fee_id'] as String,
    dueOn: DateTime.parse(j['due_on'] as String),
    amount: _num(j['amount']),
    paidAmount: j['paid_amount'] == null ? null : _num(j['paid_amount']),
    paidOn: j['paid_on'] == null
        ? null
        : DateTime.parse(j['paid_on'] as String),
    method: PaymentMethod.fromDb(j['method'] as String?),
    remindedAt: j['reminded_at'] == null
        ? null
        : DateTime.parse(j['reminded_at'] as String).toLocal(),
  );

  final String id;
  final String feeId;
  final DateTime dueOn;
  final double amount;
  final DateTime? paidOn;
  final PaymentMethod? method;

  /// Son SMS hatırlatması (sıraya alındığı an).
  final DateTime? remindedAt;

  /// Tahsil edilen kısım (kısmi ödemede tutardan az).
  final double paidAmount;

  /// Kalan tutar.
  double get open => (amount - paidAmount) < 0.005 ? 0 : amount - paidAmount;
  bool get isPartial => !isPaid && paidAmount > 0;

  bool get isPaid => paidOn != null;

  /// Sunucu aynı taksite 20 saatte bir SMS yazar.
  bool remindedRecently(DateTime now) =>
      remindedAt != null && now.difference(remindedAt!).inHours < 20;
  bool isOverdue(DateTime today) => !isPaid && dueOn.isBefore(_day(today));

  FeeInstallment copyWith({
    DateTime? paidOn,
    PaymentMethod? method,
    DateTime? remindedAt,
    double? paidAmount,
    double? amount,
  }) => FeeInstallment(
    id: id,
    feeId: feeId,
    dueOn: dueOn,
    amount: amount ?? this.amount,
    paidOn: paidOn,
    method: method,
    remindedAt: remindedAt ?? this.remindedAt,
    paidAmount: paidAmount,
  );
}

/// Öğrenci başına ücret ve taksitleri.
class StudentFee {
  const StudentFee({
    required this.id,
    required this.studentName,
    required this.title,
    required this.total,
    required this.createdAt,
    required this.installments,
    this.studentId,
    this.note,
    this.dueDay,
    this.payerName,
    this.payerPhone,
    this.status = FeeStatus.active,
    this.cancelledOn,
    this.cancelNote,
    this.discounts = const [],
    this.payments = const [],
  });

  factory StudentFee.fromJson(Map<String, dynamic> j) => StudentFee(
    id: j['id'] as String,
    studentId: j['student_id'] as String?,
    studentName: j['student_name'] as String,
    title: j['title'] as String,
    total: _num(j['total']),
    note: j['note'] as String?,
    dueDay: j['due_day'] as int?,
    payerName: j['payer_name'] as String?,
    payerPhone: j['payer_phone'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    installments: [
      for (final i in (j['finance_installments'] as List? ?? const []))
        FeeInstallment.fromJson((i as Map).cast<String, dynamic>()),
    ]..sort((a, b) => a.dueOn.compareTo(b.dueOn)),
    status: j['status'] == 'cancelled' ? FeeStatus.cancelled : FeeStatus.active,
    cancelledOn: j['cancelled_on'] == null
        ? null
        : DateTime.parse(j['cancelled_on'] as String),
    cancelNote: j['cancel_note'] as String?,
    discounts: [
      for (final d in (j['finance_discounts'] as List? ?? const []))
        FeeDiscount.fromJson((d as Map).cast<String, dynamic>()),
    ],
    payments: [
      for (final x in (j['finance_payments'] as List? ?? const []))
        FeePayment.fromJson((x as Map).cast<String, dynamic>()),
    ]..sort((a, b) => b.paidOn.compareTo(a.paidOn)),
  );

  final String id;

  /// Öğrenci hesabı silindiyse null (mali kayıt adıyla kalır).
  final String? studentId;
  final String studentName;
  final String title;
  final double total;
  final String? note;

  /// Her ayın kaçında ödenir (1-28); eski kayıtlarda null.
  final int? dueDay;

  /// Ödeyen veli; hatırlatma SMS'i [payerPhone] numarasına gider.
  final String? payerName;
  final String? payerPhone;
  final DateTime createdAt;
  final List<FeeInstallment> installments;
  final FeeStatus status;
  final DateTime? cancelledOn;
  final String? cancelNote;
  final List<FeeDiscount> discounts;

  /// Tahsilat ve iade satırları (iptal edilenler dahil), yeni önce.
  final List<FeePayment> payments;

  bool get isCancelled => status == FeeStatus.cancelled;
  double get discountTotal => discounts.fold(0, (s, d) => s + d.amount);

  /// İndirimsiz ücret − indirimler.
  double get netTotal => total - discountTotal;
  double get refunded => payments
      .where((p) => p.isRefund && !p.isVoided)
      .fold(0, (s, p) => s + p.amount);

  /// Makbuz başına toplanmış tahsilat / iadeler (iptal edilenler dahil).
  List<Receipt> get receipts => groupReceipts(payments);

  StudentFee copyWith({
    List<FeeInstallment>? installments,
    FeePayer? payer,
    FeeStatus? status,
    DateTime? cancelledOn,
    List<FeeDiscount>? discounts,
    List<FeePayment>? payments,
  }) => StudentFee(
    id: id,
    studentId: studentId,
    studentName: studentName,
    title: title,
    total: total,
    note: note,
    createdAt: createdAt,
    dueDay: payer == null ? dueDay : payer.dueDay,
    payerName: payer == null ? payerName : payer.name,
    payerPhone: payer == null ? payerPhone : payer.phone,
    installments: installments ?? this.installments,
    status: status ?? this.status,
    cancelledOn: cancelledOn ?? this.cancelledOn,
    cancelNote: cancelNote,
    discounts: discounts ?? this.discounts,
    payments: payments ?? this.payments,
  );

  /// Taksitlere tahsil edilen toplam (kısmi ödemeler dahil).
  double get paid => installments.fold(0, (s, i) => s + i.paidAmount);

  /// Kalan borç (iptal edilen kayıtta 0).
  double get remaining =>
      isCancelled ? 0 : installments.fold(0, (s, i) => s + i.open);
  bool get settled =>
      installments.isNotEmpty && installments.every((i) => i.isPaid);

  /// Sıradaki ödenmemiş taksit (yoksa null).
  FeeInstallment? get nextDue =>
      installments.where((i) => !i.isPaid).firstOrNull;

  List<FeeInstallment> overdue(DateTime today) => [
    if (!isCancelled)
      for (final i in installments)
        if (i.isOverdue(today)) i,
  ];
}

enum FeeStatus { active, cancelled }

enum DiscountKind {
  discount('discount'),
  scholarship('scholarship'),
  sibling('sibling'),
  other('other');

  const DiscountKind(this.db);
  final String db;

  static DiscountKind fromDb(String? v) =>
      values.firstWhere((k) => k.db == v, orElse: () => other);

  String get label => switch (this) {
    discount => tr('İndirim'),
    scholarship => tr('Burs'),
    sibling => tr('Kardeş indirimi'),
    other => tr('Diğer indirim'),
  };
}

/// Ücrete uygulanan indirim / burs.
class FeeDiscount {
  const FeeDiscount({required this.kind, required this.amount, this.note});

  factory FeeDiscount.fromJson(Map<String, dynamic> j) => FeeDiscount(
    kind: DiscountKind.fromDb(j['kind'] as String?),
    amount: _num(j['amount']),
    note: j['note'] as String?,
  );

  final DiscountKind kind;
  final double amount;
  final String? note;

  Map<String, Object?> toJson() => {
    'kind': kind.db,
    'amount': amount,
    'note': note,
  };
}

/// Tahsilat ya da iade satırı. Bir makbuz birden çok taksite dağılabilir.
class FeePayment {
  const FeePayment({
    required this.id,
    required this.amount,
    required this.paidOn,
    this.feeId,
    this.installmentId,
    this.isRefund = false,
    this.method,
    this.accountId,
    this.receiptNo,
    this.note,
    this.voidedAt,
  });

  factory FeePayment.fromJson(Map<String, dynamic> j) => FeePayment(
    id: j['id'] as String? ?? '${j['receipt_no']}',
    feeId: j['fee_id'] as String?,
    installmentId: j['installment_id'] as String?,
    isRefund: j['kind'] == 'refund',
    amount: _num(j['amount']),
    paidOn: DateTime.parse(j['paid_on'] as String),
    method: PaymentMethod.fromDb(j['method'] as String?),
    accountId: j['account_id'] as String?,
    receiptNo: j['receipt_no'] as String?,
    note: j['note'] as String?,
    voidedAt: j['voided_at'] == null
        ? null
        : DateTime.parse(j['voided_at'] as String),
  );

  final String id;
  final String? feeId;
  final String? installmentId;
  final bool isRefund;
  final double amount;
  final DateTime paidOn;
  final PaymentMethod? method;
  final String? accountId;

  /// "2026-000123"; bu sürümden önce işaretlenen kayıtlarda null.
  final String? receiptNo;
  final String? note;
  final DateTime? voidedAt;

  bool get isVoided => voidedAt != null;
}

/// Bir makbuz: aynı numaralı satırların toplamı.
class Receipt {
  const Receipt({
    required this.number,
    required this.amount,
    required this.date,
    required this.lines,
    this.isRefund = false,
    this.method,
    this.accountId,
    this.note,
    this.voided = false,
  });

  /// Eski kayıtta null.
  final String? number;
  final double amount;
  final DateTime date;
  final bool isRefund;
  final PaymentMethod? method;
  final String? accountId;
  final String? note;
  final bool voided;
  final List<FeePayment> lines;
}

List<Receipt> groupReceipts(List<FeePayment> payments) {
  final groups = <String, List<FeePayment>>{};
  for (final p in payments) {
    groups.putIfAbsent(p.receiptNo ?? 'id:${p.id}', () => []).add(p);
  }
  return [
    for (final g in groups.values)
      Receipt(
        number: g.first.receiptNo,
        amount: g.fold(0, (s, p) => s + p.amount),
        date: g.first.paidOn,
        isRefund: g.first.isRefund,
        method: g.first.method,
        accountId: g.first.accountId,
        note: g.first.note,
        voided: g.every((p) => p.isVoided),
        lines: g,
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));
}

enum AccountKind {
  cash('cash'),
  bank('bank'),
  pos('pos');

  const AccountKind(this.db);
  final String db;

  static AccountKind fromDb(String? v) =>
      values.firstWhere((k) => k.db == v, orElse: () => cash);

  String get label => switch (this) {
    cash => tr('Kasa'),
    bank => tr('Banka'),
    pos => tr('POS / sanal pos'),
  };
}

/// Kasa / banka hesabı.
class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.name,
    this.kind = AccountKind.cash,
    this.iban,
    this.openingBalance = 0,
    this.archived = false,
  });

  factory FinanceAccount.fromJson(Map<String, dynamic> j) => FinanceAccount(
    id: j['id'] as String,
    name: j['name'] as String,
    kind: AccountKind.fromDb(j['kind'] as String?),
    iban: j['iban'] as String?,
    openingBalance: _num(j['opening_balance'] ?? 0),
    archived: j['archived'] as bool? ?? false,
  );

  final String id;
  final String name;
  final AccountKind kind;
  final String? iban;
  final double openingBalance;
  final bool archived;
}

enum IncomeCategory {
  books('books'),
  privateLesson('private_lesson'),
  material('material'),
  event('event'),
  other('other');

  const IncomeCategory(this.db);
  final String db;

  static IncomeCategory fromDb(String? v) =>
      values.firstWhere((k) => k.db == v, orElse: () => other);

  String get label => switch (this) {
    books => tr('Kitap / yayın'),
    privateLesson => tr('Özel ders'),
    material => tr('Materyal'),
    event => tr('Etkinlik'),
    other => tr('Diğer'),
  };
}

/// Ücret dışı gelir.
class FinanceIncome {
  const FinanceIncome({
    required this.id,
    required this.receivedOn,
    required this.category,
    required this.amount,
    this.method,
    this.accountId,
    this.studentId,
    this.studentName,
    this.payerName,
    this.note,
    this.receiptNo,
    this.voidedAt,
  });

  factory FinanceIncome.fromJson(Map<String, dynamic> j) => FinanceIncome(
    id: j['id'] as String,
    receivedOn: DateTime.parse(j['received_on'] as String),
    category: IncomeCategory.fromDb(j['category'] as String?),
    amount: _num(j['amount']),
    method: PaymentMethod.fromDb(j['method'] as String?),
    accountId: j['account_id'] as String?,
    studentId: j['student_id'] as String?,
    studentName: j['student_name'] as String?,
    payerName: j['payer_name'] as String?,
    note: j['note'] as String?,
    receiptNo: j['receipt_no'] as String?,
    voidedAt: j['voided_at'] == null
        ? null
        : DateTime.parse(j['voided_at'] as String),
  );

  final String id;
  final DateTime receivedOn;
  final IncomeCategory category;
  final double amount;
  final PaymentMethod? method;
  final String? accountId;
  final String? studentId;
  final String? studentName;
  final String? payerName;
  final String? note;
  final String? receiptNo;
  final DateTime? voidedAt;

  bool get isVoided => voidedAt != null;
}

class IncomeDraft {
  const IncomeDraft({
    required this.receivedOn,
    required this.category,
    required this.amount,
    this.method,
    this.accountId,
    this.studentId,
    this.payerName,
    this.note,
  });

  final DateTime receivedOn;
  final IncomeCategory category;
  final double amount;
  final PaymentMethod? method;
  final String? accountId;
  final String? studentId;
  final String? payerName;
  final String? note;
}

/// Hesaplar arası para aktarımı (ör. kasadan bankaya yatırma).
class FinanceTransfer {
  const FinanceTransfer({
    required this.id,
    required this.fromAccount,
    required this.toAccount,
    required this.amount,
    required this.movedOn,
    this.note,
  });

  factory FinanceTransfer.fromJson(Map<String, dynamic> j) => FinanceTransfer(
    id: j['id'] as String,
    fromAccount: j['from_account'] as String,
    toAccount: j['to_account'] as String,
    amount: _num(j['amount']),
    movedOn: DateTime.parse(j['moved_on'] as String),
    note: j['note'] as String?,
  );

  final String id;
  final String fromAccount;
  final String toAccount;
  final double amount;
  final DateTime movedOn;
  final String? note;
}

/// Program / sınıf ücret şablonu.
class FeePlan {
  const FeePlan({
    required this.id,
    required this.name,
    required this.total,
    this.installmentCount = 1,
    this.note,
  });

  factory FeePlan.fromJson(Map<String, dynamic> j) => FeePlan(
    id: j['id'] as String,
    name: j['name'] as String,
    total: _num(j['total']),
    installmentCount: j['installment_count'] as int? ?? 1,
    note: j['note'] as String?,
  );

  final String id;
  final String name;
  final double total;
  final int installmentCount;
  final String? note;
}

/// `record_payment` / `cancel_fee` sonucu.
class PaymentResult {
  const PaymentResult({this.receiptNo, this.remaining = 0});
  final String? receiptNo;
  final double remaining;
}

/// Toplu ücret sonucu.
class BulkFeeResult {
  const BulkFeeResult({required this.created, this.skipped = const []});
  final int created;

  /// Kurumda olmayan ya da aynı başlıkta aktif ücreti olan öğrenciler.
  final List<String> skipped;
}

/// Velinin gördüğü: çocuğunun ücretleri ve makbuzları.
class ChildFinance {
  const ChildFinance({this.orgName, this.fees = const []});
  final String? orgName;
  final List<StudentFee> fees;

  bool get isEmpty => fees.isEmpty;
}

ChildFinance childFinanceFromJson(Map<String, dynamic> j, String studentId) {
  final fees = <StudentFee>[];
  for (final f in (j['fees'] as List? ?? const [])) {
    final m = (f as Map).cast<String, dynamic>();
    final id = m['id'] as String;
    final discount = _num(m['discount'] ?? 0);
    fees.add(
      StudentFee(
        id: id,
        studentId: studentId,
        studentName: m['student_name'] as String? ?? '',
        title: m['title'] as String,
        total: _num(m['total']),
        payerName: m['payer_name'] as String?,
        createdAt: DateTime.now(),
        status: m['status'] == 'cancelled'
            ? FeeStatus.cancelled
            : FeeStatus.active,
        discounts: [
          if (discount > 0)
            FeeDiscount(kind: DiscountKind.discount, amount: discount),
        ],
        installments: [
          for (final (k, i) in (m['installments'] as List).indexed)
            FeeInstallment(
              id: '$id-$k',
              feeId: id,
              dueOn: DateTime.parse(i['due_on'] as String),
              amount: _num(i['amount']),
              paidAmount: _num(i['paid_amount'] ?? 0),
              paidOn: i['paid_on'] == null
                  ? null
                  : DateTime.parse(i['paid_on'] as String),
            ),
        ],
        payments: [
          for (final (k, x) in (m['payments'] as List).indexed)
            FeePayment(
              id: '$id-p$k',
              feeId: id,
              amount: _num(x['amount']),
              paidOn: DateTime.parse(x['paid_on'] as String),
              isRefund: x['kind'] == 'refund',
              method: PaymentMethod.fromDb(x['method'] as String?),
              receiptNo: x['receipt_no'] as String?,
            ),
        ],
      ),
    );
  }
  return ChildFinance(orgName: j['org_name'] as String?, fees: fees);
}

/// Hesap bakiyeleri: açılış + tahsilat − iade + gelir − gider ± virman.
/// Hesaba bağlanmamış hareketler `null` anahtarında.
Map<String?, double> accountBalances({
  required List<FinanceAccount> accounts,
  required List<StudentFee> fees,
  required List<FinanceIncome> incomes,
  required List<FinanceExpense> expenses,
  required List<FinanceTransfer> transfers,
}) {
  final out = <String?, double>{
    for (final a in accounts) a.id: a.openingBalance,
  };
  void add(String? id, double v) => out[id] = (out[id] ?? 0) + v;
  for (final p in fees.expand((f) => f.payments)) {
    if (!p.isVoided) add(p.accountId, p.isRefund ? -p.amount : p.amount);
  }
  for (final i in incomes) {
    if (!i.isVoided) add(i.accountId, i.amount);
  }
  for (final e in expenses) {
    add(e.accountId, -e.amount);
  }
  for (final t in transfers) {
    add(t.fromAccount, -t.amount);
    add(t.toAccount, t.amount);
  }
  return out;
}

/// Ödenmemiş taksitlere dağıtım (sunucudaki record_payment ile aynı):
/// [first] önce, sonra en eski vadeli.
List<(FeeInstallment, double)> allocatePayment(
  List<FeeInstallment> installments,
  double amount, {
  String? first,
}) {
  final open =
      [
        for (final i in installments)
          if (i.open > 0) i,
      ]..sort((a, b) {
        if (a.id == first) return -1;
        if (b.id == first) return 1;
        return a.dueOn.compareTo(b.dueOn);
      });
  var left = amount;
  final out = <(FeeInstallment, double)>[];
  for (final i in open) {
    if (left <= 0.004) break;
    final part = left < i.open ? left : i.open;
    out.add((i, double.parse(part.toStringAsFixed(2))));
    left -= part;
  }
  return out;
}

class FinanceExpense {
  const FinanceExpense({
    required this.id,
    required this.spentOn,
    required this.category,
    required this.amount,
    this.note,
    this.coachId,
    this.coachName,
    this.accountId,
  });

  factory FinanceExpense.fromJson(Map<String, dynamic> j) => FinanceExpense(
    id: j['id'] as String,
    spentOn: DateTime.parse(j['spent_on'] as String),
    category: ExpenseCategory.fromDb(j['category'] as String),
    amount: _num(j['amount']),
    note: j['note'] as String?,
    coachId: j['coach_id'] as String?,
    coachName: j['coach_name'] as String?,
    accountId: j['account_id'] as String?,
  );

  final String id;
  final DateTime spentOn;
  final ExpenseCategory category;
  final double amount;
  final String? note;

  /// Maaş / prim bir koça bağlıysa; koç silindiyse null, ad kalır.
  final String? coachId;
  final String? coachName;
  final String? accountId;
}

/// Koçun aylık maaşı ve öğrenci başına primi.
class CoachPayRate {
  const CoachPayRate({
    required this.coachId,
    this.monthlySalary = 0,
    this.perStudent = 0,
  });

  factory CoachPayRate.fromJson(Map<String, dynamic> j) => CoachPayRate(
    coachId: j['coach_id'] as String,
    monthlySalary: _num(j['monthly_salary']),
    perStudent: _num(j['per_student']),
  );

  final String coachId;
  final double monthlySalary;
  final double perStudent;

  /// Bu ayın önerilen ödemesi: maaş + öğrenci sayısı × prim.
  double suggested(int students) => monthlySalary + perStudent * students;
}

class FeeDraft {
  const FeeDraft({
    required this.studentId,
    required this.title,
    required this.total,
    required this.installments,
    this.note,
    this.payer = const FeePayer(),
    this.discounts = const [],
  });

  final String studentId;
  final String title;

  /// İndirimsiz ücret; taksitlerin toplamı [total] − indirimler.
  final double total;
  final List<(DateTime, double)> installments;
  final String? note;
  final FeePayer payer;
  final List<FeeDiscount> discounts;

  double get netTotal => total - discounts.fold(0.0, (s, d) => s + d.amount);
}

/// Ödeme günü ve ödeyen veli (sonradan değiştirilebilir).
class FeePayer {
  const FeePayer({this.dueDay, this.name, this.phone});

  final int? dueDay;
  final String? name;

  /// "+905XXXXXXXXX" ([normalizePhone]).
  final String? phone;
}

/// `send_payment_reminders` sonucu.
class ReminderResult {
  const ReminderResult({this.queued = 0, this.noPhone = 0, this.skipped = 0});

  factory ReminderResult.fromJson(Map<String, dynamic> j) => ReminderResult(
    queued: j['queued'] as int? ?? 0,
    noPhone: j['no_phone'] as int? ?? 0,
    skipped: j['skipped'] as int? ?? 0,
  );

  /// SMS sırasına yazılan.
  final int queued;

  /// Veli telefonu olmadığı için gönderilemeyen.
  final int noPhone;

  /// Ödenmiş ya da son 20 saatte hatırlatılmış.
  final int skipped;
}

/// Vadesi [day] olan, ödenmemiş taksitler (ücretleriyle).
List<(StudentFee, FeeInstallment)> unpaidDueOn(
  List<StudentFee> fees,
  DateTime day,
) => [
  for (final f in fees)
    for (final i in f.installments)
      if (!i.isPaid &&
          i.dueOn.year == day.year &&
          i.dueOn.month == day.month &&
          i.dueOn.day == day.day)
        (f, i),
];

class ExpenseDraft {
  const ExpenseDraft({
    required this.spentOn,
    required this.category,
    required this.amount,
    this.note,
    this.coachId,
    this.accountId,
  });

  final DateTime spentOn;
  final ExpenseCategory category;
  final double amount;
  final String? note;
  final String? coachId;
  final String? accountId;
}

/// Toplamı [count] aylık taksite böler: tutarlar tam lira, kuruş farkı son
/// taksitte. İlk vade [firstDue], sonrakiler her ay aynı gün (ay kısaysa
/// ayın son günü).
List<(DateTime, double)> splitInstallments(
  double total,
  int count,
  DateTime firstDue,
) {
  if (count <= 1) return [(_day(firstDue), total)];
  final each = (total / count).floorToDouble();
  return [
    for (var i = 0; i < count; i++)
      (
        _addMonths(firstDue, i),
        i == count - 1
            ? double.parse((total - each * (count - 1)).toStringAsFixed(2))
            : each,
      ),
  ];
}

DateTime _addMonths(DateTime d, int months) {
  final first = DateTime(d.year, d.month + months);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, d.day > last ? last : d.day);
}

/// Bir ayın özeti.
class MonthSummary {
  const MonthSummary({
    required this.collected,
    required this.expected,
    required this.expenses,
    required this.overdueAmount,
    required this.overdueCount,
    this.otherIncome = 0,
    this.refunds = 0,
  });

  /// Bu ay tahsil edilen ücret (kısmi ödemeler dahil).
  final double collected;

  /// Ücret dışı gelirler (kitap, özel ders, ...).
  final double otherIncome;

  /// Bu ay yapılan iadeler.
  final double refunds;

  /// Vadesi bu ay olan taksitler (ödenmiş ya da değil).
  final double expected;
  final double expenses;

  /// Bugün itibarıyla vadesi geçmiş, ödenmemiş taksitler (aydan bağımsız).
  final double overdueAmount;
  final int overdueCount;

  double get net => collected + otherIncome - refunds - expenses;
}

MonthSummary monthSummary(
  List<StudentFee> fees,
  List<FinanceExpense> expenses,
  DateTime month, {
  required DateTime today,
  List<FinanceIncome> incomes = const [],
}) {
  var collected = 0.0, expected = 0.0, overdue = 0.0, refunds = 0.0;
  var overdueCount = 0;
  for (final f in fees) {
    if (f.payments.isNotEmpty) {
      for (final p in f.payments) {
        if (p.isVoided || !_sameMonth(p.paidOn, month)) continue;
        if (p.isRefund) {
          refunds += p.amount;
        } else {
          collected += p.amount;
        }
      }
    } else {
      for (final i in f.installments) {
        if (i.paidOn != null && _sameMonth(i.paidOn!, month)) {
          collected += i.amount;
        }
      }
    }
    for (final i in f.installments) {
      if (_sameMonth(i.dueOn, month)) expected += i.amount;
    }
    for (final i in f.overdue(today)) {
      overdue += i.open;
      overdueCount++;
    }
  }
  return MonthSummary(
    otherIncome: incomes
        .where((i) => !i.isVoided && _sameMonth(i.receivedOn, month))
        .fold(0, (s, i) => s + i.amount),
    refunds: refunds,
    collected: collected,
    expected: expected,
    expenses: expenses
        .where((e) => _sameMonth(e.spentOn, month))
        .fold(0, (s, e) => s + e.amount),
    overdueAmount: overdue,
    overdueCount: overdueCount,
  );
}

/// Bu ay koça maaş / prim gideri yazıldı mı.
bool coachPaidIn(
  List<FinanceExpense> expenses,
  String coachId,
  DateTime month,
) => expenses.any(
  (e) =>
      e.coachId == coachId &&
      e.category == ExpenseCategory.salary &&
      _sameMonth(e.spentOn, month),
);

abstract interface class FinanceRepository {
  /// Kurumdaki tüm ücretler, taksitleriyle; en yeni önce.
  Future<List<StudentFee>> fetchFees();
  Future<void> addFee(FeeDraft draft);
  Future<void> deleteFee(String id);

  /// Seçilen öğrencilere aynı ücret; aynı başlıkta aktif ücreti olan atlanır.
  /// Toplu ücret. Aynı başlıkta aktif ücreti olan öğrenci atlanır;
  /// [allowDuplicate] ile onlara da açılır.
  Future<BulkFeeResult> addFeesBulk(
    List<String> studentIds,
    FeeDraft draft, {
    bool allowDuplicate = false,
  });

  /// Tahsilat: tutar ödenmemiş taksitlere dağıtılır ([installmentId] önce).
  Future<PaymentResult> recordPayment(
    String feeId, {
    required double amount,
    required DateTime paidOn,
    PaymentMethod? method,
    String? accountId,
    String? note,
    String? installmentId,
  });

  /// Makbuzu iptal et (tahsilat ya da gelir).
  Future<void> voidReceipt(String receiptNo);

  /// Sonradan indirim / burs: son vadeli taksitten başlayarak düşülür.
  Future<void> addDiscount(
    String feeId,
    DiscountKind kind,
    double amount, {
    String? note,
  });

  /// Kayıt iptali; [refund] > 0 ise iade makbuzu döner.
  Future<PaymentResult> cancelFee(
    String feeId, {
    double refund = 0,
    required DateTime on,
    PaymentMethod? method,
    String? accountId,
    String? note,
  });

  Future<List<FinanceIncome>> fetchIncomes();
  Future<String> recordIncome(IncomeDraft draft);

  Future<List<FinanceAccount>> fetchAccounts();
  Future<void> saveAccount(FinanceAccount account, {bool isNew = false});

  Future<List<FinanceTransfer>> fetchTransfers();
  Future<void> addTransfer({
    required String from,
    required String to,
    required double amount,
    required DateTime on,
    String? note,
  });
  Future<void> deleteTransfer(String id);

  Future<List<FeePlan>> fetchPlans();
  Future<void> savePlan(FeePlan plan, {bool isNew = false});
  Future<void> deletePlan(String id);

  /// Veli: çocuğunun ücretleri ve makbuzları (salt okuma).
  Future<ChildFinance> fetchChildFinance(String studentId);

  /// Ödeme günü ve ödeyen veliyi değiştir.
  Future<void> updatePayer(String feeId, FeePayer payer);

  /// Müdür onayıyla veliye SMS hatırlatması (sıraya yazar).
  Future<ReminderResult> sendReminders(List<String> installmentIds);

  /// Giderler, en yeni önce.
  Future<List<FinanceExpense>> fetchExpenses();
  Future<void> addExpense(ExpenseDraft draft);
  Future<void> deleteExpense(String id);

  Future<Map<String, CoachPayRate>> fetchPayRates();
  Future<void> savePayRate(CoachPayRate rate);
}

class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StudentFee>> fetchFees() async {
    // Toplu ücretlerin created_at'i aynı olur; id sayfalamayı kesinleştirir.
    final rows = await fetchAllPages(
      (from, to) => _client
          .from('finance_fees')
          .select(
            'id, student_id, student_name, title, total, note, created_at, '
            'due_day, payer_name, payer_phone, status, cancelled_on, cancel_note, '
            'finance_installments(id, fee_id, due_on, amount, paid_on, paid_amount, method, reminded_at), '
            'finance_discounts(kind, amount, note), '
            'finance_payments(id, fee_id, installment_id, kind, amount, paid_on, method, account_id, receipt_no, note, voided_at)',
          )
          .order('created_at', ascending: false)
          .order('id')
          .range(from, to),
    );
    return [for (final r in rows) StudentFee.fromJson(r)];
  }

  Map<String, Object?> _feeParams(FeeDraft d) => {
    'p_title': d.title,
    'p_total': d.total,
    'p_discounts': [for (final x in d.discounts) x.toJson()],
    'p_installments': [
      for (final (due, amount) in d.installments)
        {'due_on': _ymd(due), 'amount': amount},
    ],
    'p_note': d.note,
    'p_due_day': d.payer.dueDay,
  };

  @override
  Future<void> addFee(FeeDraft d) => _client.rpc(
    'create_fee',
    params: {
      ..._feeParams(d),
      'p_student': d.studentId,
      'p_payer_name': d.payer.name,
      'p_payer_phone': d.payer.phone,
    },
  );

  @override
  Future<BulkFeeResult> addFeesBulk(
    List<String> ids,
    FeeDraft d, {
    bool allowDuplicate = false,
  }) async {
    final r = Map<String, dynamic>.from(
      await _client.rpc(
            'create_fees_bulk',
            params: {
              ..._feeParams(d),
              'p_students': ids,
              'p_allow_duplicate': allowDuplicate,
            },
          )
          as Map,
    );
    return BulkFeeResult(
      created: r['created'] as int,
      skipped: [for (final x in r['skipped'] as List) x as String],
    );
  }

  @override
  Future<void> deleteFee(String id) =>
      _client.from('finance_fees').delete().eq('id', id);

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
    final r = Map<String, dynamic>.from(
      await _client.rpc(
            'record_payment',
            params: {
              'p_fee': feeId,
              'p_amount': amount,
              'p_paid_on': _ymd(paidOn),
              'p_method': method?.db,
              'p_account': accountId,
              'p_note': note,
              'p_installment': installmentId,
            },
          )
          as Map,
    );
    return PaymentResult(
      receiptNo: r['receipt_no'] as String?,
      remaining: _num(r['remaining'] ?? 0),
    );
  }

  @override
  Future<void> voidReceipt(String receiptNo) =>
      _client.rpc('void_receipt', params: {'p_receipt': receiptNo});

  @override
  Future<void> addDiscount(
    String feeId,
    DiscountKind kind,
    double amount, {
    String? note,
  }) => _client.rpc(
    'add_fee_discount',
    params: {
      'p_fee': feeId,
      'p_kind': kind.db,
      'p_amount': amount,
      'p_note': note,
    },
  );

  @override
  Future<PaymentResult> cancelFee(
    String feeId, {
    double refund = 0,
    required DateTime on,
    PaymentMethod? method,
    String? accountId,
    String? note,
  }) async {
    final r = Map<String, dynamic>.from(
      await _client.rpc(
            'cancel_fee',
            params: {
              'p_fee': feeId,
              'p_refund': refund,
              'p_on': _ymd(on),
              'p_method': method?.db,
              'p_account': accountId,
              'p_note': note,
            },
          )
          as Map,
    );
    return PaymentResult(receiptNo: r['receipt_no'] as String?);
  }

  @override
  Future<List<FinanceIncome>> fetchIncomes() async {
    final rows = await fetchAllPages(
      (from, to) => _client
          .from('finance_incomes')
          .select()
          .order('received_on', ascending: false)
          .order('created_at', ascending: false)
          .order('id')
          .range(from, to),
    );
    return [for (final r in rows) FinanceIncome.fromJson(r)];
  }

  @override
  Future<String> recordIncome(IncomeDraft d) async =>
      await _client.rpc(
            'record_income',
            params: {
              'p_on': _ymd(d.receivedOn),
              'p_category': d.category.db,
              'p_amount': d.amount,
              'p_method': d.method?.db,
              'p_account': d.accountId,
              'p_student': d.studentId,
              'p_payer_name': d.payerName,
              'p_note': d.note,
            },
          )
          as String;

  @override
  Future<List<FinanceAccount>> fetchAccounts() async {
    final rows = await _client
        .from('finance_accounts')
        .select('id, name, kind, iban, opening_balance, archived')
        .order('created_at');
    return [for (final r in rows) FinanceAccount.fromJson(r)];
  }

  @override
  Future<void> saveAccount(FinanceAccount a, {bool isNew = false}) {
    final body = {
      'name': a.name,
      'kind': a.kind.db,
      'iban': a.iban,
      'opening_balance': a.openingBalance,
      'archived': a.archived,
    };
    return isNew
        ? _client.from('finance_accounts').insert(body)
        : _client.from('finance_accounts').update(body).eq('id', a.id);
  }

  @override
  Future<List<FinanceTransfer>> fetchTransfers() async {
    final rows = await fetchAllPages(
      (from, to) => _client
          .from('finance_transfers')
          .select('id, from_account, to_account, amount, moved_on, note')
          .order('moved_on', ascending: false)
          .order('id')
          .range(from, to),
    );
    return [for (final r in rows) FinanceTransfer.fromJson(r)];
  }

  @override
  Future<void> addTransfer({
    required String from,
    required String to,
    required double amount,
    required DateTime on,
    String? note,
  }) => _client.from('finance_transfers').insert({
    'from_account': from,
    'to_account': to,
    'amount': amount,
    'moved_on': _ymd(on),
    'note': note,
  });

  @override
  Future<void> deleteTransfer(String id) =>
      _client.from('finance_transfers').delete().eq('id', id);

  @override
  Future<List<FeePlan>> fetchPlans() async {
    final rows = await _client
        .from('fee_plans')
        .select('id, name, total, installment_count, note')
        .order('name');
    return [for (final r in rows) FeePlan.fromJson(r)];
  }

  @override
  Future<void> savePlan(FeePlan p, {bool isNew = false}) {
    final body = {
      'name': p.name,
      'total': p.total,
      'installment_count': p.installmentCount,
      'note': p.note,
    };
    return isNew
        ? _client.from('fee_plans').insert(body)
        : _client.from('fee_plans').update(body).eq('id', p.id);
  }

  @override
  Future<void> deletePlan(String id) =>
      _client.from('fee_plans').delete().eq('id', id);

  @override
  Future<ChildFinance> fetchChildFinance(String studentId) async {
    final r = await _client.rpc(
      'my_child_finance',
      params: {'p_student': studentId},
    );
    return childFinanceFromJson(Map<String, dynamic>.from(r as Map), studentId);
  }

  @override
  Future<void> updatePayer(String feeId, FeePayer p) => _client
      .from('finance_fees')
      .update({
        'due_day': p.dueDay,
        'payer_name': p.name,
        'payer_phone': p.phone,
      })
      .eq('id', feeId);

  @override
  Future<ReminderResult> sendReminders(List<String> ids) async {
    final r = await _client.rpc(
      'send_payment_reminders',
      params: {'p_installments': ids},
    );
    return ReminderResult.fromJson((r as Map).cast<String, dynamic>());
  }

  @override
  Future<List<FinanceExpense>> fetchExpenses() async {
    final rows = await fetchAllPages(
      (from, to) => _client
          .from('finance_expenses')
          .select(
            'id, spent_on, category, amount, note, coach_id, coach_name, account_id',
          )
          .order('spent_on', ascending: false)
          .order('created_at', ascending: false)
          .order('id')
          .range(from, to),
    );
    return [for (final r in rows) FinanceExpense.fromJson(r)];
  }

  @override
  Future<void> addExpense(ExpenseDraft d) =>
      _client.from('finance_expenses').insert({
        'spent_on': _ymd(d.spentOn),
        'category': d.category.db,
        'amount': d.amount,
        'note': d.note,
        'coach_id': d.coachId,
        'account_id': d.accountId,
      });

  @override
  Future<void> deleteExpense(String id) =>
      _client.from('finance_expenses').delete().eq('id', id);

  @override
  Future<Map<String, CoachPayRate>> fetchPayRates() async {
    final rows = await _client
        .from('coach_pay_rates')
        .select('coach_id, monthly_salary, per_student');
    return {
      for (final r in rows) r['coach_id'] as String: CoachPayRate.fromJson(r),
    };
  }

  @override
  Future<void> savePayRate(CoachPayRate r) =>
      _client.from('coach_pay_rates').upsert({
        'coach_id': r.coachId,
        'monthly_salary': r.monthlySalary,
        'per_student': r.perStudent,
      });
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => SupabaseFinanceRepository(ref.watch(supabaseClientProvider)),
);

final financeFeesProvider = FutureProvider<List<StudentFee>>(
  (ref) => ref.watch(financeRepositoryProvider).fetchFees(),
);

final financeExpensesProvider = FutureProvider<List<FinanceExpense>>(
  (ref) => ref.watch(financeRepositoryProvider).fetchExpenses(),
);

final coachPayRatesProvider = FutureProvider<Map<String, CoachPayRate>>(
  (ref) => ref.watch(financeRepositoryProvider).fetchPayRates(),
);

final financeIncomesProvider = FutureProvider<List<FinanceIncome>>(
  (ref) => ref.watch(financeRepositoryProvider).fetchIncomes(),
);

final financeAccountsProvider = FutureProvider<List<FinanceAccount>>(
  (ref) => ref.watch(financeRepositoryProvider).fetchAccounts(),
);

final financeTransfersProvider = FutureProvider<List<FinanceTransfer>>(
  (ref) => ref.watch(financeRepositoryProvider).fetchTransfers(),
);

final feePlansProvider = FutureProvider<List<FeePlan>>(
  (ref) => ref.watch(financeRepositoryProvider).fetchPlans(),
);

final childFinanceProvider = FutureProvider.family<ChildFinance, String>(
  (ref, studentId) =>
      ref.watch(financeRepositoryProvider).fetchChildFinance(studentId),
);
