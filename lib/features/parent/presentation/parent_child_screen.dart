import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../account/data/account_repository.dart';
import '../../exams/presentation/exams_screen.dart';
import '../../student/presentation/home_sky.dart';
import '../../tracking/presentation/questions_view.dart';
import '../../tracking/presentation/study_view.dart';
import '../../tracking/presentation/topics_view.dart';
import '../../exams/data/exam_repository.dart';
import '../../plan/presentation/plan_widgets.dart';
import '../../mistakes/presentation/mistake_widgets.dart';
import '../../recap/data/week_recap.dart';
import '../../recap/presentation/recap_story_screen.dart';
import '../../tracking/data/tracking_repository.dart';

/// Velinin, çocuğunun ayrıntılarını gördüğü ekran: denemeler, sorular,
/// konular ve çalışma süresi sekmeleri (salt okunur).
class ParentChildScreen extends ConsumerWidget {
  const ParentChildScreen({
    super.key,
    required this.childId,
    this.initialTab = 0,
  });

  final String childId;

  /// 0 Denemeler · 1 Sorular · 2 Konular · 3 Süre · 4 Bal Raporu ·
  /// 5 Hata Defteri
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider).value ?? const <ChildRef>[];
    final name = children.where((c) => c.id == childId).firstOrNull?.fullName;

    return DefaultTabController(
      length: 7,
      initialIndex: initialTab.clamp(0, 6),
      child: Scaffold(
        appBar: SkyAppBar(
          title: Text(name ?? tr('Gelişim')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: tr('Denemeler')),
              Tab(text: tr('Sorular')),
              Tab(text: tr('Konular')),
              Tab(text: tr('Süre')),
              Tab(text: tr('Bal Raporu')),
              Tab(text: tr('Hata Defteri')),
              Tab(text: tr('Plan')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ExamsView(studentId: childId),
            QuestionsView(studentId: childId, bottomPadding: 32),
            TopicsView(studentId: childId),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [StudyStatsSection(studentId: childId)],
            ),
            _ParentRecap(childId: childId, name: name),
            MistakesView(studentId: childId, readOnly: true, bottomPadding: 32),
            WeeklyPlanView(studentId: childId),
          ],
        ),
      ),
    );
  }
}

/// Velinin gördüğü haftalık özet: çocuğun son 7 günü, paylaşılabilir kart.
class _ParentRecap extends ConsumerWidget {
  const _ParentRecap({required this.childId, this.name});

  final String childId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recap = WeekRecap.compute(
      logs: ref.watch(questionLogsProvider(childId)).value ?? const [],
      sessions: ref.watch(studySessionsProvider(childId)).value ?? const [],
      exams: ref.watch(examsForStudentProvider(childId)).value ?? const [],
      now: DateTime.now(),
    );
    final first = (name ?? '').split(' ').first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Center(
          child: FittedBox(
            child: RecapShareCard(recap: recap, name: first, subject: null),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          recap.isEmpty
              ? tr(
                  'Bu hafta henüz kayıt yok. Küçük bir teşvik iyi gelebilir! 💛',
                )
              : tr('Her pazar akşamı bu özeti bildirim olarak da alırsın.'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
