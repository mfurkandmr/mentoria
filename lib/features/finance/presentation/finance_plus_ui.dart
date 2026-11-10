import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../admin/data/admin_repository.dart';
import '../../student_management/data/student_management_repository.dart';
import '../data/finance_repository.dart';
import 'receipt_pdf.dart';
import '../../../core/design/haptics.dart';
import '../../../core/design/motion.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Sunucu hata kodu → kullanıcıya metin.
String financeError(Object e) {
  final s = '$e';
  if (s.contains('FINANCE_BAD_FEE')) {
    return tr('Seçilen ücret bu öğrenciye ait değil.');
  }
  if (s.contains('STAFF_BAD_REF')) {
    return tr('Bu personel kartı artık yok.');
  }
  if (s.contains('FINANCE_BAD_TEACHER')) {
    return tr('Bu öğretmen artık kurumda kayıtlı değil.');
  }
  if (s.contains('FINANCE_OVERPAYMENT')) {
    return tr('Kalan borçtan fazla tutar girildi.');
  }
  if (s.contains('FINANCE_HAS_PAYMENTS')) {
    return tr('Tahsilatı olan ücret silinemez; kaydı iptal et.');
  }
  if (s.contains('FINANCE_REFUND_TOO_BIG')) {
    return tr('İade, tahsil edilen tutardan fazla olamaz.');
  }
  if (s.contains('FINANCE_DISCOUNT_TOO_BIG')) {
    return tr('İndirim kalan borçtan büyük olamaz.');
  }
  if (s.contains('FINANCE_CANCELLED')) {
    return tr('Bu kayıt iptal edilmiş.');
  }
  if (s.contains('finance_accounts_name') || s.contains('fee_plans_name')) {
    return tr('Bu ad zaten kullanılıyor.');
  }
  return tr('Kaydedilemedi. Tekrar dene.');
}

void _invalidate(WidgetRef ref) {
  ref.invalidate(financeFeesProvider);
  ref.invalidate(financeIncomesProvider);
  ref.invalidate(financeAccountsProvider);
  ref.invalidate(financeTransfersProvider);
  ref.invalidate(financeExpensesProvider);
}

String? _orgName(WidgetRef ref) => ref.read(orgProvider).value?.name;

String? _accountName(WidgetRef ref, String? id) => id == null
    ? null
    : ref
          .read(financeAccountsProvider)
          .value
          ?.where((a) => a.id == id)
          .firstOrNull
          ?.name;

/// Ödeme şekline uyan varsayılan hesap: nakit → kasa, kart → POS (yoksa
/// banka), havale → banka; uyan yoksa ilk açık hesap.
FinanceAccount? defaultAccountFor(
  List<FinanceAccount> accounts,
  PaymentMethod? method,
) {
  final open = [
    for (final a in accounts)
      if (!a.archived) a,
  ];
  if (open.isEmpty) return null;
  final prefer = switch (method) {
    PaymentMethod.cash => const [AccountKind.cash],
    PaymentMethod.card => const [AccountKind.pos, AccountKind.bank],
    PaymentMethod.transfer => const [AccountKind.bank],
    _ => const <AccountKind>[],
  };
  for (final k in prefer) {
    final hit = open.where((a) => a.kind == k).firstOrNull;
    if (hit != null) return hit;
  }
  return open.first;
}

/// Hesap seçici. Kurumun açık hesabı varsa boş bırakılamaz: değer yoksa
/// [method]'a uyan hesap kendiliğinden seçilir, kullanıcı elle değiştirmediyse
/// ödeme şekli değişince de güncellenir. Hiç hesap yoksa gösterilmez.
class AccountPicker extends ConsumerStatefulWidget {
  const AccountPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.method,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final PaymentMethod? method;

  @override
  ConsumerState<AccountPicker> createState() => _AccountPickerState();
}

class _AccountPickerState extends ConsumerState<AccountPicker> {
  bool _touched = false;

  void _autoPick(List<FinanceAccount> all, {bool force = false}) {
    if (_touched || (!force && widget.value != null)) return;
    final d = defaultAccountFor(all, widget.method);
    if (d == null || d.id == widget.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(d.id);
    });
  }

  @override
  void didUpdateWidget(AccountPicker old) {
    super.didUpdateWidget(old);
    if (old.method != widget.method) {
      _autoPick(
        ref.read(financeAccountsProvider).value ?? const [],
        force: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(financeAccountsProvider).value ?? const [];
    final accounts = [
      for (final a in all)
        if (!a.archived || a.id == widget.value) a,
    ];
    if (accounts.isEmpty) return const SizedBox.shrink();
    _autoPick(all);
    final value = accounts.any((a) => a.id == widget.value)
        ? widget.value
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('account-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: tr('Hesap')),
      items: [
        for (final a in accounts)
          DropdownMenuItem(value: a.id, child: Text(a.name)),
      ],
      onChanged: (v) {
        _touched = true;
        widget.onChanged(v);
      },
    );
  }
}

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

// ---------------------------------------------------------------------------
// Tahsilat
// ---------------------------------------------------------------------------

/// Ödeme al: tutar ödenmemiş taksitlere dağıtılır; makbuz no döner.
Future<void> showPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  StudentFee fee, {
  FeeInstallment? installment,
}) async {
  final r = await showDialog<_PaymentInput>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (_) => _PaymentDialog(fee: fee, installment: installment),
  );
  if (r == null || !context.mounted) return;
  try {
    final res = await ref
        .read(financeRepositoryProvider)
        .recordPayment(
          fee.id,
          amount: r.amount,
          paidOn: r.date,
          method: r.method,
          accountId: r.accountId,
          note: r.note,
          installmentId: installment?.id,
        );
    _invalidate(ref);
    AppHaptics.confirm();
    if (!context.mounted) return;
    final fresh = await ref.read(financeFeesProvider.future);
    final f = fresh.where((x) => x.id == fee.id).firstOrNull;
    final receipt = f?.receipts.where((x) => x.number == res.receiptNo);
    if (!context.mounted) return;
    offerReceipt(
      context,
      tr('Tahsilat kaydedildi ({no}). Kalan: {v}', {
        'no': res.receiptNo ?? '',
        'v': formatMoney(res.remaining),
      }),
      f == null || receipt == null || receipt.isEmpty
          ? null
          : feeReceiptDoc(
              f,
              receipt.first,
              orgName: _orgName(ref),
              accountName: _accountName(ref, r.accountId),
            ),
    );
  } catch (e) {
    if (context.mounted) showMessage(context, financeError(e));
  }
}

