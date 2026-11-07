import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/brand_theme.dart';
import '../../../../shared/widgets/corporate_look.dart';

/// Müdür / koç kokpitinin paleti: nötr gri zemin, beyaz (koyuda koyu gri)
/// kartlar. Açık ve koyu tema için iki takım; widget'lar
/// `context.cockpit.ink` gibi okur.
///
/// Renk yalnızca anlam taşır ([Tone]): kırmızı risk, sarı dikkat, yeşil
/// iyi. Vurgu (düğme, seçili sekme) kurum markasından türetilir
/// ([cockpitAccent]); kurum yazı tipi ve logosu korunur.
@immutable
class CockpitColors extends ThemeExtension<CockpitColors> {
  const CockpitColors({
    required this.background,
    required this.surface,
    required this.border,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.risk,
    required this.warn,
    required this.good,
  });

  static const light = CockpitColors(
    background: Color(0xFFF3F5F8),
    surface: Colors.white,
    border: Color(0xFFE2E6EC),
    ink: Color(0xFF14213D),
    muted: Color(0xFF5E6878),
    faint: Color(0xFFEEF1F5),
    risk: Color(0xFFC62F3A),
    warn: Color(0xFFB26A00),
    good: Color(0xFF1E8152),
  );

  /// iOS koyu görünümüne yakın: siyaha yakın zemin, bir ton açık kartlar.
  static const dark = CockpitColors(
    background: Color(0xFF0E1014),
    surface: Color(0xFF1A1D23),
    border: Color(0xFF2C313A),
    ink: Color(0xFFF1F3F6),
    muted: Color(0xFF9CA5B4),
    faint: Color(0xFF252A32),
    risk: Color(0xFFFF7B80),
    warn: Color(0xFFF2B65A),
    good: Color(0xFF55C993),
  );

  final Color background;
  final Color surface;
  final Color border;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color risk;
  final Color warn;
  final Color good;

  bool get isDark => surface.computeLuminance() < 0.2;

  static CockpitColors of(BuildContext context) =>
      Theme.of(context).extension<CockpitColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  CockpitColors copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? risk,
    Color? warn,
    Color? good,
  }) => CockpitColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    border: border ?? this.border,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    faint: faint ?? this.faint,
    risk: risk ?? this.risk,
    warn: warn ?? this.warn,
    good: good ?? this.good,
  );

  @override
  CockpitColors lerp(CockpitColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return CockpitColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      border: l(border, other.border),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      risk: l(risk, other.risk),
      warn: l(warn, other.warn),
      good: l(good, other.good),
    );
  }
}

extension CockpitContext on BuildContext {
  /// Kokpit paleti (açık / koyu temaya göre).
  CockpitColors get cockpit => CockpitColors.of(this);
}

/// Anlam rengi. Yalnızca bir eşiğe göre seçilir, süs için kullanılmaz.
enum Tone {
  risk,
  warn,
  good,
  neutral;

  Color of(BuildContext context) {
    final c = context.cockpit;
    return switch (this) {
      Tone.risk => c.risk,
      Tone.warn => c.warn,
      Tone.good => c.good,
      Tone.neutral => c.muted,
    };
  }

  /// Açık zemin (bant, rozet) için.
  Color tintOf(BuildContext context) {
    final c = context.cockpit;
    return Color.alphaBlend(
      of(context).withValues(alpha: c.isDark ? 0.16 : 0.10),
      c.surface,
    );
  }

  /// Aktiflik gibi oranlar: %70 ve üstü iyi, %40 ve üstü dikkat.
  static Tone forRatio(double r) => r >= 0.7
      ? Tone.good
      : r >= 0.4
      ? Tone.warn
      : Tone.risk;
}

/// Vurgu rengi: açıkta kurumun koyu tonu, koyuda aynı tonun açık hâli.
Color cockpitAccent(BrandTheme brand, {required bool dark}) {
  if (!dark) return brand.ink;
  final hsl = HSLColor.fromColor(brand.ink);
  return hsl
      .withLightness(0.74)
      .withSaturation(math.min(hsl.saturation, 0.55))
      .toColor();
}

