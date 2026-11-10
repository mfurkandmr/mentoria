import 'package:flutter/services.dart';

/// Titreşim haritası: olay → en çok bir titreşim. Tek merkezden kapatılır.
///
/// Normal gezinme ve kaydırmada titreşim yoktur.
abstract final class AppHaptics {
  /// Uygulama genelindeki tek anahtar (testlerde kapatılabilir).
  static bool enabled = true;

  /// Seçim değişti: sekme, segment, seçici, onay kutusu.
  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Birincil işlem onaylandı: kaydedildi, gönderildi.
  static void confirm() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Yıkıcı işlem ya da hata: silindi, yanlış cevap, başarısız.
  static void warn() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
