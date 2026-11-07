import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../schedule_generator/presentation/my_timetable.dart';
import '../../announcements/presentation/announcement_widgets.dart';
import '../../../core/branding/branding_providers.dart';
import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../account/data/account_repository.dart';
import '../../assignments/presentation/assignment_widgets.dart';
import '../../admin/presentation/cockpit/cockpit_header.dart';
import '../../admin/presentation/cockpit/cockpit_motion.dart';
import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../admin/presentation/cockpit/metric_card.dart';
import '../../admin/presentation/cockpit/metric_strip.dart';
import '../../admin/presentation/cockpit/section_states.dart';
import '../../admin/presentation/cockpit/week_hero_card.dart';
import '../../../shared/widgets/tool_tile.dart';
import '../../coaching/presentation/coaching_widgets.dart';
import '../../exams/data/exam.dart';
import '../../meetings/data/meeting_repository.dart';
import '../../meetings/presentation/meeting_widgets.dart';
import '../../exams/data/exam_repository.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../../tracking/presentation/study_view.dart';
import '../data/weekly_summary_repository.dart';
import 'weekly_summary_card.dart';

/// Velinin ana ekranı: koç ve müdür panelleriyle aynı kurumsal kokpit
/// (NOTLAR §68). Üstte kurumun adı ve logosu; çocuğun haftası özet
/// kartlarında, ardından haftalık özet, ayrıntılar, hedefler, görüşmeler,
/// görevler ve ödevler (salt okunur). Maskot ve konuşma balonu yok.
class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  String? _childId;

  @override
  Widget build(BuildContext context) =>
      CockpitThemed(child: Builder(builder: _build));

  Widget _build(BuildContext context) {
    final children = ref.watch(childrenProvider);
    final list = children.value ?? const <ChildRef>[];
    final child = list.isEmpty
        ? null
        : list.firstWhere((c) => c.id == _childId, orElse: () => list.first);
    final week = child == null ? null : _ChildWeek.watch(ref, child.id);

    Future<void> refresh() async {
      // Kurum adı/logosu değiştiyse yenilensin.
      ref.invalidate(tenantBrandingProvider);
      ref.invalidate(childrenProvider);
      if (child != null) {
        ref.invalidate(questionLogsProvider(child.id));
        ref.invalidate(studySessionsProvider(child.id));
        ref.invalidate(examsForStudentProvider(child.id));
        ref.invalidate(meetingSchedulesProvider(child.id));
        ref.invalidate(weekMeetingsProvider);
        ref.invalidate(weeklySummaryProvider(child.id));
      }
    }

    final bottom = 32 + MediaQuery.paddingOf(context).bottom;
    final List<Widget> body = children.when(
      skipLoadingOnRefresh: true,
      loading: () => const [
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: HeroStrip(
              hero: SizedBox(height: 132, child: MetricSkeleton()),
              cards: [MetricSkeleton(), MetricSkeleton(), MetricSkeleton()],
            ),
          ),
        ),
      ],
      error: (_, _) => [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SectionError(
                  message: tr(
                    'Veriler yüklenemedi. İnternet bağlantını kontrol et.',
                  ),
                  onRetry: () => ref.invalidate(childrenProvider),
                ),
              ),
            ),
          ),
        ),
      ],
      data: (list) => [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: child == null
                    ? EmptyState(
                        title: tr('Bağlı öğrenci yok'),
                        message: tr(
                          'Çocuğunun profilinden oluşturduğu veli davet koduyla kayıt olduğunda gelişimi burada görünür.',
                        ),
                      )
                    : _ParentBody(
                        children: list,
                        child: child,
                        week: week!,
                        onSelect: (id) => setState(() => _childId = id),
                      ),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: CockpitBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          edgeOffset: 64,
          child: CustomScrollView(
            key: const ValueKey('parent-scroll'),
            physics: cockpitScrollPhysics(),
            slivers: [
              CockpitHeader(
                basePath: '/parent',
                examActions: false,
                showPending: false,
                title: context.brand.appName,
              ),
              ...body,
            ],
          ),
        ),
      ),
    );
  }
}

/// Çocuğun son 7 günü ve TYT denemeleri (özet kutuları ve Bızz için).
class _ChildWeek {
  const _ChildWeek({
    required this.questions,
    required this.minutes,
    required this.activeDays,
    required this.tyt,
  });

  final int questions;
  final int minutes;
  final int activeDays;
  final ExamStats tyt;

  static _ChildWeek watch(WidgetRef ref, String studentId) {
    final logs = ref.watch(questionLogsProvider(studentId)).value ?? const [];
    final sessions =
        ref.watch(studySessionsProvider(studentId)).value ?? const [];
    final exams =
        ref.watch(examsForStudentProvider(studentId)).value ?? const [];
    final weekStart = lastDays(7).first;
    final weekLogs = logs.where((l) => !l.loggedOn.isBefore(weekStart));
    final weekSessions = sessions.where(
      (s) => !s.startedAt.isBefore(weekStart),
    );
    return _ChildWeek(
      questions: weekLogs.fold<int>(0, (s, l) => s + l.total),
      minutes: weekSessions.fold<int>(0, (m, s) => m + s.durationSec) ~/ 60,
      activeDays: {
        ...weekLogs.map((l) => l.loggedOn),
        ...weekSessions.map((s) => dateOnly(s.startedAt)),
      }.length,
      tyt: ExamStats(exams.where((e) => e.examType == ExamType.tyt).toList()),
    );
  }
}

