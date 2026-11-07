import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/brand_theme.dart';
import 'push_service.dart';

/// Web: "Bildirimleri aç" kartı. Tarayıcı izni henüz sorulmamışsa
/// ([PushService.webAsk]) sağ üstte belirir; izin penceresi yalnızca
/// kullanıcı "Aç"a dokununca açılır. "Şimdi değil" kartı 14 gün gizler.
/// Uygulama kökünde (app.dart) bütün rollerin üstünde durur.
class WebPushPrompt extends ConsumerStatefulWidget {
  const WebPushPrompt({super.key});

  static const _snoozeKey = 'web_push_prompt_snoozed_until';
  static const snooze = Duration(days: 14);

  @override
  ConsumerState<WebPushPrompt> createState() => _WebPushPromptState();
}

class _WebPushPromptState extends ConsumerState<WebPushPrompt> {
  bool _busy = false;

  bool get _snoozed {
    final ms = ref
        .read(sharedPreferencesProvider)
        ?.getInt(WebPushPrompt._snoozeKey);
    return ms != null && DateTime.now().millisecondsSinceEpoch < ms;
  }

  void _later() {
    final until = DateTime.now().add(WebPushPrompt.snooze);
    ref
        .read(sharedPreferencesProvider)
        ?.setInt(WebPushPrompt._snoozeKey, until.millisecondsSinceEpoch);
    PushService.webAsk.value = false;
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    await ref.read(pushServiceProvider).enableWeb();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: PushService.webAsk,
    builder: (context, ask, _) {
      if (!ask || _snoozed) return const SizedBox.shrink();
      final brand = context.brand;
      final theme = Theme.of(context);
      return SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                key: const ValueKey('web-push-prompt'),
                elevation: 6,
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: brand.primaryDeep,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('Bildirimleri aç'),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(
                                    'Ödev, görüşme, mesaj ve deneme sonuçları sayfa kapalıyken de gelsin.',
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            key: const ValueKey('web-push-later'),
                            onPressed: _busy ? null : _later,
                            child: Text(tr('Şimdi değil')),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            key: const ValueKey('web-push-enable'),
                            onPressed: _busy ? null : _enable,
                            child: Text(tr('Aç')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
