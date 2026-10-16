import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/settings/app_settings.dart';
import 'dev/demo_mode.dart';
import 'features/notifications/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mağaza sürümünde hata ayıklama çıktısı telefon günlüğüne (logcat)
  // yazılmaz: hata metinleri adres / kimlik gibi ayrıntılar taşıyabilir.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  await initializeDateFormatting('tr_TR');
  await initializeDateFormatting('en_US');
  final prefs = await SharedPreferences.getInstance();

  if (Env.isConfigured && !Env.isDemo) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
      // PKCE: e-posta bağlantısıyla dönen kod, bu cihazda saklanan doğrulayıcı
      // olmadan işe yaramaz (mentoria:// bağlantısını başka bir uygulama
      // yakalasa bile oturum açamaz).
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
  // Telefon bildirimleri (Android/iOS). Başarısız olursa uygulama çalışmaya
  // devam eder; bildirimler yalnızca uygulama içinde görünür.
  await initFirebase();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (Env.isDemo) ...await buildDemoOverrides(),
      ],
      child: const MentoriaApp(),
    ),
  );
}
