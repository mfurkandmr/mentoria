import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../coach/data/coach_repository.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../../tracking/presentation/questions_view.dart';
import '../../tracking/presentation/study_view.dart';
import '../data/coaching_repository.dart';
import '../../../core/i18n/i18n.dart';

/// Görevleri kimin gördüğü.
enum TaskViewer { student, coach, readOnly }

/// Görev listesi. Öğrenci işaretler, koç ekler/siler, veli yalnızca görür.
class TaskList extends ConsumerWidget {
  const TaskList({
    super.key,
    required this.studentId,
    required this.viewer,
    this.onlyPending = false,
    this.emptyText,
  });

  final String studentId;
  final TaskViewer viewer;
  final bool onlyPending;
  final String? emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider(studentId));
    return AsyncView(
      value: tasks,
      onRetry: () => ref.invalidate(tasksProvider(studentId)),
      builder: (all) {
        final list = onlyPending
            ? all.where((t) => t.status == TaskStatus.pending).toList()
            : all;
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              emptyText ?? tr('Henüz görev yok.'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return Column(
          children: [
            for (final t in list)
              _TaskTile(task: t, studentId: studentId, viewer: viewer),
          ],
        );
      },
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    required this.task,
    required this.studentId,
    required this.viewer,
  });

  final CoachTask task;
  final String studentId;
  final TaskViewer viewer;

  Future<void> _set(WidgetRef ref, TaskStatus s) async {
    await ref.read(coachingRepositoryProvider).setTaskStatus(task.id, s);
    ref.invalidate(tasksProvider(studentId));
    ref.invalidate(studentSummariesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final done = task.status == TaskStatus.done;
    final details = [
      if (task.subjectCode != null)
        '${subjectByCode(task.subjectCode!).examType.label} '
            '${subjectByCode(task.subjectCode!).name}',
      if (task.targetQuestions != null) '${task.targetQuestions} soru',
      if (task.dueOn != null)
        tr('Son gün {p0}', {'p0': formatShortDate(task.dueOn!)}),
    ].join(' · ');

    final statusIcon = switch (task.status) {
      TaskStatus.done => Icon(Icons.check_circle, color: context.brand.success),
      TaskStatus.skipped => const Icon(Icons.cancel_outlined),
      TaskStatus.pending when task.isOverdue => Icon(
        Icons.schedule,
        color: context.brand.danger,
      ),
      TaskStatus.pending => const Icon(Icons.radio_button_unchecked),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading:
            viewer == TaskViewer.student && task.status != TaskStatus.skipped
            ? Checkbox(
                value: done,
                onChanged: (v) {
                  if (v == true) celebrate(context);
                  _set(ref, v == true ? TaskStatus.done : TaskStatus.pending);
                },
              )
            : statusIcon,
        title: Text(
          task.title,
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description?.isNotEmpty ?? false) Text(task.description!),
            if (details.isNotEmpty) Text(details, style: text.labelSmall),
            if (task.isOverdue)
              Text(
                tr('Süresi geçti'),
                style: text.labelSmall?.copyWith(color: context.brand.danger),
              ),
            if (viewer != TaskViewer.student)
              Text(task.status.label, style: text.labelSmall),
          ],
        ),
        trailing: viewer == TaskViewer.coach
            ? PopupMenuButton<String>(
                tooltip: tr('Görev seçenekleri'),
                onSelected: (v) async {
                  if (v == 'delete') {
                    final ok = await confirm(
                      context,
                      title: tr('Görev silinsin mi?'),
                      message: task.title,
                    );
                    if (!ok) return;
                    await ref
                        .read(coachingRepositoryProvider)
                        .deleteTask(task.id);
                    ref.invalidate(tasksProvider(studentId));
                    ref.invalidate(studentSummariesProvider);
                  } else {
                    await _set(ref, TaskStatus.fromDb(v));
                  }
                },
                itemBuilder: (_) => [
                  for (final s in TaskStatus.values)
                    if (s != task.status)
                      PopupMenuItem(
                        value: s.db,
                        child: Text(
                          tr('{p0} olarak işaretle', {'p0': s.label}),
                        ),
                      ),
                  PopupMenuItem(value: 'delete', child: Text(tr('Sil'))),
                ],
              )
            : viewer == TaskViewer.student && !done
            ? IconButton(
                tooltip: tr('Yapmadım olarak işaretle'),
                icon: Icon(
                  task.status == TaskStatus.skipped
                      ? Icons.undo
                      : Icons.do_not_disturb_on_outlined,
                ),
                onPressed: () => _set(
                  ref,
                  task.status == TaskStatus.skipped
                      ? TaskStatus.pending
                      : TaskStatus.skipped,
                ),
              )
            : null,
      ),
    );
  }
}