/// Uygulamanın açık / koyu temasından türetilir; kurum yazı tipi korunur.
ThemeData cockpitTheme(BrandTheme brand, {bool dark = false}) {
  final c = dark ? CockpitColors.dark : CockpitColors.light;
  final base = dark ? AppTheme.dark(brand) : AppTheme.light(brand);
  final accent = cockpitAccent(brand, dark: dark);
  final onAccent = dark ? CockpitColors.dark.background : Colors.white;
  // Seçili sekme / bölüm: vurgunun çok açık bir tonu.
  final accentTint = Color.alphaBlend(
    accent.withValues(alpha: dark ? 0.20 : 0.10),
    c.surface,
  );
  // Temadaki metin stillerinde boyut yoktur (Theme.of çalışırken eklenir);
  // üst çubuk, sekme, pencere başlığı gibi tema içi stiller için boyutlar
  // burada birleştirilir, yoksa 14 px'e düşerler.
  final text = Typography.material2021(platform: base.platform).englishLike
      .merge(base.textTheme)
      .apply(bodyColor: c.ink, displayColor: c.ink);
  final r10 = BorderRadius.circular(10);
  final r12 = BorderRadius.circular(12);
  const noOverlay = WidgetStatePropertyAll<Color>(Colors.transparent);

  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    canvasColor: c.surface,
    // iOS gibi: dalga (ripple) yok; parmak değdiği an hafif gri vurgu.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: c.ink.withValues(alpha: dark ? 0.08 : 0.05),
    hoverColor: c.ink.withValues(alpha: 0.03),
    // iOS kaydırma geçişi (kokpitten Navigator ile açılan sayfalar).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
    // Kurumun başarı / hata renkleri kokpitte anlam renklerine eşitlenir.
    extensions: [
      brand.copyWith(success: c.good, danger: c.risk),
      c,
      const CorporateLook(),
    ],
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      outline: c.border,
      outlineVariant: c.border,
      error: c.risk,
      primaryContainer: accentTint,
      onPrimaryContainer: c.ink,
      secondaryContainer: accentTint,
      onSecondaryContainer: c.ink,
      tertiaryContainer: c.faint,
      onTertiaryContainer: c.ink,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.faint,
      surfaceContainerHighest: c.faint,
      surfaceTint: Colors.transparent,
    ),
    textTheme: text,
    iconTheme: IconThemeData(color: c.ink),
    dividerColor: c.border,
    dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
    // iOS'a yakın: çizgisiz, çok yumuşak gölgeli, geniş köşeli kartlar.
    // Koyuda gölge görünmez; kart zeminden bir ton açık.
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 0 : 1.5,
      shadowColor: const Color(0x2E0F1B33),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    // Üst çubuk zeminle bir: içerik altına kayınca beyaza döner ve ince
    // bir gölge çıkar (iOS gezinme çubuğu gibi). Başlık büyük ve kalın.
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.scrolledUnder) ? c.surface : c.background,
      ),
      foregroundColor: c.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: dark ? 0 : 0.6,
      shadowColor: const Color(0x4D0F1B33),
      centerTitle: false,
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: c.ink),
      actionsIconTheme: IconThemeData(color: c.ink),
    ),
    // Sekmeler: seçili olanın arkasında kayan yumuşak bir hap.
    tabBarTheme: TabBarThemeData(
      labelColor: accent,
      unselectedLabelColor: c.muted,
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      unselectedLabelStyle: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: ShapeDecoration(
        color: accentTint,
        shape: RoundedRectangleBorder(borderRadius: r10),
      ),
      dividerColor: Colors.transparent,
      overlayColor: noOverlay,
      splashFactory: NoSplash.splashFactory,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: accentTint,
      height: cockpitNavHeight,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall?.copyWith(
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? accent : c.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? accent : c.muted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      indicatorColor: accentTint,
      selectedIconTheme: IconThemeData(color: accent),
      unselectedIconTheme: IconThemeData(color: c.muted),
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: text.labelMedium?.copyWith(color: c.muted),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.muted,
      textColor: c.ink,
      titleTextStyle: text.bodyLarge?.copyWith(
        color: c.ink,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: accent,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: c.muted),
      shape: RoundedRectangleBorder(borderRadius: r12),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: accent,
      collapsedIconColor: c.muted,
      textColor: c.ink,
      collapsedTextColor: c.ink,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: onAccent,
      elevation: 3,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onAccent,
        disabledBackgroundColor: c.faint,
        disabledForegroundColor: c.muted,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: r12),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.surface,
        foregroundColor: accent,
        surfaceTintColor: Colors.transparent,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: r12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        minimumSize: const Size(0, 44),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: r12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: r10),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: c.ink),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accentTint : c.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : c.muted,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: r12),
        ),
        textStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    // iOS anahtarı: beyaz top, çizgisiz ray.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? c.faint
            : s.contains(WidgetState.selected)
            ? onAccent
            : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? accent
            : (dark ? const Color(0xFF3A404A) : const Color(0xFFD5DAE1)),
      ),
      trackOutlineColor: noOverlay,
      overlayColor: noOverlay,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: c.muted, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(onAccent),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : c.muted,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: c.faint,
      circularTrackColor: Colors.transparent,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: c.faint,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(
        borderRadius: r12,
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: r12,
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r12,
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.surface,
      selectedColor: accentTint,
      checkmarkColor: accent,
      side: BorderSide(color: c.border),
      shape: const StadiumBorder(),
      labelStyle: text.labelLarge?.copyWith(
        color: c.ink,
        fontWeight: FontWeight.w600,
      ),
    ),
    // Pencereler ve alt sayfalar: geniş köşeli, düz zemin (iOS sayfası).
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      modalBackgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: dark ? const Color(0xFF4A505B) : const Color(0xFFCDD3DB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: noOverlay,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: c.surface,
      headerForegroundColor: c.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A404A) : CockpitColors.light.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: text.bodySmall?.copyWith(color: Colors.white),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: dark ? const Color(0xFF2C313A) : CockpitColors.light.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      actionTextColor: dark ? accent : const Color(0xFFB8C7FF),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Alt gezinme çubuğunun yüksekliği; liste sonuna bu + 16 boşluk konur.
