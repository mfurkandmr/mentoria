import '../../../shared/widgets/tool_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/data/profile.dart';
import '../../coach/data/coach_repository.dart';
import '../data/finance_excel.dart';
import '../data/finance_repository.dart';
import 'cheques_ui.dart';
import 'finance_plus_ui.dart';
import 'teacher_pay_ui.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _monthLabel(DateTime m) => DateFormat('MMMM yyyy', localeTag).format(m);

/// Temadaki düğmeler tam genişlik; satır içindekiler kendi boyunda.
final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

/// Kurum müdürü: ücret / taksit, gider, koç maaşı ve aylık özet. Uygulama
/// ödeme almaz; müdür elden / havaleyle alınanı işaretler.
///
/// [remindDay]: "taksit günü geldi" bildiriminden açıldı; o günün ödenmemiş
/// taksitleri için "hatırlatma gönderilsin mi?" sorulur.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key, this.remindDay});

  final DateTime? remindDay;

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  @override
  void initState() {
    super.initState();
    final day = widget.remindDay;
    if (day == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fees = await ref.read(financeFeesProvider.future);
      if (!mounted) return;
      await showRemindDialog(context, ref, unpaidDueOn(fees, day));
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Finans')),
          actions: [
            IconButton(
              key: const ValueKey('finance-export'),
              tooltip: tr('Excel olarak indir'),
              icon: const Icon(Icons.table_view_rounded),
              onPressed: () => showFinanceExportDialog(context, ref),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: tr('Özet')),
              Tab(text: tr('Ücretler')),
              Tab(text: tr('Gelirler')),
              Tab(text: tr('Giderler')),
              Tab(text: tr('Hesaplar')),
              Tab(text: tr('Koç ve öğretmen')),
              Tab(text: tr('Çek ve senet')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SummaryTab(),
            _FeesTab(),
            IncomesTab(),
            _ExpensesTab(),
            AccountsTab(),
            _CoachesTab(),
            ChequesTab(),
          ],
        ),
      ),
    );
  }
}

/// Seçilen taksitler için veliye SMS hatırlatması; telefonu olmayanlar
/// seçilemez. Liste boşsa bilgi verir.
Future<void> showRemindDialog(
  BuildContext context,
  WidgetRef ref,
  List<(StudentFee, FeeInstallment)> items,
) async {
  if (items.isEmpty) {
    showMessage(context, tr('Bugün hatırlatılacak ödenmemiş taksit yok.'));
    return;
  }
  final now = DateTime.now();
  final selected = {
    for (final (f, i) in items)
      if (f.payerPhone != null && !i.remindedRecently(now)) i.id,
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(tr('Taksit hatırlatması gönderilsin mi?')),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                tr('Seçilen velilere SMS gider.'),
                style: Theme.of(c).textTheme.bodySmall,
              ),
              for (final (f, i) in items)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(i.id),
                  onChanged: f.payerPhone == null || i.remindedRecently(now)
                      ? null
                      : (v) => setState(
                          () => v == true
                              ? selected.add(i.id)
                              : selected.remove(i.id),
                        ),
                  title: Text('${f.studentName} · ${formatMoney(i.amount)}'),
                  subtitle: Text(
                    f.payerPhone == null
                        ? tr('Veli telefonu yok')
                        : i.remindedRecently(now)
                        ? tr('Bugün hatırlatıldı')
                        : '${f.payerName ?? tr('Veli')} · ${formatPhone(f.payerPhone!)}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            style: _inline,
            onPressed: selected.isEmpty ? null : () => Navigator.pop(c, true),
            child: Text(tr('Gönder ({n})', {'n': selected.length})),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  await _sendReminders(context, ref, selected.toList());
}

Future<void> _sendReminders(
  BuildContext context,
  WidgetRef ref,
  List<String> ids,
) async {
  try {
    final r = await ref.read(financeRepositoryProvider).sendReminders(ids);
    ref.invalidate(financeFeesProvider);
    if (!context.mounted) return;
    showMessage(
      context,
      r.queued == 0
          ? tr('Hatırlatma gönderilmedi: telefon yok ya da bugün gönderildi.')
          : tr('{n} hatırlatma SMS sırasına alındı.', {'n': r.queued}),
    );
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }
}

/// Ödeme günü ve ödeyen veli: ekleme ve düzenleme formunda ortak alanlar.
class _PayerFields extends StatelessWidget {
  const _PayerFields({
    required this.name,
    required this.phone,
    required this.dueDay,
    required this.onDueDay,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final int? dueDay;
  final ValueChanged<int?> onDueDay;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<int?>(
        initialValue: dueDay,
        isExpanded: true,
        decoration: InputDecoration(labelText: tr('Ödeme günü')),
        items: [
          for (var d = 1; d <= 28; d++)
            DropdownMenuItem(
              value: d,
              child: Text(tr('Her ayın {d}. günü', {'d': d})),
            ),
        ],
        onChanged: onDueDay,
      ),
      const SizedBox(height: 10),
      TextField(
        controller: name,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: tr('Veli adı (isteğe bağlı)')),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: tr('Veli cep telefonu'),
          hintText: '05XX XXX XX XX',
          helperText: tr('Taksit hatırlatma SMS\'i bu numaraya gider.'),
        ),
      ),
    ],
  );
}

