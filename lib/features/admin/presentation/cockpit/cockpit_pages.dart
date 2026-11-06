import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../auth/data/profile.dart';
import '../../../coach/data/coach_repository.dart';
import '../../../coach/presentation/exam_trends_card.dart';
import '../../../coach/presentation/manager_widgets.dart';
import '../../../coach/presentation/risk_card.dart';
import '../../../meetings/presentation/meeting_widgets.dart';
import '../../../tracking/presentation/study_view.dart' show formatMinutes;
import '../../data/admin_repository.dart';
import '../admin_home_screen.dart' show showInviteCodeDialog;
import 'cockpit_motion.dart';
import 'cockpit_theme.dart';
import 'section_states.dart';

/// Kokpitten açılan tek kartlık sayfa (risk listesi, deneme trendleri,
/// koç görüşmeleri): eski paneldeki kartlar aynen.
class CockpitCardPage extends StatelessWidget {
  const CockpitCardPage({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => CockpitThemed(
    child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [child],
      ),
    ),
  );
}

class RiskPage extends StatelessWidget {
  const RiskPage({super.key});

  @override
  Widget build(BuildContext context) => CockpitCardPage(
    title: tr('Risk listesi'),
    child: const RiskCard(basePath: '/admin'),
  );
}

class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key, this.basePath = '/admin'});

  final String basePath;

  @override
  Widget build(BuildContext context) => CockpitCardPage(
    title: tr('Deneme trendleri'),
    child: ExamTrendsCard(basePath: basePath),
  );
}

class MeetingsPage extends ConsumerWidget {
  const MeetingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(orgMembersProvider);
    return CockpitCardPage(
      title: tr('Koç görüşmeleri'),
      child: CockpitAsync(
        value: members,
        onRetry: () => ref.invalidate(orgMembersProvider),
        builder: (all) => CoachMeetingsReport(
          coaches: [
            for (final m in all)
              if (m.role == UserRole.coach) (m.id, m.fullName),
          ],
        ),
      ),
    );
  }
}

enum ActivityView { inactive, questions }

/// Bu haftanın etkinliği: çalışmayanlar (eski "Bu hafta hareketsiz
/// öğrenciler") ya da soru sayısına göre sıralı tüm öğrenciler.
class WeekActivityPage extends ConsumerStatefulWidget {
  const WeekActivityPage({
    super.key,
    this.initial = ActivityView.inactive,
    this.basePath = '/admin',
    this.onInvite,
  });

  final ActivityView initial;
  final String basePath;

  /// Öğrenci yokken davet (koç: davet sayfası). Verilmezse müdür davet
  /// penceresi.
  final void Function(BuildContext context)? onInvite;

  @override
  ConsumerState<WeekActivityPage> createState() => _WeekActivityPageState();
}

class _WeekActivityPageState extends ConsumerState<WeekActivityPage> {
  late ActivityView _view = widget.initial;

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentSummariesProvider);
    final deletion = ref.watch(deletionRequestsProvider).value ?? const {};
    return CockpitThemed(
      child: Scaffold(
        appBar: AppBar(title: Text(tr('Bu haftanın çalışması'))),
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(studentSummariesProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              CockpitAsync(
                value: students,
                onRetry: () => ref.invalidate(studentSummariesProvider),
                builder: (all) {
                  final inactive = [
                    for (final s in all)
                      if (!s.activeThisWeek) s,
                  ];
                  final sorted = [
                    ...all,
                  ]..sort((a, b) => b.weekQuestions.compareTo(a.weekQuestions));
                  final list = _view == ActivityView.inactive
                      ? inactive
                      : sorted;
                  final maxQ = sorted.isEmpty ? 0 : sorted.first.weekQuestions;
                  final totalMin = all.fold<int>(
                    0,
                    (a, s) => a + s.weekMinutes,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SlidingSegments<ActivityView>(
                        value: _view,
                        onChanged: (v) => setState(() => _view = v),
                        segments: {
                          ActivityView.inactive: (
                            key: const ValueKey('activity-inactive'),
                            label: tr('Çalışmayanlar · {n}', {
                              'n': inactive.length,
                            }),
                            count: null,
                          ),
                          ActivityView.questions: (
                            key: const ValueKey('activity-questions'),
                            label: tr('Soru sırası'),
                            count: null,
                          ),
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _view == ActivityView.inactive
                            ? tr(
                                'Son 7 günde soru ya da çalışma kaydı olmayanlar',
                              )
                            : tr('Son 7 gün · toplam {t} çalışma', {
                                't': formatMinutes(totalMin),
                              }),
                        style: cockpitLabel(context),
                      ),
                      const SizedBox(height: 10),
                      if (all.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SectionEmpty(
                              icon: Icons.school_outlined,
                              message: tr('Kurumda henüz öğrenci yok.'),
                              actionLabel: tr('Öğrenci davet et'),
                              actionIcon: Icons.person_add_alt_1,
                              onAction: () => widget.onInvite != null
                                  ? widget.onInvite!(context)
                                  : showInviteCodeDialog(
                                      context,
                                      ref,
                                      role: UserRole.student,
                                    ),
                            ),
                          ),
                        )
                      else if (list.isEmpty)
                        Card(
                          child: ListTile(
                            key: const ValueKey('activity-all-active'),
                            leading: Icon(
                              Icons.check_circle_outline,
                              color: context.cockpit.good,
                            ),
                            title: Text(tr('Herkes bu hafta çalışmış.')),
                          ),
                        )
                      else
                        for (final s in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: StudentCard(
                              key: ValueKey('activity-${s.id}'),
                              student: s,
                              showCoach: true,
                              maxWeekQuestions: maxQ,
                              deletionRequested: deletion.containsKey(s.id),
                              onTap: () => context.push(
                                '${widget.basePath}/students/${s.id}',
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