Future<void> showAddTaskSheet(BuildContext context, String studentId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddTaskSheet(studentId: studentId),
    );

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet({required this.studentId});

  final String studentId;

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _target = TextEditingController();
  String? _subject;
  DateTime? _due = dateOnly(DateTime.now()).add(const Duration(days: 7));
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showMessage(context, tr('Göreve bir başlık yaz.'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(coachingRepositoryProvider)
          .createTask(
            widget.studentId,
            TaskDraft(
              title: _title.text.trim(),
              description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
              subjectCode: _subject,
              targetQuestions: int.tryParse(_target.text),
              dueOn: _due,
            ),
          );
      ref.invalidate(tasksProvider(widget.studentId));
      ref.invalidate(studentSummariesProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showMessage(context, tr('Görev kaydedilemedi.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Görev ver'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr('Görev'),
                hintText: tr('ör. Paragraf 40 soru'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr('Açıklama (isteğe bağlı)'),
                helperText: tr(
                  'Sağlık, aile durumu gibi özel bilgileri yazma.',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SubjectDropdown(
              value: _subject,
              allowNone: true,
              label: tr('Ders (isteğe bağlı)'),
              onChanged: (v) => setState(() => _subject = v.isEmpty ? null : v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _target,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: tr('Hedef soru')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _due ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _due = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: tr('Son gün')),
                      child: Text(_due == null ? '—' : formatShortDate(_due!)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(tr('Görevi ver')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Koç notları. [canWrite] yalnızca koç; öğrenci okur.
class NotesList extends ConsumerStatefulWidget {
  const NotesList({
    super.key,
    required this.studentId,
    this.canWrite = false,
    this.limit,
  });

  final String studentId;
  final bool canWrite;
  final int? limit;

  @override
  ConsumerState<NotesList> createState() => _NotesListState();
}

class _NotesListState extends ConsumerState<NotesList> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(coachingRepositoryProvider)
          .addNote(widget.studentId, body);
      _controller.clear();
      ref.invalidate(notesProvider(widget.studentId));
    } catch (_) {
      if (mounted) showMessage(context, tr('Not kaydedilemedi.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider(widget.studentId));
    final text = Theme.of(context).textTheme;
    final dateFormat = DateFormat('d MMMM, HH:mm', localeTag);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.canWrite) ...[
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: tr('Öğrencine bir not ya da geri bildirim yaz…'),
              helperText: tr('Sağlık, aile durumu gibi özel bilgileri yazma.'),
              suffixIcon: IconButton(
                tooltip: tr('Gönder'),
                icon: const Icon(Icons.send_rounded),
                onPressed: _sending ? null : _send,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        AsyncView(
          value: notes,
          onRetry: () => ref.invalidate(notesProvider(widget.studentId)),
          builder: (all) {
            final list = widget.limit == null
                ? all
                : all.take(widget.limit!).toList();
            if (list.isEmpty) {
              return Text(
                widget.canWrite
                    ? tr('Henüz not yazmadın.')
                    : tr('Koçundan henüz not yok.'),
                style: text.bodyMedium,
              );
            }
            return Column(
              children: [
                for (final n in list)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.brand.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.body, style: text.bodyMedium),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              dateFormat.format(n.createdAt),
                              style: text.labelSmall,
                            ),
                            const Spacer(),
                            if (widget.canWrite)
                              InkWell(
                                onTap: () async {
                                  final ok = await confirm(
                                    context,
                                    title: tr('Not silinsin mi?'),
                                    message: tr(
                                      'Bu not kalıcı olarak silinecek.',
                                    ),
                                  );
                                  if (!ok) return;
                                  await ref
                                      .read(coachingRepositoryProvider)
                                      .deleteNote(n.id);
                                  ref.invalidate(
                                    notesProvider(widget.studentId),
                                  );
                                },
                                child: Text(
                                  tr('Sil'),
                                  style: text.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Hedefler kartı. [canEdit]: öğrenci ve koçu.
class GoalsCard extends ConsumerWidget {
  const GoalsCard({super.key, required this.studentId, this.canEdit = false});

  final String studentId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider(studentId));
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: tr('Hedefler'),
      trailing: canEdit
          ? TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _GoalsDialog(
                  studentId: studentId,
                  initial: goals.value ?? const Goals(),
                ),
              ),
              child: Text(tr('Düzenle')),
            )
          : null,
      child: AsyncView(
        value: goals,
        builder: (g) {
          if (g.isEmpty) {
            return Text(
              canEdit
                  ? tr('Henüz hedef belirlenmedi. "Düzenle"ye dokun.')
                  : tr('Henüz hedef belirlenmedi.'),
              style: text.bodyMedium,
            );
          }
          Widget row(IconData icon, String label, String? value) =>
              value == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                      Text('$label: ', style: text.bodyMedium),
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                );
          return Column(
            children: [
              row(
                Icons.edit_note,
                tr('Günlük soru'),
                g.dailyQuestions?.toString(),
              ),
              row(
                Icons.timer_outlined,
                tr('Günlük çalışma'),
                g.dailyMinutes == null ? null : formatMinutes(g.dailyMinutes!),
              ),
              row(
                Icons.school_outlined,
                tr('Hedef'),
                [
                  if (g.targetUniversity?.isNotEmpty ?? false)
                    g.targetUniversity!,
                  if (g.targetDepartment?.isNotEmpty ?? false)
                    g.targetDepartment!,
                ].join(' · ').emptyToNull,
              ),
              row(
                Icons.emoji_events_outlined,
                tr('Hedef sıralama'),
                g.targetRank == null
                    ? null
                    : NumberFormat.decimalPattern(
                        localeTag,
                      ).format(g.targetRank),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension on String {
  String? get emptyToNull => isEmpty ? null : this;
}

class _GoalsDialog extends ConsumerStatefulWidget {
  const _GoalsDialog({required this.studentId, required this.initial});

  final String studentId;
  final Goals initial;

  @override
  ConsumerState<_GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends ConsumerState<_GoalsDialog> {
  late final _questions = TextEditingController(
    text: widget.initial.dailyQuestions?.toString(),
  );
  late final _minutes = TextEditingController(
    text: widget.initial.dailyMinutes?.toString(),
  );
  late final _uni = TextEditingController(
    text: widget.initial.targetUniversity,
  );
  late final _dept = TextEditingController(
    text: widget.initial.targetDepartment,
  );
  late final _rank = TextEditingController(
    text: widget.initial.targetRank?.toString(),
  );
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_questions, _minutes, _uni, _dept, _rank]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ref
          .read(trackingRepositoryProvider)
          .saveGoals(
            widget.studentId,
            Goals(
              dailyQuestions: int.tryParse(_questions.text),
              dailyMinutes: int.tryParse(_minutes.text),
              targetUniversity: t(_uni),
              targetDepartment: t(_dept),
              targetRank: int.tryParse(_rank.text),
            ),
          );
      ref.invalidate(goalsProvider(widget.studentId));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showMessage(context, tr('Hedefler kaydedilemedi.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(tr('Hedefler')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _questions,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: InputDecoration(labelText: tr('Günlük soru hedefi')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: InputDecoration(
                labelText: tr('Günlük çalışma hedefi (dakika)'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _uni,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('Hedef üniversite')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dept,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('Hedef bölüm')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _rank,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: InputDecoration(labelText: tr('Hedef sıralama')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}
