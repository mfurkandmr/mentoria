import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../../admin/presentation/cockpit/section_states.dart';
import '../../schedule_generator/presentation/timetable_format.dart';
import '../data/tutoring_repository.dart';
import 'tutoring_widgets.dart';

/// Öğretmen ana sayfası: bekleyen talepler (onayla / reddet), yaklaşan
/// onaylılar ve haftalık oturumları. Kararı yalnızca öğretmen verir
/// (NOTLAR §87). Oturumu ve talebi yoksa görünmez.
class TeacherTutoringSection extends ConsumerWidget {
  const TeacherTutoringSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(myTutoringSessionsProvider);
    final requests = ref.watch(teacherTutoringRequestsProvider);
    final s = sessions.value ?? const <TutoringSession>[];
    final r = requests.value ?? const <TutoringRequest>[];
    if (sessions.hasValue && requests.hasValue && s.isEmpty && r.isEmpty) {
      return const SizedBox.shrink();
    }
    final pending = [
      for (final x in r)
        if (x.status == TutoringStatus.pending) x,
    ];
    final approved = [
      for (final x in r)
        if (x.status == TutoringStatus.approved) x,
    ];

    return CockpitSection(
      title: tr('Soru çözümü ve birebir'),
      subtitle: pending.isEmpty
          ? tr('Bekleyen talep yok')
          : tr('{n} talep onayını bekliyor', {'n': pending.length}),
      child: CockpitAsync<List<TutoringRequest>>(
        value: requests,
        onRetry: () => ref.invalidate(teacherTutoringRequestsProvider),
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in pending)
              TutoringRequestTile(
                key: ValueKey('teacher-request-${p.id}'),
                request: p,
                showStudent: true,
                showTeacher: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey('reject-${p.id}'),
                      tooltip: tr('Reddet'),
                      icon: Icon(
                        Icons.close_rounded,
                        color: context.cockpit.risk,
                      ),
                      onPressed: () => _decide(context, ref, p, false),
                    ),
                    IconButton(
                      key: ValueKey('approve-${p.id}'),
                      tooltip: tr('Onayla'),
                      icon: Icon(
                        Icons.check_rounded,
                        color: context.cockpit.good,
                      ),
                      onPressed: () => _decide(context, ref, p, true),
                    ),
                  ],
                ),
              ),
            if (approved.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tr('Yaklaşan onaylılar'), style: cockpitLabel(context)),
              for (final a in approved.take(6))
                TutoringRequestTile(
                  key: ValueKey('teacher-approved-${a.id}'),
                  request: a,
                  showStudent: true,
                  showTeacher: false,
                ),
            ],
            if (s.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tr('Haftalık oturumlarım'), style: cockpitLabel(context)),
              const SizedBox(height: 4),
              Text(
                [
                  for (final x in s)
                    '${dayShort(x.day)} ${formatHm(x.start)} '
                        '${x.branch ?? x.kind.label}'
                        '${x.capacity > 1 ? ' (${x.capacity})' : ''}',
                ].join(' · '),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    TutoringRequest r,
    bool approve,
  ) async {
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _RejectDialog(),
      );
      if (reason == null) return;
    }
    try {
      await ref
          .read(tutoringRepositoryProvider)
          .decide(r.id, approve: approve, reason: reason);
      if (context.mounted) {
        showMessage(
          context,
          approve ? tr('Talep onaylandı') : tr('Talep reddedildi'),
        );
      }
    } catch (e) {
      if (context.mounted) showMessage(context, tutoringErrorMessage(e));
    } finally {
      ref.invalidate(teacherTutoringRequestsProvider);
    }
  }
}

class _RejectDialog extends StatelessWidget {
  const _RejectDialog();

  @override
  Widget build(BuildContext context) => ControllerScope(
    builder: (context, c) => AlertDialog(
      title: Text(tr('Talep reddedilsin mi?')),
      content: TextField(
        key: const ValueKey('reject-reason'),
        controller: c,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: tr('Gerekçe (isteğe bağlı, öğrenciye gider)'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        TextButton(
          key: const ValueKey('reject-confirm'),
          onPressed: () => Navigator.pop(context, c.text.trim()),
          child: Text(tr('Reddet')),
        ),
      ],
    ),
  );
}
