import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../staff/presentation/staff_screen.dart';
import '../../student_books/presentation/book_report_screen.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/tool_strip.dart';
import '../../../shared/widgets/tool_tile.dart';
import '../../attendance/presentation/attendance_screen.dart';
import '../../finance/presentation/finance_screen.dart';
import '../../pending_work/presentation/pending_work_screen.dart';
import '../../schedule_generator/presentation/my_timetable.dart';
import '../../student_books/presentation/book_pool_screen.dart';
import '../../student_management/presentation/students_screen.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';
import '../../coach/data/coach_repository.dart';
import '../../coach/presentation/manager_widgets.dart';
import '../../credits/data/org_credits_repository.dart';
import '../../credits/presentation/credit_widgets.dart';
import '../../privacy/presentation/guardian_statement_tile.dart';
import '../data/admin_repository.dart';
import '../data/cockpit_repository.dart';
import 'cockpit/coach_performance_section.dart' show editCoachPhone;
import 'cockpit/cockpit_header.dart' show CockpitProfileButton;
import 'cockpit/cockpit_tab.dart';
import 'cockpit/cockpit_theme.dart';
import 'cockpit/nav_groups.dart';
import 'cockpit/section_states.dart';

/// Kurum müdürü paneli (mobil ve web). "Genel" sekmesi işletme kokpitidir
/// (NOTLAR §59); tek, açık tema: [cockpitTheme].
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _tab = 0;

  /// Alt çubuk (en fazla 6): araçlar konuya göre gruplanır (NOTLAR §64).
  static final _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, tr('Genel')),
    (Icons.school_outlined, Icons.school, tr('Öğrenciler')),
    (Icons.groups_outlined, Icons.groups, tr('Koçlar')),
    (Icons.fact_check_outlined, Icons.fact_check, tr('Sınavlar')),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      tr('Finans'),
    ),
    (Icons.forum_outlined, Icons.forum, tr('İletişim')),
  ];

  @override
  Widget build(BuildContext context) =>
      CockpitThemed(child: Builder(builder: _build));

  Widget _build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    void goTo(int i) => setState(() => _tab = i);
    final pages = [
      CockpitTab(
        onGoTo: goTo,
        hasBottomNav: !wide,
        onInviteStudent: () =>
            showInviteCodeDialog(context, ref, role: UserRole.student),
        onInviteCoach: () =>
            showInviteCodeDialog(context, ref, role: UserRole.coach),
        onInviteStudentForCoach: (id) => showInviteCodeDialog(
          context,
          ref,
          role: UserRole.student,
          coachId: id,
        ),
      ),
      const _StudentsTab(),
      const _CoachesTab(),
      ToolGroupTab(
        description: tr(
          'Deneme sonuçları, kurum sınavları, optik okuma ve deneme planı',
        ),
        tools: examTools(ref, '/admin'),
      ),
      // Finans tek başına: ekranın kendisi (kendi üst çubuğu ve sekmeleri).
      const FinanceScreen(),
      ToolGroupTab(
        description: tr('Velilere SMS ve toplu duyurular'),
        tools: messageTools('/admin'),
      ),
    ];

    final body = IndexedStack(index: _tab, children: pages);

    final fab = switch (_tab) {
      1 => FloatingActionButton.extended(
        onPressed: () =>
            showInviteCodeDialog(context, ref, role: UserRole.student),
        icon: const Icon(Icons.add),
        label: Text(tr('Öğrenci daveti')),
      ),
      2 => FloatingActionButton.extended(
        onPressed: () =>
            showInviteCodeDialog(context, ref, role: UserRole.coach),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('Koç davet et')),
      ),
      _ => null,
    };

    return Scaffold(
      floatingActionButton: fab,
      // Genel sekmesi üst çubuğunu kendisi çizer (kurum logosu ve adı);
      // Finans ekranının kendi üst çubuğu ve sekmeleri var.
      appBar: _tab == 0 || _tab == 4
          ? null
          : AppBar(
              title: Text(_destinations[_tab].$3),
              actions: const [
                PendingWorkButton(basePath: '/admin'),
                _AdminProfileButton(),
              ],
            ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: goTo,
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
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: body,
                    ),
                  ),
                ),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.cockpit.border)),
              ),
              child: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: goTo,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: d.$3,
                    ),
                ],
              ),
            ),
    );
  }
}

