import '../../../shared/widgets/tool_tile.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../admin/data/admin_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/data/profile.dart';
import '../../finance/data/finance_repository.dart'
    show formatPhone, normalizePhone;
import '../../schedule_generator/data/timetable_repository.dart';
import '../../student_registration/data/registration_repository.dart';
import '../data/student_management_repository.dart';
import 'classes_screen.dart';
import '../../../core/design/motion.dart';

/// Öğrenci yönetimi (müdür: kurum, koç: kendi öğrencileri). Sekmeler:
/// sınıfı olmayanlar, tümü, şüpheli numaralar (serbest kayıtta ya da
/// işaretli varsa), henüz kayıt olmayanlar (müdür, liste modunda).
class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key, required this.basePath});

  final String basePath;

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  String _query = '';
  String? _classFilter;
  String? _coachFilter;
  final _selected = <String>{};

  bool get _admin => widget.basePath == '/admin';

  List<ManagedStudent> _filter(List<ManagedStudent> list) {
    final q = _query.trim().toLowerCase();
    return [
      for (final s in list)
        if ((q.isEmpty ||
                s.fullName.toLowerCase().contains(q) ||
                (s.studentNumber ?? '').contains(q)) &&
            (_classFilter == null || s.classroomId == _classFilter) &&
            (_coachFilter == null || s.coachId == _coachFilter))
          s,
    ];
  }

  Future<void> _assignSelected() async {
    final setup = await ref.read(timetableSetupProvider.future);
    if (!mounted) return;
    final target = await pickClassroom(
      context,
      setup,
      title: tr('{n} öğrenci hangi sınıfa?', {'n': _selected.length}),
      allowNone: true,
    );
    if (target == null || !mounted) return;
    try {
      await ref
          .read(studentManagementRepositoryProvider)
          .assignToClass(_selected.toList(), target.isEmpty ? null : target);
      ref.invalidate(managedStudentsProvider);
      ref.invalidate(timetableSetupProvider);
      if (!mounted) return;
      showMessage(
        context,
        tr('{n} öğrencinin sınıfı güncellendi.', {'n': _selected.length}),
      );
      setState(_selected.clear);
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(managedStudentsProvider);
    final setup = ref.watch(timetableSetupProvider);
    final mode = ref.watch(registrationModeProvider).value;
    final expected = _admin && mode == RegistrationMode.list
        ? ref.watch(expectedStudentsProvider).value
        : null;

    return AsyncView(
      value: students,
      onRetry: () => ref.invalidate(managedStudentsProvider),
      builder: (all) {
        final classes = setup.value?.classrooms ?? const <ClassroomRecord>[];
        final unassigned = [
          for (final s in all)
            if (!s.hasClass) s,
        ];
        final suspicious = suspiciousStudents(all);
        final showSuspicious =
            mode == RegistrationMode.free || all.any((s) => s.flag != null);
        final pending = [
          for (final e in expected ?? const <ExpectedStudent>[])
            if (!e.matched) e,
        ];
        final tabs = <(String, Widget)>[
          (
            tr('Sınıfı olmayanlar ({n})', {'n': unassigned.length}),
            _list(_filter(unassigned), classes, selectable: true),
          ),
          (
            tr('Tüm öğrenciler ({n})', {'n': all.length}),
            _list(_filter(all), classes, selectable: true),
          ),
          if (showSuspicious)
            (
              tr('Şüpheli numaralar ({n})', {'n': suspicious.length}),
              _suspiciousList(suspicious),
            ),
          if (expected != null)
            (
              tr('Henüz kayıt olmayanlar ({n})', {'n': pending.length}),
              _pendingList(pending),
            ),
        ];
        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr('Öğrenciler')),
              actions: [
                IconButton(
                  tooltip: tr('Sınıflar'),
                  icon: const Icon(Icons.meeting_room_outlined),
                  onPressed: () => context.push('${widget.basePath}/classes'),
                ),
                if (_admin)
                  IconButton(
                    key: const ValueKey('registration-settings'),
                    tooltip: tr('Kayıt ayarları'),
                    icon: const Icon(Icons.how_to_reg_outlined),
                    onPressed: () => context.push('/admin/registration'),
                  ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                onTap: (_) => setState(_selected.clear),
                tabs: [for (final t in tabs) Tab(text: t.$1)],
              ),
            ),
            bottomNavigationBar: _selected.isEmpty
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FilledButton.icon(
                        key: const ValueKey('assign-selected'),
                        onPressed: _assignSelected,
                        icon: const Icon(Icons.drive_file_move_outline),
                        label: Text(
                          tr('Seçilenleri sınıfa ata ({n})', {
                            'n': _selected.length,
                          }),
                        ),
                      ),
                    ),
                  ),
            body: classes.isEmpty && setup.hasValue
                ? EmptyClassesState(admin: _admin, basePath: widget.basePath)
                : Column(
                    children: [
                      _Filters(
                        classes: classes,
                        coaches: {
                          for (final s in all)
                            if (s.coachId != null)
                              s.coachId!: s.coachName ?? '',
                        },
                        classFilter: _classFilter,
                        coachFilter: _coachFilter,
                        showCoach: _admin,
                        onQuery: (v) => setState(() => _query = v),
                        onClass: (v) => setState(() => _classFilter = v),
                        onCoach: (v) => setState(() => _coachFilter = v),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(managedStudentsProvider);
                            ref.invalidate(timetableSetupProvider);
                            ref.invalidate(expectedStudentsProvider);
                          },
                          child: TabBarView(
                            children: [for (final t in tabs) t.$2],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _list(
    List<ManagedStudent> list,
    List<ClassroomRecord> classes, {
    bool selectable = false,
  }) {
    if (list.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(tr('Öğrenci yok.'), textAlign: TextAlign.center),
          ),
        ],
      );
    }
    final allSelected = list.every((s) => _selected.contains(s.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      children: [
        if (selectable)
          CheckboxListTile(
            key: const ValueKey('select-all'),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(tr('Hepsini seç')),
            value: allSelected,
            onChanged: (v) => setState(
              () => v == true
                  ? _selected.addAll(list.map((s) => s.id))
                  : _selected.removeAll(list.map((s) => s.id)),
            ),
          ),
        for (final s in list)
          StudentRow(
            student: s,
            selected: selectable ? _selected.contains(s.id) : null,
            onSelected: (v) => setState(
              () => v ? _selected.add(s.id) : _selected.remove(s.id),
            ),
            onTap: () => openStudentEditor(context, ref, s, widget.basePath),
          ),
      ],
    );
  }

  Widget _suspiciousList(List<SuspiciousStudent> list) => list.isEmpty
      ? ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                tr('Şüpheli numara yok.'),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        )
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final x = list[i];
            return StudentRow(
              student: x.student,
              reasons: x.reasons,
              onTap: () =>
                  openStudentEditor(context, ref, x.student, widget.basePath),
            );
          },
        );

  Widget _pendingList(List<ExpectedStudent> list) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
    children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          tr(
            'Kurum listesinde olup uygulamaya henüz kayıt olmayan öğrenciler.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      for (final e in list)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.hourglass_empty_rounded),
            title: Text(e.fullName),
            subtitle: Text(
              [e.number, if (e.className != null) e.className!].join(' · '),
            ),
          ),
        ),
    ],
  );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.classes,
    required this.coaches,
    required this.classFilter,
    required this.coachFilter,
    required this.showCoach,
    required this.onQuery,
    required this.onClass,
    required this.onCoach,
  });

  final List<ClassroomRecord> classes;
  final Map<String, String> coaches;
  final String? classFilter;
  final String? coachFilter;
  final bool showCoach;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onClass;
  final ValueChanged<String?> onCoach;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: Column(
      children: [
        TextField(
          key: const ValueKey('student-search'),
          decoration: InputDecoration(
            hintText: tr('Ad soyad veya öğrenci no ara'),
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
          onChanged: onQuery,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: classFilter,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('Sınıf'),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(tr('Hepsi'))),
                  for (final c in classes)
                    DropdownMenuItem(
                      value: c.classroom.id,
                      child: Text(c.classroom.name),
                    ),
                ],
                onChanged: onClass,
              ),
            ),
            if (showCoach) ...[
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: coachFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr('Koç'),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr('Hepsi'))),
                    for (final e in coaches.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: onCoach,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

/// Öğrenci satırı: ad, numara, sınıf (yoksa "Atanmadı"), şüpheli rozeti.
class StudentRow extends StatelessWidget {
  const StudentRow({
    super.key,
    required this.student,
    required this.onTap,
    this.selected,
    this.onSelected,
    this.reasons,
    this.trailing,
  });

  final ManagedStudent student;
  final VoidCallback onTap;

  /// null: seçim kutusu yok.
  final bool? selected;
  final ValueChanged<bool>? onSelected;
  final List<String>? reasons;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget badge(String label, Color bg, Color fg) => Container(
      margin: const EdgeInsets.only(right: 6, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: text.labelSmall?.copyWith(color: fg)),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: ValueKey('student-${student.id}'),
        onTap: onTap,
        leading: selected == null
            ? null
            : Checkbox(
                key: ValueKey('check-${student.id}'),
                value: selected,
                onChanged: (v) => onSelected?.call(v ?? false),
              ),
        title: Text(student.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                student.studentNumber == null
                    ? tr('Numarası yok')
                    : tr('No {n}', {'n': student.studentNumber!}),
                if (student.coachName != null) student.coachName!,
              ].join(' · '),
            ),
            Wrap(
              children: [
                if (student.classroomName != null)
                  badge(
                    student.classroomName!,
                    scheme.secondaryContainer,
                    scheme.onSecondaryContainer,
                  )
                else
                  badge(
                    tr('Atanmadı'),
                    scheme.surfaceContainerHighest,
                    scheme.onSurfaceVariant,
                  ),
                if (student.flag != null)
                  badge(
                    tr('Şüpheli'),
                    scheme.errorContainer,
                    scheme.onErrorContainer,
                  ),
              ],
            ),
            for (final r in reasons ?? const <String>[])
              Text(
                '• $r',
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
          ],
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Öğrenci düzenleme: numara (anlık benzersizlik), sınıf, koç (müdür),
/// şüpheli işaretini kaldırma.
Future<void> openStudentEditor(
  BuildContext context,
  WidgetRef ref,
  ManagedStudent student,
  String basePath,
) async {
  final setup = await ref.read(timetableSetupProvider.future);
  List<(String, String)> coaches = const [];
  if (basePath == '/admin') {
    final members = await ref
        .read(orgMembersProvider.future)
        .catchError((_) => <OrgMember>[]);
    coaches = [
      for (final m in members)
        if (m.role == UserRole.coach) (m.id, m.fullName),
    ];
  }
  if (!context.mounted) return;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    sheetAnimationStyle: AppMotion.overlayStyle(context),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _StudentEditor(
      student: student,
      classes: [
        for (final c in setup.classrooms)
          if (c.active || c.classroom.id == student.classroomId)
            (c.classroom.id, c.classroom.name),
      ],
      coaches: coaches,
    ),
  );
  if (saved == true) {
    ref.invalidate(managedStudentsProvider);
    ref.invalidate(timetableSetupProvider);
  }
}

class _StudentEditor extends ConsumerStatefulWidget {
  const _StudentEditor({
    required this.student,
    required this.classes,
    required this.coaches,
  });

  final ManagedStudent student;
  final List<(String, String)> classes;
  final List<(String, String)> coaches;

  @override
  ConsumerState<_StudentEditor> createState() => _StudentEditorState();
}

class _StudentEditorState extends ConsumerState<_StudentEditor> {
  late final _number = TextEditingController(
    text: widget.student.studentNumber ?? '',
  );
  late String? _class = widget.student.classroomId;
  late String? _coach = widget.student.coachId;
  bool? _available;
  bool _saving = false;
  Timer? _debounce;
  final _guardianName = TextEditingController();
  final _guardianPhone = TextEditingController();

  /// Kayıtlı veli (yüklenince); değişmediyse kaydedilmez.
  (String?, String)? _guardian;
  bool _guardianLoaded = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(guardianProvider(widget.student.id).future)
        .then((g) {
          if (!mounted) return;
          setState(() {
            _guardian = g;
            _guardianLoaded = true;
            _guardianName.text = g?.$1 ?? '';
            _guardianPhone.text = g == null ? '' : formatPhone(g.$2);
          });
        })
        .catchError((Object _) {
          // Okunamazsa veli alanı gösterilmez; diğer alanlar kaydedilir.
        });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _number.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    super.dispose();
  }

  void _onNumber(String v) {
    _debounce?.cancel();
    final n = v.trim();
    if (n.isEmpty ||
        n == widget.student.studentNumber ||
        !isValidStudentNumber(n)) {
      setState(() => _available = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final ok = await ref
            .read(studentManagementRepositoryProvider)
            .isNumberAvailable(widget.student.id, n);
        if (mounted && _number.text.trim() == n) {
          setState(() => _available = ok);
        }
      } catch (_) {}
    });
  }

  Future<void> _save() async {
    final repo = ref.read(studentManagementRepositoryProvider);
    final s = widget.student;
    final n = _number.text.trim();
    if (n.isNotEmpty && !isValidStudentNumber(n)) {
      showMessage(
        context,
        tr('Öğrenci numarası yalnızca rakamlardan oluşmalı.'),
      );
      return;
    }
    final pt = _guardianPhone.text.trim();
    final phone = pt.isEmpty ? null : normalizePhone(pt);
    if (_guardianLoaded && pt.isNotEmpty && phone == null) {
      showMessage(context, tr('Cep telefonunu 05XX XXX XX XX biçiminde yaz.'));
      return;
    }
    final gName = _guardianName.text.trim().isEmpty
        ? null
        : _guardianName.text.trim();
    final guardianChanged =
        _guardianLoaded &&
        (phone != _guardian?.$2 || (phone != null && gName != _guardian?.$1));
    setState(() => _saving = true);
    try {
      if (guardianChanged) {
        await ref
            .read(attendanceRepositoryProvider)
            .setGuardianPhone(s.id, name: gName, phone: phone);
        ref.invalidate(guardianProvider(s.id));
      }
      if (n != (s.studentNumber ?? '')) {
        await repo.setStudentNumber(s.id, n.isEmpty ? null : n);
      }
      if (_class != s.classroomId) {
        await repo.assignToClass([s.id], _class);
      }
      if (_coach != null && _coach != s.coachId) {
        await repo.setCoach(s.id, _coach!);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(
        context,
        '$e'.contains('NUMBER_TAKEN')
            ? tr('Bu numara zaten kullanımda.')
            : '$e'.contains('INVALID_NUMBER')
            ? tr('Öğrenci numarası yalnızca rakamlardan oluşmalı.')
            : tr('Kaydedilemedi. Tekrar dene.'),
      );
    }
  }

  Future<void> _clearFlag() async {
    try {
      await ref
          .read(studentManagementRepositoryProvider)
          .clearFlag(widget.student.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.fullName,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (s.flag != null) ...[
              const SizedBox(height: 8),
              Card(
                color: scheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.flag_rounded,
                    color: scheme.onErrorContainer,
                  ),
                  title: Text(
                    s.flag!.label,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  subtitle: s.attemptedNumber == null
                      ? null
                      : Text(
                          tr('Kayıtta girdiği numara: {n}', {
                            'n': s.attemptedNumber!,
                          }),
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                  trailing: TextButton(
                    key: const ValueKey('clear-flag'),
                    onPressed: _clearFlag,
                    child: Text(tr('İşareti kaldır')),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('edit-number'),
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: InputDecoration(
                labelText: tr('Öğrenci numarası'),
                helperText: _available == null
                    ? null
                    : _available!
                    ? tr('Numara kullanılabilir')
                    : tr('Bu numara zaten kullanımda.'),
                helperStyle: TextStyle(
                  color: _available == false ? scheme.error : null,
                ),
              ),
              onChanged: _onNumber,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              key: const ValueKey('edit-class'),
              initialValue: _class,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Sınıf')),
              items: [
                DropdownMenuItem(value: null, child: Text(tr('Atanmadı'))),
                for (final (id, name) in widget.classes)
                  DropdownMenuItem(value: id, child: Text(name)),
              ],
              onChanged: (v) => setState(() => _class = v),
            ),
            if (widget.coaches.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: widget.coaches.any((c) => c.$1 == _coach)
                    ? _coach
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Koç')),
                items: [
                  for (final (id, name) in widget.coaches)
                    DropdownMenuItem(value: id, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _coach = v),
              ),
            ],
            if (_guardianLoaded) ...[
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('edit-guardian-name'),
                controller: _guardianName,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: tr('Veli adı (isteğe bağlı)'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('edit-guardian-phone'),
                controller: _guardianPhone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: tr('Veli cep telefonu'),
                  hintText: '05XX XXX XX XX',
                  helperText: tr(
                    'Yoklama ve ödeme hatırlatma mesajları bu numaraya gider.',
                  ),
                  helperMaxLines: 2,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.history_rounded, size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr('Bu değişiklik kayıt altına alınacaktır.'),
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const ValueKey('student-save'),
              onPressed: _saving || _available == false ? null : _save,
              child: Text(tr('Kaydet')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Müdür / koç ana sayfası: sınıflar ve öğrenciler.
/// Sınıflar ve öğrenciler kısayolu.
ToolInfo studentsTool(WidgetRef ref, String basePath) {
  final list = ref.watch(managedStudentsProvider).value;
  final unassigned = list?.where((s) => !s.hasClass).length ?? 0;
  final flagged = list?.where((s) => s.flag != null).length ?? 0;
  return ToolInfo(
    id: 'students-home-card',
    icon: Icons.groups_rounded,
    title: tr('Sınıflar ve öğrenciler'),
    status: list == null
        ? tr('Sınıf ataması, öğrenci numarası, veli telefonu ve kayıtlar')
        : [
            tr('{n} öğrenci', {'n': list.length}),
            if (unassigned > 0) tr('{n} sınıfsız', {'n': unassigned}),
            if (flagged > 0) tr('{n} şüpheli', {'n': flagged}),
          ].join(' · '),
    needsAction: unassigned > 0 || flagged > 0,
    open: (context) => context.push('$basePath/roster'),
  );
}

class StudentsHomeCard extends ConsumerWidget {
  const StudentsHomeCard({super.key, required this.basePath});

  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ToolListCard(tool: studentsTool(ref, basePath));
}