class _PaymentInput {
  const _PaymentInput(
    this.amount,
    this.date,
    this.method,
    this.accountId,
    this.note,
  );
  final double amount;
  final DateTime date;
  final PaymentMethod? method;
  final String? accountId;
  final String? note;
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.fee, this.installment});
  final StudentFee fee;
  final FeeInstallment? installment;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(
    text: _plain(
      widget.installment?.open ??
          widget.fee.nextDue?.open ??
          widget.fee.remaining,
    ),
  );
  final _note = TextEditingController();
  DateTime _date = _today();
  PaymentMethod _method = PaymentMethod.cash;
  String? _account;

  static String _plain(double v) => v == v.roundToDouble()
      ? '${v.round()}'
      : v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseMoney(_amount.text);
    final over = amount != null && amount > widget.fee.remaining + 0.001;
    final alloc = amount == null || over
        ? const <(FeeInstallment, double)>[]
        : allocatePayment(
            widget.fee.installments,
            amount,
            first: widget.installment?.id,
          );
    return AlertDialog(
      title: Text(tr('Ödeme al')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.fee.studentName} · ${tr('Kalan: {v}', {'v': formatMoney(widget.fee.remaining)})}',
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('payment-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('Tutar'),
                suffixText: '₺',
                errorText: over
                    ? tr('Kalan borçtan fazla tutar girildi.')
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            for (final (i, part) in alloc)
              Text(
                tr('{d} vadeli taksite {v}', {
                  'd': formatShortDate(i.dueOn),
                  'v': formatMoney(part),
                }),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: InputDecoration(labelText: tr('Ödeme şekli')),
              items: [
                for (final m in PaymentMethod.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 8),
            AccountPicker(
              value: _account,
              method: _method,
              onChanged: (v) => setState(() => _account = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(formatLongDate(_date)),
              onTap: () async {
                final d = await _pickDate(context, _date);
                if (d != null) setState(() => _date = d);
              },
            ),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: tr('Not (isteğe bağlı)')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          key: const ValueKey('payment-save'),
          onPressed: amount == null || over
              ? null
              : () => Navigator.pop(
                  context,
                  _PaymentInput(
                    amount,
                    _date,
                    _method,
                    _account,
                    _note.text.trim().isEmpty ? null : _note.text.trim(),
                  ),
                ),
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}

/// Ücretin makbuzları: PDF ve iptal.
class FeeReceiptsList extends ConsumerWidget {
  const FeeReceiptsList({super.key, required this.fee});
  final StudentFee fee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = fee.receipts;
    if (receipts.isEmpty) return const SizedBox.shrink();
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(tr('Makbuzlar'), style: Theme.of(context).textTheme.titleSmall),
        for (final r in receipts)
          ListTile(
            key: ValueKey('receipt-${r.number}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              r.isRefund ? Icons.undo_rounded : Icons.receipt_long_outlined,
              color: r.voided
                  ? null
                  : (r.isRefund ? brand.danger : brand.success),
            ),
            title: Text(
              '${r.isRefund ? '−' : ''}${formatMoney(r.amount)} · ${formatShortDate(r.date)}',
              style: TextStyle(
                decoration: r.voided ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              [
                r.number ?? tr('Eski kayıt'),
                if (r.method != null) r.method!.label,
                if (r.voided) tr('İptal edildi'),
              ].join(' · '),
            ),
            trailing: r.number == null || r.voided
                ? null
                : PopupMenuButton<String>(
                    tooltip: tr('Makbuz işlemleri'),
                    onSelected: (v) async {
                      if (v == 'pdf') {
                        await shareReceipt(
                          context,
                          feeReceiptDoc(
                            fee,
                            r,
                            orgName: _orgName(ref),
                            accountName: _accountName(ref, r.accountId),
                          ),
                        );
                        return;
                      }
                      final ok = await confirm(
                        context,
                        title: tr('Makbuz iptal edilsin mi?'),
                        message: tr(
                          '{no} numaralı makbuzun tutarı taksitlerden geri alınır. Numara tekrar kullanılmaz.',
                          {'no': r.number},
                        ),
                        action: tr('İptal et'),
                      );
                      if (!ok || !context.mounted) return;
                      try {
                        await ref
                            .read(financeRepositoryProvider)
                            .voidReceipt(r.number!);
                        _invalidate(ref);
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, financeError(e));
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pdf',
                        child: Text(tr('Makbuzu paylaş (PDF)')),
                      ),
                      PopupMenuItem(
                        value: 'void',
                        child: Text(tr('Makbuzu iptal et')),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// İndirim ve kayıt iptali
// ---------------------------------------------------------------------------

Future<void> showDiscountDialog(
  BuildContext context,
  WidgetRef ref,
  StudentFee fee,
) async {
  final r = await showDialog<FeeDiscount>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (_) => DiscountDialog(base: fee.remaining, max: fee.remaining),
  );
  if (r == null || !context.mounted) return;
  try {
    await ref
        .read(financeRepositoryProvider)
        .addDiscount(fee.id, r.kind, r.amount, note: r.note);
    _invalidate(ref);
    if (context.mounted) {
      showMessage(
        context,
        tr('{k} eklendi; son taksitlerden düşüldü.', {'k': r.kind.label}),
      );
    }
  } catch (e) {
    if (context.mounted) showMessage(context, financeError(e));
  }
}

/// İndirim / burs: tutar ya da yüzde ([base] üzerinden).
class DiscountDialog extends StatefulWidget {
  const DiscountDialog({super.key, required this.base, this.max});
  final double base;
  final double? max;

  @override
  State<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<DiscountDialog> {
  final _value = TextEditingController();
  final _note = TextEditingController();
  DiscountKind _kind = DiscountKind.discount;
  bool _percent = false;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _amount {
    final v = parseMoney(_value.text);
    if (v == null) return null;
    if (!_percent) return v;
    if (v > 100) return null;
    return (widget.base * v / 100).roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final a = _amount;
    final tooBig = a != null && widget.max != null && a > widget.max! + 0.001;
    return AlertDialog(
      title: Text(tr('İndirim / burs')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<DiscountKind>(
            initialValue: _kind,
            decoration: InputDecoration(labelText: tr('Tür')),
            items: [
              for (final k in DiscountKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('discount-value'),
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _percent ? tr('Yüzde') : tr('Tutar'),
                    suffixText: _percent ? '%' : '₺',
                    errorText: tooBig
                        ? tr('İndirim kalan borçtan büyük olamaz.')
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('₺')),
                  ButtonSegment(value: true, label: Text('%')),
                ],
                selected: {_percent},
                onSelectionChanged: (s) => setState(() => _percent = s.first),
              ),
            ],
          ),
          if (_percent && a != null)
            Align(alignment: Alignment.centerLeft, child: Text(formatMoney(a))),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: tr('Not (isteğe bağlı)')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          key: const ValueKey('discount-save'),
          onPressed: a == null || a <= 0 || tooBig
              ? null
              : () => Navigator.pop(
                  context,
                  FeeDiscount(
                    kind: _kind,
                    amount: a,
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                  ),
                ),
          child: Text(tr('Ekle')),
        ),
      ],
    );
  }
}

Future<void> showCancelFeeDialog(
  BuildContext context,
  WidgetRef ref,
  StudentFee fee,
) async {
  final collected =
      fee.payments
          .where((p) => !p.isVoided && !p.isRefund)
          .fold<double>(0, (s, p) => s + p.amount) -
      fee.refunded;
  final r = await showDialog<_CancelInput>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (_) => _CancelDialog(fee: fee, collected: collected),
  );
  if (r == null || !context.mounted) return;
  try {
    final res = await ref
        .read(financeRepositoryProvider)
        .cancelFee(
          fee.id,
          refund: r.refund,
          on: r.date,
          method: r.method,
          accountId: r.accountId,
          note: r.note,
        );
    _invalidate(ref);
    if (!context.mounted) return;
    ReceiptDoc? doc;
    if (res.receiptNo != null) {
      final fresh = (await ref.read(
        financeFeesProvider.future,
      )).where((x) => x.id == fee.id).firstOrNull;
      final rec = fresh?.receipts.where((x) => x.number == res.receiptNo);
      if (fresh != null && rec != null && rec.isNotEmpty) {
        doc = feeReceiptDoc(
          fresh,
          rec.first,
          orgName: _orgName(ref),
          accountName: _accountName(ref, r.accountId),
        );
      }
    }
    if (!context.mounted) return;
    offerReceipt(
      context,
      r.refund > 0
          ? tr('Kayıt iptal edildi; {v} iade kaydedildi.', {
              'v': formatMoney(r.refund),
            })
          : tr('Kayıt iptal edildi.'),
      doc,
    );
  } catch (e) {
    if (context.mounted) showMessage(context, financeError(e));
  }
}

class _CancelInput {
  const _CancelInput(
    this.refund,
    this.date,
    this.method,
    this.accountId,
    this.note,
  );
  final double refund;
  final DateTime date;
  final PaymentMethod? method;
  final String? accountId;
  final String? note;
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.fee, required this.collected});
  final StudentFee fee;
  final double collected;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _refund = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = _today();
  PaymentMethod _method = PaymentMethod.transfer;
  String? _account;

  @override
  void dispose() {
    _refund.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refund = _refund.text.trim().isEmpty ? 0.0 : parseMoney(_refund.text);
    final tooBig = refund != null && refund > widget.collected + 0.001;
    return AlertDialog(
      title: Text(tr('Kaydı iptal et')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                'Ödenmemiş taksitler silinir, kısmen ödenen taksit ödenen tutara iner. Tahsil edilen: {v}.',
                {'v': formatMoney(widget.collected)},
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('refund-amount'),
              controller: _refund,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('İade tutarı (yoksa boş)'),
                suffixText: '₺',
                errorText: tooBig
                    ? tr('İade, tahsil edilen tutardan fazla olamaz.')
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if ((refund ?? 0) > 0) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _method,
                decoration: InputDecoration(labelText: tr('İade şekli')),
                items: [
                  for (final m in PaymentMethod.values)
                    DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (v) => setState(() => _method = v ?? _method),
              ),
              const SizedBox(height: 8),
              AccountPicker(
                value: _account,
                method: _method,
                onChanged: (v) => setState(() => _account = v),
              ),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(formatLongDate(_date)),
              onTap: () async {
                final d = await _pickDate(context, _date);
                if (d != null) setState(() => _date = d);
              },
            ),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: tr('Sebep (isteğe bağlı)'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          key: const ValueKey('cancel-fee-save'),
          style: FilledButton.styleFrom(backgroundColor: context.brand.danger),
          onPressed: refund == null || tooBig
              ? null
              : () => Navigator.pop(
                  context,
                  _CancelInput(
                    refund,
                    _date,
                    refund > 0 ? _method : null,
                    refund > 0 ? _account : null,
                    _note.text.trim().isEmpty ? null : _note.text.trim(),
                  ),
                ),
          child: Text(tr('İptal et')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Toplu ücret
// ---------------------------------------------------------------------------

Future<void> showBulkFeeSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const BulkFeeSheet(),
    );

/// Sınıfa / programa toplu ücret: şablon ya da elle; öğrenciler sınıfa göre
/// seçilir; veli telefonu yoklama kaydından gelir.
class BulkFeeSheet extends ConsumerStatefulWidget {
  const BulkFeeSheet({super.key});

  @override
  ConsumerState<BulkFeeSheet> createState() => _BulkFeeSheetState();
}

class _BulkFeeSheetState extends ConsumerState<BulkFeeSheet> {
  final _title = TextEditingController();
  final _total = TextEditingController();
  int _count = 1;
  int _dueDay = _today().day > 28 ? 28 : _today().day;
  DateTime _firstMonth = DateTime(_today().year, _today().month);
  FeeDiscount? _discount;
  final _selected = <String>{};
  bool _savePlan = false;
  bool _saving = false;

  /// Aynı başlıkta aktif ücreti olanlara da açılsın mı (varsayılan: atla).
  bool _allowDuplicate = false;

  static String _norm(String v) => v
      .trim()
      .replaceAll('I', 'ı')
      .replaceAll('İ', 'i')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Başlığa göre zaten aktif ücreti olan öğrenciler.
  Set<String> _duplicates(List<StudentFee> fees) {
    final t = _norm(_title.text);
    if (t.isEmpty) return const {};
    return {
      for (final f in fees)
        if (!f.isCancelled && _norm(f.title) == t) ?f.studentId,
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    super.dispose();
  }

  void _usePlan(FeePlan p) => setState(() {
    _title.text = p.name;
    _total.text = '${p.total.round()}';
    _count = p.installmentCount.clamp(1, 12);
  });

  Future<void> _save() async {
    final total = parseMoney(_total.text);
    if (total == null || _title.text.trim().isEmpty || _selected.isEmpty) {
      showMessage(context, tr('Başlık, tutar ve en az bir öğrenci seç.'));
      return;
    }
    final net = total - (_discount?.amount ?? 0);
    if (net <= 0) {
      showMessage(context, tr('İndirim ücretten büyük olamaz.'));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(financeRepositoryProvider);
    try {
      final res = await repo.addFeesBulk(
        allowDuplicate: _allowDuplicate,
        [..._selected],
        FeeDraft(
          studentId: '',
          title: _title.text.trim(),
          total: total,
          installments: splitInstallments(
            net,
            _count,
            DateTime(_firstMonth.year, _firstMonth.month, _dueDay),
          ),
          payer: FeePayer(dueDay: _dueDay),
          discounts: [?_discount],
        ),
      );
      if (_savePlan) {
        try {
          await repo.savePlan(
            FeePlan(
              id: '',
              name: _title.text.trim(),
              total: total,
              installmentCount: _count,
            ),
            isNew: true,
          );
          ref.invalidate(feePlansProvider);
        } catch (_) {
          // Aynı adlı şablon varsa ücretler yine açıldı.
        }
      }
      ref.invalidate(financeFeesProvider);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(
        context,
        res.skipped.isEmpty
            ? tr('{n} öğrenciye ücret açıldı.', {'n': res.created})
            : tr(
                '{n} öğrenciye ücret açıldı; {s} öğrenci atlandı (aynı başlıkta kaydı var).',
                {'n': res.created, 's': res.skipped.length},
              ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, financeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(feePlansProvider).value ?? const [];
    final students = ref.watch(managedStudentsProvider).value ?? const [];
    final classes = {
      for (final s in students)
        if (s.classroomId != null) s.classroomId!: s.classroomName ?? '',
    };
    final total = parseMoney(_total.text);
    final dups = _duplicates(ref.watch(financeFeesProvider).value ?? const []);
    final selectedDups = _selected.where(dups.contains).length;
    final willCreate = _allowDuplicate
        ? _selected.length
        : _selected.length - selectedDups;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Toplu ücret'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (plans.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in plans)
                    ActionChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 18),
                      label: Text('${p.name} · ${formatMoney(p.total)}'),
                      onPressed: () => _usePlan(p),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('bulk-title'),
              controller: _title,
              decoration: InputDecoration(labelText: tr('Başlık')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('bulk-total'),
              controller: _total,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('İndirimsiz ücret'),
                suffixText: '₺',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _count,
                    decoration: InputDecoration(labelText: tr('Taksit')),
                    items: [
                      for (var n = 1; n <= 12; n++)
                        DropdownMenuItem(
                          value: n,
                          child: Text(
                            n == 1 ? tr('Peşin') : tr('{n} taksit', {'n': n}),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _count = v ?? 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _dueDay,
                    decoration: InputDecoration(labelText: tr('Ödeme günü')),
                    items: [
                      for (var d = 1; d <= 28; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (v) => setState(() => _dueDay = v ?? _dueDay),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<DateTime>(
              initialValue: _firstMonth,
              decoration: InputDecoration(labelText: tr('İlk taksit')),
              items: [
                for (var k = -2; k <= 10; k++)
                  DropdownMenuItem(
                    value: DateTime(_today().year, _today().month + k),
                    child: Text(
                      formatLongDate(
                        DateTime(_today().year, _today().month + k),
                      ).replaceFirst(RegExp(r'^\d+ '), ''),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _firstMonth = v ?? _firstMonth),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.percent_rounded),
              title: Text(
                _discount == null
                    ? tr('İndirim yok')
                    : '${_discount!.kind.label} · ${formatMoney(_discount!.amount)}',
              ),
              trailing: TextButton(
                onPressed: total == null
                    ? null
                    : () async {
                        final d = await showDialog<FeeDiscount>(
                          context: context,
                          animationStyle: AppMotion.overlayStyle(context),
                          builder: (_) =>
                              DiscountDialog(base: total, max: total),
                        );
                        setState(() => _discount = d);
                      },
                child: Text(_discount == null ? tr('Ekle') : tr('Değiştir')),
              ),
            ),
            const Divider(),
            Text(
              tr('Öğrenciler ({n} seçili)', {'n': _selected.length}),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text(tr('Tümü')),
                  onPressed: () => setState(
                    () => _selected.addAll(students.map((s) => s.id)),
                  ),
                ),
                for (final c in classes.entries)
                  ActionChip(
                    label: Text(c.value),
                    onPressed: () => setState(
                      () => _selected.addAll([
                        for (final s in students)
                          if (s.classroomId == c.key) s.id,
                      ]),
                    ),
                  ),
                ActionChip(
                  label: Text(tr('Temizle')),
                  onPressed: () => setState(_selected.clear),
                ),
              ],
            ),
            for (final s in students)
              CheckboxListTile(
                key: ValueKey('bulk-student-${s.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(s.id),
                onChanged: (v) => setState(
                  () => v! ? _selected.add(s.id) : _selected.remove(s.id),
                ),
                title: Text(s.fullName),
                subtitle: !dups.contains(s.id)
                    ? (s.classroomName == null ? null : Text(s.classroomName!))
                    : Text(
                        [
                          ?s.classroomName,
                          tr('Bu başlıkta ücreti var'),
                        ].join(' · '),
                        style: TextStyle(color: context.brand.danger),
                      ),
              ),
            if (selectedDups > 0)
              SwitchListTile(
                key: const ValueKey('bulk-allow-duplicate'),
                contentPadding: EdgeInsets.zero,
                value: _allowDuplicate,
                onChanged: (v) => setState(() => _allowDuplicate = v),
                title: Text(
                  tr('Aynı başlıkta ücreti olanlara da aç ({n})', {
                    'n': selectedDups,
                  }),
                ),
                subtitle: Text(
                  _allowDuplicate
                      ? tr('Bu öğrencilere ikinci bir ücret açılır.')
                      : tr('Kapalıyken bu öğrenciler atlanır.'),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _savePlan,
              onChanged: (v) => setState(() => _savePlan = v!),
              title: Text(tr('Şablon olarak kaydet')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('bulk-save'),
              onPressed: _saving ? null : _save,
              child: Text(tr('{n} öğrenciye ücret aç', {'n': willCreate})),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diğer gelirler
// ---------------------------------------------------------------------------

/// Gelirler sekmesinin başı: öğrenci ödemeleri burada listelenmez, bu ayın
/// tahsilatı müdür aramasın diye özetlenir (ayrıntısı Ücretler sekmesinde).
class _MonthCollectionCard extends StatelessWidget {
  const _MonthCollectionCard({required this.fees});

  final List<StudentFee> fees;

  @override
  Widget build(BuildContext context) {
    final today = _today();
    final s = monthSummary(
      fees,
      const [],
      DateTime(today.year, today.month),
      today: today,
    );
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Bu ay öğrenci tahsilatı'),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  formatMoney(s.collected),
                  key: const ValueKey('income-month-collected'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (s.refunds > 0)
              Text(
                tr('İade: {v}', {'v': formatMoney(s.refunds)}),
                style: text.bodySmall,
              ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Öğrenci ödemelerinin ayrıntısı Ücretler sekmesinde. Aşağıda ücret dışı gelirler var.',
              ),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class IncomesTab extends ConsumerWidget {
  const IncomesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomes = ref.watch(financeIncomesProvider);
    final fees = ref.watch(financeFeesProvider).value;
    final brand = context.brand;
    return AsyncView(
      value: incomes,
      onRetry: () => ref.invalidate(financeIncomesProvider),
      builder: (list) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (fees != null) _MonthCollectionCard(fees: fees),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('add-income'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                sheetAnimationStyle: AppMotion.overlayStyle(context),
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _IncomeSheet(),
              ),
              icon: const Icon(Icons.add),
              label: Text(tr('Gelir ekle')),
            ),
          ),
          if (list.isEmpty)
            EmptyState(
              title: tr('Henüz gelir yok'),
              message: tr(
                'Kitap, özel ders, materyal gibi ücret dışı gelirleri buradan kaydet; makbuz no verilir.',
              ),
            ),
          for (final i in list)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${i.category.label} · ${formatMoney(i.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: i.isVoided ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  [
                    formatShortDate(i.receivedOn),
                    if ((i.studentName ?? i.payerName) != null)
                      (i.studentName ?? i.payerName)!,
                    if (i.receiptNo != null) i.receiptNo!,
                    if (i.note != null) i.note!,
                    if (i.isVoided) tr('İptal edildi'),
                  ].join(' · '),
                ),
                trailing: i.isVoided || i.receiptNo == null
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: tr('Makbuz işlemleri'),
                        onSelected: (v) async {
                          if (v == 'pdf') {
                            await shareReceipt(
                              context,
                              incomeReceiptDoc(
                                i,
                                orgName: _orgName(ref),
                                accountName: _accountName(ref, i.accountId),
                              ),
                            );
                            return;
                          }
                          final ok = await confirm(
                            context,
                            title: tr('Makbuz iptal edilsin mi?'),
                            message: tr(
                              '{no} numaralı makbuz iptal edilir. Numara tekrar kullanılmaz.',
                              {'no': i.receiptNo},
                            ),
                            action: tr('İptal et'),
                          );
                          if (!ok || !context.mounted) return;
                          try {
                            await ref
                                .read(financeRepositoryProvider)
                                .voidReceipt(i.receiptNo!);
                            _invalidate(ref);
                          } catch (e) {
                            if (context.mounted) {
                              showMessage(context, financeError(e));
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'pdf',
                            child: Text(tr('Makbuzu paylaş (PDF)')),
                          ),
                          PopupMenuItem(
                            value: 'void',
                            child: Text(tr('Makbuzu iptal et')),
                          ),
                        ],
                      ),
                iconColor: brand.success,
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomeSheet extends ConsumerStatefulWidget {
  const _IncomeSheet();

  @override
  ConsumerState<_IncomeSheet> createState() => _IncomeSheetState();
}

class _IncomeSheetState extends ConsumerState<_IncomeSheet> {
  final _amount = TextEditingController();
  final _payer = TextEditingController();
  final _note = TextEditingController();
  IncomeCategory _category = IncomeCategory.books;
  PaymentMethod _method = PaymentMethod.cash;
  String? _account;
  String? _student;
  DateTime _date = _today();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _payer.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    if (amount == null) {
      showMessage(context, tr('Tutarı gir.'));
      return;
    }
    setState(() => _saving = true);
    final draft = IncomeDraft(
      receivedOn: _date,
      category: _category,
      amount: amount,
      method: _method,
      accountId: _account,
      studentId: _student,
      payerName: _payer.text.trim().isEmpty ? null : _payer.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    try {
      final no = await ref.read(financeRepositoryProvider).recordIncome(draft);
      _invalidate(ref);
      if (!mounted) return;
      final students = ref.read(managedStudentsProvider).value ?? const [];
      final doc = ReceiptDoc(
        number: no,
        date: _date,
        amount: amount,
        orgName: _orgName(ref),
        payer: draft.payerName,
        studentName: students
            .where((s) => s.id == _student)
            .firstOrNull
            ?.fullName,
        title: _category.label,
        method: _method,
        accountName: _accountName(ref, _account),
        note: draft.note,
        lines: [(draft.note ?? _category.label, amount)],
      );
      final nav = Navigator.of(context);
      offerReceipt(context, tr('Gelir kaydedildi ({no}).', {'no': no}), doc);
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, financeError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(managedStudentsProvider).value ?? const [];
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Gelir ekle'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<IncomeCategory>(
              initialValue: _category,
              decoration: InputDecoration(labelText: tr('Tür')),
              items: [
                for (final c in IncomeCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('income-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('Tutar'),
                suffixText: '₺',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _student,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr('Öğrenci (isteğe bağlı)'),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(tr('Öğrenci yok'))),
                for (final s in students)
                  DropdownMenuItem(value: s.id, child: Text(s.fullName)),
              ],
              onChanged: (v) => setState(() => _student = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _payer,
              decoration: InputDecoration(
                labelText: tr('Ödeyen (isteğe bağlı)'),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: InputDecoration(labelText: tr('Ödeme şekli')),
              items: [
                for (final m in PaymentMethod.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 10),
            AccountPicker(
              value: _account,
              method: _method,
              onChanged: (v) => setState(() => _account = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(formatLongDate(_date)),
              onTap: () async {
                final d = await _pickDate(context, _date);
                if (d != null) setState(() => _date = d);
              },
            ),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: tr('Not (isteğe bağlı)')),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('income-save'),
              onPressed: _saving ? null : _save,
              child: Text(tr('Kaydet')),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hesaplar
// ---------------------------------------------------------------------------

class AccountsTab extends ConsumerWidget {
  const AccountsTab({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    FinanceAccount? a,
  ]) async {
    final r = await showDialog<FinanceAccount>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (_) => _AccountDialog(account: a),
    );
    if (r == null || !context.mounted) return;
    try {
      await ref
          .read(financeRepositoryProvider)
          .saveAccount(r, isNew: a == null);
      ref.invalidate(financeAccountsProvider);
    } catch (e) {
      if (context.mounted) showMessage(context, financeError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(financeAccountsProvider);
    final fees = ref.watch(financeFeesProvider).value ?? const [];
    final incomes = ref.watch(financeIncomesProvider).value ?? const [];
    final expenses = ref.watch(financeExpensesProvider).value ?? const [];
    final transfers = ref.watch(financeTransfersProvider).value ?? const [];
    final text = Theme.of(context).textTheme;
    return AsyncView(
      value: accounts,
      onRetry: () => ref.invalidate(financeAccountsProvider),
      builder: (list) {
        final balances = accountBalances(
          accounts: list,
          fees: fees,
          incomes: incomes,
          expenses: expenses,
          transfers: transfers,
        );
        final names = {for (final a in list) a.id: a.name};
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('add-transfer'),
                  onPressed: list.length < 2
                      ? null
                      : () => _transfer(context, ref, list),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(tr('Virman')),
                ),
                FilledButton.icon(
                  key: const ValueKey('add-account'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(tr('Hesap ekle')),
                ),
              ],
            ),
            if (list.isEmpty)
              EmptyState(
                title: tr('Henüz hesap yok'),
                message: tr(
                  'Kasa ve banka hesaplarını ekle; tahsilat, gelir ve giderleri hesaba bağlayınca bakiyeler burada görünür.',
                ),
              ),
            for (final a in list)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  key: ValueKey('account-${a.id}'),
                  leading: Icon(switch (a.kind) {
                    AccountKind.cash => Icons.payments_outlined,
                    AccountKind.bank => Icons.account_balance_outlined,
                    AccountKind.pos => Icons.credit_card_outlined,
                  }),
                  title: Text(a.name),
                  subtitle: Text(
                    [
                      a.kind.label,
                      if (a.iban != null) a.iban!,
                      if (a.archived) tr('Kullanılmıyor'),
                    ].join(' · '),
                  ),
                  trailing: Text(
                    formatMoney(balances[a.id] ?? 0),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () => _edit(context, ref, a),
                ),
              ),
            if ((balances[null] ?? 0) != 0)
              ListTile(
                title: Text(tr('Hesap seçilmeyen hareketler')),
                trailing: Text(formatMoney(balances[null]!)),
              ),
            if (transfers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tr('Virmanlar'), style: text.titleSmall),
              for (final t in transfers)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${names[t.fromAccount] ?? '?'} → ${names[t.toAccount] ?? '?'} · ${formatMoney(t.amount)}',
                  ),
                  subtitle: Text(
                    [
                      formatShortDate(t.movedOn),
                      if (t.note != null) t.note!,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: tr('Sil'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref
                          .read(financeRepositoryProvider)
                          .deleteTransfer(t.id);
                      ref.invalidate(financeTransfersProvider);
                    },
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _transfer(
    BuildContext context,
    WidgetRef ref,
    List<FinanceAccount> accounts,
  ) async {
    String from = accounts.first.id;
    String to = accounts[1].id;
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(tr('Hesaplar arası aktarım')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: from,
                decoration: InputDecoration(labelText: tr('Çıkan hesap')),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => set(() => from = v ?? from),
              ),
              DropdownButtonFormField<String>(
                initialValue: to,
                decoration: InputDecoration(labelText: tr('Giren hesap')),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => set(() => to = v ?? to),
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: tr('Tutar'),
                  suffixText: '₺',
                ),
              ),
              TextField(
                controller: note,
                decoration: InputDecoration(
                  labelText: tr('Not (isteğe bağlı)'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('Vazgeç')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('Kaydet')),
            ),
          ],
        ),
      ),
    );
    final v = parseMoney(amount.text);
    final n = note.text.trim();
    amount.dispose();
    note.dispose();
    if (ok != true || !context.mounted) return;
    if (v == null || from == to) {
      showMessage(context, tr('Farklı iki hesap ve tutar seç.'));
      return;
    }
    try {
      await ref
          .read(financeRepositoryProvider)
          .addTransfer(
            from: from,
            to: to,
            amount: v,
            on: _today(),
            note: n.isEmpty ? null : n,
          );
      ref.invalidate(financeTransfersProvider);
    } catch (e) {
      if (context.mounted) showMessage(context, financeError(e));
    }
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({this.account});
  final FinanceAccount? account;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _iban = TextEditingController(text: widget.account?.iban ?? '');
  late final _opening = TextEditingController(
    text: widget.account == null || widget.account!.openingBalance == 0
        ? ''
        : '${widget.account!.openingBalance.round()}',
  );
  late AccountKind _kind = widget.account?.kind ?? AccountKind.cash;
  late bool _archived = widget.account?.archived ?? false;

  @override
  void dispose() {
    _name.dispose();
    _iban.dispose();
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iban = _iban.text.replaceAll(' ', '').toUpperCase();
    final ibanBad = iban.isNotEmpty && !RegExp(r'^TR\d{24}$').hasMatch(iban);
    return AlertDialog(
      title: Text(
        widget.account == null ? tr('Hesap ekle') : tr('Hesabı düzenle'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('account-name'),
              controller: _name,
              decoration: InputDecoration(labelText: tr('Ad')),
            ),
            DropdownButtonFormField<AccountKind>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: tr('Tür')),
              items: [
                for (final k in AccountKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            if (_kind == AccountKind.bank)
              TextField(
                controller: _iban,
                decoration: InputDecoration(
                  labelText: tr('IBAN (isteğe bağlı)'),
                  errorText: ibanBad
                      ? tr('IBAN TR ile başlayan 26 karakter olmalı.')
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            TextField(
              controller: _opening,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('Açılış bakiyesi'),
                suffixText: '₺',
              ),
            ),
            if (widget.account != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Kullanılmıyor')),
                value: _archived,
                onChanged: (v) => setState(() => _archived = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          key: const ValueKey('account-save'),
          onPressed: ibanBad
              ? null
              : () {
                  if (_name.text.trim().isEmpty) return;
                  Navigator.pop(
                    context,
                    FinanceAccount(
                      id: widget.account?.id ?? '',
                      name: _name.text.trim(),
                      kind: _kind,
                      iban: _kind == AccountKind.bank && iban.isNotEmpty
                          ? iban
                          : null,
                      openingBalance: _opening.text.trim().isEmpty
                          ? 0
                          : (parseMoney(_opening.text) ?? 0),
                      archived: _archived,
                    ),
                  );
                },
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Veli görünümü
// ---------------------------------------------------------------------------

/// Velinin gördüğü ücret, taksit ve makbuzlar (salt okuma).
class ChildFinanceView extends ConsumerWidget {
  const ChildFinanceView({super.key, required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(childFinanceProvider(studentId));
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    final today = _today();
    return AsyncView(
      value: data,
      onRetry: () => ref.invalidate(childFinanceProvider(studentId)),
      builder: (c) => c.isEmpty
          ? ListView(
              children: [
                EmptyState(
                  title: tr('Ödeme kaydı yok'),
                  message: tr('Kurum bu öğrenci için ücret kaydı girmemiş.'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final f in c.fees)
                  SectionCard(
                    title: f.title,
                    subtitle: f.isCancelled
                        ? tr('Kayıt iptal edildi')
                        : tr('Kalan: {v}', {'v': formatMoney(f.remaining)}),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            tr('Ücret: {v}', {'v': formatMoney(f.total)}),
                            if (f.discountTotal > 0)
                              tr('İndirim: {v}', {
                                'v': formatMoney(f.discountTotal),
                              }),
                            tr('Ödenen: {v}', {'v': formatMoney(f.paid)}),
                          ].join(' · '),
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        for (final i in f.installments)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              i.isPaid
                                  ? Icons.check_circle_rounded
                                  : i.isOverdue(today)
                                  ? Icons.error_outline_rounded
                                  : Icons.schedule_rounded,
                              color: i.isPaid
                                  ? brand.success
                                  : i.isOverdue(today)
                                  ? brand.danger
                                  : null,
                            ),
                            title: Text(
                              '${formatLongDate(i.dueOn)} · ${formatMoney(i.amount)}',
                            ),
                            subtitle: i.isPaid
                                ? Text(tr('Ödendi'))
                                : i.isPartial
                                ? Text(
                                    tr('{p} ödendi, {r} kaldı', {
                                      'p': formatMoney(i.paidAmount),
                                      'r': formatMoney(i.open),
                                    }),
                                  )
                                : i.isOverdue(today)
                                ? Text(tr('Gecikti'))
                                : null,
                          ),
                        if (f.receipts.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(tr('Makbuzlar'), style: text.titleSmall),
                          for (final r in f.receipts)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${r.isRefund ? tr('İade') : tr('Tahsilat')} · ${formatMoney(r.amount)}',
                              ),
                              subtitle: Text(
                                [
                                  formatShortDate(r.date),
                                  r.number ?? tr('Eski kayıt'),
                                ].join(' · '),
                              ),
                              trailing: r.number == null
                                  ? null
                                  : IconButton(
                                      tooltip: tr('Makbuzu paylaş (PDF)'),
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                      ),
                                      onPressed: () => shareReceipt(
                                        context,
                                        feeReceiptDoc(f, r, orgName: c.orgName),
                                      ),
                                    ),
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
