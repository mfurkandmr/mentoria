import 'package:flutter/foundation.dart';

/// Derleme zamanı ortam değişkenleri.
///
/// Çalıştırma: `flutter run --dart-define-from-file=env.json`
/// (şablon için `env.example.json` dosyasına bakın).
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// `--dart-define=DEMO=true`: Supabase'e bağlanmadan örnek verilerle açılır
  /// (arayüz geliştirme ve mağaza ekran görüntüleri için).
  static const isDemo = bool.fromEnvironment('DEMO');

  /// `--dart-define=DEMO_RICH=true`: demo kurumu kalabalık açılır (24 öğrenci,
  /// 4 koç); sunum için. Testler küçük demo verisini kullanır.
  static const demoRich = bool.fromEnvironment('DEMO_RICH');

  /// Demo modunda hangi rolün ekranları açılsın: `student` (varsayılan) ya da
  /// `coach` (`--dart-define=DEMO_ROLE=coach`).
  static const demoRole = String.fromEnvironment(
    'DEMO_ROLE',
    defaultValue: 'student',
  );

  static const _demoRoles = {'student', 'coach', 'admin', 'parent', 'teacher'};

  /// Demo modunda açılan rol. Web demosunda (`/demo`) rol adresten okunur:
  /// önce `?rol=coach`, yoksa yoldaki rol bölümü (`/demo/panel/coach/...`;
  /// sayfa yenilenince aynı rol kalsın diye). Yoksa [demoRole].
  static final String activeDemoRole = kIsWeb
      ? demoRoleFromUri(Uri.base)
      : demoRole;

  @visibleForTesting
  static String demoRoleFromUri(Uri uri) {
    final q = uri.queryParameters['rol'];
    if (_demoRoles.contains(q)) return q!;
    for (final s in uri.pathSegments) {
      if (s == 'platform') return 'admin';
      if (_demoRoles.contains(s)) return s;
    }
    return demoRole;
  }

  /// Demo modunda kullanıcının dershanesi (white label denemesi için):
  /// `--dart-define=DEMO_TENANT=yildiz`. Boşsa varsayılan demo dershanesi.
  static const demoTenant = String.fromEnvironment('DEMO_TENANT');

  /// Paylaşılabilir davet/dershane linklerinin kökü. Boşsa web'de uygulamanın
  /// kendi adresi, mobilde `mentoria://app` kullanılır. Web derlemesi
  /// (`tool/web/build_web.py`) `https://mentoria.com.tr/app` verir.
  static const appLinkBase = String.fromEnvironment('APP_LINK_BASE');

  // Web bildirimleri (FCM). Firebase konsolunda kayıtlı web uygulamasının
  // ayarları; hepsi tarayıcıya giden herkese açık değerlerdir (gizli değil).
  // Proje kimliği ve gönderen numarası android/app/google-services.json ile
  // aynı proje. Web uygulama kimliği yoksa web bildirimi kapalı kalır.
  static const firebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );
  static const firebaseWebAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'mentoria-4939f',
  );
  static const firebaseSenderId = String.fromEnvironment(
    'FIREBASE_SENDER_ID',
    defaultValue: '1075014627516',
  );

  /// Web Push sertifikasının herkese açık anahtarı (Firebase → Cloud
  /// Messaging → Web Push certificates).
  static const firebaseVapidKey = String.fromEnvironment(
    'FIREBASE_VAPID_KEY',
    defaultValue:
        'BGAVxwOB6QIFnyuU32n1UDLNNnDk848-SdxoZkKH9ky3IUPqyxHJpAntjeX4LkKH6bLd2q20GyfNs3VoVJsHIn4',
  );

  static bool get webPushConfigured =>
      firebaseWebApiKey.isNotEmpty && firebaseWebAppId.isNotEmpty;
}
