import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'brand_theme.dart';

/// Material teması marka paletinden (dershane renkleri) kurulur.
class AppTheme {
  const AppTheme._();

  static ThemeData light([BrandTheme? brand]) =>
      _build(Brightness.light, brand ?? BrandTheme.mentoria());
  static ThemeData dark([BrandTheme? brand]) =>
      _build(Brightness.dark, brand ?? BrandTheme.mentoria());

  static ThemeData _build(Brightness brightness, BrandTheme b) {
    final isDark = brightness == Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: b.primary,
          brightness: brightness,
        ).copyWith(
          primary: b.primary,
          onPrimary: b.onPrimary,
          secondary: b.secondary,
          onSecondary: b.onSecondary,
          error: b.danger,
          surface: isDark ? b.darkSurface : Colors.white,
          onSurface: isDark ? const Color(0xFFF5F2FF) : b.ink,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? b.darkBackground : b.canvas,
      extensions: [b],
    );

    final radius = BorderRadius.circular(14);
    // Kurumun seçtiği yazı tipi (Google Fonts).
    TextStyle font({FontWeight? fontWeight, double? fontSize}) =>
        b.font.style(fontWeight: fontWeight, fontSize: fontSize);

    return base.copyWith(
      textTheme: b.font
          .textTheme(base.textTheme)
          .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: b.primary,
          foregroundColor: b.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: font(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? b.darkInput : Colors.white,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: b.primaryDeep, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: b.primary,
        foregroundColor: b.onPrimary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? b.primary : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? b.onPrimary
                : scheme.onSurface,
          ),
          textStyle: WidgetStatePropertyAll(font(fontWeight: FontWeight.w800)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: b.primary.withValues(alpha: 0.35),
        backgroundColor: scheme.surface,
      ),
    );
  }
}
