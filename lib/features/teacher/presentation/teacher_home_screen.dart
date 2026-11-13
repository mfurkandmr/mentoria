import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/branding_providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/panel.dart';
import '../../admin/presentation/cockpit/cockpit_header.dart';
import '../../admin/presentation/cockpit/cockpit_motion.dart';
import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../admin/presentation/cockpit/metric_card.dart';
import '../../admin/presentation/cockpit/metric_strip.dart';
import '../../admin/presentation/cockpit/section_states.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../../schedule_generator/domain/models.dart';
import '../../schedule_generator/presentation/timetable_format.dart';
import '../../student_schedule/data/student_schedule.dart';
import '../../tutoring/data/tutoring_repository.dart';
import '../../tutoring/presentation/teacher_tutoring_section.dart';
import '../data/teacher_repository.dart';

/// Öğretmenin ana ekranı (NOTLAR §86): kokpit dilinde bugünkü dersleri,
/// haftalık ders yükü, branşları ve programına giriş. Öğrenci verisi yok;
/// öğrenci takibi koçlarda.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CockpitThemed(child: Builder(builder: (c) => _build(c, ref)));

  Widget _build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myTeacherProvider);
    final lessons = ref.watch(myTimetableProvider);

    Future<void> refresh() async {
      ref.invalidate(tenantBrandingProvider);
      ref.invalidate(myTimetableProvider);
      ref.invalidate(myTutoringSessionsProvider);
      ref.invalidate(teacherTutoringRequestsProvider);
      final _ = await ref.refresh(myTeacherProvider.future);
    }

    final bottom = 32 + MediaQuery.paddingOf(context).bottom;
    final Widget body = me.when(
      skipLoadingOnRefresh: true,
      loading: () => const MetricGrid([MetricSkeleton(), MetricSkeleton()]),
      error: (_, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SectionError(
            message: tr('Veriler yüklenemedi. İnternet bağlantını kontrol et.'),
            onRetry: () => ref.invalidate(myTeacherProvider),
          ),
        ),
      ),
      data: (teacher) => teacher == null
          ? EmptyState(
              title: tr('Öğretmen kaydın bulunamadı'),
              message: tr(
                'Kurumdaki öğretmen kaydın silinmiş olabilir. Kurum müdürüne ulaş.',
              ),
            )
          : _TeacherBody(
              teacher: teacher,
              lessons: lessons,
              onRetryLessons: () => ref.invalidate(myTimetableProvider),
            ),
    );

    return Scaffold(
      body: CockpitBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          edgeOffset: 64,
          child: CustomScrollView(
            key: const ValueKey('teacher-scroll'),
            physics: cockpitScrollPhysics(),
            slivers: [
              CockpitHeader(
                basePath: '/teacher',
                examActions: false,
                showPending: false,
                title: context.brand.appName,
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherBody extends StatelessWidget {
  const _TeacherBody({
    required this.teacher,
    required this.lessons,
    required this.onRetryLessons,
  });

  final MyTeacher teacher;
  final AsyncValue<List<TimetableItem>> lessons;
  final VoidCallback onRetryLessons;

  @override
  Widget build(BuildContext context) {
    final list = lessons.value ?? const <TimetableItem>[];
    final now = DateTime.now();
    final today = [
      for (final i in list)
        if (i.day == now.weekday) i,
    ]..sort((a, b) => a.seq.compareTo(b.seq));
    final (current, next) = currentAndNext(today, now);
    final classes = {for (final i in list) i.classroomName};

    final sections = <Widget>[
      Text(
        tr('Merhaba, {name}', {'name': teacher.fullName.split(' ').first}),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      MetricGrid([
        MetricCard(
          key: const ValueKey('teacher-today'),
          label: tr('Bugünkü ders'),
          value: '${today.length}',
          count: today.length,
          detail: current != null
              ? tr('Şimdi: {b} · {c}', {
                  'b': current.branch,
                  'c': current.classroomName,
                })
              : next != null
              ? tr('Sıradaki {t}: {b}', {
                  't': formatClock(next.start),
                  'b': next.branch,
                })
              : tr('Bugün dersin bitti ya da yok'),
          semanticsHint: tr('Haftalık programı açar'),
          onTap: () => context.push('/teacher/timetable'),
        ),
        MetricCard(
          key: const ValueKey('teacher-week'),
          label: tr('Haftalık ders saati'),
          value: '${list.length}',
          count: list.length,
          detail: classes.isEmpty
              ? tr('Yayında program yok')
              : tr('{n} sınıf', {'n': classes.length}),
          semanticsHint: tr('Haftalık programı açar'),
          onTap: () => context.push('/teacher/timetable'),
        ),
      ]),
      CockpitSection(
        title: tr('Bugün'),
        subtitle: dayLong(now.weekday),
        trailing: TextButton(
          onPressed: () => context.push('/teacher/timetable'),
          child: Text(tr('Haftalık program')),
        ),
        child: CockpitAsync<List<TimetableItem>>(
          value: lessons,
          onRetry: onRetryLessons,
          builder: (_) => today.isEmpty
              ? Text(
                  list.isEmpty
                      ? tr(
                          'Kurum ders programını yayınlayınca derslerin burada görünür.',
                        )
                      : tr('Bugün dersin yok.'),
                  style: cockpitLabel(context),
                )
              : Column(
                  children: [
                    for (final i in today)
                      _LessonRow(item: i, now: identical(i, current)),
                  ],
                ),
        ),
      ),
      const TeacherTutoringSection(),
      _BranchesCard(teacher: teacher),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in sections.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          Reveal(index: i, child: c),
        ],
      ],
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.item, required this.now});

  final TimetableItem item;
  final bool now;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 6,
          height: 40,
          decoration: BoxDecoration(
            color: branchColor(item.branch),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          child: Text(
            '${formatClock(item.start)}–${formatClock(item.end)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            [
              item.branch,
              item.classroomName,
              if (item.roomName != null) item.roomName!,
            ].join(' · '),
          ),
        ),
        if (now)
          InfoPill(
            icon: Icons.play_arrow_rounded,
            text: tr('Şimdi'),
            color: context.cockpit.good,
          ),
      ],
    ),
  );
}

