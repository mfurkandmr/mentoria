import 'package:flutter/material.dart';

import '../branding/branding.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

/// Tema katmanı: markaya (dershaneye) bağlı tüm renkler ve marka kimliği.
///
/// Widget'lar renkleri koda gömmez, `context.brand.primary` gibi buradan
/// okur. Dershane değişince tema yeniden kurulur ve her şey güncellenir.
@immutable
class BrandTheme extends ThemeExtension<BrandTheme> {
  const BrandTheme({
    required this.appName,
    required this.logoUrl,
    required this.isDefaultBrand,
    required this.primary,
    required this.primaryDeep,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.ink,
    required this.canvas,
    required this.info,
    required this.success,
    required this.danger,
    required this.chart,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkInput,
    this.font = AppFont.fallback,
  });

  /// Mentoria'nın birebir varsayılan paleti.
  factory BrandTheme.mentoria({
    String appName = 'Mentoria',
    String? logoUrl,
    AppFont font = AppFont.fallback,
  }) => BrandTheme(
    appName: appName,
    logoUrl: logoUrl,
    isDefaultBrand: logoUrl == null && appName == 'Mentoria',
    primary: AppColors.honey,
    primaryDeep: AppColors.honeyDark,
    onPrimary: AppColors.night,
    secondary: AppColors.grape,
    onSecondary: Colors.white,
    ink: AppColors.night,
    canvas: AppColors.cream,
    info: AppColors.wing,
    success: AppColors.success,
    danger: AppColors.danger,
    chart: AppColors.grape,
    darkBackground: AppColors.darkBackground,
    darkSurface: AppColors.darkSurface,
    darkInput: AppColors.darkInput,
    font: font,
  );

  /// Dershane markasından palet türetir. Renkler Mentoria'nınkiyle aynıysa
  /// varsayılan palet birebir korunur.
  factory BrandTheme.fromBranding(Branding b) {
    if (b.usesDefaultColors) {
      return BrandTheme.mentoria(
        appName: b.name,
        logoUrl: b.logoUrl,
        font: b.font,
      )._withDefaultFlag(b.isDefault && !b.hasLogo);
    }
    final ink = _shade(b.secondary, lightness: 0.2, maxSaturation: 0.45);
    return BrandTheme(
      appName: b.name,
      logoUrl: b.logoUrl,
      isDefaultBrand: false,
      primary: b.primary,
      primaryDeep: _darken(b.primary, 0.1),
      onPrimary: readableOn(b.primary, dark: ink),
      secondary: b.secondary,
      onSecondary: readableOn(b.secondary, dark: ink),
      ink: ink,
      canvas: Color.lerp(Colors.white, b.primary, 0.08)!,
      info: AppColors.wing,
      success: AppColors.success,
      danger: AppColors.danger,
      chart: b.secondary,
      darkBackground: _shade(ink, lightness: 0.09, maxSaturation: 0.28),
      darkSurface: _shade(ink, lightness: 0.13, maxSaturation: 0.28),
      darkInput: _shade(ink, lightness: 0.17, maxSaturation: 0.28),
      font: b.font,
    );
  }

  final String appName;
  final String? logoUrl;

  /// Dershane markası değil (Mentoria yazı logosu gösterilir).
  final bool isDefaultBrand;

  /// Ana marka rengi (butonlar, vurgular). Mentoria: bal sarısı.
  final Color primary;

  /// Ana rengin koyusu (ikon, ilerleme, metin vurgusu).
  final Color primaryDeep;
  final Color onPrimary;

  /// İkincil renk. Mentoria: mor.
  final Color secondary;
  final Color onSecondary;

  /// Koyu metin/zemin rengi (gece mavisi).
  final Color ink;

  /// Açık temada sayfa zemini.
  final Color canvas;

  final Color info;
  final Color success;
  final Color danger;

  /// Grafik çizgisi/çubuğu (açık tema). Koyu temada [chartOn] açar.
  final Color chart;

  final Color darkBackground;
  final Color darkSurface;
  final Color darkInput;

