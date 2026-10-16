import 'package:flutter/material.dart';

/// Mentoria'nın VARSAYILAN marka paleti.
///
/// Widget'lar bu sabitleri doğrudan kullanmaz; renkler dershaneye göre
/// değişebildiği için `context.brand` (bkz. brand_theme.dart) üzerinden
/// okunur. Bu sınıf yalnızca varsayılan temanın ve maskot çiziminin kaynağıdır.
class AppColors {
  const AppColors._();

  static const honey = Color(0xFFFFC531);
  static const honeyDark = Color(0xFFF5A300);
  static const night = Color(0xFF2B2350);
  static const grape = Color(0xFF6C5CE7);

  /// Koyu zeminde grafik moru (renk denetiminden geçen ton).
  static const grapeLight = Color(0xFF8B7FF0);
  static const cream = Color(0xFFFFF8DE);
  static const wing = Color(0xFFD8ECFF);

  static const success = Color(0xFF22B07D);
  static const danger = Color(0xFFE5484D);

  // Koyu tema yüzeyleri
  static const darkBackground = Color(0xFF16122E);
  static const darkSurface = Color(0xFF1C1838);
  static const darkInput = Color(0xFF241F47);
}
