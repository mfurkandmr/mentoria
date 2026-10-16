import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../data/assignment_repository.dart';

enum AssignmentViewer {
  /// Maddeleri işaretler.
  student,

  /// Koç / müdür: işaretler ve siler.
  manager,

  /// Veli: yalnızca görür.
  readOnly,
}

/// Öğrencinin ödev paketleri. [onlyActive]: bitmemiş olanlar.
class AssignmentList extends ConsumerWidget {
  const AssignmentList({
    super.key,
    required this.studentId,
    required this.viewer,
    this.onlyActive = false,
    this.limit,
    this.emptyText,
  });

  final String studentId;
  final AssignmentViewer viewer;
  final bool onlyActive;
  final int? limit;
  final String? emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(assignmentsProvider(studentId)),
      onRetry: () => ref.invalidate(assignmentsProvider(studentId)),
      builder: (all) {
        var list = onlyActive ? all.where((a) => !a.isComplete).toList() : all;
        if (limit != null) list = list.take(limit!).toList();
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(emptyText ?? tr('Henüz ödev yok.')),
          );
        }
        return Column(
          children: [
            for (final (i, a) in list.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: AssignmentCard(
                  assignment: a,
                  studentId: studentId,
                  viewer: viewer,
                  initiallyExpanded: i == 0 && !a.isComplete,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Tek ödev paketi: başlık, ilerleme, son tarih ve işaretlenebilir maddeler.
class AssignmentCard extends ConsumerStatefulWidget {
  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.studentId,
    required this.viewer,
    this.initiallyExpanded = false,
  });

  final Assignment assignment;
  final String studentId;
  final AssignmentViewer viewer;
  final bool initiallyExpanded;

  @override
  ConsumerState<AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends ConsumerState<AssignmentCard> {
  late bool _open = widget.initiallyExpanded;

  /// Sunucu cevabı gelene kadar işaretler anında görünsün.
  final _pending = <String, bool>{};

  bool _doneOf(AssignmentItem i) => _pending[i.id] ?? i.done;

  Future<void> _tick(AssignmentItem item, bool done) async {
    HapticFeedback.selectionClick();
    setState(() => _pending[item.id] = done);
    final a = widget.assignment;
    final willComplete =
        done && a.items.every((i) => i.id == item.id || _doneOf(i));
    if (willComplete) {
      celebrate(context);
      showMessage(context, tr('Ödev tamamlandı, harikasın! 🎉'));
    }
    try {
      await ref.read(assignmentRepositoryProvider).setItemDone(item.id, done);
      ref.invalidate(assignmentsProvider(widget.studentId));
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending.remove(item.id));
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: tr('Ödev silinsin mi?'),
      message: tr('"{title}" öğrencinin listesinden kaldırılacak.', {
        'title': widget.assignment.title,
      }),
    );
    if (!ok) return;
    await ref
        .read(assignmentRepositoryProvider)
        .deleteAssignment(widget.assignment.id);
    ref.invalidate(assignmentsProvider(widget.studentId));
  }

  @override
  void didUpdateWidget(AssignmentCard old) {
    super.didUpdateWidget(old);
    // Sunucudan gelen veri işaretleri yakaladıysa geçici kayıtları bırak.
    _pending.removeWhere(
      (id, v) => widget.assignment.items.any((i) => i.id == id && i.done == v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final done = a.items.where(_doneOf).length;
    final complete = a.items.isNotEmpty && done == a.items.length;
    final progress = a.items.isEmpty ? 0.0 : done / a.items.length;
    final canTick = widget.viewer != AssignmentViewer.readOnly;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              width: 5,
              color: complete
                  ? context.brand.success
                  : a.isOverdue
                  ? context.brand.danger
                  : context.brand.primary,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  children: [
                    _ProgressHex(progress: progress, complete: complete),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              decoration: complete
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (a.coachName != null) a.coachName!,
                              formatShortDate(a.createdAt),
                              tr('{done}/{all} tamam', {
                                'done': done,
                                'all': a.items.length,
                              }),
                            ].join(' · '),
                            style: text.bodySmall,
                          ),
                          if (a.dueOn != null && !complete) ...[
                            const SizedBox(height: 4),
                            _DueChip(due: a.dueOn!, overdue: a.isOverdue),
                          ],
                        ],
                      ),
                    ),
                    if (widget.viewer == AssignmentViewer.manager)
                      IconButton(
                        tooltip: tr('Sil'),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(Icons.expand_more),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 280),
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: _open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a.note != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.brand.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💬 '),
                          Expanded(child: Text(a.note!, style: text.bodySmall)),
                        ],
                      ),
                    ),
                  for (final item in a.items)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _doneOf(item),
                      onChanged: canTick ? (v) => _tick(item, v!) : null,
                      title: Text(
                        '${item.subjectName} · ${item.label}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: _doneOf(item)
                              ? TextDecoration.lineThrough
                              : null,
                          color: _doneOf(item) ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (item.questionCount != null)
                            tr('{n} soru', {'n': item.questionCount}),
                          if (item.note != null) item.note!,
                        ].join(' · '),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.due, required this.overdue});

  final DateTime due;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final days = due.difference(today).inDays;
    final label = overdue
        ? tr('Süresi geçti')
        : days == 0
        ? tr('Bugün son gün')
        : days == 1
        ? tr('Yarın son gün')
        : tr('{n} gün kaldı', {'n': days});
    final color = overdue
        ? context.brand.danger
        : days <= 1
        ? context.brand.primaryDeep
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Altıgen ilerleme rozeti: bal dolar, bitince yeşil tik.
class _ProgressHex extends StatelessWidget {
  const _ProgressHex({required this.progress, required this.complete});

  final double progress;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => CustomPaint(
        size: const Size.square(40),
        painter: _HexFill(
          v,
          complete: complete,
          track: track,
          brand: context.brand,
        ),
        child: SizedBox.square(
          dimension: 40,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: complete
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('ok'),
                      color: Colors.white,
                      size: 22,
                    )
                  : Text(
                      '%${(v * 100).round()}',
                      key: const ValueKey('p'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: context.brand.ink,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexFill extends CustomPainter {
  _HexFill(
    this.v, {
    required this.complete,
    required this.track,
    required this.brand,
  });

  final BrandTheme brand;

  final double v;
  final bool complete;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final hex = hexPath(size.center(Offset.zero), size.width / 2);
    canvas.drawPath(hex, Paint()..color = track);
    canvas.save();
    canvas.clipPath(hex);
    final top = size.height * (1 - v);
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, size.height - top),
      Paint()..color = complete ? brand.success : brand.primary,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HexFill old) =>
      old.brand != brand ||
      old.v != v ||
      old.complete != complete ||
      old.track != track;
}