  /// Kurumun yazı tipi; tema metinleri bununla kurulur.
  final AppFont font;

  /// Koyu zeminde okunur grafik rengi.
  Color chartOn(Brightness b) {
    if (b != Brightness.dark) return chart;
    if (chart.toARGB32() == AppColors.grape.toARGB32()) {
      return AppColors.grapeLight;
    }
    return Color.lerp(chart, Colors.white, 0.2)!;
  }

  BrandTheme _withDefaultFlag(bool v) =>
      v == isDefaultBrand ? this : copyWith(isDefaultBrand: v);

  /// Zemin üzerinde okunur yazı rengi: koyu ile beyazdan kontrastı yüksek
  /// olanı (WCAG kontrast oranına göre).
  static Color readableOn(Color bg, {Color dark = AppColors.night}) =>
      contrast(bg, dark) >= contrast(bg, Colors.white) ? dark : Colors.white;

  /// WCAG kontrast oranı (1-21).
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  static Color _darken(Color c, double amount) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _shade(
    Color c, {
    required double lightness,
    double? maxSaturation,
  }) {
    final h = HSLColor.fromColor(c);
    final s = maxSaturation == null
        ? h.saturation
        : h.saturation.clamp(0.0, maxSaturation);
    return h.withSaturation(s).withLightness(lightness).toColor();
  }

  @override
  BrandTheme copyWith({
    String? appName,
    String? logoUrl,
    bool? isDefaultBrand,
    Color? primary,
    Color? primaryDeep,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? ink,
    Color? canvas,
    Color? info,
    Color? success,
    Color? danger,
    Color? chart,
    Color? darkBackground,
    Color? darkSurface,
    Color? darkInput,
    AppFont? font,
  }) => BrandTheme(
    appName: appName ?? this.appName,
    logoUrl: logoUrl ?? this.logoUrl,
    isDefaultBrand: isDefaultBrand ?? this.isDefaultBrand,
    primary: primary ?? this.primary,
    primaryDeep: primaryDeep ?? this.primaryDeep,
    onPrimary: onPrimary ?? this.onPrimary,
    secondary: secondary ?? this.secondary,
    onSecondary: onSecondary ?? this.onSecondary,
    ink: ink ?? this.ink,
    canvas: canvas ?? this.canvas,
    info: info ?? this.info,
    success: success ?? this.success,
    danger: danger ?? this.danger,
    chart: chart ?? this.chart,
    darkBackground: darkBackground ?? this.darkBackground,
    darkSurface: darkSurface ?? this.darkSurface,
    darkInput: darkInput ?? this.darkInput,
    font: font ?? this.font,
  );

  @override
  BrandTheme lerp(BrandTheme? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrandTheme(
      appName: t < 0.5 ? appName : other.appName,
      logoUrl: t < 0.5 ? logoUrl : other.logoUrl,
      isDefaultBrand: t < 0.5 ? isDefaultBrand : other.isDefaultBrand,
      primary: l(primary, other.primary),
      primaryDeep: l(primaryDeep, other.primaryDeep),
      onPrimary: l(onPrimary, other.onPrimary),
      secondary: l(secondary, other.secondary),
      onSecondary: l(onSecondary, other.onSecondary),
      ink: l(ink, other.ink),
      canvas: l(canvas, other.canvas),
      info: l(info, other.info),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      chart: l(chart, other.chart),
      darkBackground: l(darkBackground, other.darkBackground),
      darkSurface: l(darkSurface, other.darkSurface),
      darkInput: l(darkInput, other.darkInput),
      font: t < 0.5 ? font : other.font,
    );
  }
}

extension BrandThemeContext on BuildContext {
  /// Geçerli markanın renkleri ve kimliği. Tema eklenmemişse (ör. yalın
  /// widget testleri) Mentoria varsayılanı döner.
  BrandTheme get brand => Theme.of(this).extension<BrandTheme>() ?? _fallback;
}

final _fallback = BrandTheme.mentoria();
