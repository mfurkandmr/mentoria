import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/exam_subjects.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/format.dart';
import '../../../coach/data/coach_repository.dart';
import '../../data/cockpit_repository.dart';
import 'attention_row.dart';
import 'cockpit_motion.dart';
import 'cockpit_theme.dart';
import 'section_states.dart';

enum AttentionKind { inactive, netDrop, overdue }

/// "Dikkat gerektirenler": 7+ gündür girmeyen, son iki denemede 3+ net
/// düşen ve taksiti geciken öğrenciler. Her satırdan koça bildirim / arama.
class AttentionSection extends ConsumerStatefulWidget {
  const AttentionSection({super.key, required this.onInviteStudent});

  /// Kurumda hiç öğrenci yokken boş haldeki eylem.
  final VoidCallback onInviteStudent;

  @override
  ConsumerState<AttentionSection> createState() => _AttentionSectionState();
}

class _AttentionSectionState extends ConsumerState<AttentionSection> {
  AttentionKind? _kind;
  bool _all = false;

  static const _visible = 5;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(cockpitProvider);
    final count = value.value?.attentionCount;
    return CockpitSection(
      key: const ValueKey('section-attention'),
      title: tr('Dikkat gerektirenler'),
      subtitle: count == null || count == 0
          ? null
          : tr('{n} öğrenci', {'n': count}),
      trailing: TextButton(
        onPressed: () => context.push('/admin/risk'),
        child: Text(tr('Risk listesi')),
      ),
      child: CockpitAsync(
        value: value,
        onRetry: () => ref.invalidate(cockpitProvider),
        builder: (d) => _body(context, d),
      ),
    );
  }

  Widget _body(BuildContext context, CockpitData d) {
    if (d.students == 0) {
      return SectionEmpty(
        icon: Icons.school_outlined,
        message: tr('Kurumda henüz öğrenci yok.'),
        actionLabel: tr('Öğrenci davet et'),
        actionIcon: Icons.person_add_alt_1,
        onAction: widget.onInviteStudent,
      );
    }
    if (d.attentionCount == 0) {
      return Row(
        key: const ValueKey('attention-none'),
        children: [
          Icon(Icons.check_circle_outline, color: context.cockpit.good),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('Şu an dikkat gerektiren öğrenci yok.'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    final lists = {
      AttentionKind.inactive: d.inactive,
      AttentionKind.netDrop: d.netDrops,
      AttentionKind.overdue: d.overdue,
    };
    // İlk açılışta dolu olan ilk grup.
    final kind =
        _kind ?? lists.entries.firstWhere((e) => e.value.isNotEmpty).key;
    final rows = lists[kind]!;
    final shown = _all ? rows : rows.take(_visible).toList();
    final phones = {for (final c in d.coaches) c.coachId: c.phone};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // iOS kayan seçim kontrolü: ad ve sayı iki satır (etiket kesilmez).
        SlidingSegments<AttentionKind>(
          key: const ValueKey('attention-kinds'),
          value: kind,
          onChanged: (k) => setState(() {
            _kind = k;
            _all = false;
          }),
          segments: {
            AttentionKind.inactive: (
              key: const ValueKey('kind-inactive'),
              label: tr('Giriş yok'),
              count: '${d.inactive.length}',
            ),
            AttentionKind.netDrop: (
              key: const ValueKey('kind-netDrop'),
              label: tr('Net düşüşü'),
              count: '${d.netDrops.length}',
            ),
            AttentionKind.overdue: (
              key: const ValueKey('kind-overdue'),
              label: tr('Ödeme'),
              count: '${d.overdue.length}',
            ),
          },
        ),
        const SizedBox(height: 12),
        // Grup değişince liste yumuşakça yer değiştirir.
        SmoothSwitch(
          child: KeyedSubtree(
            key: ValueKey('attention-list-${kind.name}-$_all'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_explain(kind), style: cockpitLabel(context)),
                if (kind == AttentionKind.netDrop) const _OrgAverageLine(),
                const SizedBox(height: 4),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      tr('Bu grupta öğrenci yok.'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.cockpit.muted,
                      ),
                    ),
                  )
                else
                  for (final (i, s) in shown.indexed) ...[
                    if (i > 0) const Divider(),
                    AttentionRow(
                      key: ValueKey('attention-${kind.name}-${s.studentId}'),
                      student: s,
                      coachPhone: phones[s.coachId],
                    ),
                  ],
                if (rows.length > _visible)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => setState(() => _all = !_all),
                      child: Text(
                        _all
                            ? tr('Daha az göster')
                            : tr('Tümünü gör ({n})', {'n': rows.length}),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _explain(AttentionKind k) => switch (k) {
    AttentionKind.inactive => tr('7 gün ya da daha uzun süredir girmeyenler'),
    AttentionKind.netDrop => tr(
      'Son iki denemesi arasında 3 ya da daha çok net düşenler',
    ),
    AttentionKind.overdue => tr('Vadesi geçmiş, ödenmemiş taksiti olanlar'),
  };
}

/// Kurumun son TYT ortalaması (eski panelin "Ort. son TYT" göstergesi).
class _OrgAverageLine extends ConsumerWidget {
  const _OrgAverageLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentSummariesProvider).value ?? const [];
    final nets = [
      for (final s in students)
        if (s.lastExamType == ExamType.tyt && s.lastTotalNet != null)
          s.lastTotalNet!,
    ];
    if (nets.isEmpty) return const SizedBox.shrink();
    final avg = nets.reduce((a, b) => a + b) / nets.length;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        tr('Kurumun son TYT ortalaması: {v} net ({n} öğrenci)', {
          'v': formatNet(avg),
          'n': nets.length,
        }),
        key: const ValueKey('org-tyt-average'),
        style: cockpitLabel(context),
      ),
    );
  }
}
