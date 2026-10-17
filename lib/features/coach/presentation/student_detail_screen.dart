import '../../mistakes/presentation/mistake_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../assignments/presentation/assignment_widgets.dart';
import '../../../core/constants/exam_subjects.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';
import '../../coaching/presentation/coaching_widgets.dart';
import '../../exams/presentation/exams_screen.dart';
import '../../learn/presentation/learn_report_view.dart';
import '../../meetings/presentation/meeting_widgets.dart';
import '../../tracking/presentation/questions_view.dart';
import '../../tracking/presentation/study_view.dart';
import '../../tracking/presentation/topics_view.dart';
import '../data/coach_repository.dart';
import '../../../core/i18n/i18n.dart';

/// Koçun (ya da kurum müdürünün) gözünden bir öğrenci.
class StudentDetailScreen extends ConsumerStatefulWidget {
  const StudentDetailScreen({
    super.key,
    required this.studentId,
    this.basePath = '/coach',
  });

  final String studentId;

  /// Rota kökü: `/coach` ya da `/admin`.
  final String basePath;

  @override
  ConsumerState<StudentDetailScreen> createState() =>
      _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  static final _tabs = [
    tr('Özet'),
    tr('Denemeler'),
    tr('Sorular'),
    tr('Konular'),
    tr('Süre'),
    tr('Görevler'),
    tr('Ödevler'),
    tr('Notlar'),
    tr('Hata Defteri'),
    tr('Eğitim'),
  ];
  late final TabController _controller =
      TabController(length: _tabs.length, vsync: this)..addListener(() {
        if (!_controller.indexIsChanging) setState(() {});
      });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Öğrencinin hesabını ve tüm verilerini kalıcı olarak siler. Yanlışlıkla
  /// silinmesin diye "SİL" yazılması istenir.
  Future<void> _deleteStudent(String? name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteStudentDialog(name: name ?? tr('Öğrenci')),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(coachRepositoryProvider).deleteStudent(widget.studentId);
      ref.invalidate(studentSummariesProvider);
      ref.invalidate(deletionRequestsProvider);
      if (!mounted) return;
      showMessage(context, tr('Öğrenci hesabı silindi.'));
      context.go(widget.basePath);
    } catch (e) {
      if (!mounted) return;
      showMessage(
        context,
        '$e'.contains('NOT_ALLOWED')
            ? tr('Bu öğrenciyi silme yetkin yok.')
            : tr('Hesap silinemedi. Tekrar dene.'),
      );
    }
  }

  void _openAddExam(ExamType type) => context.push(
    '${widget.basePath}/students/${widget.studentId}/exams/new?type=${type.db}',
  );

  @override
  Widget build(BuildContext context) {
    final id = widget.studentId;
    final students = ref.watch(studentSummariesProvider).value ?? const [];
    final student = students.where((s) => s.id == id).firstOrNull;
    final role = ref.watch(currentProfileProvider).value?.role;
    final isCoach = role == UserRole.coach;
    final canManage = isCoach || role == UserRole.admin;
    final deletionRequestedAt = canManage
        ? (ref.watch(deletionRequestsProvider).value ?? const {})[id]
        : null;

    final fab = switch (_controller.index) {
      1 when (student?.examCount ?? 0) > 0 => FloatingActionButton.extended(
        onPressed: () => _openAddExam(ExamType.tyt),
        icon: const Icon(Icons.add),
        label: Text(tr('Deneme gir')),
      ),
      5 when isCoach => FloatingActionButton.extended(
        onPressed: () => showAddTaskSheet(context, id),
        icon: const Icon(Icons.add_task),
        label: Text(tr('Görev ver')),
      ),
      6 when canManage => FloatingActionButton.extended(
        onPressed: () =>
            context.push('${widget.basePath}/homework?student=$id'),
        icon: const Icon(Icons.assignment_add),
        label: Text(tr('Ödev ver')),
      ),
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(student?.fullName ?? tr('Öğrenci')),
        actions: [
          if (canManage)
            PopupMenuButton<String>(
              tooltip: tr('Diğer'),
              // Bekleyen hesap silme talebi varsa menüde rozet.
              icon: Badge(
                isLabelVisible: deletionRequestedAt != null,
                backgroundColor: Theme.of(context).colorScheme.error,
                child: const Icon(Icons.more_vert),
              ),
              onSelected: (_) => _deleteStudent(student?.fullName),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.person_remove_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(tr('Öğrenci hesabını sil')),
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final t in _tabs) Tab(text: t)],
        ),
      ),
      floatingActionButton: fab,
      body: Column(
        children: [
          if (deletionRequestedAt != null)
            _DeletionRequestBanner(
              requestedAt: deletionRequestedAt,
              onDelete: () => _deleteStudent(student?.fullName),
            ),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: [
                _OverviewTab(
                  studentId: id,
                  student: student,
                  canEditGoals: isCoach,
                ),
                ExamsView(studentId: id, onAdd: _openAddExam),
                QuestionsView(studentId: id, bottomPadding: 32),
                TopicsView(studentId: id),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [StudyStatsSection(studentId: id)],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    TaskList(
                      studentId: id,
                      viewer: isCoach ? TaskViewer.coach : TaskViewer.readOnly,
                      emptyText: isCoach
                          ? tr('Henüz görev vermedin. "Görev ver"e dokun.')
                          : tr('Henüz görev yok.'),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    AssignmentList(
                      studentId: id,
                      viewer: canManage
                          ? AssignmentViewer.manager
                          : AssignmentViewer.readOnly,
                      emptyText: canManage
                          ? tr('Henüz ödev vermedin. "Ödev ver"e dokun.')
                          : tr('Henüz ödev yok.'),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [NotesList(studentId: id, canWrite: isCoach)],
                ),
                MistakesView(studentId: id, readOnly: true, bottomPadding: 32),
                LearnReportView(studentId: id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Öğrenci hesabının silinmesini istediyse sekmelerin üstünde görünür;
/// "Hesabı sil" mevcut onaylı silme diyaloğunu açar. Karar koçta.
class _DeletionRequestBanner extends StatelessWidget {
  const _DeletionRequestBanner({
    required this.requestedAt,
    required this.onDelete,
  });

  final DateTime requestedAt;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.person_remove_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Hesap silme talebi'),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  Text(
                    tr('{date} tarihinde hesabının silinmesini istedi.', {
                      'date': formatLongDate(requestedAt),
                    }),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: Text(tr('Hesabı sil')),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.studentId,
    required this.student,
    required this.canEditGoals,
  });

  final String studentId;
  final StudentSummary? student;
  final bool canEditGoals;

  @override
  Widget build(BuildContext context) {
    final s = student;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _NumberCard(studentId: studentId, number: s?.studentNumber),
        const SizedBox(height: 12),
        if (s != null) ...[
          StatRow(
            children: [
              StatTile(
                label: tr('Bu hafta'),
                value: '${s.weekQuestions}',
                caption: tr('soru'),
              ),
              StatTile(
                label: tr('Bu hafta'),
                value: formatMinutes(s.weekMinutes),
                caption: tr('çalışma'),
              ),
              StatTile(
                label: tr('Son deneme'),
                value: s.lastTotalNet == null
                    ? '–'
                    : formatNet(s.lastTotalNet!),
                caption: s.lastExamType == null
                    ? tr('henüz yok')
                    : '${s.lastExamType!.label} net',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (s.coachName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                tr('Koçu: {p0}', {'p0': s.coachName}),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
        GoalsCard(studentId: studentId, canEdit: canEditGoals),
        const SizedBox(height: 12),
        // Görüşmeyi yalnızca koç planlar; müdür görür.
        StudentMeetingsCard(studentId: studentId, canManage: canEditGoals),
        const SizedBox(height: 12),
        SectionCard(
          title: tr('Bekleyen görevler'),
          child: TaskList(
            studentId: studentId,
            viewer: TaskViewer.readOnly,
            onlyPending: true,
            emptyText: tr('Bekleyen görev yok.'),
          ),
        ),
      ],
    );
  }
}

class _NumberCard extends ConsumerWidget {
  const _NumberCard({required this.studentId, required this.number});

  final String studentId;
  final String? number;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _NumberDialog(studentId: studentId, initial: number),
    );
    if (saved == true) ref.invalidate(studentSummariesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final missing = number == null;

    return Card(
      child: ListTile(
        leading: Icon(
          missing ? Icons.error_outline : Icons.badge_outlined,
          color: missing ? context.brand.primaryDeep : null,
        ),
        title: Text(
          missing
              ? tr('Okul numarası girilmemiş')
              : tr('Okul no: {number}', {'number': number}),
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(tr('Deneme dosyaları bu numarayla eşleştirilir')),
        trailing: TextButton(
          onPressed: () => _edit(context, ref),
          child: Text(missing ? tr('Ekle') : tr('Değiştir')),
        ),
      ),
    );
  }
}

class _NumberDialog extends ConsumerStatefulWidget {
  const _NumberDialog({required this.studentId, this.initial});

  final String studentId;
  final String? initial;

  @override
  ConsumerState<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends ConsumerState<_NumberDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final value = _controller.text.trim();
      await ref
          .read(coachRepositoryProvider)
          .setStudentNumber(widget.studentId, value.isEmpty ? null : value);
      if (mounted) Navigator.pop(context, true);
    } on StudentNumberException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = tr('Kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Okul numarası')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: tr('ör. 1042'),
          errorText: _error,
          errorMaxLines: 3,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
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

/// "SİL" yazılmadan onaylanamayan silme diyaloğu. Metin denetleyicisi
/// diyaloğun kendisinde: kapanış animasyonu bitince serbest bırakılır.
class _DeleteStudentDialog extends StatefulWidget {
  const _DeleteStudentDialog({required this.name});

  final String name;

  @override
  State<_DeleteStudentDialog> createState() => _DeleteStudentDialogState();
}

class _DeleteStudentDialogState extends State<_DeleteStudentDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmed =>
      const {'SİL', 'SIL'}.contains(_controller.text.trim().toUpperCase());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Öğrenci hesabı silinsin mi?')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(
            '{name} adlı öğrencinin hesabı ve tüm verileri (denemeler, soru kayıtları, ödevler, notlar) kalıcı olarak silinir. Bu işlem geri alınamaz.',
            {'name': widget.name},
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: tr('Onaylamak için SİL yaz')),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(tr('Vazgeç')),
      ),
      TextButton(
        onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        child: Text(tr('Kalıcı olarak sil')),
      ),
    ],
  );
}
