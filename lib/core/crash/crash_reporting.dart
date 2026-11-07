import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_version.dart';
import '../config/env.dart';
import 'web_error_reporter.dart';

/// Çökme raporlama (Firebase Crashlytics): yakalanmamış hatalar ve çökmeler
/// Firebase konsoluna düşer; kullanıcının telefonunda bir şey bozulursa
/// haberimiz olur.
///
/// - Telefonda (Android/iOS) sürüm derlemesinde Crashlytics; geliştirme
///   sırasında ve Firebase başlatılamadıysa kapalı.
/// - Web'de Crashlytics yok: sürüm derlemesinde hatalar kendi tablomuza
///   (`client_errors`, [WebErrorReporter]) yazılır; demo ve ayarsız
///   çalıştırmada kapalı.
/// - KVKK: kullanıcı kimliği, ad, e-posta gönderilmez. Rapor; hata yığını,
///   cihaz modeli, işletim sistemi sürümü ve uygulama sürümünden oluşur
///   (bkz. docs/kvkk/01_veri_envanteri.md).
Future<void> initCrashReporting() async {
  if (kIsWeb) {
    _initWebErrorReporting();
    return;
  }
  if (Firebase.apps.isEmpty) return;
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

void _initWebErrorReporting() {
  if (!kReleaseMode || Env.isDemo || !Env.isConfigured) return;
  final reporter = WebErrorReporter(
    (params) =>
        Supabase.instance.client.rpc('report_client_error', params: params),
  );
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    reporter.report(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report(error, stack);
    return true;
  };
}