class _BranchesCard extends ConsumerWidget {
  const _BranchesCard({required this.teacher});

  final MyTeacher teacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CockpitSection(
    title: tr('Branşlarım'),
    subtitle: teacher.needsBranches
        ? tr('Branşını seç; ders programı buna göre hazırlanır.')
        : teacher.orgName,
    trailing: TextButton(
      key: const ValueKey('teacher-edit-branches'),
      onPressed: () => showBranchesDialog(context, ref, teacher.branches),
      child: Text(tr('Düzenle')),
    ),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final b in teacher.branches)
          InfoPill(icon: Icons.menu_book_outlined, text: b),
      ],
    ),
  );
}

/// Branş seçimi: hazır liste + kendi yazdığı; en az bir, en çok 8.
Future<void> showBranchesDialog(
  BuildContext context,
  WidgetRef ref,
  List<String> current,
) => showDialog<void>(
  context: context,
  builder: (_) => _BranchesDialog(
    initial: {
      for (final b in current)
        if (b != 'Genel') b,
    },
  ),
);

class _BranchesDialog extends ConsumerStatefulWidget {
  const _BranchesDialog({required this.initial});

  final Set<String> initial;

  @override
  ConsumerState<_BranchesDialog> createState() => _BranchesDialogState();
}

class _BranchesDialogState extends ConsumerState<_BranchesDialog> {
  late final Set<String> _selected = {...widget.initial};
  final _other = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(teacherRepositoryProvider)
          .setMyBranches(_selected.toList());
      ref.invalidate(myTeacherProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addOther() {
    final v = _other.text.trim();
    if (v.isEmpty || _selected.length >= 8) return;
    setState(() {
      _selected.add(v.length > 40 ? v.substring(0, 40) : v);
      _other.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = {...commonBranches, ..._selected}.toList();
    return AlertDialog(
      title: Text(tr('Branşlarım')),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in options)
                    FilterChip(
                      key: ValueKey('branch-$b'),
                      label: Text(b),
                      selected: _selected.contains(b),
                      onSelected: (on) => setState(() {
                        if (on && _selected.length < 8) {
                          _selected.add(b);
                        } else {
                          _selected.remove(b);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _other,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: tr('Başka bir branş'),
                  suffixIcon: IconButton(
                    tooltip: tr('Ekle'),
                    icon: const Icon(Icons.add),
                    onPressed: _addOther,
                  ),
                ),
                onSubmitted: (_) => _addOther(),
              ),
              if (_selected.isEmpty)
                Text(
                  tr('En az bir branş seç.'),
                  style: TextStyle(color: context.cockpit.warn),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        TextButton(
          key: const ValueKey('teacher-save-branches'),
          onPressed: _saving || _selected.isEmpty ? null : _save,
          child: Text(tr('Kaydet')),
        ),
      ],
    );
  }
}
