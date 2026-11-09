import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import 'finance_repository.dart';

/// Excel dönemi: bir ay ya da bir takvim yılı.
class FinancePeriod {
  const FinancePeriod.month(int year, int month)
    : start = year,
      _month = month,
      isYear = false;

  const FinancePeriod.year(int year) : start = year, _month = 1, isYear = true;

  /// Dönemin yılı.
  final int start;
  final int _month;
  final bool isYear;

  DateTime get from => DateTime(start, isYear ? 1 : _month);
  DateTime get until =>
      isYear ? DateTime(start + 1) : DateTime(start, _month + 1);

  bool contains(DateTime d) => !d.isBefore(from) && d.isBefore(until);

  /// "Kasım 2026" ya da "2026".
  String get label =>
      isYear ? '$start' : DateFormat('MMMM yyyy', localeTag).format(from);

  /// Dosya adı için: "2026-11" ya da "2026".
  String get slug =>
      isYear ? '$start' : '$start-${_month.toString().padLeft(2, '0')}';

  /// Dönemdeki aylar (yıllıkta 12, aylıkta 1).
  List<DateTime> get months => [
    for (var m = 0; m < (isYear ? 12 : 1); m++)
      DateTime(from.year, from.month + m),
  ];
}

String _date(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

/// Kurum finansının aylık ya da yıllık Excel dosyası:
///  * Özet: tahsilat, beklenen, gider, net, geciken; yıllıkta ay ay tablo;
///    gider türlerine göre dağılım.
///  * Tahsilatlar: dönemde ödendi işaretlenen taksitler.
///  * Taksitler: vadesi dönemde olan taksitler ve durumları.
///  * Giderler: dönemdeki giderler.
///  * Öğrenci bakiyeleri: bugün itibarıyla toplam / ödenen / kalan / geciken.
Uint8List buildFinanceWorkbook({
  required List<StudentFee> fees,
  required List<FinanceExpense> expenses,
  required FinancePeriod period,
  required DateTime today,
  String? orgName,
  List<FinanceIncome> incomes = const [],
  List<FinanceAccount> accounts = const [],
  List<FinanceTransfer> transfers = const [],
}) {
  final book = xl.Excel.createExcel();
  final defaultSheet = book.getDefaultSheet();
  xl.CellValue t(String v) => xl.TextCellValue(v);
  xl.CellValue n(num v) =>
      v is int ? xl.IntCellValue(v) : xl.DoubleCellValue(v.toDouble());
  xl.CellValue money(double v) => xl.DoubleCellValue((v * 100).round() / 100);
  final bold = xl.CellStyle(bold: true);
  void header(xl.Sheet s, List<String> cols) {
    s.appendRow([for (final c in cols) t(c)]);
    final r = s.maxRows - 1;
    for (var c = 0; c < cols.length; c++) {
      s
              .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
              .cellStyle =
          bold;
    }
  }

  final installments = [
    for (final f in fees)
      for (final i in f.installments) (f, i),
  ];

  // --- Özet ---
  final summary = book[tr('Özet')];
  // Tahsilat: makbuzlu satırlar (kısmi ödemeler dahil); eski kayıtta taksit.
  final payRows = <(StudentFee, FeePayment)>[
    for (final f in fees)
      for (final p in f.payments)
        if (!p.isVoided && period.contains(p.paidOn)) (f, p),
  ]..sort((a, b) => a.$2.paidOn.compareTo(b.$2.paidOn));
  final legacyPaid = [
    for (final x in installments)
      if (x.$1.payments.isEmpty &&
          x.$2.paidOn != null &&
          period.contains(x.$2.paidOn!))
        x,
  ];
  final collected =
      payRows
          .where((x) => !x.$2.isRefund)
          .fold<double>(0, (s, x) => s + x.$2.amount) +
      legacyPaid.fold<double>(0, (s, x) => s + x.$2.amount);
  final refunds = payRows
      .where((x) => x.$2.isRefund)
      .fold<double>(0, (s, x) => s + x.$2.amount);
  final periodIncomes = [
    for (final i in incomes)
      if (!i.isVoided && period.contains(i.receivedOn)) i,
  ]..sort((a, b) => a.receivedOn.compareTo(b.receivedOn));
  final other = periodIncomes.fold<double>(0, (s, i) => s + i.amount);
  final expected = installments
      .where((x) => period.contains(x.$2.dueOn))
      .fold<double>(0, (s, x) => s + x.$2.amount);
  final periodExpenses = [
    for (final e in expenses)
      if (period.contains(e.spentOn)) e,
  ]..sort((a, b) => a.spentOn.compareTo(b.spentOn));
  final spent = periodExpenses.fold<double>(0, (s, e) => s + e.amount);
  final overdue = installments.where((x) => x.$2.isOverdue(today)).toList();
  header(summary, [tr('Kurum finansı'), orgName ?? '']);
  summary.appendRow([t(tr('Dönem')), t(period.label)]);
  summary.appendRow([t(tr('Hazırlanma tarihi')), t(_date(today))]);
  summary.appendRow([]);
  summary.appendRow([t(tr('Tahsilat (₺)')), money(collected)]);
  summary.appendRow([t(tr('Beklenen: vadesi dönemde (₺)')), money(expected)]);
  summary.appendRow([t(tr('Diğer gelir (₺)')), money(other)]);
  summary.appendRow([t(tr('İade (₺)')), money(refunds)]);
  summary.appendRow([t(tr('Gider (₺)')), money(spent)]);
  summary.appendRow([
    t(tr('Net: tahsilat + gelir − iade − gider (₺)')),
    money(collected + other - refunds - spent),
  ]);
  summary.appendRow([
    t(tr('Bugün geciken taksit')),
    n(overdue.length),
    money(overdue.fold<double>(0, (s, x) => s + x.$2.open)),
  ]);
  if (period.isYear) {
    summary.appendRow([]);
    header(summary, [
      tr('Ay'),
      tr('Tahsilat (₺)'),
      tr('Beklenen (₺)'),
      tr('Gider (₺)'),
      tr('Net (₺)'),
    ]);
    for (final m in period.months) {
      final s = monthSummary(fees, expenses, m, today: today, incomes: incomes);
      summary.appendRow([
        t(DateFormat('MMMM', localeTag).format(m)),
        money(s.collected),
        money(s.expected),
        money(s.expenses),
        money(s.net),
      ]);
    }
    summary.appendRow([
      t(tr('Toplam')),
      money(collected),
      money(expected),
      money(spent),
      money(collected + other - refunds - spent),
    ]);
  }
  summary.appendRow([]);
  header(summary, [tr('Gider türü'), tr('Tutar (₺)')]);
  for (final c in ExpenseCategory.values) {
    final sum = periodExpenses
        .where((e) => e.category == c)
        .fold<double>(0, (s, e) => s + e.amount);
    if (sum > 0) summary.appendRow([t(c.label), money(sum)]);
  }

  // --- Tahsilatlar (makbuz satırları; iade eksi) ---
  final accName = {for (final a in accounts) a.id: a.name};
  final paid = book[tr('Tahsilatlar')];
  header(paid, [
    tr('Tarih'),
    tr('Makbuz no'),
    tr('Öğrenci'),
    tr('Ücret kalemi'),
    tr('Tür'),
    tr('Tutar (₺)'),
    tr('Ödeme şekli'),
    tr('Hesap'),
  ]);
  for (final (f, p) in payRows) {
    paid.appendRow([
      t(_date(p.paidOn)),
      t(p.receiptNo ?? ''),
      t(f.studentName),
      t(f.title),
      t(p.isRefund ? tr('İade') : tr('Tahsilat')),
      money(p.isRefund ? -p.amount : p.amount),
      t(p.method?.label ?? ''),
      t(accName[p.accountId] ?? ''),
    ]);
  }
  for (final (f, i) in legacyPaid) {
    paid.appendRow([
      t(_date(i.paidOn!)),
      t(''),
      t(f.studentName),
      t(f.title),
      t(tr('Tahsilat')),
      money(i.amount),
      t(i.method?.label ?? ''),
      t(''),
    ]);
  }

  // --- Diğer gelirler ---
  final inc = book[tr('Diğer gelirler')];
  header(inc, [
    tr('Tarih'),
    tr('Makbuz no'),
    tr('Tür'),
    tr('Öğrenci / ödeyen'),
    tr('Tutar (₺)'),
    tr('Ödeme şekli'),
    tr('Hesap'),
    tr('Not'),
  ]);
  for (final i in periodIncomes) {
    inc.appendRow([
      t(_date(i.receivedOn)),
      t(i.receiptNo ?? ''),
      t(i.category.label),
      t(i.studentName ?? i.payerName ?? ''),
      money(i.amount),
      t(i.method?.label ?? ''),
      t(accName[i.accountId] ?? ''),
      t(i.note ?? ''),
    ]);
  }

  // --- Taksitler ---
  final due = book[tr('Taksitler')];
  header(due, [
    tr('Vade'),
    tr('Öğrenci'),
    tr('Ücret kalemi'),
    tr('Tutar (₺)'),
    tr('Durum'),
    tr('Ödendiği tarih'),
    tr('Veli'),
  ]);
  final dueRows = [
    for (final x in installments)
      if (period.contains(x.$2.dueOn)) x,
  ]..sort((a, b) => a.$2.dueOn.compareTo(b.$2.dueOn));
  for (final (f, i) in dueRows) {
    due.appendRow([
      t(_date(i.dueOn)),
      t(f.studentName),
      t(f.title),
      money(i.amount),
      t(
        i.isPaid
            ? tr('Ödendi')
            : i.isPartial
            ? tr('Kısmen ödendi')
            : i.isOverdue(today)
            ? tr('Gecikti')
            : tr('Bekliyor'),
      ),
      t(i.paidOn == null ? '' : _date(i.paidOn!)),
      t([f.payerName, f.payerPhone].whereType<String>().join(' · ')),
    ]);
  }

  // --- Giderler ---
  final exp = book[tr('Giderler')];
  header(exp, [
    tr('Tarih'),
    tr('Gider türü'),
    tr('Tutar (₺)'),
    tr('Koç / öğretmen'),
    tr('Not'),
  ]);
  for (final e in periodExpenses) {
    exp.appendRow([
      t(_date(e.spentOn)),
      t(e.category.label),
      money(e.amount),
      t(e.coachName ?? e.teacherName ?? ''),
      t(e.note ?? ''),
    ]);
  }

  // --- Öğrenci bakiyeleri (bugün itibarıyla) ---
  final bal = book[tr('Öğrenci bakiyeleri')];
  header(bal, [
    tr('Öğrenci'),
    tr('Ücret kalemi'),
    tr('İndirimsiz ücret (₺)'),
    tr('İndirim (₺)'),
    tr('Ödenen (₺)'),
    tr('İade (₺)'),
    tr('Kalan (₺)'),
    tr('Geciken (₺)'),
    tr('Durum'),
  ]);
  final sortedFees = [...fees]
    ..sort((a, b) => a.studentName.compareTo(b.studentName));
  for (final f in sortedFees) {
    final lateSum = f.overdue(today).fold<double>(0, (s, i) => s + i.open);
    bal.appendRow([
      t(f.studentName),
      t(f.title),
      money(f.total),
      money(f.discountTotal),
      money(f.paid),
      money(f.refunded),
      money(f.remaining),
      money(lateSum),
      t(f.isCancelled ? tr('Kayıt iptal') : tr('Aktif')),
    ]);
  }

  // --- Hesaplar (bugün itibarıyla) ---
  if (accounts.isNotEmpty) {
    final acc = book[tr('Hesaplar')];
    header(acc, [tr('Hesap'), tr('Tür'), tr('IBAN'), tr('Bakiye (₺)')]);
    final b = accountBalances(
      accounts: accounts,
      fees: fees,
      incomes: incomes,
      expenses: expenses,
      transfers: transfers,
    );
    for (final a in accounts) {
      acc.appendRow([
        t(a.name),
        t(a.kind.label),
        t(a.iban ?? ''),
        money(b[a.id] ?? 0),
      ]);
    }
    if ((b[null] ?? 0) != 0) {
      acc.appendRow([t(tr('Hesap seçilmemiş')), t(''), t(''), money(b[null]!)]);
    }
  }

  book.setDefaultSheet(tr('Özet'));
  if (defaultSheet != null && defaultSheet != tr('Özet')) {
    book.delete(defaultSheet);
  }
  return Uint8List.fromList(book.encode()!);
}
