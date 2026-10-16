import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/motion.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../coach/data/coach_repository.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../data/assignment_repository.dart';

/// Türkçe büyük/küçük harf duyarsız arama için.
String _fold(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();

/// Koçun ödev verme ekranı: öğrenciyi bul → ders → konu → sepete ekle →
/// sepeti gözden geçir → öğrenciye gönder.
class AssignHomeworkScreen extends ConsumerStatefulWidget {
  const AssignHomeworkScreen({super.key, this.initialStudentId});

  final String? initialStudentId;

  @override
  ConsumerState<AssignHomeworkScreen> createState() =>
      _AssignHomeworkScreenState();
}

class _AssignHomeworkScreenState extends ConsumerState<AssignHomeworkScreen> {
  StudentSummary? _student;
  ExamType _type = ExamType.tyt;
  late String _subject = _subjects.first.code;
  String _topicQuery = '';
  final _basket = ValueNotifier<List<AssignmentItemDraft>>(const []);
  final _topicSearch = TextEditingController();
  int _bump = 0;

  @override
  void dispose() {
    _basket.dispose();
    _topicSearch.dispose();
    super.dispose();
  }

  List<ExamSubject> get _subjects =>
      examSubjects.where((s) => s.examType == _type).toList();

  void _toggle(AssignmentItemDraft d) {
    final list = [..._basket.value];
    final i = list.indexWhere((x) => x.key == d.key);
    if (i >= 0) {
      list.removeAt(i);
      HapticFeedback.selectionClick();
    } else {
      list.add(d);
      HapticFeedback.lightImpact();
      _bump++;
    }
    _basket.value = list;
  }

  Future<void> _openBasket() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _BasketSheet(basket: _basket, student: _student!),
    );
    if (sent != true || !mounted) return;
    showMessage(
      context,
      tr('Ödev {name} adlı öğrenciye gönderildi 🐝', {
        'name': _student!.fullName,
      }),
    );
    if (widget.initialStudentId != null && context.canPop()) {
      context.pop();
    } else {
      setState(() => _student = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentSummariesProvider);
    if (_student == null && widget.initialStudentId != null) {
      final match = students.value
          ?.where((s) => s.id == widget.initialStudentId)
          .firstOrNull;
      if (match != null) _student = match;
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Ödev ver'))),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(a),
            child: child,
          ),
        ),
        child: _student == null
            ? AsyncView(
                key: const ValueKey('pick'),
                value: students,
                onRetry: () => ref.invalidate(studentSummariesProvider),
                builder: (list) => _StudentPicker(
                  students: list,
                  onPick: (s) {
                    HapticFeedback.selectionClick();
                    setState(() => _student = s);
                  },
                ),
              )
            : _buildPicker(context),
      ),
      bottomNavigationBar: _student == null
          ? null
          : ValueListenableBuilder(
              valueListenable: _basket,
              builder: (context, basket, _) =>
                  _BasketBar(basket: basket, bump: _bump, onOpen: _openBasket),
            ),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topics =
        (ref.watch(topicsProvider).value ?? const <Topic>[])
            .where((t) => t.subjectCode == _subject)
            .where((t) => _fold(t.name).contains(_fold(_topicQuery)))
            .toList()
          ..sort((a, b) => a.sort.compareTo(b.sort));
    final subject = subjectByCode(_subject);

    return Column(
      key: const ValueKey('topics'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectedStudent(
          student: _student!,
          onChange: () => setState(() => _student = null),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<ExamType>(
            segments: [
              for (final t in ExamType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() {
              _type = v.first;
              _subject = _subjects.first.code;
              _topicSearch.clear();
              _topicQuery = '';
            }),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            children: [
              for (final s in _subjects)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s.name),
                    selected: s.code == _subject,
                    onSelected: (_) => setState(() {
                      _subject = s.code;
                      _topicSearch.clear();
                      _topicQuery = '';
                    }),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            controller: _topicSearch,
            onChanged: (v) => setState(() => _topicQuery = v),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: tr('{subject} konularında ara', {
                'subject': subject.name,
              }),
            ),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: _basket,
            builder: (context, basket, _) {
              final keys = {for (final b in basket) b.key};
              final general = AssignmentItemDraft(
                subjectCode: _subject,
                questionCount: 20,
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                children: [
                  if (_topicQuery.isEmpty)
                    _TopicTile(
                      title: tr('Genel tekrar'),
                      subtitle: tr('Konu seçmeden tüm {subject}', {
                        'subject': subject.name,
                      }),
                      icon: Icons.all_inclusive_rounded,
                      inBasket: keys.contains(general.key),
                      onTap: () => _toggle(general),
                    ),
                  for (final (i, t) in topics.indexed)
                    FadeSlideIn(
                      key: ValueKey('${t.id}'),
                      delay: Duration(milliseconds: 20 * i.clamp(0, 12)),
                      offset: 10,
                      duration: const Duration(milliseconds: 320),
                      child: _TopicTile(
                        title: t.name,
                        inBasket: keys.contains('$_subject/${t.id}'),
                        onTap: () => _toggle(
                          AssignmentItemDraft(
                            subjectCode: _subject,
                            topicId: t.id,
                            topicName: t.name,
                            questionCount: 20,
                          ),
                        ),
                      ),
                    ),
                  if (topics.isEmpty && _topicQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tr('"{q}" ile eşleşen konu yok', {'q': _topicQuery}),
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── Öğrenci seçimi ─────────────────────────────

class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.students, required this.onPick});

  final List<StudentSummary> students;
  final ValueChanged<StudentSummary> onPick;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _fold(_q);
    final list =
        widget.students
            .where(
              (s) =>
                  q.isEmpty ||
                  _fold(s.fullName).contains(q) ||
                  (s.studentNumber ?? '').toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            tr('Kime ödev vereceksin?'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            autofocus: widget.students.length > 6,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_search_rounded),
              hintText: tr('İsim veya okul numarası'),
            ),
          ),
        ),
        Expanded(
          child: widget.students.isEmpty
              ? EmptyState(
                  title: tr('Henüz öğrencin yok'),
                  message: tr('Önce öğrencilerini davet et.'),
                )
              : list.isEmpty
              ? EmptyState(
                  title: tr('Öğrenci bulunamadı'),
                  message: tr('Başka bir isim ya da numara dene.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return FadeSlideIn(
                      key: ValueKey(s.id),
                      delay: FadeSlideIn.stagger(i.clamp(0, 10), 30),
                      offset: 12,
                      child: ListTile(
                        leading: _Initials(name: s.fullName),
                        title: Text(
                          s.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          s.studentNumber == null
                              ? tr('Okul numarası yok')
                              : tr('No {p0}', {'p0': s.studentNumber}),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => widget.onPick(s),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, this.radius = 20});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = [
      if (parts.isNotEmpty && parts.first.isNotEmpty) parts.first[0],
      if (parts.length > 1 && parts.last.isNotEmpty) parts.last[0],
    ].join().toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.brand.primary,
      foregroundColor: context.brand.ink,
      child: Text(
        initials,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: radius * 0.75),
      ),
    );
  }
}

class _SelectedStudent extends StatelessWidget {
  const _SelectedStudent({required this.student, required this.onChange});

  final StudentSummary student;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              _Initials(name: student.fullName, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      student.studentNumber == null
                          ? tr('Okul numarası yok')
                          : tr('No {p0}', {'p0': student.studentNumber}),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onChange, child: Text(tr('Değiştir'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.title,
    required this.inBasket,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool inBasket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: inBasket
            ? context.brand.primary.withValues(alpha: 0.16)
            : Colors.transparent,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: icon == null
              ? null
              : Icon(icon, color: context.brand.primaryDeep),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: inBasket ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, a) => ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
              child: child,
            ),
            child: inBasket
                ? Icon(
                    Icons.check_circle_rounded,
                    key: const ValueKey('in'),
                    color: context.brand.success,
                  )
                : Icon(
                    Icons.add_circle_outline_rounded,
                    key: const ValueKey('out'),
                    color: scheme.onSurfaceVariant,
                  ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ─────────────────────────────── Sepet ───────────────────────────────

class _BasketBar extends StatelessWidget {
  const _BasketBar({
    required this.basket,
    required this.bump,
    required this.onOpen,
  });

  final List<AssignmentItemDraft> basket;
  final int bump;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final questions = basket.fold(0, (s, i) => s + (i.questionCount ?? 0));
    final empty = basket.isEmpty;
    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Material(
            color: empty
                ? Theme.of(context).colorScheme.surfaceContainerHigh
                : context.brand.ink,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: empty ? null : onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey(bump),
                      tween: Tween(begin: bump == 0 ? 1 : 1.35, end: 1),
                      duration: Duration(
                        milliseconds: Motion.of(context) ? 520 : 0,
                      ),
                      curve: Curves.elasticOut,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: Badge(
                        isLabelVisible: !empty,
                        backgroundColor: context.brand.primary,
                        textColor: context.brand.ink,
                        label: Text('${basket.length}'),
                        child: Icon(
                          Icons.shopping_basket_rounded,
                          color: empty ? null : context.brand.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        empty
                            ? tr('Konulara dokunarak sepete ekle')
                            : tr('{n} madde · {q} soru', {
                                'n': basket.length,
                                'q': questions,
                              }),
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: empty ? null : Colors.white,
                        ),
                      ),
                    ),
                    if (!empty)
                      FilledButton(
                        onPressed: onOpen,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                        child: Text(tr('Sepeti gör')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BasketSheet extends ConsumerStatefulWidget {
  const _BasketSheet({required this.basket, required this.student});

  final ValueNotifier<List<AssignmentItemDraft>> basket;
  final StudentSummary student;

  @override
  ConsumerState<_BasketSheet> createState() => _BasketSheetState();
}

class _BasketSheetState extends ConsumerState<_BasketSheet> {
  late final _title = TextEditingController(text: _defaultTitle());
  final _note = TextEditingController();
  DateTime? _due = dateOnly(DateTime.now()).add(const Duration(days: 7));
  bool _sending = false;
  String? _error;

  String _defaultTitle() {
    final subjects = {
      for (final i in widget.basket.value) subjectByCode(i.subjectCode).name,
    };
    return subjects.length == 1
        ? tr('{subject} ödevi', {'subject': subjects.first})
        : tr('Haftalık ödev');
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _update(int index, AssignmentItemDraft? d) {
    final list = [...widget.basket.value];
    d == null ? list.removeAt(index) : list[index] = d;
    widget.basket.value = list;
    if (list.isEmpty) Navigator.pop(context);
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = tr('Ödeve bir başlık ver.'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(assignmentRepositoryProvider)
          .sendAssignment(
            studentId: widget.student.id,
            title: _title.text.trim(),
            items: widget.basket.value,
            dueOn: _due,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      ref.invalidate(assignmentsProvider(widget.student.id));
      widget.basket.value = const [];
      if (!mounted) return;
      celebrate(context);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = tr('Gönderilemedi. Tekrar dene.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ValueListenableBuilder(
        valueListenable: widget.basket,
        builder: (context, items, _) {
          final questions = items.fold(0, (s, i) => s + (i.questionCount ?? 0));
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                tr('Ödev sepeti'),
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                tr('{name} için {n} madde · {q} soru', {
                  'name': widget.student.fullName,
                  'n': items.length,
                  'q': questions,
                }),
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final (i, d) in items.indexed)
                Dismissible(
                  key: ValueKey(d.key),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _update(i, null),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: context.brand.danger.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.delete_outline,
                      color: context.brand.danger,
                    ),
                  ),
                  child: _BasketItem(
                    draft: d,
                    onChanged: (n) => _update(i, n),
                    onRemove: () => _update(i, null),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                maxLength: 120,
                decoration: InputDecoration(labelText: tr('Ödev başlığı')),
              ),
              TextField(
                controller: _note,
                maxLines: 3,
                minLines: 1,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: tr('Öğrenciye not (isteğe bağlı)'),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.event_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _due == null
                          ? tr('Son tarih yok')
                          : tr('Son tarih: {date}', {
                              'date': formatLongDate(_due!),
                            }),
                    ),
                  ),
                  TextButton(onPressed: _pickDue, child: Text(tr('Değiştir'))),
                  if (_due != null)
                    IconButton(
                      tooltip: tr('Son tarihi kaldır'),
                      onPressed: () => setState(() => _due = null),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _sending || items.isEmpty ? null : _send,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(tr('Öğrenciye gönder')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BasketItem extends StatelessWidget {
  const _BasketItem({
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final AssignmentItemDraft draft;
  final ValueChanged<AssignmentItemDraft> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = draft.questionCount ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectByCode(draft.subjectCode).name,
                  style: text.labelMedium?.copyWith(
                    color: context.brand.primaryDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  draft.topicName ?? tr('Genel tekrar'),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('Azalt'),
            onPressed: count <= 5
                ? null
                : () => onChanged(draft.copyWith(questionCount: count - 5)),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 56,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Text(
                tr('{n} soru', {'n': count}),
                key: ValueKey(count),
                textAlign: TextAlign.center,
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('Artır'),
            onPressed: count >= 500
                ? null
                : () => onChanged(draft.copyWith(questionCount: count + 5)),
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('Sepetten çıkar'),
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
