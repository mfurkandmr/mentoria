import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/tool_tile.dart';
import '../../admin/data/admin_repository.dart';
import '../../admin/presentation/admin_home_screen.dart'
    show showInviteCodeDialog;
import '../../auth/data/profile.dart';
import '../../coach/data/coach_repository.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/presentation/finance_screen.dart';
import '../../finance/presentation/teacher_pay_ui.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../data/staff_repository.dart';
import '../../../core/design/motion.dart';

DateTime _today() => DateUtils.dateOnly(DateTime.now());

String _staffError(Object e) {
  final s = '$e';
  if (s.contains('STAFF_LEAVE_OVERLAP')) {
    return tr('Bu tarihlerde kişinin başka bir izni var.');
  }
  if (s.contains('STAFF_BAD_REF')) {
    return tr('Bu koç ya da öğretmenin zaten bir kartı var.');
  }
  return tr('Kaydedilemedi. Tekrar dene.');
}

/// Kartlar, koçlar ve öğretmenler tek listede.
final personnelProvider = Provider<AsyncValue<List<PersonnelEntry>>>((ref) {
  final staff = ref.watch(staffMembersProvider);
  final members = ref.watch(orgMembersProvider);
  // Ders programı kurulmamış ya da açılamamış olabilir: liste yine görünür.
  final setup = ref.watch(timetableSetupProvider).value;
  if (staff.hasError) return AsyncError(staff.error!, staff.stackTrace!);
  if (members.hasError) return AsyncError(members.error!, members.stackTrace!);
  if (!staff.hasValue || !members.hasValue) return const AsyncLoading();
  return AsyncData(
    mergePersonnel(
      staff: staff.value!,
      coaches: {
        for (final m in members.value!)
          if (m.role == UserRole.coach) m.id: m.fullName,
      },
      teachers: [
        for (final t in setup?.teachers ?? const <TeacherRecord>[])
          TeacherRef(
            id: t.teacher.id,
            name: t.teacher.name,
            profileId: t.profileId,
            branches: t.teacher.branches,
          ),
      ],
    ),
  );
});

/// Aylık sabit ücret: kartta yazan maaş, yoksa koç maaşı ya da öğretmenin sabiti.
double personnelSalary(
  PersonnelEntry e, {
  required Map<String, CoachPayRate> coachRates,
  required Map<String, TeacherPayRate> teacherRates,
}) {
  final own = e.staff?.monthlySalary ?? 0;
  if (own > 0) return own;
  final coach = coachRates[e.coachId]?.monthlySalary ?? 0;
  if (coach > 0) return coach;
  final teacher = teacherRates[e.teacherId];
  return teacher?.type == TeacherPayType.fixed ? teacher!.amount : 0;
}

/// Müdür: personel kısayolu (kurum araçları ve Koçlar sekmesi).
ToolInfo staffTool(WidgetRef ref) {
  final people = ref.watch(personnelProvider).value;
  final today = _today();
  final active = people?.where((p) => p.isActive(today)).length;
  return ToolInfo(
    id: 'tool-staff',
    icon: Icons.badge_outlined,
    title: tr('Personel'),
    status: active == null
        ? tr('Çalışan kartları, izinler ve ödemeler')
        : tr('{n} çalışan; izin ve ödemeler', {'n': active}),
    open: (c) => c.push('/admin/staff'),
  );
}

