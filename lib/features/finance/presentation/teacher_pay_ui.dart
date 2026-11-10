import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../../schedule_generator/domain/models.dart';
import '../data/finance_repository.dart';
import 'finance_plus_ui.dart';

/// Öğretmen başına haftalık ders saati: programdaki her satır bir ders saati.
Map<String, int> weeklyHoursByTeacher(Iterable<ScheduleEntry> entries) {
  final out = <String, int>{};
  for (final e in entries) {
    out[e.teacherId] = (out[e.teacherId] ?? 0) + 1;
  }
  return out;
}

/// Yayındaki programdan haftalık saatler; yayında program yoksa null.
/// Program ekranı schedulesProvider'ı yenileyince saatler de yeniden sayılır.
final teacherWeeklyHoursProvider = FutureProvider<Map<String, int>?>((
  ref,
) async {
  final schedules = await ref.watch(schedulesProvider.future);
  final published = schedules.where((s) => s.published).firstOrNull;
  if (published == null) return null;
  return weeklyHoursByTeacher(
    await ref.read(timetableRepositoryProvider).fetchEntries(published.id),
  );
});

final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

String _plain(double v) => NumberFormat('0.##', 'en').format(v);

String _monthName(DateTime d) => DateFormat('MMMM', localeTag).format(d);

/// Finans → Koç ve öğretmen sekmesinin öğretmen bölümü. Uygulama ödeme
/// yapmaz; müdür yaptığı ödemeyi gider olarak kaydeder.
class TeachersPaySection extends ConsumerWidget {
  const TeachersPaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(timetableSetupProvider);
    final hours = ref.watch(teacherWeeklyHoursProvider);
    final rates = ref.watch(teacherPayRatesProvider).value ?? const {};
    final expenses = ref.watch(financeExpensesProvider).value ?? const [];
    final text = Theme.of(context).textTheme;
    final teachers = setup.value?.teachers ?? const <TeacherRecord>[];
    final noProgram = hours.hasValue && hours.value == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Öğretmenler'),
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        if (setup.hasError && !setup.hasValue)
          Row(
            children: [
              Expanded(child: Text(tr('Ders programı yüklenemedi.'))),
              TextButton(
                onPressed: () => ref.invalidate(timetableSetupProvider),
                child: Text(tr('Tekrar dene')),
              ),
            ],
          )
        else if (setup.isLoading && !setup.hasValue)
          const LinearProgressIndicator()
        else if (teachers.isEmpty)
          Text(
            tr(
              'Ders programına öğretmen ekleyince ücret ve ödemelerini buradan tutarsın.',
            ),
            style: text.bodySmall,
          )
        else ...[
          Text(
            noProgram
                ? tr(
                    'Yayında ders programı yok; saati ödeme sırasında elle yazabilirsin.',
                  )
                : tr('Haftalık saatler yayındaki ders programından gelir.'),
            style: text.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final t in teachers)
            _TeacherCard(
              record: t,
              weeklyHours: hours.value?[t.teacher.id] ?? 0,
              noProgram: hours.value == null,
              rate:
                  rates[t.teacher.id] ??
                  TeacherPayRate(teacherId: t.teacher.id),
              expenses: [
                for (final e in expenses)
                  if (e.teacherId == t.teacher.id) e,
              ],
            ),
        ],
      ],
    );
  }
}

class _TeacherCard extends ConsumerWidget {
  const _TeacherCard({
    required this.record,
    required this.weeklyHours,
    required this.noProgram,
    required this.rate,
    required this.expenses,
  });

  final TeacherRecord record;
  final int weeklyHours;
  final bool noProgram;
  final TeacherPayRate rate;

  /// Bu öğretmene yazılan ödemeler, en yeni önce.
  final List<FinanceExpense> expenses;

  String get _rateLine {
    if (rate.amount <= 0) return tr('Ücret girilmedi');
    return switch (rate.type) {
      TeacherPayType.hourly => tr('Saat başına {v} · haftalık {w}', {
        'v': formatMoney(rate.amount),
        'w': formatMoney(rate.amount * weeklyHours),
      }),
      TeacherPayType.fixed => tr('Aylık sabit {v}', {
        'v': formatMoney(rate.amount),
      }),
    };
  }

