import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/format.dart';
import '../../../../shared/widgets/common.dart';
import '../../../finance/data/finance_repository.dart' show formatMoney;
import '../../data/cockpit_repository.dart';
import 'cockpit_theme.dart';
import 'section_states.dart';
import '../../../../core/design/haptics.dart';

/// Satırın sebebi ve anlam rengi.
({String reason, Tone tone}) attentionReason(
  AttentionStudent s,
  DateTime now,
) => switch (s) {
  InactiveStudent(:final seenAt) when seenAt == null => (
    reason: tr('Hiç giriş yapmadı'),
    tone: Tone.risk,
  ),
  final InactiveStudent i => (
    reason: tr('{n} gündür giriş yapmadı', {'n': i.daysSince(now)}),
    tone: i.daysSince(now)! >= 14 ? Tone.risk : Tone.warn,
  ),
  final NetDropStudent d => (
    reason: tr('{type} neti {a} → {b} ({c})', {
      'type': d.examType.label,
      'a': formatNet(d.prevNet),
      'b': formatNet(d.lastNet),
      'c': formatChange(-d.drop),
    }),
    tone: d.drop >= 6 ? Tone.risk : Tone.warn,
  ),
  final OverdueStudent o => (
    reason: [
      tr('{n} taksit gecikti', {'n': o.count}),
      formatMoney(o.amount),
      if (o.oldestDue != null)
        tr('{d} gündür', {'d': now.difference(o.oldestDue!).inDays}),
    ].join(' · '),
    tone: o.oldestDue != null && now.difference(o.oldestDue!).inDays >= 30
        ? Tone.risk
        : Tone.warn,
  ),
};

/// Dikkat listesindeki satır: öğrenci adı, sebep, koçu; tek dokunuşla
/// koça bildirim ya da koçu arama. Satıra dokununca öğrenci detayı açılır.
class AttentionRow extends ConsumerWidget {
  const AttentionRow({super.key, required this.student, this.coachPhone});

  final AttentionStudent student;

  /// Müdürün girdiği koç telefonu; yoksa arama düğmesi görünmez.
  final String? coachPhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = student;
    final (:reason, :tone) = attentionReason(s, DateTime.now());
    final text = Theme.of(context).textTheme;
    final hasCoach = s.coachId != null;
    return InkWell(
      onTap: () => context.push('/admin/students/${s.studentId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Renk tek başına anlam taşımasın: işaret + metin.
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: tone.of(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: text.bodySmall?.copyWith(
                      color: tone == Tone.risk
                          ? context.cockpit.risk
                          : context.cockpit.warn,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hasCoach
                        ? tr('Koçu: {name}', {'name': s.coachName ?? ''})
                        : tr('Koçu atanmamış'),
                    style: text.bodySmall?.copyWith(
                      color: context.cockpit.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('notify-${s.runtimeType}-${s.studentId}'),
              tooltip: hasCoach
                  ? tr('Koçuna bildir')
                  : tr('Önce öğrenciye koç ata'),
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: hasCoach
                  ? () => notifyCoachFlow(context, ref, s, reason)
                  : null,
            ),
            if (coachPhone != null)
              IconButton(
                key: ValueKey('call-${s.runtimeType}-${s.studentId}'),
                tooltip: tr('Koçu ara'),
                icon: const Icon(Icons.call_outlined),
                onPressed: () => callPhone(context, coachPhone!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Koça bildirim: metin düzenlenebilir, sonra uygulama içi + push.
Future<void> notifyCoachFlow(
  BuildContext context,
  WidgetRef ref,
  AttentionStudent s,
  String reason,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final send = await showDialog<String>(
    context: context,
    builder: (context) => ControllerScope(
      initial: reason,
      builder: (context, controller) => AlertDialog(
        title: Text(
          tr('{coach} bilgilendirilsin', {'coach': s.coachName ?? ''}),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                'Koça uygulama içinde ve telefonuna bildirim gider: "{name} ile ilgilenir misin?"',
                {'name': s.name},
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('notify-reason'),
              controller: controller,
              maxLength: 200,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(labelText: tr('Not')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            key: const ValueKey('notify-send'),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr('Gönder')),
          ),
        ],
      ),
    ),
  );
  if (send == null) return;
  // Önceki mesaj kuyrukta beklemesin.
  messenger.hideCurrentSnackBar();
  try {
    await ref.read(cockpitRepositoryProvider).notifyCoach(s.studentId, send);
    AppHaptics.confirm();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          tr('{coach} bilgilendirildi.', {'coach': s.coachName ?? ''}),
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.toString().contains('COACH_ALERT_RECENT')
              ? tr(
                  'Bu öğrenci için koça son 6 saat içinde zaten bildirim gönderildi.',
                )
              : tr('Bildirim gönderilemedi. Tekrar dene.'),
        ),
      ),
    );
  }
}

/// Telefon uygulamasını numarayla açar.
Future<void> callPhone(BuildContext context, String phone) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
  if (!ok && context.mounted) {
    showMessage(context, tr('Arama başlatılamadı: {p}', {'p': phone}));
  }
}
