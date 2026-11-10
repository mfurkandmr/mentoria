import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/data/profile.dart';
import '../../coach/data/coach_repository.dart';
import '../data/timetable_repository.dart';
import '../domain/models.dart';
import 'timetable_format.dart';
import '../../../core/design/motion.dart';

final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

Future<void> _guard(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  try {
    await action();
    ref.invalidate(timetableSetupProvider);
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }
}

/// Kurum müdürü: ders programı kurulumu (ders saatleri → sınıflar →
/// öğretmenler → dersler → oluştur). Her adım kendi kaydını hemen yazar.
class TimetableSetupScreen extends ConsumerStatefulWidget {
  const TimetableSetupScreen({super.key});

  @override
  ConsumerState<TimetableSetupScreen> createState() =>
      _TimetableSetupScreenState();
}

class _TimetableSetupScreenState extends ConsumerState<TimetableSetupScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(timetableSetupProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ders programı kurulumu'))),
      body: AsyncView(
        value: setup,
        onRetry: () => ref.invalidate(timetableSetupProvider),
        builder: (s) => Stepper(
          currentStep: _step,
          onStepTapped: (i) => setState(() => _step = i),
          onStepContinue: _step < 4 ? () => setState(() => _step++) : null,
          onStepCancel: _step > 0 ? () => setState(() => _step--) : null,
          controlsBuilder: (context, d) => _step == 4
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      FilledButton(
                        style: _inline,
                        onPressed: d.onStepContinue,
                        child: Text(tr('Devam')),
                      ),
                      const SizedBox(width: 8),
                      if (_step > 0)
                        TextButton(
                          onPressed: d.onStepCancel,
                          child: Text(tr('Geri')),
                        ),
                    ],
                  ),
                ),
          steps: [
            Step(
              title: Text(tr('Ders saatleri')),
              subtitle: Text(
                s.slots.isEmpty
                    ? tr('Henüz yok')
                    : tr('{n} ders saati', {'n': s.slots.length}),
              ),
              isActive: _step >= 0,
              state: s.slots.isEmpty ? StepState.indexed : StepState.complete,
              content: _SlotsStep(setup: s),
            ),
            Step(
              title: Text(tr('Sınıflar ve derslikler')),
              subtitle: Text(
                tr('{c} sınıf · {r} derslik', {
                  'c': s.classrooms.length,
                  'r': s.rooms.length,
                }),
              ),
              isActive: _step >= 1,
              state: s.classrooms.isEmpty
                  ? StepState.indexed
                  : StepState.complete,
              content: _ClassesStep(setup: s),
            ),
            Step(
              title: Text(tr('Öğretmenler ve müsaitlik')),
              subtitle: Text(tr('{n} öğretmen', {'n': s.teachers.length})),
              isActive: _step >= 2,
              state: s.teachers.isEmpty
                  ? StepState.indexed
                  : StepState.complete,
              content: _TeachersStep(setup: s),
            ),
            Step(
              title: Text(tr('Dersler')),
              subtitle: Text(tr('{n} ders ihtiyacı', {'n': s.lessons.length})),
              isActive: _step >= 3,
              state: s.lessons.isEmpty ? StepState.indexed : StepState.complete,
              content: _LessonsStep(setup: s),
            ),
            Step(
              title: Text(tr('Programı oluştur')),
              isActive: _step >= 4,
              content: _CreateStep(setup: s),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Ders saatleri
// ---------------------------------------------------------------------------

class _SlotsStep extends ConsumerStatefulWidget {
  const _SlotsStep({required this.setup});

  final TimetableSetup setup;

  @override
  ConsumerState<_SlotsStep> createState() => _SlotsStepState();
}

class _SlotsStepState extends ConsumerState<_SlotsStep> {
  late final Set<int> _days = widget.setup.slots.isEmpty
      ? {1, 2, 3, 4, 5, 6}
      : {for (final s in widget.setup.slots) s.day};
  late int _start = widget.setup.slots.isEmpty
      ? 9 * 60
      : widget.setup.slots.map((s) => s.start).reduce((a, b) => a < b ? a : b);
  int _lesson = 40;
  int _break = 10;
  late int _perDay = widget.setup.slots.isEmpty
      ? 6
      : gridShape(widget.setup.slots).$2;
  int _lunchAfter = 0;
  int _lunch = 40;

  List<TimeSlot> _build() {
    final out = <TimeSlot>[];
    for (final d in _days.toList()..sort()) {
      var t = _start;
      for (var k = 1; k <= _perDay; k++) {
        out.add(TimeSlot(id: '', day: d, seq: k, start: t, end: t + _lesson));
        t += _lesson + (k == _lunchAfter ? _lunch : _break);
      }
    }
    return out;
  }

  Widget _number(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> on,
  ) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        tooltip: tr('Azalt'),
        onPressed: value > min ? () => setState(() => on(value - 1)) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center)),
      IconButton(
        tooltip: tr('Artır'),
        onPressed: value < max ? () => setState(() => on(value + 1)) : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final preview = _build().where(
      (s) => s.day == (_days.isEmpty ? 1 : (_days.toList()..sort()).first),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Günler'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(dayShort(d)),
                selected: _days.contains(d),
                onSelected: (v) =>
                    setState(() => v ? _days.add(d) : _days.remove(d)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('İlk ders')),
          trailing: Text(formatClock(_start)),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: _start ~/ 60, minute: _start % 60),
            );
            if (t != null) setState(() => _start = t.hour * 60 + t.minute);
          },
        ),
        _number(tr('Günlük ders sayısı'), _perDay, 1, 14, (v) => _perDay = v),
        _number(tr('Ders süresi (dk)'), _lesson, 20, 120, (v) => _lesson = v),
        _number(tr('Teneffüs (dk)'), _break, 0, 60, (v) => _break = v),
        _number(
          tr('Öğle arası şu dersten sonra (0: yok)'),
          _lunchAfter,
          0,
          _perDay,
          (v) => _lunchAfter = v,
        ),
        if (_lunchAfter > 0)
          _number(tr('Öğle arası (dk)'), _lunch, 10, 120, (v) => _lunch = v),
        const SizedBox(height: 6),
        Text(
          preview.map(slotLabel).join('  ·  '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('save-slots'),
          onPressed: _days.isEmpty
              ? null
              : () => _guard(context, ref, () async {
                  await ref
                      .read(timetableRepositoryProvider)
                      .saveTimeSlots(_build());
                  if (context.mounted) {
                    showMessage(context, tr('Ders saatleri kaydedildi.'));
                  }
                }),
          icon: const Icon(Icons.save_rounded),
          label: Text(tr('Şablonu kaydet')),
        ),
        if (widget.setup.slots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr('Kaldırılan saatlerdeki dersler programlardan silinir.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Sınıflar ve derslikler
// ---------------------------------------------------------------------------

class _ClassesStep extends ConsumerWidget {
  const _ClassesStep({required this.setup});

  final TimetableSetup setup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = {for (final r in setup.rooms) r.id: r.name};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in setup.classrooms)
          Card(
            child: ListTile(
              title: Text(c.classroom.name),
              subtitle: Text(
                [
                  levelLabel(c.level),
                  fieldLabel(c.field),
                  if (c.classroom.homeRoomId != null)
                    rooms[c.classroom.homeRoomId] ?? '',
                  tr('{n} öğrenci', {'n': c.studentIds.length}),
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: tr('Sil'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(
                  context,
                  ref,
                  c.classroom.name,
                  () => ref
                      .read(timetableRepositoryProvider)
                      .deleteClassroom(c.classroom.id),
                ),
              ),
              onTap: () => _editClassroom(context, ref, setup, c),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _editClassroom(context, ref, setup, null),
          icon: const Icon(Icons.add),
          label: Text(tr('Sınıf ekle')),
        ),
        const SizedBox(height: 16),
        Text(
          tr('Derslikler (isteğe bağlı)'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in setup.rooms)
              InputChip(
                label: Text(
                  r.capacity == null ? r.name : '${r.name} (${r.capacity})',
                ),
                onPressed: () => _editRoom(context, ref, r),
                onDeleted: () => _confirmDelete(
                  context,
                  ref,
                  r.name,
                  () => ref.read(timetableRepositoryProvider).deleteRoom(r.id),
                ),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(tr('Derslik ekle')),
              onPressed: () => _editRoom(context, ref, null),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  String name,
  Future<void> Function() action,
) async {
  final ok = await showDialog<bool>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (c) => AlertDialog(
      title: Text(tr('{name} silinsin mi?', {'name': name})),
      content: Text(tr('Programlardaki ilgili dersler de silinir.')),
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
  if (ok == true && context.mounted) await _guard(context, ref, action);
}

Future<void> _editRoom(BuildContext context, WidgetRef ref, Room? room) async {
  final name = TextEditingController(text: room?.name ?? '');
  final cap = TextEditingController(text: room?.capacity?.toString() ?? '');
  final ok = await showDialog<bool>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (c) => AlertDialog(
      title: Text(room == null ? tr('Derslik ekle') : room.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: InputDecoration(labelText: tr('Derslik adı')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: cap,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr('Kapasite (isteğe bağlı)'),
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
          style: _inline,
          onPressed: () => Navigator.pop(c, true),
          child: Text(tr('Kaydet')),
        ),
      ],
    ),
  );
  final n = name.text.trim();
  final capacity = int.tryParse(cap.text.trim());
  name.dispose();
  cap.dispose();
  if (ok != true || n.isEmpty || !context.mounted) return;
  await _guard(
    context,
    ref,
    () => ref
        .read(timetableRepositoryProvider)
        .saveRoom(Room(id: room?.id ?? '', name: n, capacity: capacity)),
  );
}

Future<void> _editClassroom(
  BuildContext context,
  WidgetRef ref,
  TimetableSetup setup,
  ClassroomRecord? record,
) async {
  final students = await ref.read(studentSummariesProvider.future);
  if (!context.mounted) return;
  final result = await showDialog<_ClassroomForm>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (_) => _ClassroomDialog(
      setup: setup,
      record: record,
      students: [for (final s in students) (s.id, s.fullName)],
    ),
  );
  if (result == null || !context.mounted) return;
  await _guard(context, ref, () async {
    final repo = ref.read(timetableRepositoryProvider);
    final id = await repo.saveClassroom(
      Classroom(
        id: record?.classroom.id ?? '',
        name: result.name,
        homeRoomId: result.roomId,
      ),
      level: result.level,
      field: result.field,
      capacity: record?.capacity,
      active: record?.active ?? true,
    );
    await repo.setClassroomStudents(id, result.students.toList());
  });
}

class _ClassroomForm {
  const _ClassroomForm(
    this.name,
    this.level,
    this.field,
    this.roomId,
    this.students,
  );

  final String name;
  final String? level;
  final String? field;
  final String? roomId;
  final Set<String> students;
}

class _ClassroomDialog extends StatefulWidget {
  const _ClassroomDialog({
    required this.setup,
    required this.record,
    required this.students,
  });

  final TimetableSetup setup;
  final ClassroomRecord? record;
  final List<(String, String)> students;

  @override
  State<_ClassroomDialog> createState() => _ClassroomDialogState();
}

class _ClassroomDialogState extends State<_ClassroomDialog> {
  late final _name = TextEditingController(
    text: widget.record?.classroom.name ?? '',
  );
  late String? _level = widget.record?.level;
  late String? _field = widget.record?.field;
  late String? _room = widget.record?.classroom.homeRoomId;
  late final _students = {...?widget.record?.studentIds};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Başka sınıfa kayıtlı öğrenciler de seçilebilir (etüt grupları).
    return AlertDialog(
      title: Text(
        widget.record == null ? tr('Sınıf ekle') : tr('Sınıfı düzenle'),
      ),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              key: const ValueKey('classroom-name'),
              controller: _name,
              decoration: InputDecoration(
                labelText: tr('Sınıf adı'),
                hintText: tr('Örn. Sayısal-1'),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _level,
              decoration: InputDecoration(labelText: tr('Seviye')),
              items: [
                for (final l in [null, '9', '10', '11', '12', 'graduate'])
                  DropdownMenuItem(value: l, child: Text(levelLabel(l))),
              ],
              onChanged: (v) => setState(() => _level = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _field,
              decoration: InputDecoration(labelText: tr('Alan')),
              items: [
                for (final f in [null, 'SAY', 'EA', 'SOZ', 'DIL'])
                  DropdownMenuItem(value: f, child: Text(fieldLabel(f))),
              ],
              onChanged: (v) => setState(() => _field = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _room,
              decoration: InputDecoration(labelText: tr('Sınıfın dersliği')),
              items: [
                DropdownMenuItem(value: null, child: Text(tr('Yok'))),
                for (final r in widget.setup.rooms)
                  DropdownMenuItem(value: r.id, child: Text(r.name)),
              ],
              onChanged: (v) => setState(() => _room = v),
            ),
            const SizedBox(height: 12),
            Text(
              tr('Öğrenciler ({n})', {'n': _students.length}),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              tr('Öğrenciler ve velileri programı uygulamada görür.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final (id, name) in widget.students)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _students.contains(id),
                title: Text(name),
                onChanged: (v) => setState(
                  () => v == true ? _students.add(id) : _students.remove(id),
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
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty) {
              showMessage(context, tr('Sınıf adını yaz.'));
              return;
            }
            Navigator.pop(
              context,
              _ClassroomForm(n, _level, _field, _room, _students),
            );
          },
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Öğretmenler
// ---------------------------------------------------------------------------

class _TeachersStep extends ConsumerWidget {
  const _TeachersStep({required this.setup});

  final TimetableSetup setup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (setup.slots.isEmpty)
          Text(tr('Müsaitlik için önce ders saatlerini kaydet.')),
        for (final t in setup.teachers)
          Card(
            child: ListTile(
              title: Text(t.teacher.name),
              subtitle: Text(
                [
                  t.teacher.branches.join(', '),
                  tr('en çok {n} saat', {'n': t.teacher.maxWeeklyHours}),
                  t.teacher.availability.isEmpty
                      ? tr('her saat müsait')
                      : tr('{n} saat müsait', {
                          'n': setup.slots
                              .where((s) => t.teacher.availableAt(s))
                              .length,
                        }),
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: tr('Sil'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(
                  context,
                  ref,
                  t.teacher.name,
                  () => ref
                      .read(timetableRepositoryProvider)
                      .deleteTeacher(t.teacher.id),
                ),
              ),
              onTap: () => _openTeacher(context, ref, setup, t),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _openTeacher(context, ref, setup, null),
          icon: const Icon(Icons.add),
          label: Text(tr('Öğretmen ekle')),
        ),
      ],
    );
  }
}

Future<void> _openTeacher(
  BuildContext context,
  WidgetRef ref,
  TimetableSetup setup,
  TeacherRecord? record,
) async {
  final members = await ref
      .read(orgMembersProvider.future)
      .catchError((_) => <OrgMember>[]);
  if (!context.mounted) return;
  final saved = await Navigator.of(context).push<(Teacher, String?)>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TeacherEditorScreen(
        slots: setup.slots,
        record: record,
        accounts: [
          for (final m in members)
            if (m.role == UserRole.coach || m.role == UserRole.admin)
              (m.id, m.fullName),
        ],
      ),
    ),
  );
  if (saved == null || !context.mounted) return;
  await _guard(
    context,
    ref,
    () => ref
        .read(timetableRepositoryProvider)
        .saveTeacher(saved.$1, profileId: saved.$2),
  );
}

/// Öğretmen: ad, branşlar, haftalık üst sınır, uygulama hesabı ve haftalık
/// ızgaradan müsait saatler. (Öğretmen, profil) döner.
class TeacherEditorScreen extends StatefulWidget {
  const TeacherEditorScreen({
    super.key,
    required this.slots,
    required this.record,
    required this.accounts,
  });

  final List<TimeSlot> slots;
  final TeacherRecord? record;

  /// Bağlanabilecek koç / müdür hesapları (kimlik, ad).
  final List<(String, String)> accounts;

  @override
  State<TeacherEditorScreen> createState() => _TeacherEditorScreenState();
}

class _TeacherEditorScreenState extends State<TeacherEditorScreen> {
  late final _name = TextEditingController(
    text: widget.record?.teacher.name ?? '',
  );
  late final _custom = TextEditingController();
  late final Set<String> _branches = {...?widget.record?.teacher.branches};
  late int _max = widget.record?.teacher.maxWeeklyHours ?? 30;
  late String? _profile = widget.record?.profileId;

  /// Müsait saatler (kimlik). Hepsi seçiliyse "her saat müsait" kaydedilir.
  late final Set<String> _available = {
    for (final s in widget.slots)
      if (widget.record?.teacher.availableAt(s) ?? true) s.id,
  };

  @override
  void dispose() {
    _name.dispose();
    _custom.dispose();
    super.dispose();
  }

  /// Seçili ardışık saatleri gün içinde aralıklara birleştirir.
  List<AvailabilityRange> _ranges() {
    if (_available.length == widget.slots.length) return const [];
    final out = <AvailabilityRange>[];
    final (days, _) = gridShape(widget.slots);
    for (final d in days) {
      final list = widget.slots.where((s) => s.day == d).toList()
        ..sort((a, b) => a.seq.compareTo(b.seq));
      int? start;
      int? end;
      for (final s in list) {
        if (_available.contains(s.id)) {
          start ??= s.start;
          end = s.end;
        } else if (start != null) {
          out.add(AvailabilityRange(day: d, start: start, end: end!));
          start = null;
        }
      }
      if (start != null) {
        out.add(AvailabilityRange(day: d, start: start, end: end!));
      }
    }
    // Hiç seçili saat yoksa öğretmen hiç müsait değil: hiçbir ders saatini
    // kapsamayan 1 dakikalık aralık (boş liste "her saat müsait" demek).
    if (out.isEmpty) out.add(const AvailabilityRange(day: 7, start: 0, end: 1));
    return out;
  }

  void _save() {
    final n = _name.text.trim();
    if (n.isEmpty || _branches.isEmpty) {
      showMessage(context, tr('Ad ve en az bir branş gerekli.'));
      return;
    }
    Navigator.pop(context, (
      Teacher(
        id: widget.record?.teacher.id ?? '',
        name: n,
        branches: _branches,
        maxWeeklyHours: _max,
        availability: _ranges(),
      ),
      _profile,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final (days, maxSeq) = gridShape(widget.slots);
    final text = Theme.of(context).textTheme;
    final branchOptions = {...commonBranches, ..._branches}.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.record == null ? tr('Öğretmen ekle') : tr('Öğretmeni düzenle'),
        ),
        actions: [
          TextButton(
            key: const ValueKey('teacher-save'),
            onPressed: _save,
            child: Text(tr('Kaydet')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('teacher-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: tr('Ad soyad')),
          ),
          const SizedBox(height: 14),
          Text(tr('Branşlar'), style: text.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in branchOptions)
                FilterChip(
                  label: Text(b),
                  selected: _branches.contains(b),
                  onSelected: (v) => setState(
                    () => v ? _branches.add(b) : _branches.remove(b),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  decoration: InputDecoration(hintText: tr('Başka branş')),
                ),
              ),
              IconButton(
                tooltip: tr('Branş ekle'),
                icon: const Icon(Icons.add),
                onPressed: () {
                  final b = _custom.text.trim();
                  if (b.isEmpty) return;
                  setState(() {
                    _branches.add(b);
                    _custom.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(tr('Haftalık en çok ders saati'))),
              IconButton(
                tooltip: tr('Azalt'),
                onPressed: _max > 1 ? () => setState(() => _max--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_max'),
              IconButton(
                tooltip: tr('Artır'),
                onPressed: _max < 80 ? () => setState(() => _max++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          DropdownButtonFormField<String?>(
            initialValue: widget.accounts.any((a) => a.$1 == _profile)
                ? _profile
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tr('Uygulama hesabı (isteğe bağlı)'),
              helperText: tr(
                'Bağlanırsa öğretmen programını kendi panelinde görür.',
              ),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(tr('Bağlı değil'))),
              for (final (id, name) in widget.accounts)
                DropdownMenuItem(value: id, child: Text(name)),
            ],
            onChanged: (v) => setState(() => _profile = v),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(tr('Müsait saatler'), style: text.titleSmall),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _available
                    ..clear()
                    ..addAll(widget.slots.map((s) => s.id)),
                ),
                child: Text(tr('Hepsi')),
              ),
              TextButton(
                onPressed: () => setState(_available.clear),
                child: Text(tr('Hiçbiri')),
              ),
            ],
          ),
          Text(
            tr('Dokunarak işaretle: yeşil müsait, gri değil.'),
            style: text.bodySmall,
          ),
          const SizedBox(height: 8),
          if (widget.slots.isEmpty)
            Text(tr('Önce ders saatlerini kaydet.'))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(52),
                columnWidths: const {0: FixedColumnWidth(56)},
                children: [
                  TableRow(
                    children: [
                      const SizedBox.shrink(),
                      for (final d in days)
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            dayShort(d),
                            textAlign: TextAlign.center,
                            style: text.labelMedium,
                          ),
                        ),
                    ],
                  ),
                  for (var seq = 1; seq <= maxSeq; seq++)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            rowLabel(widget.slots, seq),
                            style: text.labelSmall,
                          ),
                        ),
                        for (final d in days)
                          _AvailCell(
                            slot: widget.slots
                                .where((s) => s.day == d && s.seq == seq)
                                .firstOrNull,
                            selected: _available,
                            onToggle: (id) => setState(
                              () => _available.contains(id)
                                  ? _available.remove(id)
                                  : _available.add(id),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AvailCell extends StatelessWidget {
  const _AvailCell({
    required this.slot,
    required this.selected,
    required this.onToggle,
  });

  final TimeSlot? slot;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = slot;
    if (s == null) return const SizedBox(height: 44);
    final on = selected.contains(s.id);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: true,
        selected: on,
        label: '${dayLong(s.day)} ${slotLabel(s)}',
        child: Material(
          color: on
              ? const Color(0xFF2EA37A).withValues(alpha: 0.85)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: ValueKey('avail-${s.id}'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => onToggle(s.id),
            child: SizedBox(
              height: 40,
              child: Icon(
                on ? Icons.check_rounded : Icons.close_rounded,
                size: 18,
                color: on ? Colors.white : scheme.outline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Dersler
// ---------------------------------------------------------------------------

class _LessonsStep extends ConsumerWidget {
  const _LessonsStep({required this.setup});

  final TimetableSetup setup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachers = {
      for (final t in setup.teachers) t.teacher.id: t.teacher.name,
    };
    if (setup.classrooms.isEmpty) return Text(tr('Önce sınıf ekle.'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in setup.classrooms)
          Builder(
            builder: (context) {
              final lessons = [
                for (final l in setup.lessons)
                  if (l.classroomId == c.classroom.id) l,
              ];
              final total = lessons.fold<int>(0, (s, l) => s + l.weeklyHours);
              final over = total > setup.slots.length;
              return Card(
                child: ExpansionTile(
                  title: Text(c.classroom.name),
                  subtitle: Text(
                    tr('Haftada {n} / {max} saat', {
                      'n': total,
                      'max': setup.slots.length,
                    }),
                    style: over
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null,
                  ),
                  children: [
                    for (final (i, l) in lessons.indexed)
                      ListTile(
                        leading: CircleAvatar(
                          radius: 6,
                          backgroundColor: branchColor(l.branch),
                        ),
                        title: Text(
                          tr('{branch} · {n} saat', {
                            'branch': l.branch,
                            'n': l.weeklyHours,
                          }),
                        ),
                        subtitle: Text(
                          [
                            l.teacherId == null
                                ? tr('Öğretmen otomatik seçilir')
                                : teachers[l.teacherId] ?? '',
                            tr('günde en çok {n}', {'n': l.maxPerDay}),
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          tooltip: tr('Sil'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _guard(
                            context,
                            ref,
                            () => ref
                                .read(timetableRepositoryProvider)
                                .saveLessons(c.classroom.id, [
                                  ...lessons.take(i),
                                  ...lessons.skip(i + 1),
                                ]),
                          ),
                        ),
                        onTap: () =>
                            _editLesson(context, ref, setup, c, lessons, i),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _editLesson(context, ref, setup, c, lessons, null),
                        icon: const Icon(Icons.add),
                        label: Text(tr('Ders ekle')),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

Future<void> _editLesson(
  BuildContext context,
  WidgetRef ref,
  TimetableSetup setup,
  ClassroomRecord c,
  List<ClassLesson> lessons,
  int? index,
) async {
  final current = index == null ? null : lessons[index];
  final result = await showDialog<ClassLesson>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (_) => _LessonDialog(
      setup: setup,
      classroomId: c.classroom.id,
      lesson: current,
      taken: {
        for (final (i, l) in lessons.indexed)
          if (i != index) l.branch,
      },
    ),
  );
  if (result == null || !context.mounted) return;
  final next = [...lessons];
  index == null ? next.add(result) : next[index] = result;
  await _guard(
    context,
    ref,
    () =>
        ref.read(timetableRepositoryProvider).saveLessons(c.classroom.id, next),
  );
}

class _LessonDialog extends StatefulWidget {
  const _LessonDialog({
    required this.setup,
    required this.classroomId,
    required this.lesson,
    required this.taken,
  });

  final TimetableSetup setup;
  final String classroomId;
  final ClassLesson? lesson;

  /// Sınıfta zaten olan branşlar (aynı branş iki kez eklenmez).
  final Set<String> taken;

  @override
  State<_LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<_LessonDialog> {
  late String? _branch = widget.lesson?.branch;
  late int _hours = widget.lesson?.weeklyHours ?? 2;
  late String? _teacher = widget.lesson?.teacherId;
  late int _maxPerDay = widget.lesson?.maxPerDay ?? 2;

  @override
  Widget build(BuildContext context) {
    final branches = {
      ...commonBranches,
      for (final t in widget.setup.teachers) ...t.teacher.branches,
    }.where((b) => !widget.taken.contains(b)).toList();
    final teachers = [
      for (final t in widget.setup.teachers)
        if (_branch != null && t.teacher.branches.contains(_branch)) t.teacher,
    ];
    Widget counter(
      String label,
      int v,
      int min,
      int max,
      ValueChanged<int> on,
    ) => Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: tr('Azalt'),
          onPressed: v > min ? () => setState(() => on(v - 1)) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$v'),
        IconButton(
          tooltip: tr('Artır'),
          onPressed: v < max ? () => setState(() => on(v + 1)) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
    return AlertDialog(
      title: Text(
        widget.lesson == null ? tr('Ders ekle') : tr('Dersi düzenle'),
      ),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('lesson-branch'),
              initialValue: _branch,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Branş')),
              items: [
                for (final b in branches)
                  DropdownMenuItem(value: b, child: Text(b)),
              ],
              onChanged: (v) => setState(() {
                _branch = v;
                _teacher = null;
              }),
            ),
            const SizedBox(height: 6),
            counter(
              tr('Haftalık ders saati'),
              _hours,
              1,
              40,
              (v) => _hours = v,
            ),
            counter(
              tr('Günde en çok'),
              _maxPerDay,
              1,
              10,
              (v) => _maxPerDay = v,
            ),
            DropdownButtonFormField<String?>(
              initialValue: teachers.any((t) => t.id == _teacher)
                  ? _teacher
                  : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Öğretmen')),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(tr('Otomatik seç (branşı tutan)')),
                ),
                for (final t in teachers)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => _teacher = v),
            ),
            if (_branch != null && teachers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr('Bu branşa giren öğretmen yok; önce öğretmen ekle.'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          onPressed: _branch == null
              ? null
              : () => Navigator.pop(
                  context,
                  ClassLesson(
                    id: widget.lesson?.id ?? '',
                    classroomId: widget.classroomId,
                    branch: _branch!,
                    weeklyHours: _hours,
                    teacherId: _teacher,
                    maxPerDay: _maxPerDay,
                  ),
                ),
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Oluştur
// ---------------------------------------------------------------------------

class _CreateStep extends ConsumerStatefulWidget {
  const _CreateStep({required this.setup});

  final TimetableSetup setup;

  @override
  ConsumerState<_CreateStep> createState() => _CreateStepState();
}

class _CreateStepState extends ConsumerState<_CreateStep> {
  final _name = TextEditingController(text: tr('Haftalık program'));
  final _term = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _term.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(timetableRepositoryProvider)
          .createSchedule(
            name,
            term: _term.text.trim().isEmpty ? null : _term.text.trim(),
          );
      ref.invalidate(schedulesProvider);
      if (!mounted) return;
      context.pushReplacement('/admin/schedule/$id?generate=1');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.setup;
    final hours = s.lessons.fold<int>(0, (a, l) => a + l.weeklyHours);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            '{c} sınıf, {t} öğretmen, haftada toplam {h} saat ders, {s} ders saati.',
            {
              'c': s.classrooms.length,
              't': s.teachers.length,
              'h': hours,
              's': s.slots.length,
            },
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: tr('Program adı')),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _term,
          decoration: InputDecoration(
            labelText: tr('Dönem (isteğe bağlı)'),
            hintText: '2026-2027 Güz',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('create-schedule'),
          onPressed: s.isEmpty || _busy ? null : _create,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(tr('Programı oluştur')),
        ),
        if (s.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr('Ders saati, sınıf, öğretmen ve ders gerekli.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
