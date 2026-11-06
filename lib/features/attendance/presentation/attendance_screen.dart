import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../finance/data/finance_repository.dart'
    show formatPhone, normalizePhone;
import '../data/attendance_repository.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Temadaki düğmeler tam genişlik; satır içindekiler kendi boyunda.
final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

Color _statusColor(BuildContext context, AttendanceStatus s) {
  final brand = context.brand;
  return switch (s) {
    AttendanceStatus.present => brand.success,
    AttendanceStatus.absent => Theme.of(context).colorScheme.error,
    AttendanceStatus.late => brand.primary,
    AttendanceStatus.excused => brand.info,
  };
}

/// Günlük yoklama (koç: kendi öğrencileri, müdür: kurumun bütün
/// öğrencileri). Kaydedince "gelmedi" işaretlenenlerin velisine SMS
/// gönderilsin mi diye sorar.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _day = _today();

  /// Kaydedilmemiş işaretler: öğrenci → durum (null: işareti kaldır).
  final _edits = <String, AttendanceStatus?>{};
  String _query = '';
  bool _saving = false;

  AttendanceStatus? _statusOf(AttendanceRow r) =>
      _edits.containsKey(r.studentId) ? _edits[r.studentId] : r.status;

  Future<bool> _confirmDiscard() async {
    if (_edits.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Kaydedilmemiş yoklama')),
        content: Text(tr('Yaptığın işaretler silinsin mi?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            style: _inline,
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Sil')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _changeDay(DateTime day) async {
    if (day == _day || !await _confirmDiscard() || !mounted) return;
    setState(() {
      _edits.clear();
      _day = day;
    });
  }

  Future<void> _pickDay() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today,
    );
    if (picked != null) {
      await _changeDay(DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save(List<AttendanceRow> rows) async {
    setState(() => _saving = true);
    final day = _day;
    try {
      await ref.read(attendanceRepositoryProvider).save(day, {..._edits});
      _edits.clear();
      ref.invalidate(attendanceDayProvider(day));
      final fresh = await ref.read(attendanceDayProvider(day).future);
      if (!mounted) return;
      setState(() => _saving = false);
      final absent = [
        for (final r in fresh)
          if (r.status == AttendanceStatus.absent && r.smsAt == null) r,
      ];
      if (absent.isEmpty) {
        showMessage(context, tr('Yoklama kaydedildi.'));
      } else {
        await showAbsenceSmsDialog(context, ref, day, absent, afterSave: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  void _markAllPresent(List<AttendanceRow> rows) => setState(() {
    for (final r in rows) {
      if (_statusOf(r) == null) _edits[r.studentId] = AttendanceStatus.present;
    }
  });

  void _mark(AttendanceRow r, AttendanceStatus s) => setState(() {
    final next = _statusOf(r) == s ? null : s;
    if (next == r.status) {
      _edits.remove(r.studentId);
    } else {
      _edits[r.studentId] = next;
    }
  });

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(attendanceDayProvider(_day));
    final today = _today();
    final isToday = _day == today;
    final dayLabel = DateFormat('d MMMM EEEE', localeTag).format(_day);
    return PopScope(
      canPop: _edits.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(_edits.clear);
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Yoklama')),
          actions: [
            IconButton(
              tooltip: tr('Gelmeyenlerin velisine SMS'),
              icon: const Icon(Icons.sms_outlined),
              onPressed: () {
                final list = rows.value;
                if (list == null) return;
                showAbsenceSmsDialog(context, ref, _day, [
                  for (final r in list)
                    if (r.status == AttendanceStatus.absent && r.smsAt == null)
                      r,
                ]);
              },
            ),
          ],
        ),
        body: AsyncView(
          value: rows,
          onRetry: () => ref.invalidate(attendanceDayProvider(_day)),
          builder: (list) {
            final q = _query.trim().toLowerCase();
            final shown = q.isEmpty
                ? list
                : [
                    for (final r in list)
                      if (r.fullName.toLowerCase().contains(q) ||
                          (r.studentNumber?.toLowerCase().contains(q) ?? false))
                        r,
                  ];
            final counts = {
              for (final s in AttendanceStatus.values)
                s: list.where((r) => _statusOf(r) == s).length,
            };
            final unmarked = list.where((r) => _statusOf(r) == null).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: tr('Önceki gün'),
                      icon: const Icon(Icons.chevron_left),
                      onPressed: today.difference(_day).inDays >= 30 || _saving
                          ? null
                          : () => _changeDay(
                              DateTime(_day.year, _day.month, _day.day - 1),
                            ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _saving ? null : _pickDay,
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(
                          isToday
                              ? tr('Bugün · {d}', {'d': dayLabel})
                              : dayLabel,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('Sonraki gün'),
                      icon: const Icon(Icons.chevron_right),
                      onPressed: isToday || _saving
                          ? null
                          : () => _changeDay(
                              DateTime(_day.year, _day.month, _day.day + 1),
                            ),
                    ),
                  ],
                ),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr('Yoklama alınacak öğrenci yok.'),
                      textAlign: TextAlign.center,
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in AttendanceStatus.values)
                        _CountChip(
                          icon: s.icon,
                          color: _statusColor(context, s),
                          label: '${s.label} ${counts[s]}',
                        ),
                      if (unmarked > 0)
                        _CountChip(
                          icon: Icons.radio_button_unchecked,
                          color: Theme.of(context).colorScheme.outline,
                          label: tr('İşaretsiz {n}', {'n': unmarked}),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (unmarked > 0)
                    OutlinedButton.icon(
                      onPressed: () => _markAllPresent(list),
                      icon: const Icon(Icons.done_all_rounded),
                      label: Text(tr('İşaretsizlerin hepsi geldi')),
                    ),
                  if (list.length > 8) ...[
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: tr('Öğrenci adı veya numarası ara'),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                  const SizedBox(height: 6),
                  for (final r in shown)
                    _StudentTile(
                      key: ValueKey('att-${r.studentId}'),
                      row: r,
                      status: _statusOf(r),
                      edited: _edits.containsKey(r.studentId),
                      onMark: (s) => _mark(r, s),
                      onPhone: () => _editPhone(r),
                    ),
                ],
              ],
            );
          },
        ),
        bottomNavigationBar: _edits.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    key: const ValueKey('attendance-save'),
                    onPressed: _saving
                        ? null
                        : () => _save(rows.value ?? const []),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      tr('Yoklamayı kaydet ({n})', {'n': _edits.length}),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _editPhone(AttendanceRow r) async {
    final result = await showDialog<(String?, String?)>(
      context: context,
      builder: (_) => _GuardianPhoneDialog(row: r),
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .setGuardianPhone(r.studentId, name: result.$1, phone: result.$2);
      ref.invalidate(attendanceDayProvider);
      if (mounted) showMessage(context, tr('Veli telefonu kaydedildi.'));
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 18, color: color),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    super.key,
    required this.row,
    required this.status,
    required this.edited,
    required this.onMark,
    required this.onPhone,
  });

  final AttendanceRow row;
  final AttendanceStatus? status;
  final bool edited;
  final ValueChanged<AttendanceStatus> onMark;
  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.fullName,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          if (row.studentNumber != null)
                            tr('No {n}', {'n': row.studentNumber!}),
                          if (row.smsAt != null)
                            tr('Veliye SMS gönderildi')
                          else if (edited)
                            tr('Kaydedilmedi'),
                        ].join(' · '),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: row.hasPhone
                      ? tr('Veli telefonu')
                      : tr('Veli telefonu ekle'),
                  icon: Icon(
                    row.hasPhone
                        ? Icons.phone_rounded
                        : Icons.phone_disabled_rounded,
                    color: row.hasPhone
                        ? context.brand.success
                        : scheme.outline,
                  ),
                  onPressed: onPhone,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in AttendanceStatus.values)
                  ChoiceChip(
                    key: ValueKey('att-${row.studentId}-${s.db}'),
                    avatar: Icon(
                      s.icon,
                      size: 18,
                      color: status == s
                          ? _statusColor(context, s)
                          : scheme.outline,
                    ),
                    showCheckmark: false,
                    label: Text(s.label),
                    selected: status == s,
                    selectedColor: _statusColor(
                      context,
                      s,
                    ).withValues(alpha: 0.18),
                    onSelected: (_) => onMark(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Veli adı ve cep telefonu; (ad, telefon) döner, telefon null: sil.
class _GuardianPhoneDialog extends StatefulWidget {
  const _GuardianPhoneDialog({required this.row});

  final AttendanceRow row;

  @override
  State<_GuardianPhoneDialog> createState() => _GuardianPhoneDialogState();
}

class _GuardianPhoneDialogState extends State<_GuardianPhoneDialog> {
  late final _name = TextEditingController(text: widget.row.guardianName ?? '');
  late final _phone = TextEditingController(
    text: widget.row.guardianPhone == null
        ? ''
        : formatPhone(widget.row.guardianPhone!),
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final t = _phone.text.trim();
    final phone = t.isEmpty ? null : normalizePhone(t);
    if (t.isNotEmpty && phone == null) {
      showMessage(context, tr('Cep telefonunu 05XX XXX XX XX biçiminde yaz.'));
      return;
    }
    final name = _name.text.trim();
    Navigator.pop(context, (name.isEmpty ? null : name, phone));
  }

  @override
  Widget build(BuildContext context) {
    final fromFinance = widget.row.hasPhone && widget.row.guardianPhone == null;
    return AlertDialog(
      title: Text(widget.row.fullName),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('Veli adı (isteğe bağlı)'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('guardian-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('Veli cep telefonu'),
                hintText: '05XX XXX XX XX',
                helperText: fromFinance
                    ? tr(
                        'Şu an kurum finansındaki veli numarası kullanılıyor. Buraya yazarsan bu numara kullanılır.',
                      )
                    : tr('"Gelmedi" SMS\'i bu numaraya gider.'),
                helperMaxLines: 3,
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
          style: _inline,
          onPressed: _save,
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}

/// "Gelmedi" işaretli öğrencilerin velisine SMS; telefonu olmayanlar
/// seçilemez. Liste boşsa bilgi verir.
Future<void> showAbsenceSmsDialog(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
  List<AttendanceRow> absent, {
  bool afterSave = false,
}) async {
  if (absent.isEmpty) {
    showMessage(context, tr('SMS gönderilecek gelmeyen öğrenci yok.'));
    return;
  }
  final selected = {
    for (final r in absent)
      if (r.hasPhone) r.studentId,
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(tr('Gelmeyenlerin velisine SMS gönderilsin mi?')),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                tr(
                  'Seçilen velilere "öğrenciniz bugün kuruma gelmedi" SMS\'i gider.',
                ),
                style: Theme.of(c).textTheme.bodySmall,
              ),
              for (final r in absent)
                CheckboxListTile(
                  key: ValueKey('absent-sms-${r.studentId}'),
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(r.studentId),
                  onChanged: r.hasPhone
                      ? (v) => setState(
                          () => v == true
                              ? selected.add(r.studentId)
                              : selected.remove(r.studentId),
                        )
                      : null,
                  title: Text(r.fullName),
                  subtitle: Text(
                    !r.hasPhone
                        ? tr('Veli telefonu yok')
                        : r.guardianPhone == null
                        ? tr('Kurumdaki veli numarası')
                        : '${r.guardianName ?? tr('Veli')} · ${formatPhone(r.guardianPhone!)}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Gönderme')),
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
  if (ok != true || !context.mounted) {
    if (afterSave && context.mounted) {
      showMessage(context, tr('Yoklama kaydedildi.'));
    }
    return;
  }
  try {
    final r = await ref
        .read(attendanceRepositoryProvider)
        .sendAbsenceSms(day, selected.toList());
    ref.invalidate(attendanceDayProvider(day));
    if (!context.mounted) return;
    showMessage(
      context,
      r.queued == 0
          ? tr('SMS gönderilmedi: telefon yok ya da bugün gönderildi.')
          : tr('{n} veliye SMS sırasına alındı.', {'n': r.queued}),
    );
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }
}

/// Koç ve müdür ana sayfası: bugünkü yoklamanın özeti.
class AttendanceHomeCard extends ConsumerWidget {
  const AttendanceHomeCard({super.key, required this.basePath});

  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(attendanceDayProvider(_today())).value;
    final c = rows == null ? null : AttendanceCounts(rows);
    final String subtitle;
    if (c == null || c.total == 0) {
      subtitle = tr('Günlük yoklama ve gelmeyenin velisine SMS');
    } else if (c.marked == 0) {
      subtitle = tr('Bugünkü yoklama alınmadı');
    } else {
      subtitle = [
        tr('Bugün {p} geldi · {a} gelmedi', {
          'p':
              c.count(AttendanceStatus.present) +
              c.count(AttendanceStatus.late),
          'a': c.count(AttendanceStatus.absent),
        }),
        if (c.marked < c.total) tr('{n} işaretsiz', {'n': c.total - c.marked}),
      ].join(' · ');
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.how_to_reg_outlined),
        title: Text(tr('Yoklama')),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('$basePath/attendance'),
      ),
    );
  }
}
