import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../shared/widgets/common.dart';
import '../../../finance/data/finance_repository.dart'
    show formatPhone, normalizePhone;
import '../../data/cockpit_repository.dart';
import 'attention_row.dart' show callPhone;
import 'cockpit_theme.dart';
import 'section_states.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/haptics.dart';

/// Koç performansı: koç başına öğrenci sayısı, bu haftaki görüşmeler ve
/// öğrencilerinin bu haftaki aktifliği.
class CoachPerformanceSection extends ConsumerWidget {
  const CoachPerformanceSection({
    super.key,
    required this.onInviteCoach,
    required this.onInviteStudent,
  });

  final VoidCallback onInviteCoach;

  /// Bu koça bağlanacak öğrenci daveti.
  final ValueChanged<String> onInviteStudent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(cockpitProvider);
    return CockpitSection(
      key: const ValueKey('section-coaches'),
      title: tr('Koç performansı'),
      subtitle: tr('Görüşmeler pazartesiden bu yana; aktiflik son 7 gün'),
      trailing: TextButton(
        onPressed: () => context.push('/admin/meetings'),
        child: Text(tr('Haftalık ayrıntı')),
      ),
      child: CockpitAsync(
        value: value,
        onRetry: () => ref.invalidate(cockpitProvider),
        builder: (d) => d.coaches.isEmpty
            ? SectionEmpty(
                icon: Icons.groups_outlined,
                message: tr('Kurumda henüz koç yok.'),
                actionLabel: tr('Koç davet et'),
                actionIcon: Icons.person_add_alt_1,
                onAction: onInviteCoach,
              )
            : Column(
                children: [
                  for (final (i, c) in d.coaches.indexed) ...[
                    if (i > 0) const Divider(height: 20),
                    _CoachRow(
                      key: ValueKey('coach-${c.coachId}'),
                      coach: c,
                      onInviteStudent: () => onInviteStudent(c.coachId),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CoachRow extends ConsumerWidget {
  const _CoachRow({
    super.key,
    required this.coach,
    required this.onInviteStudent,
  });

  final CoachStat coach;
  final VoidCallback onInviteStudent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = coach;
    final text = Theme.of(context).textTheme;
    final ratio = c.activeRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.name,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (c.phone != null)
              IconButton(
                tooltip: tr('Koçu ara'),
                icon: const Icon(Icons.call_outlined),
                onPressed: () => callPhone(context, c.phone!),
              ),
            PopupMenuButton<String>(
              key: ValueKey('coach-menu-${c.coachId}'),
              tooltip: tr('Seçenekler'),
              onSelected: (v) {
                if (v == 'phone') {
                  editCoachPhone(context, ref, c.coachId, c.name, c.phone);
                }
                if (v == 'invite') onInviteStudent();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'phone',
                  child: Text(
                    c.phone == null
                        ? tr('Telefon ekle')
                        : tr('Telefonu düzenle'),
                  ),
                ),
                PopupMenuItem(
                  value: 'invite',
                  child: Text(tr('Bu koça öğrenci daveti')),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Stat(value: '${c.students}', label: tr('öğrenci')),
            ),
            Expanded(
              child: c.meetingsPlanned == 0
                  ? _Stat(value: '–', label: tr('planlı görüşme yok'))
                  : _Stat(
                      value: '${c.meetingsHeld} / ${c.meetingsPlanned}',
                      label: tr('görüşme yapıldı'),
                    ),
            ),
            Expanded(
              child: ratio == null
                  ? _Stat(value: '–', label: tr('aktif öğrenci'))
                  : _Stat(
                      value: '${c.active} / ${c.students}',
                      label: tr('aktif öğrenci'),
                      ratio: ratio,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.ratio});

  final String value;
  final String label;

  /// Doluysa altında ince oran çubuğu (renk eşiğe göre).
  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final tone = ratio == null ? null : Tone.forRatio(ratio!);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(label, style: cockpitLabel(context)),
          if (ratio != null) ...[
            const SizedBox(height: 6),
            Semantics(
              label: tr('Yüzde {p}', {'p': (ratio! * 100).round()}),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio!),
                  duration: AppMotion.of(context, AppMotion.base),
                  curve: AppMotion.enter,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    color: tone!.of(context),
                    backgroundColor: context.cockpit.faint,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Koç telefonunu ekler / değiştirir / siler (boş bırakılırsa silinir).
Future<void> editCoachPhone(
  BuildContext context,
  WidgetRef ref,
  String coachId,
  String coachName,
  String? current,
) async {
  String? error;
  final result = await showDialog<String>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (context) => ControllerScope(
      initial: current == null ? '' : formatPhone(current),
      builder: (context, controller) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('{name} · telefon', {'name': coachName})),
          content: TextField(
            key: const ValueKey('coach-phone-field'),
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: tr('Cep telefonu'),
              hintText: '0532 123 45 67',
              helperText: tr('Kokpitteki "Koçu ara" düğmesi bu numarayı arar.'),
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Vazgeç')),
            ),
            FilledButton(
              key: const ValueKey('coach-phone-save'),
              onPressed: () {
                final t = controller.text.trim();
                if (t.isEmpty) return Navigator.pop(context, '');
                final p = normalizePhone(t);
                if (p == null) {
                  setLocal(() => error = tr('Geçerli bir cep telefonu yaz.'));
                  return;
                }
                Navigator.pop(context, p);
              },
              child: Text(tr('Kaydet')),
            ),
          ],
        ),
      ),
    ),
  );
  if (result == null) return;
  try {
    await ref
        .read(cockpitRepositoryProvider)
        .setCoachPhone(coachId, result.isEmpty ? null : result);
    ref.invalidate(cockpitProvider);
    AppHaptics.confirm();
    if (context.mounted) {
      showMessage(
        context,
        result.isEmpty ? tr('Telefon silindi.') : tr('Telefon kaydedildi.'),
      );
    }
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Telefon kaydedilemedi. Tekrar dene.'));
    }
  }
}
