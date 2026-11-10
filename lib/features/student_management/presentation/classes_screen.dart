import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../../schedule_generator/domain/models.dart';
import '../../schedule_generator/presentation/timetable_format.dart';
import '../data/student_management_repository.dart';
import 'students_screen.dart';
import '../../../core/design/motion.dart';

final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

/// Sınıf listesi. Müdür ekler / düzenler / pasifleştirir / siler (boşsa);
/// koç görür ve sınıfa dokununca öğrencilerini yönetir.
class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key, required this.basePath});

  final String basePath;

  bool get _admin => basePath == '/admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(timetableSetupProvider);
    final students = ref.watch(managedStudentsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Sınıflar')),
        actions: [
          IconButton(
            tooltip: tr('Öğrenciler'),
            icon: const Icon(Icons.groups_rounded),
            onPressed: () => context.push('$basePath/roster'),
          ),
        ],
      ),
      floatingActionButton: _admin
          ? FloatingActionButton.extended(
              key: const ValueKey('add-class'),
              onPressed: () => editClassroom(context, ref, null),
              icon: const Icon(Icons.add),
              label: Text(tr('Sınıf ekle')),
            )
          : null,
      body: AsyncView(
        value: setup,
        onRetry: () => ref.invalidate(timetableSetupProvider),
        builder: (s) {
          if (s.classrooms.isEmpty) {
            return EmptyClassesState(admin: _admin, basePath: basePath);
          }
          final sorted = [...s.classrooms]
            ..sort((a, b) {
              if (a.active != b.active) return a.active ? -1 : 1;
              return a.classroom.name.compareTo(b.classroom.name);
            });
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(timetableSetupProvider);
              ref.invalidate(managedStudentsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                for (final c in sorted)
                  Builder(
                    builder: (context) {
                      final n = students
                          .where((x) => x.classroomId == c.classroom.id)
                          .length;
                      final full = c.capacity != null && n > c.capacity!;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          key: ValueKey('class-${c.classroom.id}'),
                          leading: Icon(
                            c.active
                                ? Icons.meeting_room_outlined
                                : Icons.do_not_disturb_on_outlined,
                          ),
                          title: Text(c.classroom.name),
                          subtitle: Text(
                            [
                              levelLabel(c.level),
                              fieldLabel(c.field),
                              c.capacity == null
                                  ? tr('{n} öğrenci', {'n': n})
                                  : tr('{n} / {max} öğrenci', {
                                      'n': n,
                                      'max': c.capacity!,
                                    }),
                              if (!c.active) tr('Pasif'),
                            ].join(' · '),
                            style: full
                                ? TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  )
                                : null,
                          ),
                          trailing: _admin
                              ? PopupMenuButton<String>(
                                  tooltip: tr('Diğer'),
                                  onSelected: (v) => switch (v) {
                                    'edit' => editClassroom(context, ref, c),
                                    'toggle' => _toggle(context, ref, c),
                                    _ => _delete(context, ref, c, n),
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(tr('Düzenle')),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        c.active
                                            ? tr('Pasifleştir')
                                            : tr('Etkinleştir'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(tr('Sil')),
                                    ),
                                  ],
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ClassDetailScreen(
                                classroomId: c.classroom.id,
                                basePath: basePath,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    ClassroomRecord c,
  ) async {
    try {
      await ref
          .read(timetableRepositoryProvider)
          .saveClassroom(
            c.classroom,
            level: c.level,
            field: c.field,
            capacity: c.capacity,
            active: !c.active,
          );
      ref.invalidate(timetableSetupProvider);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ClassroomRecord c,
    int students,
  ) async {
    if (students > 0) {
      // İçinde öğrenci olan sınıf silinemez: önce toplu taşıma.
      final moved = await moveAllStudents(context, ref, c);
      if (!moved || !context.mounted) return;
    }
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (d) => AlertDialog(
        title: Text(tr('{name} silinsin mi?', {'name': c.classroom.name})),
        content: Text(tr('Programlardaki ilgili dersler de silinir.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            style: _inline,
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Sil')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(timetableRepositoryProvider)
          .deleteClassroom(c.classroom.id);
      ref.invalidate(timetableSetupProvider);
    } catch (e) {
      if (!context.mounted) return;
      showMessage(
        context,
        '$e'.contains('CLASSROOM_NOT_EMPTY')
            ? tr('Sınıfta öğrenci var; önce öğrencileri başka sınıfa taşı.')
            : tr('Kaydedilemedi. Tekrar dene.'),
      );
    }
  }
}

/// Sınıf yokken: "Önce sınıf oluşturmalısınız".
class EmptyClassesState extends StatelessWidget {
  const EmptyClassesState({
    super.key,
    required this.admin,
    required this.basePath,
  });

  final bool admin;
  final String basePath;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 32),
      Icon(
        Icons.meeting_room_outlined,
        size: 56,
        color: Theme.of(context).colorScheme.outline,
      ),
      const SizedBox(height: 12),
      Text(
        tr('Önce sınıf oluşturmalısınız'),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        admin
            ? tr('Öğrencileri atamak için önce sınıflarını oluştur.')
            : tr(
                'Kurum müdürü sınıfları oluşturunca öğrencilerini atayabilirsin.',
              ),
        textAlign: TextAlign.center,
      ),
      if (admin) ...[
        const SizedBox(height: 16),
        Center(
          child: Consumer(
            builder: (context, ref, _) => FilledButton.icon(
              key: const ValueKey('empty-add-class'),
              style: _inline,
              onPressed: () => editClassroom(context, ref, null),
              icon: const Icon(Icons.add),
              label: Text(tr('Sınıf oluştur')),
            ),
          ),
        ),
      ],
    ],
  );
}

/// Sınıf ekle / düzenle (müdür).
Future<void> editClassroom(
  BuildContext context,
  WidgetRef ref,
  ClassroomRecord? record,
) async {
  final setup = await ref.read(timetableSetupProvider.future);
  if (!context.mounted) return;
  final result = await showDialog<ClassroomRecord>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (_) => _ClassDialog(record: record, rooms: setup.rooms),
  );
  if (result == null || !context.mounted) return;
  try {
    await ref
        .read(timetableRepositoryProvider)
        .saveClassroom(
          result.classroom,
          level: result.level,
          field: result.field,
          capacity: result.capacity,
          active: result.active,
        );
    ref.invalidate(timetableSetupProvider);
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }
}

class _ClassDialog extends StatefulWidget {
  const _ClassDialog({required this.record, required this.rooms});

  final ClassroomRecord? record;
  final List<Room> rooms;

  @override
  State<_ClassDialog> createState() => _ClassDialogState();
}

class _ClassDialogState extends State<_ClassDialog> {
  late final _name = TextEditingController(
    text: widget.record?.classroom.name ?? '',
  );
  late final _capacity = TextEditingController(
    text: widget.record?.capacity?.toString() ?? '',
  );
  late String? _level = widget.record?.level;
  late String? _field = widget.record?.field;
  late String? _room = widget.record?.classroom.homeRoomId;
  late bool _active = widget.record?.active ?? true;

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.record == null ? tr('Sınıf ekle') : tr('Sınıfı düzenle'),
    ),
    content: SizedBox(
      width: 420,
      child: ListView(
        shrinkWrap: true,
        children: [
          TextField(
            key: const ValueKey('class-name'),
            controller: _name,
            autofocus: widget.record == null,
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
          TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr('Kapasite (isteğe bağlı)'),
            ),
          ),
          if (widget.rooms.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _room,
              decoration: InputDecoration(labelText: tr('Sınıfın dersliği')),
              items: [
                DropdownMenuItem(value: null, child: Text(tr('Yok'))),
                for (final r in widget.rooms)
                  DropdownMenuItem(value: r.id, child: Text(r.name)),
              ],
              onChanged: (v) => setState(() => _room = v),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Aktif')),
            subtitle: Text(tr('Pasif sınıfa öğrenci atanamaz.')),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
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
        key: const ValueKey('class-save'),
        style: _inline,
        onPressed: () {
          final n = _name.text.trim();
          if (n.isEmpty) {
            showMessage(context, tr('Sınıf adını yaz.'));
            return;
          }
          final cap = int.tryParse(_capacity.text.trim());
          Navigator.pop(
            context,
            ClassroomRecord(
              Classroom(
                id: widget.record?.classroom.id ?? '',
                name: n,
                homeRoomId: _room,
              ),
              level: _level,
              field: _field,
              capacity: cap == null || cap <= 0 ? null : cap,
              active: _active,
            ),
          );
        },
        child: Text(tr('Kaydet')),
      ),
    ],
  );
}

/// Sınıftaki bütün öğrencileri başka sınıfa taşır (ya da sınıfsız bırakır).
Future<bool> moveAllStudents(
  BuildContext context,
  WidgetRef ref,
  ClassroomRecord from,
) async {
  final setup = await ref.read(timetableSetupProvider.future);
  final students = await ref.read(managedStudentsProvider.future);
  final ids = [
    for (final s in students)
      if (s.classroomId == from.classroom.id) s.id,
  ];
  if (!context.mounted) return false;
  final target = await pickClassroom(
    context,
    setup,
    title: tr('{n} öğrenci nereye taşınsın?', {'n': ids.length}),
    exclude: from.classroom.id,
    allowNone: true,
  );
  if (target == null || !context.mounted) return false;
  try {
    await ref
        .read(studentManagementRepositoryProvider)
        .assignToClass(ids, target.isEmpty ? null : target);
    ref.invalidate(managedStudentsProvider);
    ref.invalidate(timetableSetupProvider);
    return true;
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
    return false;
  }
}

/// Sınıf seçimi: kimlik döner; [allowNone] ise '' = sınıfsız.
Future<String?> pickClassroom(
  BuildContext context,
  TimetableSetup setup, {
  required String title,
  String? exclude,
  bool allowNone = false,
}) => showDialog<String>(
  context: context,
  animationStyle: AppMotion.overlayStyle(context),
  builder: (d) => SimpleDialog(
    title: Text(title),
    children: [
      for (final c in setup.classrooms)
        if (c.active && c.classroom.id != exclude)
          SimpleDialogOption(
            key: ValueKey('pick-${c.classroom.id}'),
            onPressed: () => Navigator.pop(d, c.classroom.id),
            child: Text(c.classroom.name),
          ),
      if (allowNone)
        SimpleDialogOption(
          key: const ValueKey('pick-none'),
          onPressed: () => Navigator.pop(d, ''),
          child: Text(tr('Sınıfsız bırak')),
        ),
    ],
  ),
);

/// Bir sınıfın öğrencileri: çıkar, taşı, öğrenci ekle.
class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({
    super.key,
    required this.classroomId,
    required this.basePath,
  });

  final String classroomId;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(timetableSetupProvider).value;
    final klass = setup?.classrooms
        .where((c) => c.classroom.id == classroomId)
        .firstOrNull;
    final students = ref.watch(managedStudentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(klass?.classroom.name ?? tr('Sınıf'))),
      floatingActionButton: klass?.active ?? false
          ? FloatingActionButton.extended(
              onPressed: () => _addStudents(context, ref),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(tr('Öğrenci ekle')),
            )
          : null,
      body: AsyncView(
        value: students,
        onRetry: () => ref.invalidate(managedStudentsProvider),
        builder: (all) {
          final inClass = [
            for (final s in all)
              if (s.classroomId == classroomId) s,
          ];
          if (inClass.isEmpty) {
            return Center(child: Text(tr('Bu sınıfta öğrenci yok.')));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              for (final s in inClass)
                StudentRow(
                  student: s,
                  onTap: () => openStudentEditor(context, ref, s, basePath),
                  trailing: IconButton(
                    tooltip: tr('Sınıftan çıkar'),
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () async {
                      try {
                        await ref
                            .read(studentManagementRepositoryProvider)
                            .assignToClass([s.id], null);
                        ref.invalidate(managedStudentsProvider);
                        ref.invalidate(timetableSetupProvider);
                      } catch (_) {
                        if (context.mounted) {
                          showMessage(
                            context,
                            tr('Kaydedilemedi. Tekrar dene.'),
                          );
                        }
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addStudents(BuildContext context, WidgetRef ref) async {
    final all = await ref.read(managedStudentsProvider.future);
    if (!context.mounted) return;
    final candidates = [
      for (final s in all)
        if (s.classroomId != classroomId) s,
    ];
    final picked = await showDialog<List<String>>(
      context: context,
      animationStyle: AppMotion.overlayStyle(context),
      builder: (_) => _PickStudentsDialog(students: candidates),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    try {
      await ref
          .read(studentManagementRepositoryProvider)
          .assignToClass(picked, classroomId);
      ref.invalidate(managedStudentsProvider);
      ref.invalidate(timetableSetupProvider);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
      }
    }
  }
}

class _PickStudentsDialog extends StatefulWidget {
  const _PickStudentsDialog({required this.students});

  final List<ManagedStudent> students;

  @override
  State<_PickStudentsDialog> createState() => _PickStudentsDialogState();
}

class _PickStudentsDialogState extends State<_PickStudentsDialog> {
  final _picked = <String>{};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final shown = [
      for (final s in widget.students)
        if (q.isEmpty ||
            s.fullName.toLowerCase().contains(q) ||
            (s.studentNumber ?? '').contains(q))
          s,
    ];
    return AlertDialog(
      title: Text(tr('Öğrenci ekle')),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: tr('Öğrenci adı veya numarası ara'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final s in shown)
                    CheckboxListTile(
                      dense: true,
                      value: _picked.contains(s.id),
                      title: Text(s.fullName),
                      subtitle: Text(
                        [
                          s.studentNumber ?? tr('Numarası yok'),
                          s.classroomName ?? tr('Atanmadı'),
                        ].join(' · '),
                      ),
                      onChanged: (v) => setState(
                        () => v == true
                            ? _picked.add(s.id)
                            : _picked.remove(s.id),
                      ),
                    ),
                ],
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
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, _picked.toList()),
          child: Text(tr('Ekle ({n})', {'n': _picked.length})),
        ),
      ],
    );
  }
}
