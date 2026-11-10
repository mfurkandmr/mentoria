import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../coach/data/coach_repository.dart';
import '../data/finance_repository.dart';
import 'finance_plus_ui.dart';

DateTime _today() => DateUtils.dateOnly(DateTime.now());

String _chequeError(Object e) {
  final s = '$e';
  if (s.contains('CHEQUE_BAD_STATUS')) {
    return tr('Bu kayıt bu duruma geçirilemez.');
  }
  if (s.contains('CHEQUE_NOT_DELETABLE')) {
    return tr('İşlem görmüş kayıt silinemez; önceki duruma geri al.');
  }
  if (s.contains('CHEQUE_NEEDS_ENDORSEE')) {
    return tr('Ciro edilen kişiyi yaz.');
  }
  return financeError(e);
}

Color _statusColor(BuildContext context, FinanceCheque c, DateTime today) {
  final brand = context.brand;
  if (c.isOverdue(today) || c.status == ChequeStatus.bounced) {
    return brand.danger;
  }
  return switch (c.status) {
    ChequeStatus.collected || ChequeStatus.paid => brand.success,
    ChequeStatus.deposited || ChequeStatus.endorsed => Tone.warn.of(context),
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

/// Finans → Çek ve senet.
class ChequesTab extends ConsumerStatefulWidget {
  const ChequesTab({super.key});

  @override
  ConsumerState<ChequesTab> createState() => _ChequesTabState();
}

class _ChequesTabState extends ConsumerState<ChequesTab> {
  ChequeDirection _direction = ChequeDirection.received;

  @override
  Widget build(BuildContext context) {
    final cheques = ref.watch(financeChequesProvider);
    final today = _today();
    return AsyncView(
      value: cheques,
      onRetry: () => ref.invalidate(financeChequesProvider),
      builder: (all) {
        final s = chequeSummary(all, today);
        final list = all.where((c) => c.direction == _direction).toList()
          ..sort((a, b) {
            // Açık olanlar vadesine göre başta; kapananlar en yeni önce sonda.
            if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
            return a.isOpen
                ? a.dueOn.compareTo(b.dueOn)
                : b.dueOn.compareTo(a.dueOn);
          });
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            StatRow(
              children: [
                StatTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: tr('Portföyde'),
                  value: formatMoney(s.portfolio),
                  caption: tr('Tahsilde olanlar dahil'),
                ),
                StatTile(
                  icon: Icons.warning_amber_rounded,
                  label: tr('Vadesi geçen'),
                  value: formatMoney(s.overdueAmount),
                  caption: tr('{n} kayıt', {'n': s.overdueCount}),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StatRow(
              children: [
                StatTile(
                  icon: Icons.south_west_rounded,
                  label: tr('Bu ay alınacak'),
                  value: formatMoney(s.monthIn),
                ),
                StatTile(
                  icon: Icons.north_east_rounded,
                  label: tr('Bu ay ödenecek'),
                  value: formatMoney(s.monthOut),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ChequeDirection>(
              showSelectedIcon: false,
              segments: [
                for (final d in ChequeDirection.values)
                  ButtonSegment(value: d, label: Text(d.label)),
              ],
              selected: {_direction},
              onSelectionChanged: (v) => setState(() => _direction = v.first),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                key: const ValueKey('cheque-add'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => _AddChequeSheet(direction: _direction),
                ),
                icon: const Icon(Icons.add),
                label: Text(tr('Çek / senet ekle')),
              ),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _direction == ChequeDirection.received
                      ? tr('Veliden ya da kişilerden alınan çek ve senet yok.')
                      : tr('Kurumun verdiği çek ve senet yok.'),
                  textAlign: TextAlign.center,
                ),
              ),
            for (final c in list) _ChequeCard(cheque: c),
          ],
        );
      },
    );
  }
}

class _ChequeCard extends ConsumerWidget {
  const _ChequeCard({required this.cheque});

  final FinanceCheque cheque;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cheque;
    final today = _today();
    final color = _statusColor(context, c, today);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: ValueKey('cheque-${c.id}'),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _ChequeActionsSheet(cheque: c),
        ),
        leading: Icon(
          c.kind == ChequeKind.note
              ? Icons.description_outlined
              : Icons.request_quote_outlined,
        ),
        title: Text(
          '${c.partyName} · ${formatMoney(c.amount)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            tr('Vade: {d}', {'d': formatShortDate(c.dueOn)}),
            c.kind.label,
            ?c.serialNo,
            ?c.bank,
            if (c.studentName != null) c.studentName!,
          ].join(' · '),
        ),
        trailing: Text(
          c.isOverdue(today) ? tr('Vadesi geçti') : c.status.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Özet sekmesindeki uyarı: vadesi geçen ya da 7 gün içinde gelen kayıt varsa.
class ChequesDueBanner extends ConsumerWidget {
  const ChequesDueBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(financeChequesProvider).value;
    if (all == null) return const SizedBox.shrink();
    final s = chequeSummary(all, _today());
    if (s.overdueCount == 0 && s.soonCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          key: const ValueKey('cheques-due-banner'),
          leading: Icon(
            Icons.request_quote_outlined,
            color: s.overdueCount > 0
                ? context.brand.danger
                : Tone.warn.of(context),
          ),
          title: Text(tr('Çek ve senet')),
          subtitle: Text(
            [
              if (s.overdueCount > 0)
                tr('{n} kaydın vadesi geçti', {'n': s.overdueCount}),
              if (s.soonCount > 0)
                tr('{n} kaydın vadesi 7 gün içinde', {'n': s.soonCount}),
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => DefaultTabController.of(context).animateTo(6),
        ),
      ),
    );
  }
}

class _ChequeActionsSheet extends ConsumerStatefulWidget {
  const _ChequeActionsSheet({required this.cheque});

  final FinanceCheque cheque;

  @override
  ConsumerState<_ChequeActionsSheet> createState() =>
      _ChequeActionsSheetState();
}

class _ChequeActionsSheetState extends ConsumerState<_ChequeActionsSheet> {
  bool _busy = false;

  void _refresh() {
    ref.invalidate(financeChequesProvider);
    // Tahsilat ve ödeme ücrete, gelire ya da gidere yazılır.
    ref.invalidate(financeFeesProvider);
    ref.invalidate(financeIncomesProvider);
    ref.invalidate(financeExpensesProvider);
  }

  Future<void> _apply(ChequeStatus next) async {
    final c = widget.cheque;
    DateTime on = _today();
    String? account;
    String? endorsedTo;
    if (next == ChequeStatus.collected ||
        next == ChequeStatus.paid ||
        next == ChequeStatus.deposited ||
        next == ChequeStatus.endorsed) {
      final r = await showDialog<_StatusInput>(
        context: context,
        builder: (_) => _StatusDialog(status: next),
      );
      if (r == null || !mounted) return;
      on = r.on;
      account = r.accountId;
      endorsedTo = r.endorsedTo;
    } else if (c.status == ChequeStatus.collected ||
        c.status == ChequeStatus.paid) {
      final ok = await confirm(
        context,
        title: tr('İşlem geri alınsın mı?'),
        message: c.status == ChequeStatus.collected
            ? tr('Tahsilat makbuzu iptal edilir.')
            : tr('Yazılan gider silinir.'),
        action: chequeActionLabel(next),
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(financeRepositoryProvider)
          .setChequeStatus(
            c.id,
            next,
            on: on,
            accountId: account,
            endorsedTo: endorsedTo,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, _chequeError(e));
      return;
    }
    _refresh();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final c = widget.cheque;
    final ok = await confirm(
      context,
      title: tr('Kayıt silinsin mi?'),
      message: '${c.partyName} · ${formatMoney(c.amount)}',
      action: tr('Sil'),
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(financeRepositoryProvider).deleteCheque(c.id);
    } catch (e) {
      if (mounted) showMessage(context, _chequeError(e));
      return;
    }
    ref.invalidate(financeChequesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cheque;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${c.partyName} · ${formatMoney(c.amount)}',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              [
                c.direction.label,
                c.kind.label,
                c.status.label,
                if (c.statusOn != null) formatShortDate(c.statusOn!),
              ].join(' · '),
            ),
            Text(
              [
                tr('Vade: {d}', {'d': formatLongDate(c.dueOn)}),
                if (c.issueOn != null)
                  tr('Düzenleme: {d}', {'d': formatShortDate(c.issueOn!)}),
              ].join(' · '),
              style: text.bodySmall,
            ),
            if (c.serialNo != null || c.bank != null)
              Text([?c.serialNo, ?c.bank].join(' · '), style: text.bodySmall),
            if (c.studentName != null)
              Text(c.studentName!, style: text.bodySmall),
            if (c.endorsedTo != null)
              Text(
                tr('Ciro edilen: {n}', {'n': c.endorsedTo!}),
                style: text.bodySmall,
              ),
            if (c.receiptNo != null)
              Text(
                tr('Makbuz: {n}', {'n': c.receiptNo!}),
                style: text.bodySmall,
              ),
            if (c.note != null) Text(c.note!, style: text.bodySmall),
            const SizedBox(height: 12),
            for (final next in c.nextStatuses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  key: ValueKey('cheque-to-${next.db}'),
                  onPressed: _busy ? null : () => _apply(next),
                  child: Text(chequeActionLabel(next)),
                ),
              ),
            if (c.status == ChequeStatus.portfolio ||
                c.status == ChequeStatus.issued)
              TextButton(
                key: const ValueKey('cheque-delete'),
                onPressed: _busy ? null : _delete,
                child: Text(tr('Kaydı sil')),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusInput {
  const _StatusInput(this.on, this.accountId, this.endorsedTo);

  final DateTime on;
  final String? accountId;
  final String? endorsedTo;
}

/// Tahsil, ödeme, tahsile verme ve ciro: gün, hesap ya da ciro edilen kişi.
class _StatusDialog extends StatefulWidget {
  const _StatusDialog({required this.status});

  final ChequeStatus status;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  DateTime _on = _today();
  String? _account;
  final _endorsee = TextEditingController();

  bool get _endorsing => widget.status == ChequeStatus.endorsed;

  @override
  void dispose() {
    _endorsee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(chequeActionLabel(widget.status)),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _on,
                firstDate: DateTime(_on.year - 2),
                lastDate: DateTime(_on.year + 1),
              );
              if (d != null) setState(() => _on = d);
            },
            icon: const Icon(Icons.event),
            label: Text(formatLongDate(_on)),
          ),
          const SizedBox(height: 10),
          if (_endorsing)
            TextField(
              key: const ValueKey('cheque-endorsee'),
              controller: _endorsee,
              maxLength: 80,
              decoration: InputDecoration(labelText: tr('Ciro edilen kişi')),
            )
          else
            AccountPicker(
              value: _account,
              onChanged: (v) => setState(() => _account = v),
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
        key: const ValueKey('cheque-status-save'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () {
          final to = _endorsee.text.trim();
          if (_endorsing && to.isEmpty) {
            showMessage(context, tr('Ciro edilen kişiyi yaz.'));
            return;
          }
          Navigator.pop(
            context,
            _StatusInput(_on, _account, _endorsing ? to : null),
          );
        },
        child: Text(tr('Kaydet')),
      ),
    ],
  );
}

class _AddChequeSheet extends ConsumerStatefulWidget {
  const _AddChequeSheet({required this.direction});

  final ChequeDirection direction;

  @override
  ConsumerState<_AddChequeSheet> createState() => _AddChequeSheetState();
}

class _AddChequeSheetState extends ConsumerState<_AddChequeSheet> {
  ChequeKind _kind = ChequeKind.cheque;
  final _serial = TextEditingController();
  final _bank = TextEditingController();
  final _party = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _student;
  String? _fee;
  DateTime? _issue;
  DateTime _due = _today().add(const Duration(days: 30));
  bool _saving = false;

  bool get _received => widget.direction == ChequeDirection.received;

  @override
  void dispose() {
    for (final c in [_serial, _bank, _party, _amount, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final party = _party.text.trim();
    final amount = parseMoney(_amount.text);
    if (party.isEmpty) {
      showMessage(context, tr('Kişi ya da kurum adını yaz.'));
      return;
    }
    if (amount == null) {
      showMessage(context, tr('Tutarı gir.'));
      return;
    }
    String? blank(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    setState(() => _saving = true);
    try {
      await ref
          .read(financeRepositoryProvider)
          .addCheque(
            ChequeDraft(
              direction: widget.direction,
              kind: _kind,
              serialNo: blank(_serial),
              bank: blank(_bank),
              partyName: party,
              studentId: _received ? _student : null,
              feeId: _received ? _fee : null,
              amount: amount,
              issueOn: _issue,
              dueOn: _due,
              note: blank(_note),
            ),
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, _chequeError(e));
      return;
    }
    ref.invalidate(financeChequesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final students =
        ref.watch(studentSummariesProvider).value ?? const <StudentSummary>[];
    final fees = [
      for (final f
          in ref.watch(financeFeesProvider).value ?? const <StudentFee>[])
        if (f.studentId == _student && !f.isCancelled && f.remaining > 0) f,
    ];
    const gap = SizedBox(height: 10);
    const money = TextInputType.numberWithOptions(decimal: true);
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
              _received ? tr('Alınan çek / senet') : tr('Verilen çek / senet'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ChequeKind>(
              showSelectedIcon: false,
              segments: [
                for (final k in ChequeKind.values)
                  ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            gap,
            TextField(
              key: const ValueKey('cheque-party'),
              controller: _party,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: _received ? tr('Kimden') : tr('Kime'),
              ),
            ),
            TextField(
              key: const ValueKey('cheque-amount'),
              controller: _amount,
              keyboardType: money,
              decoration: InputDecoration(
                labelText: tr('Tutar'),
                suffixText: '₺',
              ),
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serial,
                    maxLength: 40,
                    decoration: InputDecoration(labelText: tr('Seri no')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _bank,
                    maxLength: 80,
                    decoration: InputDecoration(labelText: tr('Banka')),
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              key: const ValueKey('cheque-due'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _due,
                  firstDate: DateTime(_due.year - 3),
                  lastDate: DateTime(_due.year + 5),
                );
                if (d != null) setState(() => _due = d);
              },
              icon: const Icon(Icons.event),
              label: Text(tr('Vade: {d}', {'d': formatLongDate(_due)})),
            ),
            gap,
            OutlinedButton.icon(
              onPressed: () async {
                final base = _issue ?? _today();
                final d = await showDatePicker(
                  context: context,
                  initialDate: base,
                  firstDate: DateTime(base.year - 3),
                  lastDate: DateTime(base.year + 1),
                );
                if (d != null) setState(() => _issue = d);
              },
              icon: const Icon(Icons.event_note),
              label: Text(
                _issue == null
                    ? tr('Düzenleme tarihi (isteğe bağlı)')
                    : tr('Düzenleme: {d}', {'d': formatLongDate(_issue!)}),
              ),
            ),
            if (_received) ...[
              gap,
              DropdownButtonFormField<String?>(
                key: const ValueKey('cheque-student'),
                initialValue: _student,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('Öğrenci (isteğe bağlı)'),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(tr('Seçilmedi'))),
                  for (final s in students)
                    DropdownMenuItem(value: s.id, child: Text(s.fullName)),
                ],
                onChanged: (v) => setState(() {
                  _student = v;
                  _fee = null;
                }),
              ),
              if (fees.isNotEmpty) ...[
                gap,
                DropdownButtonFormField<String?>(
                  key: ValueKey('cheque-fee-$_student'),
                  initialValue: _fee,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr('Hangi ücrete sayılsın'),
                    helperText: tr(
                      'Seçilmezse tahsil edilince ücret dışı gelir yazılır.',
                    ),
                    helperMaxLines: 2,
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr('Seçilmedi'))),
                    for (final f in fees)
                      DropdownMenuItem(
                        value: f.id,
                        child: Text(
                          tr('{t} · kalan {v}', {
                            't': f.title,
                            'v': formatMoney(f.remaining),
                          }),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _fee = v),
                ),
              ],
            ],
            gap,
            TextField(
              controller: _note,
              maxLength: 300,
              decoration: InputDecoration(labelText: tr('Not (isteğe bağlı)')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('cheque-save'),
              onPressed: _saving ? null : _save,
              child: Text(tr('Kaydet')),
            ),
          ],
        ),
      ),
    );
  }
}
