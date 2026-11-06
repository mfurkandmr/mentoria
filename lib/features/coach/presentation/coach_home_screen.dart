import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/branding/branding_providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/tool_tile.dart';
import '../../admin/data/admin_repository.dart';
import '../../admin/data/cockpit_repository.dart';
import '../../admin/presentation/cockpit/activity_trend_card.dart';
import '../../admin/presentation/cockpit/cockpit_header.dart';
import '../../admin/presentation/cockpit/cockpit_motion.dart';
import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../admin/presentation/cockpit/week_hero_card.dart';
import '../../admin/presentation/cockpit/metric_card.dart';
import '../../admin/presentation/cockpit/metric_strip.dart';
import '../../admin/presentation/cockpit/org_tools_section.dart';
import '../../admin/presentation/cockpit/section_states.dart';
import '../../announcements/data/announcement_repository.dart';
import '../../announcements/presentation/announcement_widgets.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/presentation/attendance_screen.dart';
import '../../credits/data/org_credits_repository.dart';
import '../../credits/presentation/credit_widgets.dart';
import '../../exam_import/data/exam_admin_repository.dart';
import '../../exam_import/presentation/org_exams_screen.dart';
import '../../meetings/data/meeting_repository.dart';
import '../../meetings/presentation/meeting_widgets.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../../schedule_generator/presentation/my_timetable.dart';
import '../../student_books/data/books_repository.dart';
import '../../student_books/presentation/book_pool_screen.dart';
import '../../student_management/data/student_management_repository.dart';
import '../../student_management/presentation/students_screen.dart';
import '../../tracking/presentation/study_view.dart' show formatMinutes;
import '../data/coach_repository.dart';
import '../data/exam_trends.dart';
import '../data/risk_repository.dart';
import 'invite_sheet.dart';
import 'manager_widgets.dart';
import 'risk_card.dart';

/// Koçun ana ekranı: müdür kokpitiyle aynı sade dil (NOTLAR §60). Üst çubuk
/// (kurum logosu, adı, tarih), özet şeridi, bu hafta konuşulacaklar,
/// görüşmeler, 8 haftalık eğilim, kısayollar, duyurular ve öğrenciler.
/// Alt çubuktaki düğmeler sayfa değil eylemdir (davet, ödev, yükle, denemeler).
class CoachHomeScreen extends ConsumerWidget {
  const CoachHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CockpitThemed(child: Builder(builder: (context) => _build(context, ref)));

