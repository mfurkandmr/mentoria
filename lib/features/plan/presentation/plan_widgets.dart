import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../auth/data/auth_repository.dart';
import '../../learn/data/practice_repository.dart';
import '../../learn/presentation/learn_screen.dart';
import '../data/plan_repository.dart';

String _subjectLabel(String code) => code.startsWith('TYT_')
    ? 'TYT ${subjectByCode(code).name}'
    : code.startsWith('AYT_')
    ? practiceSubjectLabel(code)
    : subjectByCode(code).name;

/// Maddenin hedef özeti: "40 soru · 45 dk".
String planTargetText(PlanItem i) => [
  if (i.questionCount != null) tr('{n} soru', {'n': i.questionCount}),
  if (i.minutes != null) tr('{n} dk', {'n': i.minutes}),
].join(' · ');

/// Öğrencinin ana sayfasındaki "Bugünün planı" kartı.
class PlanTodayCard extends ConsumerWidget {
  const PlanTodayCard({super.key, required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final items =
        ref.watch(planWeekProvider((studentId, weekStartOf(now)))).value ??
        const <PlanItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final today = DateTime(now.year, now.month, now.day);
    final todays = items.where((i) => i.day == today).toList();
    final weekDone = items.where((i) => i.done).length;
    final brand = context.brand;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/student/plan'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note_rounded, color: brand.primaryDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Bugünün planı'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    tr('Hafta %{p}', {
                      'p': (weekDone * 100 / items.length).round(),
                    }),
                    style: TextStyle(
                      color: brand.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 6),
              if (todays.isEmpty)
                Text(tr('Bugün için madde yok. Haftanın planına bak.'))
              else
                for (final i in todays.take(3))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          i.done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: i.done ? brand.success : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              _subjectLabel(i.subject),
                              if (i.topic != null) i.topic!,
                            ].join(' · '),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: i.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              if (todays.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tr('+{n} madde daha', {'n': todays.length - 3}),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Öğrencinin plan ekranı.
class StudentPlanScreen extends ConsumerWidget {
  const StudentPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Haftalık plan'))),
      body: me == null
          ? const Center(child: BizzLoader())
          : WeeklyPlanView(studentId: me.id, canTick: true),
    );
  }
}

/// Haftalık plan: hafta seçici, tamamlanma oranı ve gün gün maddeler.
/// [canEdit]: koç / müdür (ekler, siler, kopyalar). [canTick]: işaretleyebilir.
class WeeklyPlanView extends ConsumerStatefulWidget {
  const WeeklyPlanView({
    super.key,
    required this.studentId,
    this.canEdit = false,
    this.canTick = false,
    this.bottomPadding = 32,
  });

  final String studentId;
  final bool canEdit;
  final bool canTick;
  final double bottomPadding;

  @override
  ConsumerState<WeeklyPlanView> createState() => _WeeklyPlanViewState();
}

class _WeeklyPlanViewState extends ConsumerState<WeeklyPlanView> {
  DateTime _week = weekStartOf(DateTime.now());

  (String, DateTime) get _key => (widget.studentId, _week);

