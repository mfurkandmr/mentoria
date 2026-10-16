import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../i18n/i18n.dart';

/// Kurumun seçebileceği yazı tipleri (Google Fonts). Her biri ayrı bir
/// tarzdadır (yuvarlak, geometrik, tırnaklı, dar, el yazısı…) ki seçenekler
/// birbirine benzemesin. Hepsi Türkçe karakterleri (ç ğ ı İ ö ş ü) destekler.
///
/// Anahtarlar veritabanındaki `tenants.font_family` kısıtıyla aynıdır
/// (supabase/migrations/20261018120000_tenant_fonts_v2.sql).
///
/// Yazı tipleri adla (`GoogleFonts.getFont`) değil, her biri kendi
/// fonksiyonuyla çağrılır: böylece derlemeye yalnızca bu 10 yazı tipi girer
/// (adla çağırmak Google Fonts'un bütün kataloğunu uygulamaya ekler ve APK'yı
/// ~30 MB büyütür).
enum AppFont {
  nunito('nunito', 'Nunito', 'Yuvarlak'),
  poppins('poppins', 'Poppins', 'Geometrik'),
  merriweather('merriweather', 'Merriweather', 'Klasik tırnaklı'),
  playfairDisplay('playfair_display', 'Playfair Display', 'Zarif'),
  robotoSlab('roboto_slab', 'Roboto Slab', 'Kalın tırnaklı'),
  oswald('oswald', 'Oswald', 'Dar ve uzun'),
  baloo2('baloo_2', 'Baloo 2', 'Tombul ve neşeli'),
  patrickHand('patrick_hand', 'Patrick Hand', 'El yazısı'),
  spaceMono('space_mono', 'Space Mono', 'Daktilo'),
  exo2('exo_2', 'Exo 2', 'Fütüristik');

  const AppFont(this.key, this.family, this.trKind);

  /// Veritabanındaki değer.
  final String key;

  /// Google Fonts'taki adı (ekranda da bu ad gösterilir).
  final String family;
  final String trKind;

  /// Kısa tarif ("El yazısı", "Zarif"…).
  String get kind => tr(trKind);

  /// Mentoria'nın varsayılanı.
  static const fallback = AppFont.nunito;

  /// Bilinmeyen ya da boş anahtar varsayılana düşer.
  static AppFont fromKey(String? key) =>
      AppFont.values.where((f) => f.key == key).firstOrNull ?? fallback;

  /// Bu yazı tipiyle bir metin stili.
  TextStyle style({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    final make = switch (this) {
      nunito => GoogleFonts.nunito,
      poppins => GoogleFonts.poppins,
      merriweather => GoogleFonts.merriweather,
      playfairDisplay => GoogleFonts.playfairDisplay,
      robotoSlab => GoogleFonts.robotoSlab,
      oswald => GoogleFonts.oswald,
      baloo2 => GoogleFonts.baloo2,
      patrickHand => GoogleFonts.patrickHand,
      spaceMono => GoogleFonts.spaceMono,
      exo2 => GoogleFonts.exo2,
    };
    return make(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  /// Temanın tüm metinleri bu yazı tipiyle.
  TextTheme textTheme(TextTheme base) => switch (this) {
    nunito => GoogleFonts.nunitoTextTheme(base),
    poppins => GoogleFonts.poppinsTextTheme(base),
    merriweather => GoogleFonts.merriweatherTextTheme(base),
    playfairDisplay => GoogleFonts.playfairDisplayTextTheme(base),
    robotoSlab => GoogleFonts.robotoSlabTextTheme(base),
    oswald => GoogleFonts.oswaldTextTheme(base),
    baloo2 => GoogleFonts.baloo2TextTheme(base),
    patrickHand => GoogleFonts.patrickHandTextTheme(base),
    spaceMono => GoogleFonts.spaceMonoTextTheme(base),
    exo2 => GoogleFonts.exo2TextTheme(base),
  };
}