  Widget _build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentSummariesProvider);

    Future<void> refresh() {
      // Kurum adı/logosu değiştiyse yenilensin.
      ref.invalidate(tenantBrandingProvider);
      invalidateMeetings(ref);
      ref.invalidate(deletionRequestsProvider);
      ref.invalidate(orgCreditsProvider);
      ref.invalidate(riskListProvider);
      ref.invalidate(attendanceDayProvider);
      ref.invalidate(myTimetableProvider);
      ref.invalidate(managedStudentsProvider);
      ref.invalidate(activityWeeksProvider);
      ref.invalidate(examTrendsProvider);
      ref.invalidate(bookPoolProvider);
      ref.invalidate(orgExamsProvider);
      ref.invalidate(announcementsProvider);
      ref.invalidate(orgProvider);
      return ref.refresh(studentSummariesProvider.future);
    }

    final bottom = cockpitNavHeight + 16 + MediaQuery.paddingOf(context).bottom;

    final List<Widget> body = students.when(
      skipLoadingOnRefresh: true,
      loading: () => [
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                MetricGrid([
                  MetricSkeleton(),
                  MetricSkeleton(),
                  MetricSkeleton(),
                  MetricSkeleton(),
                ]),
                SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SectionSkeleton(),
                  ),
                ),
              ],
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
                  message: tr('Öğrenciler yüklenemedi.'),
                  onRetry: () => ref.invalidate(studentSummariesProvider),
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
            child: _CoachBody(
              students: list,
              deletionRequests:
                  ref.watch(deletionRequestsProvider).value ?? const {},
              onInvite: () => openInviteSheet(context),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      // Alt çubuk: eylem kısayolları (sekme değil); "Ana sayfa" hep seçili.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.cockpit.border)),
        ),
        child: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (i) {
            switch (i) {
              case 1:
                openInviteSheet(context);
              case 2:
                context.push('/coach/homework');
              case 3:
                context.push('/coach/import');
              case 4:
                context.push('/coach/exams');
            }
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: tr('Ana Sayfa'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: tr('Davet et'),
              tooltip: tr('Öğrenci davet et'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.assignment_add),
              label: tr('Ödev ver'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.upload_file_outlined),
              label: tr('Yükle'),
              tooltip: tr('Deneme sonuçlarını yükle'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.fact_check_outlined),
              label: tr('Denemeler'),
              tooltip: tr('Yüklediğin denemeler'),
            ),
          ],
        ),
      ),
      body: CockpitBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          edgeOffset: 64,
          child: CustomScrollView(
            key: const ValueKey('coach-scroll'),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              const CockpitHeader(basePath: '/coach', examActions: false),
              ...body,
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachBody extends ConsumerStatefulWidget {
  const _CoachBody({
    required this.students,
    required this.onInvite,
    this.deletionRequests = const {},
  });

  final List<StudentSummary> students;

  /// Öğrenci kimliği → silme talebi tarihi.
  final Map<String, DateTime> deletionRequests;
  final VoidCallback onInvite;

  @override
  ConsumerState<_CoachBody> createState() => _CoachBodyState();
}

class _CoachBodyState extends ConsumerState<_CoachBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final students = widget.students;
    final maxWeek = students.fold<int>(
      0,
      (a, s) => s.weekQuestions > a ? s.weekQuestions : a,
    );
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? students
        : students
              .where(
                (s) =>
                    s.fullName.toLowerCase().contains(q) ||
                    (s.studentNumber?.toLowerCase().contains(q) ?? false),
              )
              .toList();
    final timetable = myTimetableTool(ref);

    final sections = <Widget>[
      _CoachMetrics(students: students),
      MissingNumbersNotice(onTap: () => context.push('/coach/roster')),
      const RiskCard(basePath: '/coach'),
      const WeekMeetingsSection(),
      ActivityTrendCard(onInviteStudent: widget.onInvite),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CockpitHeading(tr('Kısayollar')),
          ToolGrid(
            warnColor: Tone.warn.of(context),
            tools: [
              ToolInfo(
                id: 'tool-optic',
                icon: Icons.document_scanner_outlined,
                title: tr('Optik oku'),
                status: tr('Optik formları telefonla oku'),
                open: (c) => c.push('/coach/optic'),
              ),
              attendanceTool(ref, '/coach'),
              ?timetable,
              studentsTool(ref, '/coach'),
              orgExamsTool(ref, '/coach'),
              trendsTool('/coach'),
              bookPoolTool(ref, '/coach'),
            ],
          ),
        ],
      ),
      const AnnouncementsHomeCard(),
      CockpitSection(
        key: const ValueKey('section-my-students'),
        title: tr('Öğrencilerin'),
        subtitle: tr('{p0} öğrencin var', {'p0': students.length}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (students.isEmpty)
              SectionEmpty(
                icon: Icons.school_outlined,
                message: tr(
                  'Henüz öğrencin yok. Bir davet kodu oluştur ve öğrencine gönder; kodla kayıt olan öğrenci otomatik olarak sana bağlanır.',
                ),
                actionLabel: tr('Öğrenci davet et'),
                actionIcon: Icons.person_add_alt_1,
                onAction: widget.onInvite,
              ),
            if (students.length > 5) ...[
              TextField(
                decoration: InputDecoration(
                  hintText: tr('Öğrenci adı veya numarası ara'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
            ],
            for (final (i, s) in visible.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              StudentCard(
                key: ValueKey(s.id),
                student: s,
                maxWeekQuestions: maxWeek,
                deletionRequested: widget.deletionRequests.containsKey(s.id),
                onTap: () => context.push('/coach/students/${s.id}'),
              ),
            ],
            if (students.isNotEmpty && visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr('"{_query}" ile eşleşen öğrenci yok.', {'_query': _query}),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kredi 50'nin altındaysa; değilse yer kaplamaz.
        const LowCreditBanner(padding: EdgeInsets.only(bottom: 12)),
        for (final (i, c) in sections.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          Reveal(index: i, child: c),
        ],
      ],
    );
  }
}

/// Koçun özet şeridi: öğrencilerim, bu hafta aktif, bu hafta soru,
/// bekleyen görev. Geçen haftaya göre değişim eğilim verisinden.
class _CoachMetrics extends ConsumerWidget {
  const _CoachMetrics({required this.students});

  final List<StudentSummary> students;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = NumberFormat.decimalPattern(localeTag);
    final weeks = ref.watch(activityWeeksProvider).value;
    final last = weeks != null && weeks.length >= 2
        ? (weeks[weeks.length - 1], weeks[weeks.length - 2])
        : null;
    final total = students.length;
    final active = students.where((s) => s.activeThisWeek).length;
    final questions = students.fold<int>(0, (a, s) => a + s.weekQuestions);
    final minutes = students.fold<int>(0, (a, s) => a + s.weekMinutes);
    final pending = students.fold<int>(0, (a, s) => a + s.pendingTasks);

    return HeroStrip(
      hero: WeekHeroCard(
        key: const ValueKey('coach-metric-active'),
        active: active,
        total: total,
        delta: last == null
            ? null
            : MetricDelta.between(last.$1.active, last.$2.active),
        onTap: () => context.push('/coach/activity'),
      ),
      cards: [
        MetricCard(
          key: const ValueKey('coach-metric-students'),
          label: tr('Öğrencilerim'),
          value: n.format(total),
          count: total,
          format: n.format,
          delta: last == null
              ? null
              : MetricDelta.between(last.$1.students, last.$2.students),
          semanticsHint: tr('Öğrencileri soru sayısına göre sıralar'),
          onTap: () => context.push('/coach/activity?sort=questions'),
        ),
        MetricCard(
          key: const ValueKey('coach-metric-questions'),
          label: tr('Bu hafta çözülen soru'),
          value: n.format(questions),
          count: questions,
          format: n.format,
          detail: minutes > 0
              ? tr('{t} çalışma', {'t': formatMinutes(minutes)})
              : null,
          delta: last == null
              ? null
              : MetricDelta.between(
                  last.$1.questions,
                  last.$2.questions,
                  percent: true,
                ),
          semanticsHint: tr('Öğrencileri soru sayısına göre sıralar'),
          onTap: () => context.push('/coach/activity?sort=questions'),
        ),
        MetricCard(
          key: const ValueKey('coach-metric-pending'),
          label: tr('Bekleyen görev'),
          value: n.format(pending),
          count: pending,
          format: n.format,
          detail: tr('öğrencilerinde yapılmamış'),
          semanticsHint: tr('Ödev verme ekranını açar'),
          onTap: () => context.push('/coach/homework'),
        ),
      ],
    );
  }
}