  Future<void> _toggle(PlanItem i) async {
    HapticFeedback.selectionClick();
    try {
      await ref.read(planRepositoryProvider).setDone(i.id, !i.done);
      if (!i.done && mounted) {
        final items = ref.read(planWeekProvider(_key)).value ?? const [];
        final today = items.where((x) => x.day == i.day);
        if (today.every((x) => x.id == i.id || x.done)) celebrate(context);
      }
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
    ref.invalidate(planWeekProvider(_key));
  }

  Future<void> _delete(PlanItem i) async {
    try {
      await ref.read(planRepositoryProvider).delete(i.id);
    } catch (_) {
      if (mounted) showMessage(context, tr('Silinemedi. Tekrar dene.'));
    }
    ref.invalidate(planWeekProvider(_key));
  }

  Future<void> _copyLastWeek() async {
    final repo = ref.read(planRepositoryProvider);
    final last = await repo.fetchWeek(
      widget.studentId,
      _week.subtract(const Duration(days: 7)),
    );
    if (last.isEmpty) {
      if (mounted) showMessage(context, tr('Geçen hafta plan yok.'));
      return;
    }
    var failed = 0;
    for (final i in last) {
      try {
        await repo.add(
          widget.studentId,
          i.toDraft(i.day.add(const Duration(days: 7))),
        );
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(planWeekProvider(_key));
    if (mounted) {
      showMessage(
        context,
        failed == 0
            ? tr('Geçen haftanın planı kopyalandı.')
            : tr('{n} madde kopyalanamadı.', {'n': failed}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(planWeekProvider(_key));
    final brand = context.brand;
    final thisWeek = weekStartOf(DateTime.now());
    final fmt = DateFormat('d MMM', localeTag);
    final end = _week.add(const Duration(days: 6));
    return AsyncView(
      value: items,
      onRetry: () => ref.invalidate(planWeekProvider(_key)),
      builder: (list) {
        final done = list.where((i) => i.done).length;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(planWeekProvider(_key).future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottomPadding),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: tr('Önceki hafta'),
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setState(
                      () => _week = _week.subtract(const Duration(days: 7)),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${fmt.format(_week)} – ${fmt.format(end)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        if (_week == thisWeek)
                          Text(
                            tr('Bu hafta'),
                            style: TextStyle(
                              color: brand.primaryDeep,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => setState(() => _week = thisWeek),
                            child: Text(tr('Bu haftaya dön')),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Sonraki hafta'),
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => setState(
                      () => _week = _week.add(const Duration(days: 7)),
                    ),
                  ),
                ],
              ),
              if (list.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedLinearProgress(
                        value: done / list.length,
                        color: brand.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tr('{d} / {n} madde · %{p}', {
                        'd': done,
                        'n': list.length,
                        'p': (done * 100 / list.length).round(),
                      }),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: EmptyState(
                    title: tr('Bu hafta için plan yok'),
                    message: widget.canEdit
                        ? tr(
                            'Günlere madde ekle ya da geçen haftanın planını kopyala.',
                          )
                        : tr('Koçun plan hazırlayınca burada görünecek.'),
                    bizzSize: 90,
                    action: widget.canEdit
                        ? OutlinedButton.icon(
                            onPressed: _copyLastWeek,
                            icon: const Icon(Icons.copy_all_rounded),
                            label: Text(tr('Geçen haftayı kopyala')),
                          )
                        : null,
                  ),
                ),
              for (var d = 0; d < 7; d++)
                _DaySection(
                  day: _week.add(Duration(days: d)),
                  isToday: _week.add(Duration(days: d)) == today,
                  items: [
                    for (final i in list)
                      if (i.day == _week.add(Duration(days: d))) i,
                  ],
                  canEdit: widget.canEdit,
                  canTick: widget.canTick,
                  hideEmpty: !widget.canEdit,
                  onToggle: _toggle,
                  onDelete: _delete,
                  onAdd: () async {
                    final added = await showAddPlanSheet(
                      context,
                      studentId: widget.studentId,
                      day: _week.add(Duration(days: d)),
                    );
                    if (added == true) ref.invalidate(planWeekProvider(_key));
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.isToday,
    required this.items,
    required this.canEdit,
    required this.canTick,
    required this.hideEmpty,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
  });

  final DateTime day;
  final bool isToday;
  final List<PlanItem> items;
  final bool canEdit;
  final bool canTick;
  final bool hideEmpty;
  final ValueChanged<PlanItem> onToggle;
  final ValueChanged<PlanItem> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && hideEmpty) return const SizedBox.shrink();
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  DateFormat('EEEE, d MMMM', localeTag).format(day),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isToday ? brand.primaryDeep : null,
                  ),
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: brand.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tr('Bugün'),
                    style: TextStyle(
                      color: brand.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (canEdit)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(tr('Madde ekle')),
                ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                tr('Madde yok'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            Card(
              margin: const EdgeInsets.only(top: 4),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (n, i) in items.indexed) ...[
                    if (n > 0) const Divider(height: 1),
                    _ItemTile(
                      item: i,
                      canTick: canTick,
                      canEdit: canEdit,
                      onToggle: () => onToggle(i),
                      onDelete: () => onDelete(i),
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

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.canTick,
    required this.canEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final PlanItem item;
  final bool canTick;
  final bool canEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final look = subjectLook(item.subject);
    final target = planTargetText(item);
    final brand = context.brand;
    return ListTile(
      onTap: canTick ? onToggle : null,
      leading: canTick
          ? Checkbox(value: item.done, onChanged: (_) => onToggle())
          : Icon(
              item.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: item.done ? brand.success : null,
            ),
      title: Text(
        [
          _subjectLabel(item.subject),
          if (item.topic != null) item.topic!,
        ].join(' · '),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          decoration: item.done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: target.isEmpty && item.note == null
          ? null
          : Text(
              [
                if (target.isNotEmpty) target,
                if (item.note != null) item.note!,
              ].join('\n'),
            ),
      trailing: canEdit
          ? IconButton(
              tooltip: tr('Sil'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onDelete,
            )
          : Icon(look.icon, color: look.color),
    );
  }
}

/// Madde ekleme. Eklendiyse true döner.
Future<bool?> showAddPlanSheet(
  BuildContext context, {
  required String studentId,
  required DateTime day,
}) => showModalBottomSheet<bool>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _AddPlanSheet(studentId: studentId, day: day),
);

class _AddPlanSheet extends ConsumerStatefulWidget {
  const _AddPlanSheet({required this.studentId, required this.day});
  final String studentId;
  final DateTime day;

  @override
  ConsumerState<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends ConsumerState<_AddPlanSheet> {
  String _subject = 'TYT_MAT';
  final _topic = TextEditingController();
  final _questions = TextEditingController();
  final _minutes = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _topic.dispose();
    _questions.dispose();
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final q = int.tryParse(_questions.text.trim());
    final m = int.tryParse(_minutes.text.trim());
    if ((q != null && (q < 1 || q > 1000)) ||
        (m != null && (m < 5 || m > 600))) {
      showMessage(context, tr('Soru 1-1000, süre 5-600 dakika olmalı.'));
      return;
    }
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      await ref
          .read(planRepositoryProvider)
          .add(
            widget.studentId,
            PlanDraft(
              day: widget.day,
              subject: _subject,
              topic: _clean(_topic),
              questionCount: q,
              minutes: m,
              note: _clean(_note),
            ),
          );
      nav.pop(true);
    } on PlanException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, switch (e.code) {
        'PLAN_DAY_FULL' => tr('Bir güne en çok 12 madde eklenebilir.'),
        'PLAN_DAY_PAST' => tr('Geçmiş haftalara madde eklenemez.'),
        _ => tr('Kaydedilemedi. Tekrar dene.'),
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('{day} için madde', {
                'day': DateFormat('EEEE, d MMMM', localeTag).format(widget.day),
              }),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _subject,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Ders')),
              items: [
                for (final s in examSubjects)
                  DropdownMenuItem(
                    value: s.code,
                    child: Text(_subjectLabel(s.code)),
                  ),
              ],
              onChanged: (v) => setState(() => _subject = v!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _topic,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: tr('Konu (isteğe bağlı)'),
                hintText: tr('ör. Problemler'),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questions,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: tr('Soru hedefi')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: tr('Süre (dk)')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLength: 300,
              decoration: InputDecoration(labelText: tr('Not (isteğe bağlı)')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(tr('Ekle')),
            ),
          ],
        ),
      ),
    ),
  );
}
