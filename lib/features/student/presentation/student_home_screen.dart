import 'package:flutter/material.dart';
import '../../../core/branding/branding_providers.dart';
import '../../avatar/presentation/student_avatar.dart';
import '../../avatar/data/avatar_repository.dart';
import '../../avatar/data/avatar_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/brand_logo.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../account/data/account_repository.dart';
import '../../assignments/data/assignment_repository.dart';
import '../../assignments/presentation/assignment_widgets.dart';
import '../../notifications/presentation/notification_widgets.dart';
import '../../meetings/data/meeting_repository.dart';
import '../../meetings/presentation/meeting_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../coaching/presentation/coaching_widgets.dart';
import '../../exams/data/exam.dart';
import '../../exams/data/exam_repository.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../../tracking/presentation/questions_view.dart';
import '../../tracking/presentation/study_view.dart';
import '../../../core/settings/app_settings.dart';
import '../data/bizz_shake.dart';
import '../../recap/data/week_recap.dart';
import '../../recap/presentation/recap_card.dart';
import 'home_cards.dart';
import '../../learn/presentation/daily_question_screen.dart';
import '../../plan/presentation/plan_widgets.dart';
import 'home_shortcuts.dart';
import '../../mistakes/data/mistake_repository.dart';
import '../../garden/presentation/garden_screen.dart';
import 'home_sky.dart';
import '../../ranking/data/ranking_repository.dart';

