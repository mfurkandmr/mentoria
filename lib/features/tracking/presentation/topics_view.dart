import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/panel.dart';
import '../../auth/data/auth_repository.dart';
import '../../student/presentation/home_sky.dart';
import '../data/tracking_models.dart';
import '../data/tracking_repository.dart';
import '../../../shared/widgets/effects.dart';
import '../../../core/i18n/i18n.dart';

/// Öğrencinin konu takibi sekmesi.
class TopicsScreen extends ConsumerWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: SkyAppBar(title: Text(tr('Konu takibi'))),
      body: profile == null
          ? const BizzLoader()
          : TopicsView(studentId: profile.id, canEdit: true),
    );
  }
}

/// Durum renkleri ve ikonları (renk tek başına anlam taşımaz; ikon + etiket).
extension TopicStatusStyle on TopicStatus {
  IconData get icon => switch (this) {
    TopicStatus.notStarted => Icons.radio_button_unchecked,
    TopicStatus.inProgress => Icons.timelapse,
    TopicStatus.done => Icons.check_circle,
    TopicStatus.review => Icons.replay_circle_filled,
  };

  Color color(BuildContext context) => switch (this) {
    TopicStatus.notStarted => Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45),
    TopicStatus.inProgress => context.brand.secondary,
    TopicStatus.done => context.brand.success,
    TopicStatus.review => context.brand.primaryDeep,
  };
}

class TopicsView extends ConsumerStatefulWidget {
  const TopicsView({super.key, required this.studentId, this.canEdit = false});

  final String studentId;
  final bool canEdit;

  @override
  ConsumerState<TopicsView> createState() => _TopicsViewState();
}

