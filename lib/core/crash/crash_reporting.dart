import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/app_version.dart';

/// Çökme raporlama (Firebase Crashlytics): yakalanmamış hatalar ve çökmeler
/// Firebase konsoluna düşer; kullanıcının telefonunda bir şey bozulursa
/// haberimiz olur.
///
/// - Yalnızca telefonda (Android/iOS) ve sürüm derlemesinde açık; web'de,
///   geliştirme sırasında ve Firebase başlatılamadıysa kapalı.
/// - KVKK: kullanıcı kimliği, ad, e-posta gönderilmez. Rapor; hata yığını,
///   cihaz modeli, işletim sistemi sürümü ve uygulama sürümünden oluşur
///   (bkz. docs/kvkk/01_veri_envanteri.md).
Future<void> initCrashReporting() async {
  if (kIsWeb || Firebase.apps.isEmpty) return;
  try {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    if (kDebugMode) return;
    await crashlytics.setCustomKey('build', appBuild);

    // Flutter çerçevesinin yakaladığı hatalar (çizim, düzen, olay).
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    // Çerçevenin dışında kalan asenkron hatalar.
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Çökme raporlama başlatılamadı: $e');
  }
}