/// Ödeme günü ve veliyi düzenler; geçerli değerlerle [FeePayer] döner.
/// Metin kutularını kendisi tutar (pencere kapanırken silinmesinler).
class _PayerDialog extends StatefulWidget {
  const _PayerDialog({required this.fee});

  final StudentFee fee;

  @override
  State<_PayerDialog> createState() => _PayerDialogState();
}

class _PayerDialogState extends State<_PayerDialog> {
  late final _name = TextEditingController(text: widget.fee.payerName ?? '');
  late final _phone = TextEditingController(
    text: widget.fee.payerPhone == null
        ? ''
        : formatPhone(widget.fee.payerPhone!),
  );
  late int? _dueDay = widget.fee.dueDay;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final (valid, phone) = _readPhone(context, _phone);
    if (!valid) return;
    final name = _name.text.trim();
    Navigator.pop(
      context,
      FeePayer(dueDay: _dueDay, name: name.isEmpty ? null : name, phone: phone),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Ödeme günü ve veli')),
    content: SingleChildScrollView(
      child: _PayerFields(
        name: _name,
        phone: _phone,
        dueDay: _dueDay,
        onDueDay: (v) => setState(() => _dueDay = v),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Vazgeç')),
      ),
      FilledButton(style: _inline, onPressed: _save, child: Text(tr('Kaydet'))),
    ],
  );
}

/// Telefon alanı boşsa null, geçersizse hata mesajı gösterir ve false döner.
(bool, String?) _readPhone(BuildContext context, TextEditingController c) {
  final t = c.text.trim();
  if (t.isEmpty) return (true, null);
  final p = normalizePhone(t);
  if (p == null) {
    showMessage(context, tr('Cep telefonunu 05XX XXX XX XX biçiminde yaz.'));
    return (false, null);
  }
  return (true, p);
}

Future<void> _guard(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }
}

// ---------------------------------------------------------------------------
// Özet
// ---------------------------------------------------------------------------

class _SummaryTab extends ConsumerStatefulWidget {
  const _SummaryTab();