const _headerHeight = 270.0;

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null) {
      return const Scaffold(body: Center(child: BizzLoader()));
    }
    final id = profile.id;
    final now = DateTime.now();
    final today = dateOnly(now);
    final phase = DayPhase.of(now);

    final logs = ref.watch(questionLogsProvider(id)).value ?? const [];
    final sessions = ref.watch(studySessionsProvider(id)).value ?? const [];
    final goals = ref.watch(goalsProvider(id)).value;
    final exams = ref.watch(examsForStudentProvider(id)).value ?? const [];
    final topics = ref.watch(topicProgressProvider(id)).value ?? const {};
    final examYear = ref.watch(profileDetailsProvider).value?.examYear;

    final activeDays = {
      ...sessions.map((s) => dateOnly(s.startedAt)),
      ...logs.where((l) => l.total > 0).map((l) => dateOnly(l.loggedOn)),
    };
    final streak = studyStreak(activeDays, now);
    final todayQuestions = logs
        .where((l) => l.loggedOn == today)
        .fold<int>(0, (s, l) => s + l.total);
    final weekStart = today.subtract(const Duration(days: 6));
    final weekQuestions = logs
        .where((l) => !l.loggedOn.isBefore(weekStart))
        .fold<int>(0, (s, l) => s + l.total);
    final totalQuestions = logs.fold<int>(0, (s, l) => s + l.total);
    final totalMinutes =
        sessions.fold<int>(0, (m, s) => m + s.durationSec) ~/ 60;

    // Hak edilen avatar parçaları oturumda bir kez açılır; yeni varsa haber ver.
    ref.listen(avatarUnlocksProvider, (_, next) {
      final fresh = next.value?.fresh ?? const [];
      if (fresh.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('{n} yeni avatar parçası açıldı! 🎉', {'n': fresh.length}),
          ),
          action: SnackBarAction(
            label: tr('Gör'),
            onPressed: () => context.push('/student/avatar'),
          ),
        ),
      );
    });

    final lines = _bizzLines(
      phase: phase,
      todayQuestions: todayQuestions,
      dailyGoal: goals?.dailyQuestions,
      streak: streak,
    );

    Future<void> refresh() async {
      // Kurum adı/logosu değiştiyse yenilensin.
      ref.invalidate(tenantBrandingProvider);
      ref.invalidate(successStatusProvider);
      ref.invalidate(questionLogsProvider(id));
      ref.invalidate(studySessionsProvider(id));
      ref.invalidate(goalsProvider(id));
      ref.invalidate(examsForStudentProvider(id));
      ref.invalidate(topicProgressProvider(id));
      ref.invalidate(assignmentsProvider(id));
      ref.invalidate(meetingSchedulesProvider(id));
      ref.invalidate(mistakeCardsProvider(id));
      ref.invalidate(allSessionsProvider(id));
      await Future.wait([
        ref.read(questionLogsProvider(id).future),
        ref.read(studySessionsProvider(id).future),
      ]);
    }

    final cards = <Widget>[
      YksCountdownCard(examYear: examYear),
      // Koçla sıradaki görüşme (planlı görüşme yoksa görünmez).
      NextMeetingCard(studentId: id),
      _TodayCard(studentId: id),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => showAddQuestionSheet(context, id),
              icon: const Icon(Icons.edit_note),
              label: Text(tr('Soru ekle')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.go('/student/timer'),
              icon: const Icon(Icons.timer_outlined),
              label: Text(tr('Pomodoro')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ],
      ),
      // Haftanın Bal Raporu: son 7 günün hikayesi.
      RecapCard(
        firstName: profile.firstName,
        recap: WeekRecap.compute(
          logs: logs,
          sessions: sessions,
          exams: exams,
          now: now,
        ),
      ),
      // Günün Sorusu, Hata Defteri ve Odak Bahçesi kısayolları.
      const DailyQuestionCard(),
      PlanTodayCard(studentId: id),
      HomeShortcuts(studentId: id),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: HoneyJarCard(
                weekQuestions: weekQuestions,
                dailyGoal: goals?.dailyQuestions,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreakCard(streak: streak, activeDays: activeDays),
            ),
          ],
        ),
      ),
      SectionCard(
        title: tr('Ödevlerim'),
        subtitle: tr('Koçunun gönderdiği ödevler'),
        trailing: TextButton(
          onPressed: () => context.push('/student/homework'),
          child: Text(tr('Tümü')),
        ),
        child: AssignmentList(
          studentId: id,
          viewer: AssignmentViewer.student,
          onlyActive: true,
          limit: 2,
          emptyText: tr('Bekleyen ödevin yok. 🎉'),
        ),
      ),
      const _LeaderboardCard(),
      const DailyQuoteCard(),
      AchievementsCard(
        achievements: buildAchievements(
          totalQuestions: totalQuestions,
          bestStreak: bestStreak(activeDays),
          exams: exams.length,
          studyMinutes: totalMinutes,
          topicsDone: topics.values.where((s) => s == TopicStatus.done).length,
        ),
      ),
      SectionCard(
        title: tr('Görevlerim'),
        subtitle: tr('Koçunun verdiği görevler'),
        child: TaskList(
          studentId: id,
          viewer: TaskViewer.student,
          emptyText: tr('Şu an bekleyen görevin yok. 🎉'),
        ),
      ),
      SectionCard(
        title: tr('Koçundan notlar'),
        child: NotesList(studentId: id, limit: 3),
      ),
      _LastExamCard(studentId: id),
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        edgeOffset: 100,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: _headerHeight,
              backgroundColor: phase.sky.first,
              foregroundColor: phase.ink,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: phase.ink == Colors.white
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              actions: [
                const NotificationBell(),
                const _SuccessRankingButton(),
                IconButton(
                  tooltip: tr('Profil'),
                  icon: StudentAvatar(
                    config: AvatarConfig.fromJson(profile.avatar),
                    reward: ref.watch(myAvatarRewardProvider),
                    size: 34,
                  ),
                  onPressed: () => context.push('/student/profile'),
                ),
              ],
              flexibleSpace: LayoutBuilder(
                builder: (context, c) {
                  final top = MediaQuery.paddingOf(context).top;
                  final min = kToolbarHeight + top;
                  final open =
                      ((c.maxHeight - min) / (_headerHeight - kToolbarHeight))
                          .clamp(0.0, 1.0);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      SkyHeader(
                        firstName: profile.firstName,
                        lines: lines,
                        phase: phase,
                        contentOpacity: Curves.easeIn.transform(open),
                        // Telefonu salla: yeni Bızz gelir (saatte 2 kez).
                        swapLimit: switch (ref.read(
                          sharedPreferencesProvider,
                        )) {
                          final prefs? => BizzSwapLimit(prefs),
                          null => null,
                        },
                        avatar: Semantics(
                          button: true,
                          label: tr('Avatarını düzenle'),
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () => context.push('/student/avatar'),
                            child: StudentAvatar(
                              config: AvatarConfig.fromJson(profile.avatar),
                              reward: ref.watch(myAvatarRewardProvider),
                              size: 86,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: top,
                        height: kToolbarHeight,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 1 - open,
                            child: const Center(
                              child: BrandLogo(fontSize: 22, onDark: true),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.separated(
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => FadeSlideIn(
                  delay: FadeSlideIn.stagger(i, 70),
                  child: cards[i],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bızz'ın o anki duruma göre söyleyecekleri.
List<String> _bizzLines({
  required DayPhase phase,
  required int todayQuestions,
  required int? dailyGoal,
  required int streak,
}) {
  final lines = <String>[];
  if (dailyGoal != null && todayQuestions >= dailyGoal) {
    lines.add(tr('Bugünkü hedefi tutturdun, harikasın! 🎉'));
  } else if (todayQuestions == 0) {
    lines.add(
      phase == DayPhase.night
          ? tr('Geç oldu; birkaç soru, sonra güzel bir uyku 🌙')
          : tr('Bugünün ilk sorusuyla başlayalım mı?'),
    );
  } else if (dailyGoal != null) {
    lines.add(
      tr('Hedefe {n} soru kaldı, az kaldı!', {'n': dailyGoal - todayQuestions}),
    );
  } else {
    lines.add(tr('Bugün {n} soru çözdün, süpersin!', {'n': todayQuestions}));
  }
  if (streak >= 2) {
    lines.add(tr('{n} gündür buradasın, seriyi bozmayalım 🔥', {'n': streak}));
  }
  lines.addAll([
    switch (phase) {
      DayPhase.morning => tr('Sabah zihni taze olur, zor konular şimdi!'),
      DayPhase.day => tr('Kısa bir mola, bir bardak su, sonra devam 💧'),
      DayPhase.evening => tr('Akşam tekrarı, öğrendiklerini kalıcı yapar.'),
      DayPhase.night => tr('Uyku da çalışmanın bir parçası, unutma 😴'),
    },
    tr('Bana dokunursan yeni bir şey söylerim 🐝'),
  ]);
  return lines;
}

/// Bugünkü soru ve çalışma süresi, hedefe göre halka göstergeler.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final logs = ref.watch(questionLogsProvider(studentId)).value ?? const [];
    final sessions =
        ref.watch(studySessionsProvider(studentId)).value ?? const [];
    final goals = ref.watch(goalsProvider(studentId)).value;

    final questions = logs
        .where((l) => l.loggedOn == today)
        .fold<int>(0, (s, l) => s + l.total);
    final minutes =
        sessions
            .where((s) => dateOnly(s.startedAt) == today)
            .fold<int>(0, (m, s) => m + s.durationSec) ~/
        60;

    return SectionCard(
      title: tr('Bugün'),
      child: Row(
        children: [
          Expanded(
            child: _Ring(
              value: questions,
              goal: goals?.dailyQuestions,
              label: tr('soru'),
              goalText: goals?.dailyQuestions?.toString(),
              display: '$questions',
            ),
          ),
          Expanded(
            child: _Ring(
              value: minutes,
              goal: goals?.dailyMinutes,
              label: tr('çalışma'),
              goalText: goals?.dailyMinutes == null
                  ? null
                  : formatMinutes(goals!.dailyMinutes!),
              display: formatMinutes(minutes),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hedef halkası: dolarken renk baldan yeşile döner, hedefe ulaşınca
/// halkanın etrafında yumuşak bir ışık belirir.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.value,
    required this.goal,
    required this.label,
    required this.display,
    this.goalText,
  });

  /// Hedefin biçimlenmiş hali ("150", "4 sa").
  final String? goalText;

  final int value;
  final int? goal;
  final String label;
  final String display;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ratio = goal == null || goal == 0
        ? 0.0
        : (value / goal!).clamp(0.0, 1.0);
    final reached = goal != null && value >= goal!;
    return Semantics(
      label:
          '$label: $display${goal == null ? '' : ', ${tr('hedef {goal}', {'goal': goalText})}'}',
      excludeSemantics: true,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                if (reached)
                  BoxShadow(
                    color: context.brand.success.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: ratio),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => CircularProgressIndicator(
                    value: v,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                    color: Color.lerp(
                      context.brand.primaryDeep,
                      context.brand.success,
                      Curves.easeIn.transform(v),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: FittedBox(
                      child: Text(
                        display,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: text.bodyMedium),
          Text(
            goal == null
                ? tr('hedef yok')
                : reached
                ? tr('hedef tamam ✓')
                : tr('hedef {goal}', {'goal': goalText}),
            style: text.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _LastExamCard extends ConsumerWidget {
  const _LastExamCard({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(examsForStudentProvider(studentId)).value;
    if (exams == null || exams.isEmpty) return const SizedBox.shrink();
    final last = exams.reduce((a, b) => Exam.byDate(a, b) >= 0 ? a : b);
    final stats = ExamStats(
      exams.where((e) => e.examType == last.examType).toList(),
    );
    final change = stats.changeFor(last);
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/student/exams'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Son deneme'), style: text.bodySmall),
                    Text(
                      last.name,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${last.examType.label} · ${formatLongDate(last.takenOn)}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CountUp(
                    value: last.totalNet,
                    format: (v) => '${formatNet(v)} net',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (change != null)
                    Text(
                      '${change >= 0 ? '↑' : '↓'} ${formatChange(change)}',
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: change >= 0
                            ? context.brand.success
                            : context.brand.danger,
                      ),
                    ),
                ],
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Başarı sıralamasına giriş: üst çubukta, profilin yanında. Yalnızca müdür
/// sıralamayı açtıysa görünür; ödülü olan öğrencide kupa altın renkte.
class _SuccessRankingButton extends ConsumerWidget {
  const _SuccessRankingButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(successStatusProvider).value;
    if (status == null || !status.enabled) return const SizedBox.shrink();
    final reward = status.reward;
    return IconButton(
      tooltip: status.tytRank == null
          ? tr('Başarı sıralaması')
          : tr('Başarı sıralaması · TYT\'de {rank}.', {'rank': status.tytRank}),
      onPressed: () => context.push('/student/success'),
      icon: Icon(
        Icons.emoji_events_rounded,
        color: reward == null ? null : const Color(0xFFFFC531),
      ),
    );
  }
}

/// Haftalık sıralamaya ve avatar editörüne giriş.
class _LeaderboardCard extends ConsumerWidget {
  const _LeaderboardCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/student/leaderboard'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              StudentAvatar(
                config: AvatarConfig.fromJson(profile?.avatar),
                reward: ref.watch(myAvatarRewardProvider),
                size: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Haftanın arıları'),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      tr('Dershanendeki haftalık soru sıralaması'),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Avatarını düzenle'),
                onPressed: () => context.push('/student/avatar'),
                icon: const Icon(Icons.brush_rounded),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
