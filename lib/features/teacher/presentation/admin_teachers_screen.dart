import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/panel.dart';
import '../../admin/presentation/admin_home_screen.dart'
    show showInviteCodeDialog;
import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../admin/presentation/cockpit/section_states.dart';
import '../../auth/data/profile.dart';
import '../../schedule_generator/data/timetable_repository.dart';
import '../data/teacher_repository.dart';

/// Müdür: kurumun öğretmenleri (NOTLAR §86). Davetle kayıt olan öğretmen
/// listeye kendiliğinden düşer ("Hesabı var"); elle eklenip hesabı
/// olmayanlar "Hesap yok". Aynı adlı iki satır varsa birleştirme önerilir.
class AdminTeachersScreen extends ConsumerWidget {
  const AdminTeachersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(timetableSetupProvider);
    void invite() => showInviteCodeDialog(context, ref, role: UserRole.teacher);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Öğretmenler')),
        actions: [
          IconButton(
            tooltip: tr('Ders programı ayarları'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/admin/schedule/setup'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('invite-teacher'),
        onPressed: invite,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('Öğretmen davet et')),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(timetableSetupProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Text(
              tr(
                'Öğretmen davet koduyla kayıt olan öğretmen buraya kendiliğinden eklenir ve kendi panelinden programını görür. Elle eklediğin öğretmenlerin hesabı yoktur.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            CockpitAsync<TimetableSetup>(
              value: setup,
              onRetry: () => ref.invalidate(timetableSetupProvider),
              builder: (s) => _TeacherList(setup: s, onInvite: invite),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherList extends ConsumerWidget {
  const _TeacherList({required this.setup, required this.onInvite});

  final TimetableSetup setup;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachers = [...setup.teachers]
      ..sort((a, b) => a.teacher.name.compareTo(b.teacher.name));
    if (teachers.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SectionEmpty(
            icon: Icons.co_present_outlined,
            message: tr('Henüz öğretmen yok. Davet kodu oluştur ve gönder.'),
            actionLabel: tr('Öğretmen davet et'),
            actionIcon: Icons.person_add_alt_1,
            onAction: onInvite,
          ),
        ),
      );
    }
    final pairs = teacherMergeCandidates([
      for (final t in teachers)
        (
          id: t.teacher.id,
          name: t.teacher.name,
          hasAccount: t.profileId != null,
        ),
    ]);
    final withAccount = teachers.where((t) => t.profileId != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in pairs)
          Card(
            key: ValueKey('merge-${p.fromId}'),
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Icon(Icons.merge_type_rounded, color: context.cockpit.warn),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr(
                        '{name} adında iki kayıt var: biri senin eklediğin, biri kendi kaydı. Aynı kişiyse birleştir; program ve ödeme kayıtları korunur.',
                        {'name': p.name},
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _merge(context, ref, p.keepId, p.fromId),
                    child: Text(tr('Birleştir')),
                  ),
                ],
              ),
            ),
          ),
        Text(
          tr('{n} öğretmen · {a} hesaplı', {
            'n': teachers.length,
            'a': withAccount,
          }),
          style: cockpitLabel(context),
        ),
        const SizedBox(height: 8),
        for (final t in teachers)
          Card(
            key: ValueKey('teacher-${t.teacher.id}'),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: context.cockpit.faint,
                foregroundColor: context.cockpit.ink,
                child: const Icon(Icons.co_present_outlined),
              ),
              title: Text(
                t.teacher.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(t.teacher.branches.join(', ')),
              trailing: InfoPill(
                icon: t.profileId != null
                    ? Icons.verified_user_outlined
                    : Icons.person_off_outlined,
                text: t.profileId != null ? tr('Hesabı var') : tr('Hesap yok'),
                color: t.profileId != null
                    ? context.cockpit.good
                    : context.cockpit.muted,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _merge(
    BuildContext context,
    WidgetRef ref,
    String keepId,
    String fromId,
  ) async {
    final ok = await confirm(
      context,
      title: tr('Kayıtlar birleştirilsin mi?'),
      message: tr(
        'Senin eklediğin kayıt öğretmenin hesabına bağlanır; kayıt olurken açılan ikinci satır silinir.',
      ),
      action: tr('Birleştir'),
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(teacherRepositoryProvider)
          .mergeTeachers(keepId: keepId, fromId: fromId);
      ref.invalidate(timetableSetupProvider);
      if (context.mounted) showMessage(context, tr('Birleştirildi'));
    } catch (e) {
      if (!context.mounted) return;
      showMessage(
        context,
        e.toString().contains('TEACHER_MERGE_CONFLICT')
            ? tr(
                'İki kaydın aynı saatte dersi var. Önce programda birini taşı.',
              )
            : tr('Birleştirilemedi. Tekrar dene.'),
      );
    }
  }
}