class _TopicsViewState extends ConsumerState<TopicsView> {
  ExamType _type = ExamType.tyt;

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(topicsProvider);
    final progress = ref.watch(topicProgressProvider(widget.studentId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ExamType>(
              showSelectedIcon: false,
              segments: [
                for (final t in ExamType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ),
        ),
        Expanded(
          child: AsyncView(
            value: topics,
            onRetry: () => ref.invalidate(topicsProvider),
            builder: (all) => AsyncView(
              value: progress,
              onRetry: () =>
                  ref.invalidate(topicProgressProvider(widget.studentId)),
              builder: (status) => _TopicsContent(
                topics: [
                  for (final t in all)
                    if (subjectByCode(t.subjectCode).examType == _type) t,
                ],
                status: status,
                studentId: widget.studentId,
                canEdit: widget.canEdit,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopicsContent extends ConsumerWidget {
  const _TopicsContent({
    required this.topics,
    required this.status,
    required this.studentId,
    required this.canEdit,
  });

  final List<Topic> topics;
  final Map<int, TopicStatus> status;
  final String studentId;
  final bool canEdit;

  TopicStatus _of(Topic t) => status[t.id] ?? TopicStatus.notStarted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (topics.isEmpty) {
      return Center(
        child: EmptyState(
          title: tr('Konu listesi boş'),
          message: tr('Bu sınav türü için konu listesi henüz eklenmedi.'),
        ),
      );
    }
    final counts = {for (final s in TopicStatus.values) s: 0};
    for (final t in topics) {
      counts[_of(t)] = counts[_of(t)]! + 1;
    }
    final percent = (counts[TopicStatus.done]! * 100 / topics.length).round();

    final bySubject = <String, List<Topic>>{};
    for (final t in topics) {
      bySubject.putIfAbsent(t.subjectCode, () => []).add(t);
    }
    final subjectCodes = bySubject.keys.toList()
      ..sort(
        (a, b) => examSubjects
            .indexWhere((s) => s.code == a)
            .compareTo(examSubjects.indexWhere((s) => s.code == b)),
      );

    return RefreshIndicator(
      onRefresh: () => ref.refresh(topicProgressProvider(studentId).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          staggered(
            0,
            StatRow(
              children: [
                GlowStat(
                  icon: TopicStatus.done.icon,
                  // Dar kutuda kelime bölünmesin diye kısa etiket.
                  label: TopicStatus.done.label,
                  value: percent.toDouble(),
                  format: (v) => '%${v.round()}',
                  caption: tr('{done} / {all} konu', {
                    'done': counts[TopicStatus.done],
                    'all': topics.length,
                  }),
                  color: context.brand.success,
                ),
                GlowStat(
                  icon: TopicStatus.inProgress.icon,
                  label: tr('Çalışılıyor'),
                  value: counts[TopicStatus.inProgress]!.toDouble(),
                  caption: tr('konu'),
                  color: context.brand.secondary,
                ),
                GlowStat(
                  icon: TopicStatus.review.icon,
                  label: tr('Tekrar gerekli'),
                  value: counts[TopicStatus.review]!.toDouble(),
                  caption: tr('konu'),
                  color: context.brand.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          staggered(
            1,
            PanelSectionTitle(
              title: tr('Dersler'),
              subtitle: canEdit
                  ? tr('Bir konunun durumunu değiştirmek için üstüne dokun.')
                  : tr('{n} ders', {'n': subjectCodes.length}),
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, code) in subjectCodes.indexed)
            staggered(
              i + 2,
              _SubjectCard(
                subject: subjectByCode(code),
                topics: bySubject[code]!,
                statusOf: _of,
                studentId: studentId,
                canEdit: canEdit,
              ),
            ),
        ],
      ),
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  const _SubjectCard({
    required this.subject,
    required this.topics,
    required this.statusOf,
    required this.studentId,
    required this.canEdit,
  });

  final ExamSubject subject;
  final List<Topic> topics;
  final TopicStatus Function(Topic) statusOf;
  final String studentId;
  final bool canEdit;

  Future<void> _change(BuildContext context, WidgetRef ref, Topic t) async {
    final picked = await showModalBottomSheet<TopicStatus>(
      context: context,
      // Alt menünün üstünde açılsın (sekme içi gezgin değil).
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                t.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final s in TopicStatus.values)
              ListTile(
                leading: Icon(s.icon, color: s.color(context)),
                title: Text(s.label),
                trailing: s == statusOf(t) ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == statusOf(t)) return;
    try {
      await ref
          .read(trackingRepositoryProvider)
          .setTopicStatus(studentId, t.id, picked);
      ref.invalidate(topicProgressProvider(studentId));
      if (picked == TopicStatus.done && context.mounted) {
        celebrate(context);
        final allDone = topics.every(
          (x) => x.id == t.id || statusOf(x) == TopicStatus.done,
        );
        if (allDone) {
          showMessage(
            context,
            tr('{p0} tamamen bitti, altın madalya senin! 🏅', {
              'p0': subject.name,
            }),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final done = topics.where((t) => statusOf(t) == TopicStatus.done).length;
    final track = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            children: [
              Flexible(
                child: Text(
                  subject.name,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (done == topics.length) ...[
                const SizedBox(width: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (_, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Tooltip(
                    message: tr('Ders tamamlandı'),
                    child: Icon(
                      Icons.military_tech_rounded,
                      color: context.brand.primaryDeep,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AnimatedLinearProgress(
                  value: done / topics.length,
                  minHeight: 8,
                  backgroundColor: track,
                  color: context.brand.success,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('{done} / {all} konu bitti', {
                  'done': done,
                  'all': topics.length,
                }),
                style: text.bodySmall,
              ),
            ],
          ),
          children: [
            for (final t in topics)
              ListTile(
                dense: true,
                leading: Icon(
                  statusOf(t).icon,
                  color: statusOf(t).color(context),
                ),
                title: Text(t.name),
                trailing: Text(statusOf(t).label, style: text.labelSmall),
                onTap: canEdit ? () => _change(context, ref, t) : null,
              ),
          ],
        ),
      ),
    );
  }
}
