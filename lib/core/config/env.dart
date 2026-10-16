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

  /// Demo modunda hangi rolün ekranları açılsın: `student` (varsayılan) ya da
  /// `coach` (`--dart-define=DEMO_ROLE=coach`).
  static const demoRole = String.fromEnvironment(
    'DEMO_ROLE',
    defaultValue: 'student',
  );

  /// Demo modunda kullanıcının dershanesi (white label denemesi için):
  /// `--dart-define=DEMO_TENANT=yildiz`. Boşsa varsayılan demo dershanesi.
  static const demoTenant = String.fromEnvironment('DEMO_TENANT');

  /// Paylaşılabilir davet/dershane linklerinin kökü. Boşsa web'de uygulamanın
  /// kendi adresi, mobilde `mentoria://app` kullanılır.
  /// Örn: `--dart-define=APP_LINK_BASE=https://app.mentoria.com.tr`
  static const appLinkBase = String.fromEnvironment('APP_LINK_BASE');
}