class _ParentBody extends StatelessWidget {
  const _ParentBody({
    required this.children,
    required this.child,
    required this.week,
    required this.onSelect,
  });

  final List<ChildRef> children;
  final ChildRef child;
  final _ChildWeek week;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tyt = week.tyt;
    final first = child.fullName.split(' ').first;
    void open(int tab) => context.push('/parent/child/${child.id}?tab=$tab');
    final n = NumberFormat.decimalPattern(localeTag);
    final change = tyt.lastChange;

    final sections = <Widget>[
      if (children.length > 1)
        SlidingSegments<String>(
          segments: {
            for (final c in children)
              c.id: (
                key: ValueKey('parent-child-${c.id}'),
                label: c.fullName.split(' ').first,
                count: null,
              ),
          },
          value: child.id,
          onChanged: onSelect,
        ),
      HeroStrip(
        hero: WeekHeroCard(
          key: const ValueKey('parent-week'),
          title: tr('{name} bu hafta', {'name': first}),
          active: week.activeDays,
          total: 7,
          caption: tr('gün çalıştı (son 7 gün)'),
          ringLabel: tr('devam'),
          semanticsLabel: tr('Son 7 günün {a} gününde çalıştı', {
            'a': week.activeDays,
          }),
          semanticsHint: tr('Çalışma sürelerini açar'),
          onTap: () => open(3),
        ),
        cards: [
          MetricCard(
            key: const ValueKey('parent-questions'),
            label: tr('Çözülen soru'),
            value: n.format(week.questions),
            count: week.questions,
            format: n.format,
            detail: week.minutes > 0
                ? tr('{t} çalışma', {'t': formatMinutes(week.minutes)})
                : tr('Bu hafta çalışma kaydı yok'),
            semanticsHint: tr('Soru kayıtlarını açar'),
            onTap: () => open(1),
          ),
          MetricCard(
            key: const ValueKey('parent-last-net'),
            label: tr('Son TYT neti'),
            value: tyt.last == null ? '–' : formatNet(tyt.last!.totalNet),
            detail: change == null
                ? tr('Henüz deneme yok')
                : tr('Öncekine göre {d}', {'d': formatChange(change)}),
            tone: change == null
                ? null
                : change >= 0
                ? Tone.good
                : Tone.risk,
            semanticsHint: tr('Denemeleri açar'),
            onTap: () => open(0),
          ),
          MetricCard(
            key: const ValueKey('parent-average'),
            label: tr('TYT ortalaması'),
            value: tyt.recentAverage == null
                ? '–'
                : formatNet(tyt.recentAverage!),
            detail: tr('son 5 deneme'),
            semanticsHint: tr('Denemeleri açar'),
            onTap: () => open(0),
          ),
        ],
      ),
      // Tek kartta hafta: devam, net trendi, ödev.
      WeeklySummaryCard(studentId: child.id, name: child.fullName),
      const MyTimetableCard(),
      // Son 14 günde kurumdan ya da koçtan duyuru geldiyse.
      const AnnouncementsHomeCard(),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CockpitHeading(tr('Ayrıntılar')),
          ToolGrid(
            warnColor: Tone.warn.of(context),
            tools: [
              ToolInfo(
                id: 'parent-exams',
                icon: Icons.fact_check_outlined,
                title: tr('Denemeler'),
                status: tr('Netler ve ders bazında gelişim'),
                open: (_) => open(0),
              ),
              ToolInfo(
                id: 'parent-questions-tool',
                icon: Icons.edit_note_outlined,
                title: tr('Sorular'),
                status: tr('Günlük çözülen soru'),
                open: (_) => open(1),
              ),
              ToolInfo(
                id: 'parent-topics',
                icon: Icons.checklist_outlined,
                title: tr('Konular'),
                status: tr('Biten ve kalan konular'),
                open: (_) => open(2),
              ),
              ToolInfo(
                id: 'parent-time',
                icon: Icons.timer_outlined,
                title: tr('Süre'),
                status: tr('Odaklanılan çalışma süresi'),
                open: (_) => open(3),
              ),
            ],
          ),
        ],
      ),
      GoalsCard(studentId: child.id),
      StudentMeetingsCard(studentId: child.id),
      CockpitSection(
        title: tr('Koçunun verdiği görevler'),
        child: TaskList(
          studentId: child.id,
          viewer: TaskViewer.readOnly,
          emptyText: tr('Şu an görev yok.'),
        ),
      ),
      CockpitSection(
        title: tr('Ödevler'),
        child: AssignmentList(
          studentId: child.id,
          viewer: AssignmentViewer.readOnly,
          limit: 3,
          emptyText: tr('Henüz ödev yok.'),
        ),
      ),
    ];

    return Column(
      key: ValueKey(child.id),
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
