import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../announcements/presentation/announcement_widgets.dart';
import '../../../core/branding/branding_providers.dart';
import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../../shared/widgets/panel.dart';
import '../../account/data/account_repository.dart';
import '../../assignments/presentation/assignment_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../coach/presentation/manager_widgets.dart' show ManagerSkyAppBar;
import '../../coaching/presentation/coaching_widgets.dart';
import '../../exams/data/exam.dart';
import '../../meetings/data/meeting_repository.dart';
import '../../meetings/presentation/meeting_widgets.dart';
import '../../exams/data/exam_repository.dart';
import '../../tracking/data/tracking_models.dart';
import '../../tracking/data/tracking_repository.dart';
import '../../tracking/presentation/study_view.dart';

/// Velinin ana ekranı: koç ve müdür panelleriyle aynı dil. Gökyüzü başlığında
/// konuşan Bızz, çocuğun haftalık özeti, ayrıntı sayfalarına hızlı geçişler,
/// hedefler, görevler ve ödevler (salt okunur).
class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  String? _childId;

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider);
    final profile = ref.watch(currentProfileProvider).value;
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
      }
    }

    final List<Widget> body = children.when(
      loading: () => const [
        SliverFillRemaining(hasScrollBody: false, child: BizzLoader()),
      ],
      error: (_, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('Veriler yüklenemedi. İnternet bağlantını kontrol et.'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(childrenProvider),
                  child: Text(tr('Tekrar dene')),
                ),
              ],
            ),
          ),
        ),
      ],
      data: (list) => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverToBoxAdapter(
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
      ],
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        edgeOffset: 100,
        child: CustomScrollView(
          slivers: [
            ManagerSkyAppBar(
              firstName: profile?.firstName ?? '',
              lines: child == null || week == null
                  ? [tr('Çocuğun kayıt olunca gelişimini birlikte izleriz! 🐝')]
                  : _parentBizzLines(child, week),
              actions: [
                ProfileInitialsButton(
                  name: profile?.fullName ?? '',
                  onPressed: () => context.push('/parent/profile'),
                ),
              ],
            ),
            ...body,
          ],
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

/// Bızz'ın veliye söyleyecekleri.
List<String> _parentBizzLines(ChildRef child, _ChildWeek w) {
  final name = child.fullName.split(' ').first;
  final change = w.tyt.lastChange;
  return [
    if (w.questions > 0)
      tr('{name} bu hafta {n} soru çözdü 🐝', {'name': name, 'n': w.questions})
    else
      tr('{name} bu hafta henüz soru girmedi.', {'name': name}),
    if (w.minutes > 0)
      tr('Bu hafta {time} çalıştı ⏱️', {'time': formatMinutes(w.minutes)}),
    if (w.activeDays > 0)
      tr('Son 7 günün {n} gününde çalıştı.', {'n': w.activeDays})
    else
      tr('Küçük bir moral mesajı bu hafta çok iyi gelebilir 💛'),
    if (w.tyt.last != null)
      change != null && change > 0
          ? tr('Son TYT denemesinde {net} net, öncekinden {d} fazla! 📈', {
              'net': formatNet(w.tyt.last!.totalNet),
              'd': formatNet(change),
            })
          : tr('Son TYT denemesinde {net} net yaptı.', {
              'net': formatNet(w.tyt.last!.totalNet),
            }),
  ];
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
    final brand = context.brand;
    final tyt = week.tyt;
    void open(int tab) => context.push('/parent/child/${child.id}?tab=$tab');

    final items = <Widget>[
      if (children.length > 1)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in children)
              ChoiceChip(
                avatar: InitialsAvatar(name: c.fullName, size: 24),
                label: Text(c.fullName),
                selected: c.id == child.id,
                onSelected: (_) => onSelect(c.id),
              ),
          ],
        ),
      // Son 14 günde kurumdan ya da koçtan duyuru geldiyse.
      const AnnouncementsHomeCard(),
      PanelSectionTitle(
        title: tr('{name} bu hafta', {'name': child.fullName}),
        subtitle: tr('Son 7 gün'),
      ),
      StatRow(
        children: [
          GlowStat(
            icon: Icons.edit_note_rounded,
            label: tr('Çözülen soru'),
            value: week.questions.toDouble(),
            color: brand.primary,
          ),
          GlowStat(
            icon: Icons.timer_rounded,
            label: tr('Çalışma'),
            value: week.minutes.toDouble(),
            format: (v) => formatMinutes(v.round()),
            color: brand.secondary,
          ),
          GlowStat(
            icon: Icons.event_available_rounded,
            label: tr('Aktif gün'),
            value: week.activeDays.toDouble(),
            format: (v) => '${v.round()} / 7',
            color: brand.success,
          ),
        ],
      ),
      StatRow(
        children: [
          GlowStat(
            icon: Icons.insights_rounded,
            label: tr('Son TYT neti'),
            value: tyt.last?.totalNet ?? 0,
            format: tyt.last == null ? (_) => '–' : formatNet,
            caption: tyt.lastChange == null
                ? null
                : '${tyt.lastChange! >= 0 ? '↑' : '↓'} '
                      '${formatChange(tyt.lastChange!)}',
            color: brand.info,
          ),
          GlowStat(
            icon: Icons.functions_rounded,
            label: tr('TYT ortalaması'),
            value: tyt.recentAverage ?? 0,
            format: tyt.recentAverage == null ? (_) => '–' : formatNet,
            caption: tr('son 5 deneme'),
            color: brand.primaryDeep,
          ),
        ],
      ),
      PanelSectionTitle(
        title: tr('Ayrıntılar'),
        subtitle: tr('Denemeler, sorular, konular ve çalışma süresi'),
      ),
      Column(
        children: [
          StatRow(
            children: [
              QuickActionTile(
                icon: Icons.fact_check_rounded,
                label: tr('Denemeler'),
                color: brand.success,
                onTap: () => open(0),
              ),
              QuickActionTile(
                icon: Icons.edit_note_rounded,
                label: tr('Sorular'),
                color: brand.primary,
                onTap: () => open(1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatRow(
            children: [
              QuickActionTile(
                icon: Icons.checklist_rounded,
                label: tr('Konular'),
                color: brand.info,
                onTap: () => open(2),
              ),
              QuickActionTile(
                icon: Icons.timer_rounded,
                label: tr('Süre'),
                color: brand.secondary,
                onTap: () => open(3),
              ),
            ],
          ),
        ],
      ),
      GoalsCard(studentId: child.id),
      StudentMeetingsCard(studentId: child.id),
      SectionCard(
        title: tr('Koçunun verdiği görevler'),
        child: TaskList(
          studentId: child.id,
          viewer: TaskViewer.readOnly,
          emptyText: tr('Şu an görev yok.'),
        ),
      ),
      SectionCard(
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
        for (final (i, c) in items.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          staggered(i, c),
        ],
      ],
    );
  }
}
