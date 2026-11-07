import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../announcements/data/announcement_repository.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../coach/data/coach_repository.dart';
import '../../../coach/data/exam_trends.dart';
import '../../../coach/data/risk_repository.dart';
import '../../../credits/data/org_credits_repository.dart';
import '../../../exam_import/data/exam_admin_repository.dart';
import '../../../finance/data/finance_repository.dart';
import '../../../meetings/data/meeting_repository.dart';
import '../../../ranking/data/ranking_repository.dart';
import '../../../schedule_generator/data/timetable_repository.dart';
import '../../../student_books/data/books_repository.dart';
import '../../../student_management/data/student_management_repository.dart';
import '../../data/admin_repository.dart';
import '../../data/cockpit_repository.dart';
import 'activity_trend_card.dart';
import 'attention_section.dart';
import 'coach_performance_section.dart';
import 'cockpit_header.dart';
import 'cockpit_motion.dart';
import 'cockpit_theme.dart';
import 'metric_strip.dart';
import 'org_settings_card.dart';
import 'org_tools_section.dart';

/// Müdür kokpiti ("Genel" sekmesi): yukarıdan aşağıya üst çubuk, eşik
/// bantları, özet şeridi, dikkat gerektirenler, 8 haftalık eğilim, koç performansı, kurum
/// araçları ve kurum ayarları. Her bölüm kendi verisini ayrı yükler.
class CockpitTab extends ConsumerWidget {
  const CockpitTab({
    super.key,
    required this.onGoTo,
    required this.onInviteStudent,
    required this.onInviteCoach,
    required this.onInviteStudentForCoach,
    required this.hasBottomNav,
  });

  /// Sekme değiştirir (1: Öğrenciler).
  final ValueChanged<int> onGoTo;
  final VoidCallback onInviteStudent;
  final VoidCallback onInviteCoach;
  final ValueChanged<String> onInviteStudentForCoach;

  /// Altta gezinme çubuğu varsa liste sonuna onun yüksekliği + 16 boşluk.
  final bool hasBottomNav;

  static void refreshAll(WidgetRef ref) {
    ref.invalidate(cockpitProvider);
    ref.invalidate(activityWeeksProvider);
    ref.invalidate(orgProvider);
    ref.invalidate(orgCreditsProvider);
    ref.invalidate(orgCodeProvider);
    ref.invalidate(orgMembersProvider);
    ref.invalidate(studentSummariesProvider);
    ref.invalidate(riskListProvider);
    ref.invalidate(examTrendsProvider);
    ref.invalidate(attendanceDayProvider);
    ref.invalidate(schedulesProvider);
    ref.invalidate(managedStudentsProvider);
    ref.invalidate(successStatusProvider);
    ref.invalidate(meetingSchedulesProvider);
    ref.invalidate(weekMeetingsProvider);
    ref.invalidate(financeFeesProvider);
    ref.invalidate(orgExamsProvider);
    ref.invalidate(bookPoolProvider);
    ref.invalidate(announcementsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(cockpitProvider).value?.students ?? 0;
    final bottom =
        (hasBottomNav ? cockpitNavHeight : 0) +
        16 +
        MediaQuery.paddingOf(context).bottom;

    final sections = <Widget>[
      OrgAlertBanner(students: students),
      MetricStrip(onOpenStudents: () => onGoTo(1)),
      AttentionSection(onInviteStudent: onInviteStudent),
      ActivityTrendCard(onInviteStudent: onInviteStudent),
      CoachPerformanceSection(
        onInviteCoach: onInviteCoach,
        onInviteStudent: onInviteStudentForCoach,
      ),
      OrgToolsSection(onOpenStudents: () => onGoTo(1)),
      const OrgSettingsCard(),
    ];

    return CockpitBackground(
      child: RefreshIndicator(
        edgeOffset: 64,
        onRefresh: () async {
          refreshAll(ref);
          await ref.read(cockpitProvider.future).catchError((Object _) {
            return const CockpitData(
              students: 0,
              studentsPrev: 0,
              active: 0,
              activePrev: 0,
              questions: 0,
              questionsPrev: 0,
              minutes: 0,
              minutesPrev: 0,
            );
          });
        },
        child: CustomScrollView(
          key: const ValueKey('cockpit-scroll'),
          physics: cockpitScrollPhysics(),
          slivers: [
            const CockpitHeader(),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
              sliver: SliverList.separated(
                itemCount: sections.length,
                separatorBuilder: (_, i) =>
                    // Bant yoksa boşluk da olmasın.
                    SizedBox(height: i == 0 ? 0 : 14),
                // Bölümler sırayla süzülerek belirir.
                itemBuilder: (_, i) => Reveal(index: i, child: sections[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
