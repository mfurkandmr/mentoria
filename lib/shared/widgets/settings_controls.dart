import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sound/app_sounds.dart';
import 'common.dart';

/// Profildeki "Görünüm, dil ve ses" kartı.
class AppearanceCard extends ConsumerWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final text = Theme.of(context).textTheme;

    return SectionCard(
      title: tr('Görünüm, dil ve ses'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Tema'), style: text.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_outlined),
                label: Text(tr('Sistem')),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_outlined),
                label: Text(tr('Açık')),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_outlined),
                label: Text(tr('Koyu')),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              notifier.setThemeMode(s.first);
            },
          ),
          const SizedBox(height: 16),
          Text(tr('Dil'), style: text.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<AppLanguage>(
            showSelectedIcon: false,
            segments: [
              for (final l in AppLanguage.values)
                ButtonSegment(
                  value: l,
                  label: Text(
                    '${l == AppLanguage.tr ? '🇹🇷' : '🇬🇧'}  ${l.nativeName}',
                  ),
                ),
            ],
            selected: {settings.language},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              notifier.setLanguage(s.first);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              settings.sounds
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
            title: Text(tr('Sesler')),
            subtitle: Text(
              tr('Bızz’a dokununca ve uygulama açılırken çalan sesler'),
            ),
            value: settings.sounds,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              notifier.setSounds(v);
              // Açınca örnek olarak bir kez çalsın.
              if (v) AppSounds.play(AppSound.bizzTap);
            },
          ),
        ],
      ),
    );
  }
}

/// Giriş ekranlarının köşesindeki küçük dil + tema düğmeleri.
class QuickSettingsBar extends ConsumerWidget {
  const QuickSettingsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isDark = switch (settings.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final other = settings.language == AppLanguage.tr
        ? AppLanguage.en
        : AppLanguage.tr;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            notifier.setLanguage(other);
          },
          child: Text(other == AppLanguage.en ? tr('🇬🇧 EN') : tr('🇹🇷 TR')),
        ),
        IconButton(
          tooltip: isDark ? tr('Açık tema') : tr('Koyu tema'),
          onPressed: () {
            HapticFeedback.selectionClick();
            notifier.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween(begin: 0.5, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              key: ValueKey(isDark),
            ),
          ),
        ),
      ],
    );
  }
}