/// Üst çubuktaki profil düğmesi (baş harfler).
class _AdminProfileButton extends ConsumerWidget {
  const _AdminProfileButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => CockpitProfileButton(
    name: ref.watch(currentProfileProvider).value?.fullName ?? '',
  );
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
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              cockpitNavHeight + 16,
            ),
            children: [
              ToolStrip(
                warnColor: Tone.warn.of(context),
                tools: [
                  studentsTool(ref, '/admin'),
                  attendanceTool(ref, '/admin'),
                  timetableAdminTool(ref),
                  bookPoolTool(ref, '/admin'),
                  bookReportTool('/admin'),
                ],
              ),
              const SizedBox(height: 14),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SectionEmpty(
                      icon: Icons.school_outlined,
                      message: tr(
                        'Henüz öğrenci yok. Bir koç için öğrenci davet kodu oluştur.',
                      ),
                      actionLabel: tr('Öğrenci davet et'),
                      actionIcon: Icons.person_add_alt_1,
                      onAction: () => showInviteCodeDialog(
                        context,
                        ref,
                        role: UserRole.student,
                      ),
                    ),
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
    // Koç telefonu kokpit verisinden (müdürün girdiği numara).
    final phones = {
      for (final c in ref.watch(cockpitProvider).value?.coaches ?? const [])
        c.coachId: c.phone,
    };

    return AsyncView(
      value: members,
      onRetry: () => ref.invalidate(orgMembersProvider),
      builder: (all) {
        final coaches = all.where((m) => m.role == UserRole.coach).toList();
        final strip = ToolStrip(
          warnColor: Tone.warn.of(context),
          tools: [
            staffTool(ref),
            ToolInfo(
              id: 'tool-invites',
              icon: Icons.vpn_key_outlined,
              title: tr('Davetler'),
              status: tr('Aktif davet kodları; kod oluştur ve paylaş'),
              open: (c) => c.push('/admin/invites'),
            ),
            ToolInfo(
              id: 'tool-meetings',
              icon: Icons.event_available_outlined,
              title: tr('Koç görüşmeleri'),
              status: tr('Koçların öğrencileriyle görüşme düzeni'),
              open: (c) => c.push('/admin/meetings'),
            ),
          ],
        );
        if (coaches.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              strip,
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SectionEmpty(
                    icon: Icons.groups_outlined,
                    message: tr('Henüz koç yok. Kod oluştur ve koçuna gönder.'),
                    actionLabel: tr('Koç davet et'),
                    actionIcon: Icons.person_add_alt_1,
                    onAction: () => showInviteCodeDialog(
                      context,
                      ref,
                      role: UserRole.coach,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96 + cockpitNavHeight),
          children: [
            strip,
            const SizedBox(height: 14),
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
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: context.cockpit.faint,
                          foregroundColor: context.cockpit.ink,
                          child: Text(
                            c.fullName
                                .trim()
                                .split(RegExp(r'\s+'))
                                .take(2)
                                .map((p) => p.isEmpty ? '' : p.characters.first)
                                .join()
                                .toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
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
                                    color: context.cockpit.muted,
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
                                      color: context.cockpit.warn,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: ValueKey('coach-phone-${c.id}'),
                          tooltip: phones[c.id] == null
                              ? tr('Telefon ekle')
                              : tr('Telefonu düzenle'),
                          icon: Icon(
                            phones[c.id] == null
                                ? Icons.add_call
                                : Icons.phone_outlined,
                          ),
                          onPressed: () => editCoachPhone(
                            context,
                            ref,
                            c.id,
                            c.fullName,
                            phones[c.id],
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

/// Davetler sayfası (Koçlar sekmesindeki şeritten): aktif kodlar ve yeni
/// öğrenci daveti.
class InvitesPage extends ConsumerWidget {
  const InvitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(tr('Davetler'))),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () =>
          showInviteCodeDialog(context, ref, role: UserRole.student),
      icon: const Icon(Icons.add),
      label: Text(tr('Öğrenci daveti')),
    ),
    body: const _InvitesTab(),
  );
}

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96 + cockpitNavHeight),
          children: [
            Text(
              tr(
                'Kurumdaki aktif davet kodları. Kodlar 14 gün geçerli; kullanım hakkı dolan kodlar listeden düşer.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (list.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SectionEmpty(
                    icon: Icons.vpn_key_outlined,
                    message: tr(
                      'Aktif davet yok. Koç ya da öğrenci daveti oluşturduğunda burada görünür.',
                    ),
                    actionLabel: tr('Öğrenci daveti oluştur'),
                    actionIcon: Icons.add,
                    onAction: () => showInviteCodeDialog(
                      context,
                      ref,
                      role: UserRole.student,
                    ),
                  ),
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
                      color: context.cockpit.faint,
                    ),
                    child: Icon(
                      i.role == UserRole.coach
                          ? Icons.groups_outlined
                          : Icons.school_outlined,
                      color: context.cockpit.ink,
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
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: context.cockpit.good,
                  ),
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