  Future<void> _editRate(BuildContext context, WidgetRef ref) async {
    final next = await showDialog<TeacherPayRate>(
      context: context,
      builder: (_) => _TeacherRateDialog(name: record.teacher.name, rate: rate),
    );
    if (next == null || !context.mounted) return;
    try {
      await ref.read(financeRepositoryProvider).saveTeacherPayRate(next);
    } catch (e) {
      if (context.mounted) showMessage(context, financeError(e));
    }
    ref.invalidate(teacherPayRatesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final paid = teacherPaidIn(expenses, record.teacher.id, now);
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
                    record.teacher.name,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('Ücreti düzenle'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editRate(context, ref),
                ),
              ],
            ),
            if (!noProgram)
              Text(
                weeklyHours > 0
                    ? tr('Haftada {h} ders saati', {'h': weeklyHours})
                    : tr('Programda dersi yok'),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            Text(_rateLine, style: text.bodySmall),
            if (record.profileId != null)
              Text(tr('Koç hesabına bağlı'), style: text.bodySmall),
            if (rate.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(rate.note!, style: text.bodySmall),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Bu ay ödenen: {v}', {'v': formatMoney(paid)}),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: paid > 0 ? context.brand.success : null,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  style: _inline,
                  onPressed: () => showTeacherPaySheet(
                    context,
                    name: record.teacher.name,
                    teacherId: record.teacher.id,
                    weeklyHours: weeklyHours,
                    rate: rate,
                  ),
                  child: Text(tr('Ödeme kaydet')),
                ),
              ],
            ),
            for (final e in expenses.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    formatLongDate(e.spentOn),
                    formatMoney(e.amount),
                    if (e.note != null) e.note!,
                  ].join(' · '),
                  style: text.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Öğretmene ödeme kaydı (Finans ve personel kartından açılır).