const cockpitNavHeight = 68.0;

/// Kokpit içinde açılan sayfaları da aynı temayla sarar (uygulama koyu
/// temadaysa kokpit de koyu). Kaydırma iOS gibi esnek.
class CockpitThemed extends StatelessWidget {
  const CockpitThemed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // İç içe sarıldığında temayı yeniden kurmaya gerek yok.
    if (inCockpit(context)) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: cockpitTheme(context.brand, dark: dark),
      child: ScrollConfiguration(
        behavior: const _CockpitScroll(),
        child: child,
      ),
    );
  }
}

/// Kokpit kaydırması: telefonda iOS gibi esnek (yaylanan). Web'de fare
/// tekerleğiyle esneme takılma gibi hissettirdiği için düz (NOTLAR §70).
/// Aşağı çekip yenilemek için her zaman kaydırılabilir.
ScrollPhysics cockpitScrollPhysics() => const AlwaysScrollableScrollPhysics(
  parent: kIsWeb ? ClampingScrollPhysics() : BouncingScrollPhysics(),
);

/// Kaydırma çubukları platformun varsayılanı.
class _CockpitScroll extends MaterialScrollBehavior {
  const _CockpitScroll();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      kIsWeb ? const ClampingScrollPhysics() : const BouncingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// Müdür / koç kokpitinin içinde mi? Ortak bileşenler (öğrenci kartı,
/// avatar) burada dekoratif renk yerine nötr görünür. Açılan pencerelerde
/// de geçerli (tema uzantısı).
bool inCockpit(BuildContext context) => isCorporate(context);

/// Etiket: küçük ve gri.
TextStyle? cockpitLabel(BuildContext context) => Theme.of(context)
    .textTheme
    .labelMedium
    ?.copyWith(color: context.cockpit.muted, fontWeight: FontWeight.w500);

/// Sayı: büyük ve kalın.
TextStyle? cockpitNumber(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: context.cockpit.ink,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Kokpit zemini: üstte kurum renginin çok hafif bir tonu, aşağı doğru nötr
/// griye iner (düz bir zeminden daha derin; desen yok).
class CockpitBackground extends StatelessWidget {
  const CockpitBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.cockpit;
    final tint = Color.lerp(
      c.background,
      cockpitAccent(context.brand, dark: c.isDark),
      c.isDark ? 0.06 : 0.07,
    )!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.35],
          colors: [tint, c.background],
        ),
      ),
      child: child,
    );
  }
}

/// Bölüm başlığı (kartsız bölümler için).
class CockpitHeading extends StatelessWidget {
  const CockpitHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
  );
}
