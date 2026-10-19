import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'exam_trends_card.dart';
import '../../announcements/presentation/announcement_widgets.dart';
import '../../../core/branding/branding_providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../../shared/widgets/honey_nav_bar.dart';
import '../../auth/data/auth_repository.dart';
import '../../meetings/data/meeting_repository.dart';
import '../../meetings/presentation/meeting_widgets.dart';
import '../data/coach_repository.dart';
import 'invite_sheet.dart';
import 'manager_widgets.dart';

/// Koçun ana ekranı: gökyüzü başlığı ve Bızz, haftalık özet, hızlı işlemler
/// ve öğrenci kartları.
class CoachHomeScreen extends ConsumerWidget {
  const CoachHomeScreen({super.key});

  void _openInvite(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const InviteSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentSummariesProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final list = students.value ?? const <StudentSummary>[];

    Future<void> refresh() {
      // Kurum adı/logosu değiştiyse yenilensin.
      ref.invalidate(tenantBrandingProvider);
      invalidateMeetings(ref);
      return ref.refresh(studentSummariesProvider.future);
    }

    final List<Widget> body = students.when(
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
                Text(tr('Öğrenciler yüklenemedi.')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(studentSummariesProvider),
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
            child: _CoachBody(
              students: list,
              onInvite: () => _openInvite(context),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      // Öğrenci menüsü gibi alt menü; hızlı işlem kutuları da yerinde durur.
      bottomNavigationBar: HoneyNavBar(
        selectedIndex: 0,
        onSelected: (i) {
          switch (i) {
            case 1:
              _openInvite(context);
            case 2:
              context.push('/coach/homework');
            case 3:
              context.push('/coach/import');
            case 4:
              context.push('/coach/exams');
          }
        },
        items: [
          HoneyNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: tr('Ana Sayfa'),
          ),
          HoneyNavItem(
            icon: Icons.person_add_alt_1_outlined,
            label: tr('Davet et'),
            tooltip: tr('Öğrenci davet et'),
          ),
          HoneyNavItem(icon: Icons.assignment_add, label: tr('Ödev ver')),
          HoneyNavItem(
            icon: Icons.upload_file_rounded,
            label: tr('Yükle'),
            tooltip: tr('Deneme sonuçlarını yükle'),
          ),
          HoneyNavItem(
            icon: Icons.fact_check_outlined,
            label: tr('Denemeler'),
            tooltip: tr('Yüklediğin denemeler'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        edgeOffset: 100,
        child: CustomScrollView(
          slivers: [
            ManagerSkyAppBar(
              firstName: profile?.firstName ?? '',
              lines: managerBizzLines(list),
              actions: [
                ProfileInitialsButton(
                  name: profile?.fullName ?? '',
                  onPressed: () => context.push('/coach/profile'),
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

class _CoachBody extends StatefulWidget {
  const _CoachBody({required this.students, required this.onInvite});

  final List<StudentSummary> students;
  final VoidCallback onInvite;

  @override
  State<_CoachBody> createState() => _CoachBodyState();
}

class _CoachBodyState extends State<_CoachBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final students = widget.students;
    final weekQuestions = students.fold<int>(0, (a, s) => a + s.weekQuestions);
    final pending = students.fold<int>(0, (a, s) => a + s.pendingTasks);
    final active = students.where((s) => s.activeThisWeek).length;
    final maxWeek = students.fold<int>(
      0,
      (a, s) => s.weekQuestions > a ? s.weekQuestions : a,
    );
    final missingNumbers = students
        .where((s) => s.studentNumber == null)
        .length;
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

    final children = <Widget>[
      StatRow(
        children: [
          GlowStat(
            icon: Icons.groups_rounded,
            label: tr('Öğrenciler'),
            value: students.length.toDouble(),
            caption: tr('{n} aktif', {'n': active}),
            color: brand.secondary,
          ),
          GlowStat(
            icon: Icons.edit_note_rounded,
            label: tr('Bu hafta'),
            value: weekQuestions.toDouble(),
            caption: tr('soru çözüldü'),
            color: brand.primary,
          ),
          GlowStat(
            icon: Icons.assignment_late_rounded,
            label: tr('Bekleyen'),
            value: pending.toDouble(),
            caption: tr('görev'),
            color: brand.info,
          ),
        ],
      ),
      Column(
        children: [
          StatRow(
            children: [
              QuickActionTile(
                icon: Icons.person_add_alt_1_rounded,
                label: tr('Davet et'),
                tooltip: tr('Öğrenci davet et'),
                color: brand.secondary,
                onTap: widget.onInvite,
              ),
              QuickActionTile(
                icon: Icons.assignment_add,
                label: tr('Ödev ver'),
                color: brand.primary,
                onTap: () => context.push('/coach/homework'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatRow(
            children: [
              QuickActionTile(
                icon: Icons.upload_file_rounded,
                label: tr('Deneme yükle'),
                tooltip: tr('Deneme sonuçlarını yükle'),
                color: brand.info,
                onTap: () => context.push('/coach/import'),
              ),
              QuickActionTile(
                icon: Icons.fact_check_rounded,
                label: tr('Denemeler'),
                tooltip: tr('Yüklediğin denemeler'),
                color: brand.success,
                onTap: () => context.push('/coach/exams'),
              ),
            ],
          ),
        ],
      ),
      if (missingNumbers > 0)
        PanelNotice(
          icon: Icons.badge_outlined,
          message: tr(
            '{count} öğrencinin okul numarası eksik. Deneme sonuç dosyaları öğrencilere okul numarasıyla eşleştirilir; öğrenciye dokunup numarasını gir.',
            {'count': missingNumbers},
          ),
        ),
      const AnnouncementsHomeCard(),
      const WeekMeetingsSection(),
      const ExamTrendsCard(basePath: '/coach'),
      PanelSectionTitle(
        title: tr('Öğrencilerin'),
        subtitle: tr('{p0} öğrencin var', {'p0': students.length}),
      ),
      if (students.isEmpty) _EmptyStudents(onInvite: widget.onInvite),
      if (students.length > 5)
        TextField(
          decoration: InputDecoration(
            hintText: tr('Öğrenci adı veya numarası ara'),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      for (final s in visible)
        StudentCard(
          key: ValueKey(s.id),
          student: s,
          maxWeekQuestions: maxWeek,
          onTap: () => context.push('/coach/students/${s.id}'),
        ),
      if (students.isNotEmpty && visible.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            tr('"{_query}" ile eşleşen öğrenci yok.', {'_query': _query}),
            textAlign: TextAlign.center,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          staggered(i, c),
        ],
      ],
    );
  }
}

class _EmptyStudents extends StatelessWidget {
  const _EmptyStudents({required this.onInvite});

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Bizz(size: 110),
            const SizedBox(height: 12),
            Text(
              tr('Henüz öğrencin yok'),
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Bir davet kodu oluştur ve öğrencine gönder. Kodla kayıt olan öğrenci otomatik olarak sana bağlanır.',
              ),
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(tr('Öğrenci davet et')),
            ),
          ],
        ),
      ),
    );
  }
}
