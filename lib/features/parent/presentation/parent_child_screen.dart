import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../account/data/account_repository.dart';
import '../../exams/presentation/exams_screen.dart';
import '../../student/presentation/home_sky.dart';
import '../../tracking/presentation/questions_view.dart';
import '../../tracking/presentation/study_view.dart';
import '../../tracking/presentation/topics_view.dart';

/// Velinin, çocuğunun ayrıntılarını gördüğü ekran: denemeler, sorular,
/// konular ve çalışma süresi sekmeleri (salt okunur).
class ParentChildScreen extends ConsumerWidget {
  const ParentChildScreen({
    super.key,
    required this.childId,
    this.initialTab = 0,
  });

  final String childId;

  /// 0 Denemeler · 1 Sorular · 2 Konular · 3 Süre
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider).value ?? const <ChildRef>[];
    final name = children.where((c) => c.id == childId).firstOrNull?.fullName;

    return DefaultTabController(
      length: 4,
      initialIndex: initialTab.clamp(0, 3),
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
          ],
        ),
      ),
    );
  }
}