Future<void> showTeacherPaySheet(
  BuildContext context, {
  required String name,
  required String teacherId,
  required int weeklyHours,
  required TeacherPayRate rate,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _TeacherPaySheet(
    name: name,
    teacherId: teacherId,
    weeklyHours: weeklyHours,
    rate: rate,
  ),
);

/// Öğretmenin kayıtlı ödeme şekli, tutarı ve notu.
class _TeacherRateDialog extends StatefulWidget {
  const _TeacherRateDialog({required this.name, required this.rate});

  final String name;
  final TeacherPayRate rate;

  @override
  State<_TeacherRateDialog> createState() => _TeacherRateDialogState();
}

class _TeacherRateDialogState extends State<_TeacherRateDialog> {
  late TeacherPayType _type = widget.rate.type;
  late final _amount = TextEditingController(
    text: widget.rate.amount == 0 ? '' : _plain(widget.rate.amount),
  );
  late final _note = TextEditingController(text: widget.rate.note ?? '');

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.name),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TypePicker(
            value: _type,
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _type == TeacherPayType.hourly
                  ? tr('Saat ücreti')
                  : tr('Aylık sabit tutar'),
              suffixText: '₺',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 2,
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
        style: _inline,
        onPressed: () => Navigator.pop(
          context,
          TeacherPayRate(
            teacherId: widget.rate.teacherId,
            type: _type,
            amount: parseMoney(_amount.text) ?? 0,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
        ),
        child: Text(tr('Kaydet')),
      ),
    ],
  );
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.value, required this.onChanged});

  final TeacherPayType value;
  final ValueChanged<TeacherPayType> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<TeacherPayType>(
    showSelectedIcon: false,
    segments: [
      for (final t in TeacherPayType.values)
        ButtonSegment(value: t, label: Text(t.label)),
    ],
    selected: {value},
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

/// Ödeme kaydı: saat başına ödemede hafta × haftalık saat × ücret önerilir;
/// tatil ya da ek ders için her alan elle değişir. Gider olarak kaydedilir.
class _TeacherPaySheet extends ConsumerStatefulWidget {
  const _TeacherPaySheet({
    required this.name,
    required this.teacherId,
    required this.weeklyHours,
    required this.rate,
  });

  final String name;
  final String teacherId;
  final int weeklyHours;
  final TeacherPayRate rate;

  @override
  ConsumerState<_TeacherPaySheet> createState() => _TeacherPaySheetState();
}

class _TeacherPaySheetState extends ConsumerState<_TeacherPaySheet> {
  static const _defaultWeeks = 4;

  late TeacherPayType _type = widget.rate.type;
  final _weeks = TextEditingController(text: '$_defaultWeeks');
  late final _hours = TextEditingController(
    text: widget.weeklyHours == 0
        ? ''
        : '${widget.weeklyHours * _defaultWeeks}',
  );
  late final _hourly = TextEditingController(
    text: widget.rate.type == TeacherPayType.hourly && widget.rate.amount > 0
        ? _plain(widget.rate.amount)
        : '',
  );
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _account;
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resetAmount();
  }

  @override
  void dispose() {
    _weeks.dispose();
    _hours.dispose();
    _hourly.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Ödeme şekline göre önerilen tutar; hesaplanamıyorsa dokunulmaz.
  void _resetAmount() {
    if (_type == TeacherPayType.fixed) {
      if (widget.rate.type == TeacherPayType.fixed && widget.rate.amount > 0) {
        _amount.text = _plain(widget.rate.amount);
      }
      return;
    }
    final h = parseMoney(_hours.text);
    final r = parseMoney(_hourly.text);
    if (h != null && r != null) _amount.text = _plain(h * r);
  }

  void _weeksChanged(String v) {
    final w = int.tryParse(v.trim());
    if (w == null || w <= 0 || widget.weeklyHours == 0) return;
    _hours.text = '${widget.weeklyHours * w}';
    _resetAmount();
  }

  String? _composedNote() {
    final own = _note.text.trim();
    final month = _monthName(_day);
    final h = parseMoney(_hours.text);
    final r = parseMoney(_hourly.text);
    final auto = _type == TeacherPayType.fixed
        ? tr('{m} sabit ödeme', {'m': month})
        : h != null && r != null
        ? tr('{m}: {h} ders saati × {r}', {
            'm': month,
            'h': _plain(h),
            'r': formatMoney(r),
          })
        : null;
    final parts = [?auto, if (own.isNotEmpty) own];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    if (amount == null) {
      showMessage(context, tr('Tutarı gir.'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(financeRepositoryProvider)
          .addExpense(
            ExpenseDraft(
              spentOn: _day,
              category: ExpenseCategory.salary,
              amount: amount,
              note: _composedNote(),
              teacherId: widget.teacherId,
              accountId: _account,
            ),
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, financeError(e));
      return;
    }
    ref.invalidate(financeExpensesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
              widget.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _TypePicker(
              value: _type,
              onChanged: (v) => setState(() {
                _type = v;
                _resetAmount();
              }),
            ),
            if (_type == TeacherPayType.hourly) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (widget.weeklyHours > 0) ...[
                    Expanded(
                      child: TextField(
                        key: const ValueKey('teacher-pay-weeks'),
                        controller: _weeks,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr('Hafta sayısı'),
                        ),
                        onChanged: _weeksChanged,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: TextField(
                      key: const ValueKey('teacher-pay-hours'),
                      controller: _hours,
                      keyboardType: money,
                      decoration: InputDecoration(labelText: tr('Ders saati')),
                      onChanged: (_) => _resetAmount(),
                    ),
                  ),
                ],
              ),
              if (widget.weeklyHours > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tr(
                      'Haftada {h} ders saati × hafta sayısı. Tatil varsa saati düzeltebilirsin.',
                      {'h': widget.weeklyHours},
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('teacher-pay-rate'),
                controller: _hourly,
                keyboardType: money,
                decoration: InputDecoration(
                  labelText: tr('Saat ücreti'),
                  suffixText: '₺',
                ),
                onChanged: (_) => _resetAmount(),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('teacher-pay-amount'),
              controller: _amount,
              keyboardType: money,
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
              maxLength: 200,
              decoration: InputDecoration(labelText: tr('Not (isteğe bağlı)')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('teacher-pay-save'),
              onPressed: _saving ? null : _save,
              child: Text(tr('Kaydet')),
            ),
          ],
        ),
      ),
    );
  }
}
