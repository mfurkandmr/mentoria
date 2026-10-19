import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/branding_providers.dart';
import 'core/config/app_version.dart';
import 'core/config/env.dart';
import 'core/i18n/i18n.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand_theme.dart';
import 'features/notifications/push/push_service.dart';
import 'shared/widgets/update_required_screen.dart';

class MentoriaApp extends ConsumerWidget {
  const MentoriaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    currentLanguage = settings.language;
    // Telefon bildirimleri: izin, cihaz kaydı ve bildirime dokunma.
    if (!Env.isDemo && Env.isConfigured) ref.watch(pushBootstrapProvider);
    // Dershane markası: renkler, logo ve uygulama adı çalışma anında değişir.
    final brand = BrandTheme.fromBranding(ref.watch(activeBrandingProvider));
    // Sunucu daha yeni bir sürüm istiyorsa başka hiçbir ekran açılmaz.
    final gate = ref.watch(updateGateProvider).value;
    final mustUpdate = gate != null && gate.requiredFor();

    return MaterialApp.router(
      title: brand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(brand),
      darkTheme: AppTheme.dark(brand),
      themeMode: settings.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 400),
      themeAnimationCurve: Curves.easeInOut,
      locale: settings.language == AppLanguage.en
          ? const Locale('en', 'US')
          : const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      // Dil değişince tüm metinlerin yeniden çevrilmesi için alt ağacı yenile.
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(settings.language),
        child: mustUpdate ? UpdateRequiredScreen(gate: gate) : child!,
      ),
    );
  }
}
