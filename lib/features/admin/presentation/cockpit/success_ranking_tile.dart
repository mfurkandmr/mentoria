import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../ranking/data/ranking_repository.dart';
import 'cockpit_theme.dart';

/// Kurum ayarlarındaki başarı sıralaması satırı: açılınca öğrenciler kurum
/// içi sıralamayı ve TYT ilk 5'in avatar ödüllerini görür. Kapalıyken de
/// müdür önizler. (Eski paneldeki kart.)
class SuccessRankingRow extends ConsumerStatefulWidget {
  const SuccessRankingRow({super.key});

  @override
  ConsumerState<SuccessRankingRow> createState() => _SuccessRankingRowState();
}

class _SuccessRankingRowState extends ConsumerState<SuccessRankingRow> {
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
    final text = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('settings-ranking'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.emoji_events_outlined,
              color: context.cockpit.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Başarı sıralaması'), style: cockpitLabel(context)),
                Text(
                  enabled
                      ? tr('Açık: öğrenciler görüyor')
                      : tr('Kapalı: yalnızca sen önizlersin'),
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  tr(
                    'Öğrenciler son 5 denemelerinin ortalamasına göre sıralanır. TYT\'de 1. kral tacı, ilk 3 altın kanat, 4. ve 5. gümüş kanat kazanır.',
                  ),
                  style: text.bodySmall?.copyWith(color: context.cockpit.muted),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  onPressed: () => context.push('/admin/success'),
                  icon: const Icon(Icons.leaderboard_outlined, size: 18),
                  label: Text(enabled ? tr('Sıralamayı gör') : tr('Önizle')),
                ),
              ],
            ),
          ),
          Semantics(
            label: tr('Başarı sıralaması'),
            child: Switch(
              key: const ValueKey('success-ranking-switch'),
              value: enabled,
              onChanged: _busy || !status.hasValue ? null : _toggle,
            ),
          ),
        ],
      ),
    );
  }
}
