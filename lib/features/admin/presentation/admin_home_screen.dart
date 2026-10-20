import 'package:flutter/material.dart';
import '../../privacy/presentation/guardian_statement_tile.dart';
import '../../announcements/presentation/announcement_widgets.dart';
import '../../coach/presentation/exam_trends_card.dart';
import '../../../core/branding/branding_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/data/profile.dart';
import '../../auth/data/auth_repository.dart';
import '../../coach/data/coach_repository.dart';
import '../../credits/data/org_credits_repository.dart';
import '../../credits/presentation/credit_widgets.dart';
import '../../meetings/data/meeting_repository.dart';
import '../../meetings/presentation/meeting_widgets.dart';
import '../../../shared/widgets/honey_nav_bar.dart';
import '../../coach/presentation/manager_widgets.dart';
import '../../tracking/presentation/study_view.dart';
import '../data/admin_repository.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/effects.dart';
import '../../ranking/data/ranking_repository.dart';

/// Kurum müdürü paneli (mobil ve web).
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _tab = 0;

  static final _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, tr('Genel')),
    (Icons.school_outlined, Icons.school, tr('Öğrenciler')),
    (Icons.groups_outlined, Icons.groups, tr('Koçlar')),
    (Icons.vpn_key_outlined, Icons.vpn_key, tr('Davetler')),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pages = [
      _OverviewTab(onGoTo: (i) => setState(() => _tab = i)),
      const _StudentsTab(),
      const _CoachesTab(),
      const _InvitesTab(),
    ];

    final body = IndexedStack(index: _tab, children: pages);

    final fab = switch (_tab) {
      2 => FloatingActionButton.extended(
        onPressed: () =>
            showInviteCodeDialog(context, ref, role: UserRole.coach),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('Koç davet et')),
      ),
      3 => FloatingActionButton.extended(
        onPressed: () =>
            showInviteCodeDialog(context, ref, role: UserRole.student),
        icon: const Icon(Icons.add),
        label: Text(tr('Öğrenci daveti')),
      ),
      _ => null,
    };

    return Scaffold(
      floatingActionButton: fab,
      // Genel sekmesi gökyüzü başlığını kendisi çizer.
      appBar: _tab == 0
          ? null
          : AppBar(
              title: Text(
                _destinations[_tab].$3,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              actions: [
                IconButton(
                  tooltip: tr('Deneme sonuçlarını yükle'),
                  icon: const Icon(Icons.upload_file),
                  onPressed: () => context.push('/admin/import'),
                ),
                const _AdminProfileButton(),
              ],
            ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2),
                        label: Text(d.$3),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: body,
                    ),
                  ),
                ),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : HoneyNavBar(
              selectedIndex: _tab,
              onSelected: (i) => setState(() => _tab = i),
              items: [
                for (final d in _destinations)
                  HoneyNavItem(icon: d.$1, selectedIcon: d.$2, label: d.$3),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Genel
// ---------------------------------------------------------------------------

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.onGoTo});

  final ValueChanged<int> onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    final members = ref.watch(orgMembersProvider).value ?? const [];
    final students = ref.watch(studentSummariesProvider).value ?? const [];
    final profile = ref.watch(currentProfileProvider).value;
    final brand = context.brand;

    final coaches = members.where((m) => m.role == UserRole.coach).length;
    final parents = members.where((m) => m.role == UserRole.parent).length;
    final weekQuestions = students.fold<int>(0, (a, s) => a + s.weekQuestions);
    final weekMinutes = students.fold<int>(0, (a, s) => a + s.weekMinutes);
    final tytNets = [
      for (final s in students)
        if (s.lastExamType == ExamType.tyt && s.lastTotalNet != null)
          s.lastTotalNet!,
    ];
    final avgTyt = tytNets.isEmpty
        ? null
        : tytNets.reduce((a, b) => a + b) / tytNets.length;
    final noNumber = students.where((s) => s.studentNumber == null).length;
    final inactive = students.where((s) => !s.activeThisWeek).toList();
    final credits = ref.watch(orgCreditsProvider).value;

    final lines = [
      ...managerBizzLines(students),
      if (coaches > 0)
        tr('{c} koç ve {s} öğrenciyle çalışıyorsun.', {
          'c': coaches,
          's': students.length,
        }),
    ];

    final cards = <Widget>[
      if (credits != null && (credits.low || !credits.isActive))
        const LowCreditBanner(),
      AsyncView(
        value: org,
        onRetry: () => ref.invalidate(orgProvider),
        builder: (o) => _OrgCard(
          org: o,
          students: students.length,
          credits: credits?.balance,
        ),
      ),
      const OrgCodeCard(),
      StatRow(
        children: [
          GlowStat(
            icon: Icons.school_rounded,
            label: tr('Öğrenci'),
            value: students.length.toDouble(),
            caption: tr('{n} aktif', {'n': students.length - inactive.length}),
            color: brand.secondary,
          ),
          GlowStat(
            icon: Icons.groups_rounded,
            label: tr('Koç'),
            value: coaches.toDouble(),
            color: brand.info,
          ),
          GlowStat(
            icon: Icons.family_restroom_rounded,
            label: tr('Veli'),
            value: parents.toDouble(),
            color: brand.success,
          ),
        ],
      ),
      StatRow(
        children: [
          GlowStat(
            icon: Icons.edit_note_rounded,
            label: tr('Bu hafta'),
            value: weekQuestions.toDouble(),
            caption: tr('soru'),
            color: brand.primary,
          ),
          GlowStat(
            icon: Icons.timer_rounded,
            label: tr('Bu hafta'),
            value: weekMinutes.toDouble(),
            format: (v) => formatMinutes(v.round()),
            caption: tr('çalışma'),
            color: brand.secondary,
          ),
          GlowStat(
            icon: Icons.trending_up_rounded,
            label: tr('Ort. son TYT'),
            value: avgTyt ?? 0,
            format: (v) => avgTyt == null ? '–' : formatNet(v),
            caption: tr('{p0} öğrenci', {'p0': tytNets.length}),
            color: brand.info,
          ),
        ],
      ),
      if (noNumber > 0)
        PanelNotice(
          icon: Icons.badge_outlined,
          message:
              '${tr('{noNumber} öğrencinin okul numarası eksik', {'noNumber': noNumber})} · '
              '${tr('Deneme dosyaları numarayla eşleştirildiği için numaraları gir.')}',
          onTap: () => onGoTo(1),
        ),
      const AnnouncementsHomeCard(),
      const _SuccessRankingCard(),
      const ExamTrendsCard(basePath: '/admin'),
      CoachMeetingsReport(
        coaches: [
          for (final m in members)
            if (m.role == UserRole.coach) (m.id, m.fullName),
        ],
      ),
      PanelSectionTitle(
        title: tr('Bu hafta hareketsiz öğrenciler'),
        subtitle: tr('Soru ya da çalışma kaydı olmayanlar'),
      ),
      if (inactive.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Bizz(size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('Herkes bu hafta çalışmış. 🎉'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
      else
        for (final s in inactive)
          StudentCard(
            key: ValueKey('inactive-${s.id}'),
            student: s,
            showCoach: true,
            deletionRequested:
                (ref.watch(deletionRequestsProvider).value ?? const {})
                    .containsKey(s.id),
            onTap: () => context.push('/admin/students/${s.id}'),
          ),
    ];

    return RefreshIndicator(
      edgeOffset: 100,
      onRefresh: () async {
        ref.invalidate(orgProvider);
        ref.invalidate(orgCreditsProvider);
        ref.invalidate(orgCodeProvider);
        ref.invalidate(orgMembersProvider);
        ref.invalidate(studentSummariesProvider);
        ref.invalidate(successStatusProvider);
        ref.invalidate(meetingSchedulesProvider);
        ref.invalidate(weekMeetingsProvider);
      },
      child: CustomScrollView(
        slivers: [
          ManagerSkyAppBar(
            firstName: profile?.firstName ?? '',
            lines: lines,
            actions: [
              IconButton(
                tooltip: tr('Yüklediğin denemeler'),
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () => context.push('/admin/exams'),
              ),
              IconButton(
                tooltip: tr('Deneme sonuçlarını yükle'),
                icon: const Icon(Icons.upload_file),
                onPressed: () => context.push('/admin/import'),
              ),
              const _AdminProfileButton(),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.separated(
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => staggered(i, cards[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Üst çubuktaki profil düğmesi (baş harfler).
class _AdminProfileButton extends ConsumerWidget {
  const _AdminProfileButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ProfileInitialsButton(
    name: ref.watch(currentProfileProvider).value?.fullName ?? '',
    onPressed: () => context.push('/admin/profile'),
  );
}

/// Başarı sıralaması anahtarı: açılınca öğrenciler kurum içi sıralamayı ve
/// TYT ilk 5'in avatar ödüllerini görür.
class _SuccessRankingCard extends ConsumerStatefulWidget {
  const _SuccessRankingCard();

  @override
  ConsumerState<_SuccessRankingCard> createState() =>
      _SuccessRankingCardState();
}

class _SuccessRankingCardState extends ConsumerState<_SuccessRankingCard> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(successRankingRepositoryProvider).setEnabled(value);
      ref.invalidate(successStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            value
                ? tr('Başarı sıralaması açıldı. Öğrenciler artık görebilir.')
                : tr('Başarı sıralaması kapatıldı.'),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Kaydedilemedi. Tekrar dene.'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(successStatusProvider);
    final enabled = status.value?.enabled ?? false;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  // Madalya rengi (markadan bağımsız).
                  colors: [Color(0xFFFFE68A), Color(0xFFFFC531)],
                ),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFF2B2350),
              ),
            ),
            title: Text(tr('Başarı sıralaması')),
            subtitle: Text(
              tr(
                'Öğrenciler son 5 denemelerinin ortalamasına göre sıralanır. TYT\'de 1. kral tacı, ilk 3 altın kanat, 4. ve 5. gümüş kanat kazanır.',
              ),
            ),
            value: enabled,
            onChanged: _busy || !status.hasValue ? null : _toggle,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: TextButton.icon(
                onPressed: () => context.push('/admin/success'),
                icon: const Icon(Icons.leaderboard_rounded),
                label: Text(enabled ? tr('Sıralamayı gör') : tr('Önizle')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgCard extends ConsumerWidget {
  const _OrgCard({required this.org, required this.students, this.credits});

  final OrgInfo org;
  final int students;

  /// Kalan öğrenci kredisi (yüklenmediyse null).
  final int? credits;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: org.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Kurum adı')),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Vazgeç')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr('Kaydet')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.length < 2) return;
    await ref.read(adminRepositoryProvider).renameOrg(name);
    ref.invalidate(orgProvider);
    // Kurum adı markaya da yansır (koç ve öğrenciler de yeni adı görür).
    ref.invalidate(tenantBrandingProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    // Halka: kayıtlı öğrenciler / (kayıtlı + kalan kredi).
    final left = credits ?? 0;
    final total = students + left;
    final ratio = total == 0 ? 1.0 : (students / total).clamp(0.0, 1.0);
    final full = credits != null && left <= 0;
    final expiry = org.licenseExpiresAt == null
        ? tr('Süresiz')
        : DateFormat('d MMMM yyyy', localeTag).format(org.licenseExpiresAt!);

    final brand = context.brand;
    final onCard =
        ThemeData.estimateBrightnessForColor(brand.secondary) == Brightness.dark
        ? Colors.white
        : brand.ink;
    final barColor = full ? brand.danger : brand.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(brand.secondary, Colors.white, 0.12)!,
            Color.lerp(brand.secondary, Colors.black, 0.25)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: brand.secondary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: HoneycombPainter(color: onCard, opacity: 0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      org.name,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: onCard,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Kurum adını değiştir'),
                    color: onCard,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _rename(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox.square(
                    dimension: 78,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: v,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            color: barColor,
                            backgroundColor: onCard.withValues(alpha: 0.18),
                          ),
                          Center(
                            child: Text(
                              '${(v * 100).round()}%',
                              style: text.titleMedium?.copyWith(
                                color: onCard,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          credits == null
                              ? tr('{n} öğrenci', {'n': students})
                              : tr('Öğrenci kredisi: {n}', {'n': left}),
                          style: text.titleSmall?.copyWith(
                            color: onCard,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          full
                              ? tr(
                                  'Kredi bitti. Yeni öğrenci eklenemez; yöneticinizle iletişime geçin.',
                                )
                              : tr('{n} öğrenci kayıtlı', {'n': students}),
                          style: text.bodySmall?.copyWith(
                            color: onCard.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: org.licenseExpired
                                ? brand.danger
                                : onCard.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                org.licenseExpired
                                    ? Icons.error_outline
                                    : Icons.event_available,
                                size: 15,
                                color: org.licenseExpired
                                    ? Colors.white
                                    : onCard,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  org.licenseExpired
                                      ? tr('Lisans süresi doldu ({expiry})', {
                                          'expiry': expiry,
                                        })
                                      : tr('Lisans bitişi: {expiry}', {
                                          'expiry': expiry,
                                        }),
                                  style: text.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: org.licenseExpired
                                        ? Colors.white
                                        : onCard,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/admin/branding'),
                style: FilledButton.styleFrom(
                  backgroundColor: onCard.withValues(alpha: 0.16),
                  foregroundColor: onCard,
                ),
                icon: const Icon(Icons.palette_outlined),
                label: Text(tr('Kurum görünümü: logo, renk ve yazı tipi')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Öğrenciler
// ---------------------------------------------------------------------------

class _StudentsTab extends ConsumerStatefulWidget {
  const _StudentsTab();

  @override
  ConsumerState<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<_StudentsTab> {
  String _query = '';
  String? _coachFilter;

  Future<void> _changeCoach(StudentSummary s, List<OrgMember> coaches) async {
    String? selected = s.coachId;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('{p0} · koçu', {'p0': s.fullName})),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('Koç')),
            items: [
              for (final c in coaches)
                DropdownMenuItem(value: c.id, child: Text(c.fullName)),
            ],
            onChanged: (v) => setLocal(() => selected = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Vazgeç')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text(tr('Kaydet')),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked == s.coachId) return;
    try {
      await ref.read(adminRepositoryProvider).reassignCoach(s.id, picked);
      ref.invalidate(studentSummariesProvider);
      if (mounted) showMessage(context, tr('Koç değiştirildi.'));
    } catch (_) {
      if (mounted) showMessage(context, tr('Koç değiştirilemedi.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentSummariesProvider);
    final coaches = (ref.watch(orgMembersProvider).value ?? const [])
        .where((m) => m.role == UserRole.coach)
        .toList();
    final text = Theme.of(context).textTheme;

    return AsyncView(
      value: students,
      onRetry: () => ref.invalidate(studentSummariesProvider),
      builder: (all) {
        final q = _query.trim().toLowerCase();
        final list = all.where((s) {
          if (_coachFilter != null && s.coachId != _coachFilter) return false;
          if (q.isEmpty) return true;
          return s.fullName.toLowerCase().contains(q) ||
              (s.studentNumber?.toLowerCase().contains(q) ?? false);
        }).toList();

        return RefreshIndicator(
          onRefresh: () => ref.refresh(studentSummariesProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: tr('Ad veya okul numarası ara'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _coachFilter,
                decoration: InputDecoration(labelText: tr('Koç')),
                items: [
                  DropdownMenuItem(value: null, child: Text(tr('Tüm koçlar'))),
                  for (final c in coaches)
                    DropdownMenuItem(value: c.id, child: Text(c.fullName)),
                ],
                onChanged: (v) => setState(() => _coachFilter = v),
              ),
              const SizedBox(height: 12),
              Text(
                tr('{p0} öğrenci', {'p0': list.length}),
                style: text.labelLarge,
              ),
              const SizedBox(height: 8),
              if (all.isEmpty)
                EmptyState(
                  title: tr('Henüz öğrenci yok'),
                  message: tr(
                    '"Davetler" sekmesinden bir koç için öğrenci davet kodu oluştur.',
                  ),
                ),
              for (final (i, s) in list.indexed)
                Padding(
                  key: ValueKey(s.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: staggered(
                    i,
                    StudentCard(
                      student: s,
                      showCoach: true,
                      deletionRequested:
                          (ref.watch(deletionRequestsProvider).value ??
                                  const {})
                              .containsKey(s.id),
                      maxWeekQuestions: all.fold<int>(
                        0,
                        (a, s) => s.weekQuestions > a ? s.weekQuestions : a,
                      ),
                      onTap: () => context.push('/admin/students/${s.id}'),
                      trailing: PopupMenuButton<String>(
                        tooltip: tr('Seçenekler'),
                        onSelected: (v) {
                          if (v == 'coach') _changeCoach(s, coaches);
                          if (v == 'open') {
                            context.push('/admin/students/${s.id}');
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'open',
                            child: Text(tr('Detay / okul numarası')),
                          ),
                          PopupMenuItem(
                            value: 'coach',
                            child: Text(tr('Koçunu değiştir')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Koçlar
// ---------------------------------------------------------------------------

class _CoachesTab extends ConsumerWidget {
  const _CoachesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(orgMembersProvider);
    final students = ref.watch(studentSummariesProvider).value ?? const [];

    return AsyncView(
      value: members,
      onRetry: () => ref.invalidate(orgMembersProvider),
      builder: (all) {
        final coaches = all.where((m) => m.role == UserRole.coach).toList();
        if (coaches.isEmpty) {
          return Center(
            child: EmptyState(
              title: tr('Henüz koç yok'),
              message: tr('"Koç davet et" ile kod oluştur ve koçuna gönder.'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            for (final c in coaches)
              () {
                final mine = students.where((s) => s.coachId == c.id).toList();
                final week = mine.fold<int>(0, (a, s) => a + s.weekQuestions);
                final pending = mine.fold<int>(0, (a, s) => a + s.pendingTasks);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                    child: Row(
                      children: [
                        InitialsAvatar(name: c.fullName, size: 50),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.fullName,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  InfoPill(
                                    icon: Icons.school_outlined,
                                    text: tr('{n} öğrenci', {'n': mine.length}),
                                    color: context.brand.secondary,
                                  ),
                                  InfoPill(
                                    icon: Icons.edit_note_rounded,
                                    text: tr('{n} soru', {'n': week}),
                                  ),
                                  if (pending > 0)
                                    InfoPill(
                                      icon: Icons.assignment_late_outlined,
                                      text: tr('{n} görev bekliyor', {
                                        'n': pending,
                                      }),
                                      color: context.brand.primaryDeep,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: tr('Bu koça öğrenci daveti'),
                          icon: const Icon(Icons.person_add_alt),
                          onPressed: () => showInviteCodeDialog(
                            context,
                            ref,
                            role: UserRole.student,
                            coachId: c.id,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }(),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Davetler
// ---------------------------------------------------------------------------

class _InvitesTab extends ConsumerWidget {
  const _InvitesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(orgInvitesProvider);
    final members = ref.watch(orgMembersProvider).value ?? const [];
    final names = {for (final m in members) m.id: m.fullName};
    final dateFormat = DateFormat('d MMM', localeTag);

    return AsyncView(
      value: invites,
      onRetry: () => ref.invalidate(orgInvitesProvider),
      builder: (list) => RefreshIndicator(
        onRefresh: () => ref.refresh(orgInvitesProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Text(
              tr(
                'Kurumdaki aktif davet kodları. Kodlar 14 gün geçerli; kullanım hakkı dolan kodlar listeden düşer.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (list.isEmpty)
              EmptyState(
                title: tr('Aktif davet yok'),
                message: tr(
                  'Koç ya da öğrenci daveti oluşturduğunda burada görünür.',
                ),
              ),
            for (final i in list)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          (i.role == UserRole.coach
                                  ? context.brand.info
                                  : context.brand.secondary)
                              .withValues(alpha: 0.18),
                    ),
                    child: Icon(
                      i.role == UserRole.coach
                          ? Icons.groups_rounded
                          : Icons.school_rounded,
                      color: i.role == UserRole.coach
                          ? context.brand.info
                          : context.brand.secondary,
                    ),
                  ),
                  title: Text(
                    i.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text(
                    [
                      i.role.label,
                      if (i.coachId != null)
                        tr('Koç: {p0}', {'p0': names[i.coachId] ?? '—'}),
                      '${i.remaining} hak',
                      tr('{p0} tarihine kadar', {
                        'p0': dateFormat.format(i.expiresAt),
                      }),
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: tr('Kopyala'),
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: i.code));
                          if (context.mounted) {
                            showMessage(context, tr('Kod kopyalandı'));
                          }
                        },
                      ),
                      IconButton(
                        tooltip: tr('İptal et'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await confirm(
                            context,
                            title: tr('Davet iptal edilsin mi?'),
                            message: tr('{p0} artık kullanılamayacak.', {
                              'p0': i.code,
                            }),
                            action: tr('İptal et'),
                          );
                          if (!ok) return;
                          await ref
                              .read(adminRepositoryProvider)
                              .deleteInvite(i.code);
                          ref.invalidate(orgInvitesProvider);
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Koç ya da öğrenci davet kodu oluşturma penceresi.
Future<void> showInviteCodeDialog(
  BuildContext context,
  WidgetRef ref, {
  required UserRole role,
  String? coachId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _InviteDialog(role: role, coachId: coachId),
);

class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog({required this.role, this.coachId});

  final UserRole role;
  final String? coachId;

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  late String? _coachId = widget.coachId;
  int _uses = 1;
  bool _guardianStatement = false;
  String? _code;
  bool _loading = false;

  /// Kredi bilinmiyorsa açık; sunucu yine NO_CREDITS ile reddeder.
  bool get _canAddStudent =>
      ref.read(orgCreditsProvider).value?.canAddStudent ?? true;

  Future<void> _create() async {
    if (widget.role == UserRole.student && !_canAddStudent) return;
    if (widget.role == UserRole.student && _coachId == null) {
      showMessage(context, tr('Öğrencinin bağlanacağı koçu seç.'));
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final code = widget.role == UserRole.coach
          ? await repo.createCoachInvite(maxUses: _uses)
          : await repo.createStudentInvite(
              coachId: _coachId!,
              maxUses: _uses,
              guardianStatement: _guardianStatement,
            );
      ref.invalidate(orgInvitesProvider);
      setState(() => _code = code);
    } catch (e) {
      if (e.toString().contains('NO_CREDITS')) {
        ref.invalidate(orgCreditsProvider);
      }
      if (mounted) showMessage(context, tr('Kod oluşturulamadı.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coaches = (ref.watch(orgMembersProvider).value ?? const [])
        .where((m) => m.role == UserRole.coach)
        .toList();
    final text = Theme.of(context).textTheme;
    final isCoach = widget.role == UserRole.coach;
    final canCreate =
        isCoach || (ref.watch(orgCreditsProvider).value?.canAddStudent ?? true);

    return AlertDialog(
      title: Text(isCoach ? tr('Koç davet et') : tr('Öğrenci davet et')),
      content: SizedBox(
        width: 360,
        child: _code != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Bizz(size: 80),
                  const SizedBox(height: 8),
                  SelectableText(
                    _code!,
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  Text(
                    tr('{_uses} kişi kullanabilir · 14 gün geçerli', {
                      '_uses': _uses,
                    }),
                    style: text.bodySmall,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isCoach) ...[
                    const LowCreditBanner(padding: EdgeInsets.only(bottom: 12)),
                    DropdownButtonFormField<String>(
                      initialValue: _coachId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr('Bağlanacağı koç'),
                      ),
                      items: [
                        for (final c in coaches)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(c.fullName),
                          ),
                      ],
                      onChanged: (v) => setState(() => _coachId = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(tr('Kaç kişi kullanabilsin?'), style: text.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      const ButtonSegment(value: 1, label: Text('1')),
                      const ButtonSegment(value: 5, label: Text('5')),
                      ButtonSegment(
                        value: isCoach ? 10 : 30,
                        label: Text(isCoach ? '10' : '30'),
                      ),
                    ],
                    selected: {_uses},
                    onSelectionChanged: (s) => setState(() => _uses = s.first),
                  ),
                  if (!isCoach) ...[
                    const SizedBox(height: 8),
                    GuardianStatementTile(
                      value: _guardianStatement,
                      onChanged: (v) => setState(() => _guardianStatement = v),
                    ),
                  ],
                ],
              ),
      ),
      actions: _code != null
          ? [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _code!));
                  if (context.mounted) {
                    showMessage(context, tr('Kod kopyalandı'));
                  }
                },
                child: Text(tr('Kopyala')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('Kapat')),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('Vazgeç')),
              ),
              TextButton(
                onPressed: _loading || !canCreate ? null : _create,
                child: Text(tr('Kod oluştur')),
              ),
            ],
    );
  }
}
