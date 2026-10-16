import 'strings_en.dart';

/// Uygulama dilleri. Kaynak metinler Türkçe yazılır; İngilizce karşılıkları
/// `strings_en.dart` içindedir.
enum AppLanguage {
  tr('tr', 'Türkçe', 'tr_TR'),
  en('en', 'English', 'en_US');

  const AppLanguage(this.code, this.nativeName, this.localeTag);
  final String code;
  final String nativeName;

  /// intl tarih/sayı biçimleri için.
  final String localeTag;
}

/// Seçili dil. MentoriaApp ayarlardan günceller; dil değişince tüm ağaç
/// yeniden kurulur.
AppLanguage currentLanguage = AppLanguage.tr;

/// intl biçimleri için etkin yerel ayar ("tr_TR" / "en_US").
String get localeTag => currentLanguage.localeTag;

/// Türkçe metnin seçili dildeki karşılığı. `{ad}` yer tutucuları [args] ile
/// doldurulur: `tr('{n} soru', {'n': 5})`.
String tr(String text, [Map<String, Object?> args = const {}]) {
  var out = currentLanguage == AppLanguage.en
      ? (enStrings[text] ?? text)
      : text;
  for (final e in args.entries) {
    out = out.replaceAll('{${e.key}}', '${e.value}');
  }
  return out;
}