  @override
  ConsumerState<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<_SummaryTab> {
  late DateTime _month = DateTime(_today().year, _today().month);

  @override
  Widget build(BuildContext context) {
    final fees = ref.watch(financeFeesProvider);
    final expenses = ref.watch(financeExpensesProvider);
    final incomes = ref.watch(financeIncomesProvider).value ?? const [];
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    return AsyncView(
      value: fees,
      onRetry: () => ref.invalidate(financeFeesProvider),
      builder: (f) {
        final e = expenses.value ?? const <FinanceExpense>[];
        final today = _today();
        final s = monthSummary(f, e, _month, today: today, incomes: incomes);
        final overdue = [
          for (final fee in f)
            for (final i in fee.overdue(today)) (fee, i),
        ]..sort((a, b) => a.$2.dueOn.compareTo(b.$2.dueOn));
        final months = [
          for (var k = 5; k >= 0; k--) DateTime(_month.year, _month.month - k),
        ];
        final history = [
          for (final m in months)
            monthSummary(f, e, m, today: today, incomes: incomes),
        ];
        final peak = history.fold<double>(
          1,
          (p, h) =>
              [p, h.collected, h.expenses].reduce((a, b) => a > b ? a : b),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: tr('Önceki ay'),
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                ),
                Expanded(
                  child: Text(
                    _monthLabel(_month),
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('Sonraki ay'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                ),
              ],
            ),
            StatRow(
              children: [
                StatTile(
                  icon: Icons.savings_outlined,
                  label: tr('Tahsilat'),
                  value: formatMoney(s.collected),
                  caption: tr('Beklenen: {v}', {'v': formatMoney(s.expected)}),
                ),
                StatTile(
                  icon: Icons.add_card_outlined,
                  label: tr('Diğer gelir'),
                  value: formatMoney(s.otherIncome),
                  caption: s.refunds > 0
                      ? tr('İade: {v}', {'v': formatMoney(s.refunds)})
                      : null,
                ),
                StatTile(
                  icon: Icons.receipt_long_outlined,
                  label: tr('Gider'),
                  value: formatMoney(s.expenses),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StatRow(
              children: [
                StatTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: tr('Net'),
                  value: formatMoney(s.net),
                  caption: tr('Tahsilat + gelir − iade − gider'),
                ),
                StatTile(
                  icon: Icons.warning_amber_rounded,
                  label: tr('Geciken'),
                  value: formatMoney(s.overdueAmount),
                  caption: tr('{n} taksit', {'n': s.overdueCount}),
                ),
              ],
            ),
            const ChequesDueBanner(),
            const SizedBox(height: 12),
            SectionCard(
              title: tr('Son 6 ay'),
              subtitle: tr('Tahsilat ve gider'),
              child: Column(
                children: [
                  for (final (k, m) in months.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              DateFormat('MMM', localeTag).format(m),
                              style: text.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Bar(
                                  value: history[k].collected / peak,
                                  color: brand.success,
                                ),
                                const SizedBox(height: 3),
                                _Bar(
                                  value: history[k].expenses / peak,
                                  color: brand.danger,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: Text(
                              formatMoney(history[k].net),
                              textAlign: TextAlign.end,
                              style: text.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Legend(color: brand.success, label: tr('Tahsilat')),
                      const SizedBox(width: 16),
                      _Legend(color: brand.danger, label: tr('Gider')),
                    ],
                  ),
                ],
              ),
            ),
            if (overdue.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: tr('Geciken taksitler'),
                child: Column(
                  children: [
                    for (final (fee, i) in overdue.take(20))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(fee.studentName),
                        subtitle: Text(
                          tr('Vade: {d}', {'d': formatLongDate(i.dueOn)}),
                        ),
                        trailing: Text(
                          formatMoney(i.open),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: brand.danger,
                          ),
                        ),
                        onTap: () => showFeeSheet(context, fee.id),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: value.clamp(0.02, 1.0),
    child: Container(
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

// ---------------------------------------------------------------------------
// Ücretler
// ---------------------------------------------------------------------------

class _FeesTab extends ConsumerStatefulWidget {
  const _FeesTab();

  @override
  ConsumerState<_FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends ConsumerState<_FeesTab> {
  bool _onlyOverdue = false;

  @override
  Widget build(BuildContext context) {
    final fees = ref.watch(financeFeesProvider);
    final brand = context.brand;
    final today = _today();
    return AsyncView(
      value: fees,
      onRetry: () => ref.invalidate(financeFeesProvider),
      builder: (all) {
        final list = _onlyOverdue
            ? all.where((f) => f.overdue(today).isNotEmpty).toList()
            : all;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(tr('Yalnızca gecikenler')),
                  selected: _onlyOverdue,
                  onSelected: (v) => setState(() => _onlyOverdue = v),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('open-bulk-fee'),
                      onPressed: () => showBulkFeeSheet(context),
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(tr('Toplu ücret')),
                    ),
                    FilledButton.icon(
                      style: _inline,
                      onPressed: () => _showAddFee(context),
                      icon: const Icon(Icons.add),
                      label: Text(tr('Ücret ekle')),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              EmptyState(
                title: _onlyOverdue
                    ? tr('Geciken taksit yok')
                    : tr('Henüz ücret yok'),
                message: tr(
                  'Öğrenciye ücret ve taksit planı ekle; ödeme gelince işaretle.',
                ),
              ),
            for (final f in list)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(f.studentName),
                  subtitle: Text(
                    '${f.title} · ${tr('{p} / {t} ödendi', {'p': formatMoney(f.paid), 't': formatMoney(f.netTotal)})}',
                  ),
                  trailing: _FeeStatus(fee: f, today: today, brand: brand),
                  onTap: () => showFeeSheet(context, f.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeeStatus extends StatelessWidget {
  const _FeeStatus({
    required this.fee,
    required this.today,
    required this.brand,
  });

  final StudentFee fee;
  final DateTime today;
  final BrandTheme brand;

  @override
  Widget build(BuildContext context) {
    final late = fee.overdue(today);
    final next = fee.nextDue;
    final (label, color) = fee.isCancelled
        ? (tr('İptal'), brand.ink)
        : late.isNotEmpty
        ? (tr('{n} gecikmiş', {'n': late.length}), brand.danger)
        : fee.settled
        ? (tr('Bitti'), brand.success)
        : next == null
        ? ('', brand.ink)
        : (formatShortDate(next.dueOn), brand.ink);
    return Text(
      label,
      style: TextStyle(fontWeight: FontWeight.w800, color: color),
    );
  }
}

/// Bir ücretin taksitleri: ödendi işaretle / geri al, ücreti sil.
Future<void> showFeeSheet(BuildContext context, String feeId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FeeSheet(feeId: feeId),
    );

class _FeeSheet extends ConsumerWidget {
  const _FeeSheet({required this.feeId});

  final String feeId;

  Future<void> _remind(
    BuildContext context,
    WidgetRef ref,
    StudentFee fee,
    FeeInstallment i,
  ) async {
    if (fee.payerPhone == null) {
      showMessage(context, tr('Önce veli telefonunu ekle.'));
      await _editPayer(context, ref, fee);
      return;
    }
    final ok = await confirm(
      context,
      title: tr('Hatırlatma SMS\'i gönderilsin mi?'),
      message: tr('{who} · {phone}\n{v} · vade {d}', {
        'who': fee.payerName ?? tr('Veli'),
        'phone': formatPhone(fee.payerPhone!),
        'v': formatMoney(i.amount),
        'd': formatLongDate(i.dueOn),
      }),
      action: tr('Gönder'),
    );
    if (!ok || !context.mounted) return;
    await _sendReminders(context, ref, [i.id]);
  }

  Future<void> _editPayer(
    BuildContext context,
    WidgetRef ref,
    StudentFee fee,
  ) async {
    final payer = await showDialog<FeePayer>(
      context: context,
      builder: (_) => _PayerDialog(fee: fee),
    );
    if (payer == null || !context.mounted) return;
    await _guard(
      context,
      () => ref.read(financeRepositoryProvider).updatePayer(fee.id, payer),
    );
    ref.invalidate(financeFeesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fee = ref
        .watch(financeFeesProvider)
        .value
        ?.where((f) => f.id == feeId)
        .firstOrNull;
    if (fee == null) return const SizedBox(height: 120);
    final text = Theme.of(context).textTheme;
    final brand = context.brand;
    final today = _today();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fee.studentName,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              fee.isCancelled
                  ? '${fee.title} · ${tr('Kayıt iptal edildi')}'
                  : '${fee.title} · ${tr('Kalan: {v}', {'v': formatMoney(fee.remaining)})}',
              style: text.bodyMedium,
            ),
            if (fee.discounts.isNotEmpty)
              Text(
                [
                  tr('İndirimsiz ücret: {v}', {'v': formatMoney(fee.total)}),
                  for (final d in fee.discounts)
                    '${d.kind.label}: −${formatMoney(d.amount)}',
                ].join(' · '),
                style: text.bodySmall,
              ),
            if (!fee.isCancelled && fee.remaining > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('fee-take-payment'),
                    style: _inline,
                    onPressed: () => showPaymentDialog(context, ref, fee),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(tr('Ödeme al')),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('fee-discount'),
                    onPressed: () => showDiscountDialog(context, ref, fee),
                    icon: const Icon(Icons.percent_rounded),
                    label: Text(tr('İndirim / burs')),
                  ),
                ],
              ),
            ],
            if (fee.note != null) Text(fee.note!, style: text.bodySmall),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (fee.dueDay != null)
                        tr('Her ayın {d}. günü', {'d': fee.dueDay}),
                      if (fee.payerPhone != null)
                        '${fee.payerName ?? tr('Veli')} · ${formatPhone(fee.payerPhone!)}'
                      else
                        tr('Veli telefonu yok'),
                    ].join(' · '),
                    style: text.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: tr('Ödeme günü ve veli'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editPayer(context, ref, fee),
                ),
              ],
            ),
            for (final i in fee.installments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  i.isPaid
                      ? Icons.check_circle_rounded
                      : i.isPartial
                      ? Icons.timelapse_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: i.isPaid ? brand.success : null,
                ),
                onTap: i.isPaid || fee.isCancelled
                    ? null
                    : () =>
                          showPaymentDialog(context, ref, fee, installment: i),
                title: Text(
                  formatMoney(i.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    if (i.isPaid)
                      tr('Ödendi: {d} · {m}', {
                        'd': formatLongDate(i.paidOn!),
                        'm': i.method?.label ?? '',
                      })
                    else
                      tr('Vade: {d}', {'d': formatLongDate(i.dueOn)}),
                    if (i.isPartial)
                      tr('{p} ödendi, {r} kaldı', {
                        'p': formatMoney(i.paidAmount),
                        'r': formatMoney(i.open),
                      }),
                    if (i.isOverdue(today)) tr('Gecikti'),
                    if (!i.isPaid && i.remindedAt != null)
                      tr('Hatırlatıldı: {d}', {
                        'd': formatShortDate(i.remindedAt!),
                      }),
                  ].join(' · '),
                  style: TextStyle(
                    color: i.isOverdue(today) ? brand.danger : null,
                  ),
                ),
                trailing: i.isPaid || fee.isCancelled
                    ? null
                    : IconButton(
                        tooltip: tr('Veliye hatırlat'),
                        icon: const Icon(Icons.sms_outlined),
                        onPressed: () => _remind(context, ref, fee, i),
                      ),
              ),
            FeeReceiptsList(fee: fee),
            const SizedBox(height: 8),
            if (!fee.isCancelled && fee.payments.any((p) => !p.isVoided))
              TextButton.icon(
                key: const ValueKey('fee-cancel'),
                style: TextButton.styleFrom(foregroundColor: brand.danger),
                onPressed: () => showCancelFeeDialog(context, ref, fee),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(tr('Kaydı iptal et / iade')),
              ),
            if (!fee.payments.any((p) => !p.isVoided))
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: brand.danger),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: tr('Ücret silinsin mi?'),
                    message: tr('Ücret ve tüm taksitleri silinecek.'),
                    action: tr('Sil'),
                  );
                  if (!ok || !context.mounted) return;
                  await _guard(
                    context,
                    () => ref.read(financeRepositoryProvider).deleteFee(fee.id),
                  );
                  ref.invalidate(financeFeesProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(tr('Ücreti sil')),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAddFee(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _AddFeeSheet(),
);

class _AddFeeSheet extends ConsumerStatefulWidget {
  const _AddFeeSheet();

  @override
  ConsumerState<_AddFeeSheet> createState() => _AddFeeSheetState();
}

class _AddFeeSheetState extends ConsumerState<_AddFeeSheet> {
  final _title = TextEditingController(text: tr('YKS kursu'));
  final _total = TextEditingController();
  final _note = TextEditingController();
  final _payerName = TextEditingController();
  final _payerPhone = TextEditingController();
  String? _student;
  int _count = 1;
  FeeDiscount? _discount;

  /// Her ayın kaçı (1-28) ve ilk taksitin ayı.
  int? _dueDay = _today().day > 28 ? 28 : _today().day;
  DateTime _firstMonth = DateTime(_today().year, _today().month);
  bool _saving = false;

  DateTime get _firstDue =>
      DateTime(_firstMonth.year, _firstMonth.month, _dueDay ?? 1);

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    _note.dispose();
    _payerName.dispose();
    _payerPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final total = parseMoney(_total.text);
    if (_student == null || total == null || _title.text.trim().isEmpty) {
      showMessage(context, tr('Öğrenci, başlık ve tutarı gir.'));
      return;
    }
    final net = total - (_discount?.amount ?? 0);
    if (net <= 0) {
      showMessage(context, tr('İndirim ücretten büyük olamaz.'));
      return;
    }
    final (valid, phone) = _readPhone(context, _payerPhone);
    if (!valid) return;
    setState(() => _saving = true);
    await _guard(
      context,
      () => ref
          .read(financeRepositoryProvider)
          .addFee(
            FeeDraft(
              studentId: _student!,
              title: _title.text.trim(),
              total: total,
              installments: splitInstallments(net, _count, _firstDue),
              discounts: [?_discount],
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              payer: FeePayer(
                dueDay: _dueDay,
                name: _payerName.text.trim().isEmpty
                    ? null
                    : _payerName.text.trim(),
                phone: phone,
              ),
            ),
          ),
    );
    ref.invalidate(financeFeesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentSummariesProvider).value ?? const [];
    final total = parseMoney(_total.text);
    final net = total == null ? null : total - (_discount?.amount ?? 0);
    final plan = net == null || net <= 0
        ? const <(DateTime, double)>[]
        : splitInstallments(net, _count, _firstDue);
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
              tr('Ücret ekle'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _student,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Öğrenci')),
              items: [
                for (final s in students)
                  DropdownMenuItem(value: s.id, child: Text(s.fullName)),
              ],
              onChanged: (v) => setState(() => _student = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: tr('Başlık')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _total,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('Toplam tutar'),
                suffixText: '₺',
              ),
              onChanged: (_) => setState(() {}),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.percent_rounded),
              title: Text(
                _discount == null
                    ? tr('İndirim yok')
                    : '${_discount!.kind.label} · ${formatMoney(_discount!.amount)}',
              ),
              subtitle: net == null || _discount == null
                  ? null
                  : Text(tr('Ödenecek: {v}', {'v': formatMoney(net)})),
              trailing: TextButton(
                key: const ValueKey('add-fee-discount'),
                onPressed: total == null
                    ? null
                    : () async {
                        final d = await showDialog<FeeDiscount>(
                          context: context,
                          builder: (_) =>
                              DiscountDialog(base: total, max: total),
                        );
                        setState(() => _discount = d);
                      },
                child: Text(_discount == null ? tr('Ekle') : tr('Değiştir')),
              ),
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
                  child: DropdownButtonFormField<DateTime>(
                    initialValue: _firstMonth,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tr('İlk taksit')),
                    items: [
                      for (var k = -2; k <= 10; k++)
                        DropdownMenuItem(
                          value: DateTime(_today().year, _today().month + k),
                          child: Text(
                            _monthLabel(
                              DateTime(_today().year, _today().month + k),
                            ),
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _firstMonth = v ?? _firstMonth),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PayerFields(
              name: _payerName,
              phone: _payerPhone,
              dueDay: _dueDay,
              onDueDay: (v) => setState(() => _dueDay = v),
            ),
            if (plan.length > 1) ...[
              const SizedBox(height: 8),
              for (final (due, amount) in plan)
                Text(
                  '${formatLongDate(due)} · ${formatMoney(amount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: tr('Not (isteğe bağlı)')),
            ),
            const SizedBox(height: 16),
            FilledButton(
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
// Giderler
// ---------------------------------------------------------------------------

IconData _categoryIcon(ExpenseCategory c) => switch (c) {
  ExpenseCategory.rent => Icons.home_work_outlined,
  ExpenseCategory.salary => Icons.badge_outlined,
  ExpenseCategory.bonus => Icons.emoji_events_outlined,
  ExpenseCategory.bills => Icons.bolt_outlined,
  ExpenseCategory.materials => Icons.menu_book_outlined,
  ExpenseCategory.marketing => Icons.campaign_outlined,
  ExpenseCategory.tax => Icons.account_balance_outlined,
  ExpenseCategory.other => Icons.more_horiz,
};

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(financeExpensesProvider);
    final text = Theme.of(context).textTheme;
    return AsyncView(
      value: expenses,
      onRetry: () => ref.invalidate(financeExpensesProvider),
      builder: (all) {
        final byMonth = <DateTime, List<FinanceExpense>>{};
        for (final e in all) {
          byMonth
              .putIfAbsent(DateTime(e.spentOn.year, e.spentOn.month), () => [])
              .add(e);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                style: _inline,
                onPressed: () => showAddExpense(context),
                icon: const Icon(Icons.add),
                label: Text(tr('Gider ekle')),
              ),
            ),
            if (all.isEmpty)
              EmptyState(
                title: tr('Henüz gider yok'),
                message: tr('Kira, maaş, fatura gibi giderleri buraya yaz.'),
              ),
            for (final MapEntry(key: month, value: list)
                in byMonth.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                child: Row(
                  children: [
                    Text(
                      _monthLabel(month),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatMoney(list.fold<double>(0, (s, e) => s + e.amount)),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              for (final e in list)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(_categoryIcon(e.category)),
                    title: Text(
                      [
                        e.category.label,
                        if (e.coachName != null) e.coachName!,
                        if (e.teacherName != null) e.teacherName!,
                        if (e.staffName != null) e.staffName!,
                      ].join(' · '),
                    ),
                    subtitle: Text(
                      [
                        formatLongDate(e.spentOn),
                        if (e.note != null) e.note!,
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatMoney(e.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          tooltip: tr('Sil'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              title: tr('Gider silinsin mi?'),
                              message: tr('{c} · {v}', {
                                'c': e.category.label,
                                'v': formatMoney(e.amount),
                              }),
                              action: tr('Sil'),
                            );
                            if (!ok || !context.mounted) return;
                            await _guard(
                              context,
                              () => ref
                                  .read(financeRepositoryProvider)
                                  .deleteExpense(e.id),
                            );
                            ref.invalidate(financeExpensesProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Gider ekle; koç maaşı / primi için [coachId] ve önerilen tutar verilebilir.
Future<void> showAddExpense(
  BuildContext context, {
  ExpenseCategory category = ExpenseCategory.rent,
  String? coachId,
  String? staffId,
  double? amount,
  String? note,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _AddExpenseSheet(
    category: category,
    coachId: coachId,
    staffId: staffId,
    amount: amount,
    note: note,
  ),
);

class _AddExpenseSheet extends ConsumerStatefulWidget {
  const _AddExpenseSheet({
    required this.category,
    this.coachId,
    this.staffId,
    this.amount,
    this.note,
  });

  final ExpenseCategory category;
  final String? coachId;

  /// Personel kartından açıldıysa ödeme o karta bağlanır.
  final String? staffId;
  final double? amount;
  final String? note;

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  late ExpenseCategory _category = widget.category;
  late String? _coach = widget.coachId;
  String? _account;
  late final _amount = TextEditingController(
    text: widget.amount == null
        ? ''
        : NumberFormat('0.##', 'en').format(widget.amount),
  );
  late final _note = TextEditingController(text: widget.note ?? '');
  DateTime _day = _today();
  bool _saving = false;

  bool get _forCoach =>
      _category == ExpenseCategory.salary || _category == ExpenseCategory.bonus;

  @override
  void dispose() {
    _amount.dispose();
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
    await _guard(
      context,
      () => ref
          .read(financeRepositoryProvider)
          .addExpense(
            ExpenseDraft(
              spentOn: _day,
              category: _category,
              amount: amount,
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              coachId: _forCoach && widget.staffId == null ? _coach : null,
              staffId: widget.staffId,
              accountId: _account,
            ),
          ),
    );
    ref.invalidate(financeExpensesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final coaches = [
      for (final m
          in ref.watch(orgMembersProvider).value ?? const <OrgMember>[])
        if (m.role == UserRole.coach) m,
    ];
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
              tr('Gider ekle'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              decoration: InputDecoration(labelText: tr('Tür')),
              items: [
                for (final c in ExpenseCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            if (_forCoach && widget.staffId == null) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _coach,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('Koç (isteğe bağlı)'),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(tr('Seçilmedi'))),
                  for (final c in coaches)
                    DropdownMenuItem(value: c.id, child: Text(c.fullName)),
                ],
                onChanged: (v) => setState(() => _coach = v),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
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
            AccountPicker(
              value: _account,
              onChanged: (v) => setState(() => _account = v),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime(_day.year - 2),
                  lastDate: DateTime(_day.year + 1),
                );
                if (d != null) setState(() => _day = d);
              },
              icon: const Icon(Icons.event),
              label: Text(formatLongDate(_day)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: tr('Not (isteğe bağlı)')),
            ),
            const SizedBox(height: 16),
            FilledButton(
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
// Koçlar: maaş + öğrenci başı prim
// ---------------------------------------------------------------------------

class _CoachesTab extends ConsumerWidget {
  const _CoachesTab();

  Future<void> _editRate(
    BuildContext context,
    WidgetRef ref,
    OrgMember coach,
    CoachPayRate rate,
  ) async {
    final next = await showDialog<CoachPayRate>(
      context: context,
      builder: (_) => _RateDialog(name: coach.fullName, rate: rate),
    );
    if (next == null || !context.mounted) return;
    await _guard(
      context,
      () => ref.read(financeRepositoryProvider).savePayRate(next),
    );
    ref.invalidate(coachPayRatesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(orgMembersProvider);
    final students = ref.watch(studentSummariesProvider).value ?? const [];
    final rates = ref.watch(coachPayRatesProvider).value ?? const {};
    final expenses = ref.watch(financeExpensesProvider).value ?? const [];
    final today = _today();
    final month = DateTime(today.year, today.month);
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    return AsyncView(
      value: members,
      onRetry: () => ref.invalidate(orgMembersProvider),
      builder: (all) {
        final coaches = [
          for (final m in all)
            if (m.role == UserRole.coach) m,
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (coaches.isEmpty)
              EmptyState(
                title: tr('Henüz koç yok'),
                message: tr('Koç davet edince maaş ve primi buradan tutarsın.'),
              )
            else ...[
              Text(
                tr(
                  'Önerilen ödeme = aylık maaş + öğrenci sayısı × öğrenci başı prim.',
                ),
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            for (final c in coaches)
              Builder(
                builder: (context) {
                  final rate = rates[c.id] ?? CoachPayRate(coachId: c.id);
                  final n = students.where((s) => s.coachId == c.id).length;
                  final amount = rate.suggested(n);
                  final paid = coachPaidIn(expenses, c.id, month);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.fullName,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: tr('Maaş ve primi düzenle'),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _editRate(context, ref, c, rate),
                              ),
                            ],
                          ),
                          Text(
                            tr('{n} öğrenci · maaş {s} · öğrenci başı {p}', {
                              'n': n,
                              's': formatMoney(rate.monthlySalary),
                              'p': formatMoney(rate.perStudent),
                            }),
                            style: text.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('Bu ay: {v}', {'v': formatMoney(amount)}),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (paid)
                                Text(
                                  tr('Bu ay ödendi'),
                                  style: TextStyle(
                                    color: brand.success,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              else
                                FilledButton.tonal(
                                  style: _inline,
                                  onPressed: () => showAddExpense(
                                    context,
                                    category: ExpenseCategory.salary,
                                    coachId: c.id,
                                    amount: amount > 0 ? amount : null,
                                    note: tr('{m} maaşı', {
                                      'm': DateFormat(
                                        'MMMM',
                                        localeTag,
                                      ).format(month),
                                    }),
                                  ),
                                  child: Text(tr('Ödemeyi kaydet')),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            const TeachersPaySection(),
          ],
        );
      },
    );
  }
}

/// Koçun aylık maaşı ve öğrenci başı primi.
class _RateDialog extends StatefulWidget {
  const _RateDialog({required this.name, required this.rate});

  final String name;
  final CoachPayRate rate;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  static String _fmt(double v) =>
      v == 0 ? '' : NumberFormat('0.##', 'en').format(v);

  late final _salary = TextEditingController(
    text: _fmt(widget.rate.monthlySalary),
  );
  late final _per = TextEditingController(text: _fmt(widget.rate.perStudent));

  @override
  void dispose() {
    _salary.dispose();
    _per.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.name),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _salary,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tr('Aylık maaş'),
            suffixText: '₺',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _per,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tr('Öğrenci başı prim'),
            suffixText: '₺',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Vazgeç')),
      ),
      FilledButton(
        style: _inline,
        onPressed: () => Navigator.pop(
          context,
          CoachPayRate(
            coachId: widget.rate.coachId,
            monthlySalary: parseMoney(_salary.text) ?? 0,
            perStudent: parseMoney(_per.text) ?? 0,
          ),
        ),
        child: Text(tr('Kaydet')),
      ),
    ],
  );
}

/// Müdür ana sayfasındaki kısa özet: bu ayın tahsilatı ve gecikenler.
/// Müdür: finans kısayolu (bu ayın tahsilatı, geciken taksit).
ToolInfo financeTool(WidgetRef ref) {
  final fees = ref.watch(financeFeesProvider).value;
  final expenses = ref.watch(financeExpensesProvider).value ?? const [];
  final today = _today();
  final s = fees == null
      ? null
      : monthSummary(
          fees,
          expenses,
          DateTime(today.year, today.month),
          today: today,
          incomes: ref.watch(financeIncomesProvider).value ?? const [],
        );
  return ToolInfo(
    id: 'finance-home-card',
    icon: Icons.account_balance_wallet_outlined,
    title: tr('Finans'),
    status: s == null
        ? tr('Ücret, taksit, gider ve koç maaşları')
        : s.overdueCount > 0
        ? tr('Bu ay tahsilat {v} · {n} geciken taksit', {
            'v': formatMoney(s.collected),
            'n': s.overdueCount,
          })
        : tr('Bu ay tahsilat {v}', {'v': formatMoney(s.collected)}),
    needsAction: (s?.overdueCount ?? 0) > 0,
    open: (context) => context.push('/admin/finance'),
  );
}

class FinanceHomeCard extends ConsumerWidget {
  const FinanceHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ToolListCard(tool: financeTool(ref));
}

/// Aylık ya da yıllık Excel: dönem seçilir, dosya paylaşılır.
Future<void> showFinanceExportDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final today = _today();
  final fees = await ref
      .read(financeFeesProvider.future)
      .catchError((_) => <StudentFee>[]);
  final expenses = await ref
      .read(financeExpensesProvider.future)
      .catchError((_) => <FinanceExpense>[]);
  final incomes = await ref
      .read(financeIncomesProvider.future)
      .catchError((_) => <FinanceIncome>[]);
  final accounts = await ref
      .read(financeAccountsProvider.future)
      .catchError((_) => <FinanceAccount>[]);
  final transfers = await ref
      .read(financeTransfersProvider.future)
      .catchError((_) => <FinanceTransfer>[]);
  final cheques = await ref
      .read(financeChequesProvider.future)
      .catchError((_) => <FinanceCheque>[]);
  if (!context.mounted) return;
  // Kayıtların olduğu yıllar + bu yıl.
  final years = {
    today.year,
    for (final f in fees)
      for (final i in f.installments) ...[i.dueOn.year, ?i.paidOn?.year],
    for (final e in expenses) e.spentOn.year,
  }.toList()..sort((a, b) => b.compareTo(a));
  final period = await showDialog<FinancePeriod>(
    context: context,
    builder: (_) => _ExportDialog(years: years, today: today),
  );
  if (period == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = buildFinanceWorkbook(
      fees: fees,
      expenses: expenses,
      period: period,
      today: today,
      orgName: ref.read(orgProvider).value?.name,
      incomes: incomes,
      accounts: accounts,
      transfers: transfers,
      cheques: cheques,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: 'finans-${period.slug}.xlsx',
          ),
        ],
        text: tr('Finans · {p}', {'p': period.label}),
      ),
    );
  } catch (e) {
    debugPrint('Finans Excel hazırlanamadı: $e');
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Dosya hazırlanamadı. Tekrar dene.'))),
    );
  }
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.years, required this.today});

  final List<int> years;
  final DateTime today;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  bool _yearly = false;
  late int _year = widget.today.year;
  late int _month = widget.today.month;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Excel olarak indir')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(tr('Aylık'))),
              ButtonSegment(value: true, label: Text(tr('Yıllık'))),
            ],
            selected: {_yearly},
            onSelectionChanged: (v) => setState(() => _yearly = v.first),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            key: const ValueKey('export-year'),
            initialValue: _year,
            decoration: InputDecoration(labelText: tr('Yıl')),
            items: [
              for (final y in widget.years)
                DropdownMenuItem(value: y, child: Text('$y')),
            ],
            onChanged: (v) => setState(() => _year = v ?? _year),
          ),
          if (!_yearly) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              key: const ValueKey('export-month'),
              initialValue: _month,
              decoration: InputDecoration(labelText: tr('Ay')),
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      DateFormat('MMMM', localeTag).format(DateTime(2026, m)),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _month = v ?? _month),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            tr(
              'Özet, tahsilatlar, taksitler, giderler ve öğrenci bakiyeleri ayrı sayfalarda.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          key: const ValueKey('export-go'),
          style: _inline,
          onPressed: () => Navigator.pop(
            context,
            _yearly
                ? FinancePeriod.year(_year)
                : FinancePeriod.month(_year, _month),
          ),
          child: Text(tr('İndir')),
        ),
      ],
    );
  }
}