enum _Filter { all, teachers, coaches, others, left }

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  _Filter _filter = _Filter.all;
  String _query = '';

  bool _matches(PersonnelEntry p, DateTime today) {
    if (_query.isNotEmpty &&
        !p.name.toLowerCase().contains(_query.toLowerCase())) {
      return false;
    }
    final active = p.isActive(today);
    return switch (_filter) {
      _Filter.all => active,
      _Filter.teachers => active && p.teacherId != null,
      _Filter.coaches => active && p.coachId != null,
      _Filter.others => active && p.coachId == null && p.teacherId == null,
      _Filter.left => !active,
    };
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(personnelProvider);
    final leaves = ref.watch(staffLeavesProvider).value ?? const <StaffLeave>[];
    final coachRates = ref.watch(coachPayRatesProvider).value ?? const {};
    final teacherRates = ref.watch(teacherPayRatesProvider).value ?? const {};
    final today = _today();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Personel'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('staff-add'),
        onPressed: () => showStaffForm(context, ref),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(tr('Personel ekle')),
      ),
      body: AsyncView(
        value: people,
        onRetry: () {
          ref.invalidate(staffMembersProvider);
          ref.invalidate(orgMembersProvider);
        },
        builder: (all) {
          final active = all.where((p) => p.isActive(today)).toList();
          final onLeave = {
            for (final l in leaves)
              if (l.covers(today)) l.staffId,
          };
          final salary = active.fold<double>(
            0,
            (s, p) =>
                s +
                personnelSalary(
                  p,
                  coachRates: coachRates,
                  teacherRates: teacherRates,
                ),
          );
          final shown = all.where((p) => _matches(p, today)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              StatRow(
                children: [
                  StatTile(
                    icon: Icons.groups_outlined,
                    label: tr('Aktif çalışan'),
                    value: '${active.length}',
                  ),
                  StatTile(
                    icon: Icons.beach_access_outlined,
                    label: tr('Bugün izinde'),
                    value: '${onLeave.length}',
                  ),
                  StatTile(
                    icon: Icons.payments_outlined,
                    label: tr('Aylık sabit ücret'),
                    value: formatMoney(salary),
                    caption: tr('Saatlik ödemeler hariç'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('staff-search'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: tr('Ad ara'),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (f, label) in [
                    (_Filter.all, tr('Tümü')),
                    (_Filter.teachers, tr('Öğretmenler')),
                    (_Filter.coaches, tr('Koçlar')),
                    (_Filter.others, tr('Diğer personel')),
                    (_Filter.left, tr('Ayrılanlar')),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Uygulama hesabı daveti: personel kartı yalnızca İK kaydıdır;
              // öğretmen / koç kendi paneline davet koduyla girer.
              if (_filter == _Filter.teachers || _filter == _Filter.coaches)
                _InviteCard(
                  role: _filter == _Filter.teachers
                      ? UserRole.teacher
                      : UserRole.coach,
                ),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr('Bu listede kimse yok.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final p in shown)
                _PersonCard(
                  person: p,
                  onLeave: p.staff != null && onLeave.contains(p.staff!.id),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Personel → Öğretmenler / Koçlar: uygulamaya davet kodu.
class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = role == UserRole.teacher;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teacher
                  ? tr(
                      'Öğretmen uygulamaya davet koduyla kaydolur; kendi panelinde ders programını ve soru çözümü taleplerini görür. "Personel ekle" yalnızca izin ve ödeme kartı açar.',
                    )
                  : tr(
                      'Koç uygulamaya davet koduyla kaydolur. "Personel ekle" yalnızca izin ve ödeme kartı açar.',
                    ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  key: ValueKey('staff-invite-${role.name}'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () =>
                      showInviteCodeDialog(context, ref, role: role),
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: Text(
                    teacher ? tr('Öğretmen davet et') : tr('Koç davet et'),
                  ),
                ),
                if (teacher)
                  TextButton(
                    onPressed: () => context.push('/admin/teachers'),
                    child: Text(tr('Öğretmen hesapları')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _jobLine(PersonnelEntry p) => [
  p.job.label,
  if (p.staff != null) p.staff!.employment.label,
  if (p.branches.isNotEmpty) (p.branches.toList()..sort()).join(', '),
].join(' · ');

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.onLeave});

  final PersonnelEntry person;
  final bool onLeave;

  @override
  Widget build(BuildContext context) {
    final phone = person.staff?.phone;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: ValueKey('staff-${person.key}'),
        leading: CircleAvatar(
          child: Text(person.name.characters.first.toUpperCase()),
        ),
        title: Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [_jobLine(person), if (onLeave) tr('Bugün izinde')].join(' · '),
          style: onLeave ? TextStyle(color: Tone.warn.of(context)) : null,
        ),
        trailing: phone == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: tr('Ara'),
                icon: const Icon(Icons.call_outlined),
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              ),
        onTap: () => context.push('/admin/staff/${person.key}'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ayrıntı
// ---------------------------------------------------------------------------

class StaffDetailScreen extends ConsumerWidget {
  const StaffDetailScreen({super.key, required this.personKey});

  final String personKey;

  /// İzin ya da düzenleme için kart gerekir: koç / öğretmenin kartı yoksa açılır.
  static Future<String> ensureCard(WidgetRef ref, PersonnelEntry p) async {
    if (p.staff != null) return p.staff!.id;
    final id = await ref
        .read(staffRepositoryProvider)
        .saveStaff(
          StaffMember(
            fullName: p.name,
            job: p.job,
            profileId: p.coachId,
            teacherId: p.teacherId,
          ),
        );
    ref.invalidate(staffMembersProvider);
    return id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(personnelProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Personel kartı'))),
      body: AsyncView(
        value: people,
        onRetry: () => ref.invalidate(staffMembersProvider),
        builder: (all) {
          // Kart yeni açıldıysa adres eski kalır (c_ / t_): kişiyi yine bul.
          final p = all
              .where(
                (x) =>
                    x.key == personKey ||
                    'c_${x.coachId}' == personKey ||
                    't_${x.teacherId}' == personKey,
              )
              .firstOrNull;
          if (p == null) {
            return Center(child: Text(tr('Bu kişi artık listede yok.')));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _InfoCard(person: p),
              const SizedBox(height: 12),
              _LeavesCard(person: p),
              const SizedBox(height: 12),
              _PaymentsCard(person: p),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _InfoCard extends ConsumerWidget {
  const _InfoCard({required this.person});

  final PersonnelEntry person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = person.staff;
    final hours = ref.watch(teacherWeeklyHoursProvider).value;
    final students = ref.watch(studentSummariesProvider).value ?? const [];
    final text = Theme.of(context).textTheme;
    final phone = s?.phone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    person.name,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('staff-edit'),
                  tooltip: tr('Düzenle'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showStaffForm(context, ref, person: person),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_jobLine(person), style: text.bodyMedium),
            ),
            if (person.teacherId != null && hours != null)
              _Row(
                tr('Haftalık ders'),
                tr('{h} ders saati', {'h': hours[person.teacherId] ?? 0}),
              ),
            if (person.coachId != null)
              _Row(
                tr('Öğrenci'),
                '${students.where((x) => x.coachId == person.coachId).length}',
              ),
            if (phone != null) _Row(tr('Telefon'), formatPhone(phone)),
            if (s?.email != null) _Row(tr('E-posta'), s!.email!),
            if (s?.startOn != null)
              _Row(tr('İşe giriş'), formatLongDate(s!.startOn!)),
            if (s?.endOn != null)
              _Row(tr('Ayrılış'), formatLongDate(s!.endOn!)),
            if ((s?.monthlySalary ?? 0) > 0)
              _Row(tr('Aylık maaş'), formatMoney(s!.monthlySalary)),
            if (s?.emergencyName != null || s?.emergencyPhone != null)
              _Row(
                tr('Acil durumda'),
                [
                  ?s?.emergencyName,
                  if (s?.emergencyPhone != null)
                    formatPhone(s!.emergencyPhone!),
                ].join(' · '),
              ),
            if (s?.note != null) _Row(tr('Not'), s!.note!),
            if (s == null)
              Text(
                tr('Henüz kart açılmadı. Bilgileri düzenleyince kart açılır.'),
                style: text.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _LeavesCard extends ConsumerWidget {
  const _LeavesCard({required this.person});

  final PersonnelEntry person;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<StaffLeave>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (_) => const _LeaveDialog(),
    );
    if (draft == null || !context.mounted) return;
    try {
      final id = await StaffDetailScreen.ensureCard(ref, person);
      await ref
          .read(staffRepositoryProvider)
          .addLeave(
            StaffLeave(
              staffId: id,
              kind: draft.kind,
              startOn: draft.startOn,
              endOn: draft.endOn,
              note: draft.note,
            ),
          );
    } catch (e) {
      if (context.mounted) showMessage(context, _staffError(e));
    }
    ref.invalidate(staffLeavesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = person.staff;
    final all = ref.watch(staffLeavesProvider).value ?? const <StaffLeave>[];
    final mine = s == null
        ? const <StaffLeave>[]
        : all.where((l) => l.staffId == s.id).toList();
    final year = _today().year;
    final used = s == null ? 0 : annualLeaveUsed(all, s.id, year);
    final right = s?.annualLeaveDays ?? 14;
    return SectionCard(
      title: tr('İzinler'),
      subtitle: tr('{y} yıllık izin: {u} / {r} gün', {
        'y': year,
        'u': used,
        'r': right,
      }),
      trailing: TextButton.icon(
        key: const ValueKey('leave-add'),
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(tr('İzin ekle')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mine.isEmpty) Text(tr('İzin kaydı yok.')),
          for (final l in mine)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr('{k} · {n} gün', {'k': l.kind.label, 'n': l.days}),
              ),
              subtitle: Text(
                [
                  '${formatShortDate(l.startOn)} – ${formatShortDate(l.endOn)}',
                  ?l.note,
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: tr('Sil'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    title: tr('İzin kaydı silinsin mi?'),
                    message: l.kind.label,
                    action: tr('Sil'),
                  );
                  if (!ok) return;
                  try {
                    await ref.read(staffRepositoryProvider).deleteLeave(l.id);
                  } catch (e) {
                    if (context.mounted) showMessage(context, _staffError(e));
                  }
                  ref.invalidate(staffLeavesProvider);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog();

  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends State<_LeaveDialog> {
  LeaveKind _kind = LeaveKind.annual;
  DateTime _start = _today();
  DateTime _end = _today();
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(initial.year - 2),
    lastDate: DateTime(initial.year + 2),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('İzin ekle')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<LeaveKind>(
            initialValue: _kind,
            decoration: InputDecoration(labelText: tr('Tür')),
            items: [
              for (final k in LeaveKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('leave-start'),
            onPressed: () async {
              final d = await _pick(_start);
              if (d == null) return;
              setState(() {
                _start = d;
                if (_end.isBefore(d)) _end = d;
              });
            },
            icon: const Icon(Icons.event),
            label: Text(tr('Başlangıç: {d}', {'d': formatShortDate(_start)})),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('leave-end'),
            onPressed: () async {
              final d = await _pick(_end);
              if (d == null) return;
              setState(() {
                _end = d;
                if (_start.isAfter(d)) _start = d;
              });
            },
            icon: const Icon(Icons.event),
            label: Text(tr('Bitiş: {d}', {'d': formatShortDate(_end)})),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: tr('Not (isteğe bağlı)'),
              helperText: tr('Sağlık ayrıntısı yazma.'),
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
        key: const ValueKey('leave-save'),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () => Navigator.pop(
          context,
          StaffLeave(
            staffId: '',
            kind: _kind,
            startOn: _start,
            endOn: _end,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
        ),
        child: Text(tr('Kaydet')),
      ),
    ],
  );
}

class _PaymentsCard extends ConsumerWidget {
  const _PaymentsCard({required this.person});

  final PersonnelEntry person;

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final teacherId = person.teacherId;
    if (teacherId != null) {
      final hours = ref.read(teacherWeeklyHoursProvider).value;
      final rates = ref.read(teacherPayRatesProvider).value ?? const {};
      await showTeacherPaySheet(
        context,
        name: person.name,
        teacherId: teacherId,
        weeklyHours: hours?[teacherId] ?? 0,
        rate: rates[teacherId] ?? TeacherPayRate(teacherId: teacherId),
      );
      return;
    }
    final month = DateFormat('MMMM', localeTag).format(_today());
    final note = tr('{m} maaşı', {'m': month});
    final own = person.staff?.monthlySalary ?? 0;
    if (person.coachId != null) {
      final rate = ref.read(coachPayRatesProvider).value?[person.coachId];
      final amount = own > 0 ? own : (rate?.monthlySalary ?? 0);
      await showAddExpense(
        context,
        category: ExpenseCategory.salary,
        coachId: person.coachId,
        amount: amount > 0 ? amount : null,
        note: note,
      );
      return;
    }
    await showAddExpense(
      context,
      category: ExpenseCategory.salary,
      staffId: person.staff!.id,
      amount: own > 0 ? own : null,
      note: note,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all =
        ref.watch(financeExpensesProvider).value ?? const <FinanceExpense>[];
    final mine = [
      for (final e in all)
        if ((person.staff != null && e.staffId == person.staff!.id) ||
            (person.coachId != null && e.coachId == person.coachId) ||
            (person.teacherId != null && e.teacherId == person.teacherId))
          e,
    ];
    final year = _today().year;
    final total = mine
        .where((e) => e.spentOn.year == year)
        .fold<double>(0, (s, e) => s + e.amount);
    return SectionCard(
      title: tr('Ödemeler'),
      subtitle: tr('{y} toplamı: {v}', {'y': year, 'v': formatMoney(total)}),
      trailing: TextButton.icon(
        key: const ValueKey('staff-pay'),
        onPressed: () => _pay(context, ref),
        icon: const Icon(Icons.add),
        label: Text(tr('Ödeme kaydet')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mine.isEmpty) Text(tr('Ödeme kaydı yok.')),
          for (final e in mine.take(12))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(formatMoney(e.amount)),
              subtitle: Text([formatLongDate(e.spentOn), ?e.note].join(' · ')),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kart formu
// ---------------------------------------------------------------------------

Future<void> showStaffForm(
  BuildContext context,
  WidgetRef ref, {
  PersonnelEntry? person,
}) => showModalBottomSheet<void>(
  context: context,
  sheetAnimationStyle: AppMotion.overlayStyle(context),
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _StaffFormSheet(person: person),
);

class _StaffFormSheet extends ConsumerStatefulWidget {
  const _StaffFormSheet({this.person});

  final PersonnelEntry? person;

  @override
  ConsumerState<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends ConsumerState<_StaffFormSheet> {
  StaffMember? get _s => widget.person?.staff;

  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late StaffJob _job = widget.person?.job ?? StaffJob.secretary;
  late StaffEmployment _employment = _s?.employment ?? StaffEmployment.full;
  late final _phone = TextEditingController(
    text: _s?.phone == null ? '' : formatPhone(_s!.phone!),
  );
  late final _email = TextEditingController(text: _s?.email ?? '');
  late final _salary = TextEditingController(
    text: (_s?.monthlySalary ?? 0) == 0
        ? ''
        : NumberFormat('0.##', 'en').format(_s!.monthlySalary),
  );
  late final _leave = TextEditingController(
    text: '${_s?.annualLeaveDays ?? 14}',
  );
  late final _emergencyName = TextEditingController(
    text: _s?.emergencyName ?? '',
  );
  late final _emergencyPhone = TextEditingController(
    text: _s?.emergencyPhone == null ? '' : formatPhone(_s!.emergencyPhone!),
  );
  late final _note = TextEditingController(text: _s?.note ?? '');
  late DateTime? _start = _s?.startOn;
  late DateTime? _end = _s?.endOn;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _email,
      _salary,
      _leave,
      _emergencyName,
      _emergencyPhone,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _blank(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, tr('Adı yaz.'));
      return;
    }
    final phoneText = _blank(_phone);
    final phone = phoneText == null ? null : normalizePhone(phoneText);
    final emergencyText = _blank(_emergencyPhone);
    final emergency = emergencyText == null
        ? null
        : normalizePhone(emergencyText);
    if ((phoneText != null && phone == null) ||
        (emergencyText != null && emergency == null)) {
      showMessage(context, tr('Cep telefonunu 05XX XXX XX XX biçiminde yaz.'));
      return;
    }
    final leave = int.tryParse(_leave.text.trim()) ?? 14;
    if (leave < 0 || leave > 60) {
      showMessage(context, tr('Yıllık izin 0-60 gün olabilir.'));
      return;
    }
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      showMessage(context, tr('Ayrılış günü işe girişten önce olamaz.'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(staffRepositoryProvider)
          .saveStaff(
            StaffMember(
              id: _s?.id ?? '',
              fullName: name,
              job: _job,
              employment: _employment,
              phone: phone,
              email: _blank(_email),
              startOn: _start,
              endOn: _end,
              monthlySalary: parseMoney(_salary.text) ?? 0,
              annualLeaveDays: leave,
              emergencyName: _blank(_emergencyName),
              emergencyPhone: emergency,
              note: _blank(_note),
              profileId: _s?.profileId ?? widget.person?.coachId,
              teacherId: _s?.teacherId ?? widget.person?.teacherId,
            ),
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, _staffError(e));
      return;
    }
    ref.invalidate(staffMembersProvider);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final s = _s!;
    final linked = s.profileId != null || s.teacherId != null;
    final ok = await confirm(
      context,
      title: tr('Kart silinsin mi?'),
      message: linked
          ? tr(
              'Kart ve izinler silinir; koç hesabı ya da ders programındaki öğretmen silinmez.',
            )
          : tr(
              'Kart ve izinler silinir; ödeme kayıtları adıyla kalır. Çalışan ayrıldıysa ayrılış günü girmek daha iyi.',
            ),
      action: tr('Sil'),
    );
    if (!ok || !mounted) return;
    final router = GoRouter.of(context);
    try {
      await ref.read(staffRepositoryProvider).deleteStaff(s.id);
    } catch (e) {
      if (mounted) showMessage(context, _staffError(e));
      return;
    }
    ref.invalidate(staffMembersProvider);
    ref.invalidate(staffLeavesProvider);
    if (!mounted) return;
    Navigator.pop(context);
    if (!linked) router.pop();
  }

  Widget _dateButton(
    Key key,
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: key,
          onPressed: () async {
            final now = _today();
            final d = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: DateTime(now.year - 40),
              lastDate: DateTime(now.year + 2),
            );
            if (d != null) onChanged(d);
          },
          icon: const Icon(Icons.event),
          label: Text(
            value == null ? label : '$label: ${formatLongDate(value)}',
          ),
        ),
      ),
      if (value != null)
        IconButton(
          tooltip: tr('Temizle'),
          icon: const Icon(Icons.close),
          onPressed: () => onChanged(null),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 10);
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
              widget.person == null ? tr('Personel ekle') : tr('Kartı düzenle'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('staff-name'),
              controller: _name,
              decoration: InputDecoration(labelText: tr('Ad soyad')),
            ),
            gap,
            DropdownButtonFormField<StaffJob>(
              key: const ValueKey('staff-job'),
              initialValue: _job,
              decoration: InputDecoration(labelText: tr('Görev')),
              items: [
                for (final j in StaffJob.values)
                  DropdownMenuItem(value: j, child: Text(j.label)),
              ],
              onChanged: (v) => setState(() => _job = v ?? _job),
            ),
            gap,
            DropdownButtonFormField<StaffEmployment>(
              initialValue: _employment,
              decoration: InputDecoration(labelText: tr('Çalışma şekli')),
              items: [
                for (final e in StaffEmployment.values)
                  DropdownMenuItem(value: e, child: Text(e.label)),
              ],
              onChanged: (v) => setState(() => _employment = v ?? _employment),
            ),
            gap,
            TextField(
              key: const ValueKey('staff-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('Telefon')),
            ),
            gap,
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: tr('E-posta')),
            ),
            gap,
            _dateButton(
              const ValueKey('staff-start'),
              tr('İşe giriş'),
              _start,
              (d) => setState(() => _start = d),
            ),
            gap,
            _dateButton(
              const ValueKey('staff-end'),
              tr('Ayrılış'),
              _end,
              (d) => setState(() => _end = d),
            ),
            gap,
            TextField(
              key: const ValueKey('staff-salary'),
              controller: _salary,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('Aylık maaş'),
                suffixText: '₺',
              ),
            ),
            gap,
            TextField(
              controller: _leave,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Yıllık izin hakkı (gün)'),
              ),
            ),
            gap,
            TextField(
              controller: _emergencyName,
              decoration: InputDecoration(
                labelText: tr('Acil durumda aranacak kişi'),
              ),
            ),
            gap,
            TextField(
              controller: _emergencyPhone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('Acil durum telefonu')),
            ),
            gap,
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: tr('Not (isteğe bağlı)'),
                helperText: tr(
                  'Kimlik numarası ve sağlık bilgisi yazma; gerekmeyen kişisel bilgi tutma.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('staff-save'),
              onPressed: _saving ? null : _save,
              child: Text(tr('Kaydet')),
            ),
            if (_s != null) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('staff-delete'),
                onPressed: _saving ? null : _delete,
                child: Text(tr('Kartı sil')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
