import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/constants/grade_levels.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../coach/data/coach_repository.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../data/assignment_repository.dart';
import '../../admin/data/admin_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../whatsapp/data/guardian_messaging_repository.dart';
import 'homework_pdf.dart';
import '../../../core/design/motion.dart';
import '../../../core/design/haptics.dart';

/// Türkçe büyük/küçük harf duyarsız arama için.
String _fold(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();

/// Tek seferde en çok kaç öğrenciye ödev verilir (sunucu sınırıyla aynı).
const _maxStudents = 30;

/// Koçun ödev verme ekranı: öğrenci(ler) → ders → konular → gönder.
/// Ödev konu bazlıdır (soru sayısı yok); her konuya isteğe bağlı kısa hedef
/// yazılabilir. Aynı ödev birden çok öğrenciye verilebilir.
class AssignHomeworkScreen extends ConsumerStatefulWidget {
  const AssignHomeworkScreen({super.key, this.initialStudentId});

  final String? initialStudentId;

  @override
  ConsumerState<AssignHomeworkScreen> createState() =>
      _AssignHomeworkScreenState();
}

class _AssignHomeworkScreenState extends ConsumerState<AssignHomeworkScreen> {
  List<StudentSummary> _students = const [];
  bool _initialApplied = false;
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

  /// 9-11. sınıf öğrencilerinde yalnızca o sınıflarda konusu olan dersler
  /// (null: süzme yok, seçilenlerden biri 12 / mezun).
  Set<String>? _gradeCodes;

  /// Seçilenlerin hepsi Maarif'te: yansıma dersler (AYT_MAT, TYT_TUR…) aynı
  /// konuları çift göstermesin.
  bool _allMaarif = false;

  List<ExamSubject> get _subjects {
    final codes = _gradeCodes;
    if (codes == null) {
      return examSubjects.where((s) => s.examType == _type).toList();
    }
    // 9-11 ve Maarif: TYT / AYT ayrımı yok, konusu olan bütün dersler.
    final some = [
      for (final s in examSubjects)
        if (codes.contains(s.code) &&
            !(_allMaarif && maarifMirrorSubjects.contains(s.code)))
          s,
    ];
    return some.isEmpty
        ? examSubjects.where((s) => s.examType == _type).toList()
        : some;
  }

  void _toggle(AssignmentItemDraft d) {
    final list = [..._basket.value];
    final i = list.indexWhere((x) => x.key == d.key);
    if (i >= 0) {
      list.removeAt(i);
      AppHaptics.select();
    } else {
      list.add(d);
      AppHaptics.confirm();
      _bump++;
    }
    _basket.value = list;
  }

  Future<void> _openSummary() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _SummarySheet(basket: _basket, students: _students),
    );
    if (sent != true || !mounted) return;
    showMessage(
      context,
      _students.length == 1
          ? tr('Ödev {name} adlı öğrenciye gönderildi 🐝', {
              'name': _students.first.fullName,
            })
          : tr('Ödev {n} öğrenciye gönderildi 🐝', {'n': _students.length}),
    );
    if (widget.initialStudentId != null && context.canPop()) {
      context.pop();
    } else {
      setState(() => _students = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentSummariesProvider);
    if (!_initialApplied && widget.initialStudentId != null) {
      final match = students.value
          ?.where((s) => s.id == widget.initialStudentId)
          .firstOrNull;
      if (match != null) {
        _initialApplied = true;
        _students = [match];
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Ödev ver'))),
      body: AnimatedSwitcher(
        duration: AppMotion.base,
        switchInCurve: AppMotion.enter,
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
        child: _students.isEmpty
            ? AsyncView(
                key: const ValueKey('pick'),
                value: students,
                onRetry: () => ref.invalidate(studentSummariesProvider),
                builder: (list) => _StudentPicker(
                  students: list,
                  onContinue: (picked) {
                    AppHaptics.select();
                    setState(() => _students = picked);
                  },
                ),
              )
            : _buildPicker(context),
      ),
      bottomNavigationBar: _students.isEmpty
          ? null
          : ValueListenableBuilder(
              valueListenable: _basket,
              builder: (context, basket, _) =>
                  _BasketBar(basket: basket, bump: _bump, onOpen: _openSummary),
            ),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Seçilen öğrencilerin konuları birleştirilir (aynı konu bir kez).
    final byId = <int, Topic>{};
    var anyFull = false;
    var allMaarif = true;
    for (final s in _students) {
      for (final t
          in ref.watch(studentTopicsProvider(s.id)).value ?? const <Topic>[]) {
        byId[t.id] = t;
      }
      final grade = ref.watch(studentGradeProvider(s.id)).value;
      final curriculum =
          ref.watch(studentCurriculumProvider(s.id)).value ??
          defaultCurriculum(grade);
      // Süzme yalnızca eski müfredatın 12 / mezun öğrencisinde yok; Maarif'te
      // (12. sınıf dahil) yalnızca konusu olan dersler gösterilir.
      if (effectiveGrade(grade) >= 12 && curriculum == curriculumEski) {
        anyFull = true;
      }
      if (curriculum != curriculumMaarif) allMaarif = false;
    }
    final gradeTopics = byId.values.toList();
    _gradeCodes = anyFull ? null : {for (final t in gradeTopics) t.subjectCode};
    _allMaarif = allMaarif;
    if (!_subjects.any((s) => s.code == _subject)) {
      _subject = _subjects.first.code;
    }
    final topics =
        gradeTopics
            .where((t) => t.subjectCode == _subject)
            .where((t) => _fold(t.name).contains(_fold(_topicQuery)))
            .toList()
          ..sort((a, b) => a.sort.compareTo(b.sort));
    final subject = subjectByCode(_subject);

    return Column(
      key: const ValueKey('topics'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectedStudents(
          students: _students,
          onChange: () => setState(() => _students = const []),
        ),
        // TYT / AYT ayrımı yalnızca 12. sınıf / mezun için anlamlı.
        if (_gradeCodes == null)
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
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            itemCount: _subjects.length,
            itemBuilder: (context, i) {
              final s = _subjects[i];
              return Padding(
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
              );
            },
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
              return ListView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                children: [
                  for (final (i, t) in topics.indexed)
                    FadeSlideIn(
                      key: ValueKey('${t.id}'),
                      delay: FadeSlideIn.stagger(i),
                      child: _TopicTile(
                        title: t.name,
                        inBasket: keys.contains('$_subject/${t.id}'),
                        onTap: () => _toggle(
                          AssignmentItemDraft(
                            subjectCode: _subject,
                            topicId: t.id,
                            topicName: t.name,
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
  const _StudentPicker({required this.students, required this.onContinue});

  final List<StudentSummary> students;
  final ValueChanged<List<StudentSummary>> onContinue;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  String _q = '';
  final _picked = <String>{};

  void _toggle(StudentSummary s) {
    setState(() {
      if (_picked.contains(s.id)) {
        _picked.remove(s.id);
      } else if (_picked.length >= _maxStudents) {
        showMessage(
          context,
          tr('En fazla {n} öğrenci seçebilirsin.', {'n': _maxStudents}),
        );
      } else {
        _picked.add(s.id);
      }
    });
    AppHaptics.select();
  }

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
                    final on = _picked.contains(s.id);
                    return FadeSlideIn(
                      key: ValueKey(s.id),
                      delay: FadeSlideIn.stagger(i),
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
                        trailing: Icon(
                          on
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          color: on
                              ? context.brand.success
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onTap: () => _toggle(s),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: FilledButton(
              onPressed: _picked.isEmpty
                  ? null
                  : () => widget.onContinue([
                      for (final s in widget.students)
                        if (_picked.contains(s.id)) s,
                    ]),
              child: Text(
                _picked.length <= 1
                    ? tr('Konu seç')
                    : tr('Konu seç · {n} öğrenci', {'n': _picked.length}),
              ),
            ),
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

class _SelectedStudents extends StatelessWidget {
  const _SelectedStudents({required this.students, required this.onChange});

  final List<StudentSummary> students;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final one = students.length == 1 ? students.first : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              _Initials(
                name: one?.fullName ?? '${students.length}',
                radius: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      one?.fullName ??
                          tr('{n} öğrenci seçildi', {'n': students.length}),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      one != null
                          ? (one.studentNumber == null
                                ? tr('Okul numarası yok')
                                : tr('No {p0}', {'p0': one.studentNumber}))
                          : students.map((s) => s.fullName).join(', '),
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
  });

  final String title;
  final bool inBasket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.base,
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
          title: Text(
            title,
            style: TextStyle(
              fontWeight: inBasket ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          trailing: AnimatedSwitcher(
            duration: AppMotion.base,
            transitionBuilder: (child, a) => ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: AppMotion.enter),
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

// ─────────────────────────────── Özet ───────────────────────────────

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
    final empty = basket.isEmpty;
    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: AppMotion.base,
        curve: AppMotion.enter,
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
                      tween: Tween(begin: bump == 0 ? 1 : 1.15, end: 1),
                      duration: AppMotion.of(context, AppMotion.base),
                      curve: AppMotion.enter,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: Badge(
                        isLabelVisible: !empty,
                        backgroundColor: context.brand.primary,
                        textColor: context.brand.ink,
                        label: Text('${basket.length}'),
                        child: Icon(
                          Icons.checklist_rounded,
                          color: empty ? null : context.brand.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        empty
                            ? tr('Konulara dokunarak seç')
                            : tr('{n} konu seçildi', {'n': basket.length}),
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
                        child: Text(tr('Özete geç')),
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

class _SummarySheet extends ConsumerStatefulWidget {
  const _SummarySheet({required this.basket, required this.students});

  final ValueNotifier<List<AssignmentItemDraft>> basket;
  final List<StudentSummary> students;

  @override
  ConsumerState<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<_SummarySheet> {
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

  /// Konuya isteğe bağlı kısa hedef ("2 test", "konu anlatımı") yazdırır.
  Future<void> _editGoal(int index, AssignmentItemDraft d) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _GoalDialog(draft: d),
    );
    if (result == null || !mounted) return;
    _update(index, d.withNote(result.isEmpty ? null : result));
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
      final title = _title.text.trim();
      final items = widget.basket.value;
      final note = _note.text.trim().isEmpty ? null : _note.text.trim();
      final repo = ref.read(assignmentRepositoryProvider);
      final students = widget.students;
      final ids = students.length == 1
          ? [
              await repo.sendAssignment(
                studentId: students.first.id,
                title: title,
                items: items,
                dueOn: _due,
                note: note,
              ),
            ]
          : await repo.sendAssignmentToMany(
              studentIds: [for (final s in students) s.id],
              title: title,
              items: items,
              dueOn: _due,
              note: note,
            );
      for (final s in students) {
        ref.invalidate(assignmentsProvider(s.id));
      }
      widget.basket.value = const [];
      if (!mounted) return;
      // Veliye PDF (NOTLAR §89): sayfa kapanırken arkada sürer.
      final delivery = await _guardianDelivery(
        assignmentIds: ids,
        title: title,
        items: items,
        note: note,
      );
      if (!mounted) return;
      celebrate(context);
      Navigator.pop(context, true);
      if (delivery != null) unawaited(delivery());
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = tr('Gönderilemedi. Tekrar dene.');
        });
      }
    }
  }

  /// Ödev PDF'lerini velilere (öğrenci öğrenci, sırayla) gönderecek işi
  /// hazırlar. Gereken her şey sayfa kapanmadan okunur; iş bitince sonucu
  /// alttaki bildirimde söyler.
  Future<Future<void> Function()?> _guardianDelivery({
    required List<String> assignmentIds,
    required String title,
    required List<AssignmentItemDraft> items,
    String? note,
  }) async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;
      final accent = context.brand.primaryDeep;
      final repo = ref.read(guardianMessagingRepositoryProvider);
      final me = await ref.read(currentProfileProvider.future);
      String orgName;
      try {
        orgName = (await ref.read(orgProvider.future)).name;
      } catch (_) {
        orgName = '';
      }
      final students = widget.students;
      final due = _due;
      return () async {
        var queued = 0, noPhone = 0, failed = 0;
        for (final (i, s) in students.indexed) {
          try {
            final r = await repo.sendHomeworkPdf(
              assignmentId: assignmentIds[i],
              studentId: s.id,
              buildPdf: () => renderHomeworkPdf(
                orgName: orgName,
                senderName: me?.fullName ?? orgName,
                studentName: s.fullName,
                title: title,
                items: items,
                dueOn: due,
                note: note,
                accent: accent,
                fontFamily: font,
              ),
            );
            switch (r) {
              case HomeworkDelivery.queued:
                queued++;
              case HomeworkDelivery.noPhone:
                noPhone++;
              case HomeworkDelivery.already:
                break;
            }
          } catch (_) {
            failed++;
          }
        }
        final String? message;
        if (students.length == 1) {
          message = failed > 0
              ? tr('Ödev veliye gönderilemedi.')
              : queued > 0
              ? tr("Ödev PDF'i veliye WhatsApp'tan gönderiliyor.")
              : noPhone > 0
              ? tr('Veli telefonu kayıtlı olmadığı için ödev veliye gitmedi.')
              : null;
        } else {
          final parts = [
            if (queued > 0)
              tr("{n} veliye ödev PDF'i WhatsApp'tan gönderiliyor.", {
                'n': queued,
              }),
            if (noPhone > 0)
              tr('{n} velinin telefonu kayıtlı değil.', {'n': noPhone}),
            if (failed > 0) tr('{n} veliye gönderilemedi.', {'n': failed}),
          ];
          message = parts.isEmpty ? null : parts.join(' ');
        }
        // Koç bu arada uygulamadan çıkmış olabilir: gösterecek yer yoksa geç.
        if (message == null || !messenger.mounted) return;
        try {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        } catch (_) {}
      };
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final many = widget.students.length > 1;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ValueListenableBuilder(
        valueListenable: widget.basket,
        builder: (context, items, _) {
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                tr('Ödev özeti'),
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                many
                    ? tr('{n} öğrenci için {k} konu', {
                        'n': widget.students.length,
                        'k': items.length,
                      })
                    : tr('{name} için {k} konu', {
                        'name': widget.students.first.fullName,
                        'k': items.length,
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
                  child: _SummaryItem(
                    draft: d,
                    onGoal: () => _editGoal(i, d),
                    onRemove: () => _update(i, null),
                  ),
                ),
              const SizedBox(height: 8),
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
              // Başlık otomatik gelir; değiştirmek isteyen açar.
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(tr('Başlık ve not')),
                children: [
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
                label: Text(
                  many ? tr('Öğrencilere gönder') : tr('Öğrenciye gönder'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.draft,
    required this.onGoal,
    required this.onRemove,
  });

  final AssignmentItemDraft draft;
  final VoidCallback onGoal;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final note = draft.note;
    final hasNote = note != null && note.isNotEmpty;
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
                if (hasNote) Text(note, style: text.bodySmall),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('Hedef ekle'),
            onPressed: onGoal,
            icon: Icon(
              Icons.edit_note_rounded,
              color: hasNote ? context.brand.primaryDeep : null,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('Listeden çıkar'),
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

/// Konu için isteğe bağlı hedef yazma penceresi (denetleyicisini kendisi
/// yönetir; kapanış animasyonu bitmeden dispose edilmez).
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.draft});

  final AssignmentItemDraft draft;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _controller = TextEditingController(text: widget.draft.note ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return AlertDialog(
      title: Text(d.topicName ?? subjectByCode(d.subjectCode).name),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 300,
        decoration: InputDecoration(
          labelText: tr('Hedef (isteğe bağlı)'),
          hintText: tr('Örn. 2 test çöz, konu anlatımını bitir'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}
