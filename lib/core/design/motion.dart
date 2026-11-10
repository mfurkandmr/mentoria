import 'package:flutter/widgets.dart';

/// Hareketin genel anahtarı.
///
/// Testlerde `pumpAndSettle` takılmasın diye kapatılır; ayrıca cihazda
/// "hareketi azalt" açıksa bütün animasyonlar anında son hale geçer.
class Motion {
  Motion._();

  static bool enabled = true;

  static bool of(BuildContext context) =>
      enabled && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}

/// Uygulamanın hareket dili: bütün süre, eğri ve mesafeler buradan gelir.
///
/// His: kurumsal, sakin. Animasyonun yokluğu hissedilir, varlığı değil.
/// Hiçbir arayüz animasyonu [slow] süresini (320 ms) geçmez; yaylanan /
/// taşan eğri (elastic, bounce, back) kullanılmaz. Bilinçli istisnalar
/// (maskot, gökyüzü, alev, konfeti, bahçe, haftalık özet, açılış) kendi
/// dosyalarında durur ve `test/motion_tokens_test.dart` içinde listelenir.
abstract final class AppMotion {
  /// Hover, dalga, küçük durum değişimi, grafik ipucu.
  static const instant = Duration(milliseconds: 100);

  /// Düğme, onay kutusu, çip, odak çerçevesi.
  static const fast = Duration(milliseconds: 180);

  /// Kart açılması, liste öğesi girişi, çapraz geçiş, grafik değerleri.
  static const base = Duration(milliseconds: 240);

  /// Sayfa geçişi, alt sayfa, pencere.
  static const slow = Duration(milliseconds: 320);

  /// Giriş: hızlı başlar, yumuşak durur.
  static const Curve enter = Curves.easeOutCubic;

  /// Çıkış: yavaş başlar, hızlanarak gider.
  static const Curve exit = Curves.easeInCubic;

  /// İki yönlü hareket / konum değişimi.
  static const Curve move = Curves.easeInOutCubic;

  /// Kayma mesafeleri (8–24 px).
  static const double slideSmall = 8;
  static const double slide = 12;
  static const double slidePage = 16;
  static const double slideLarge = 24;

  /// Basılınca küçülme oranı.
  static const double pressScale = 0.97;

  /// Sıralı girişte öğe başına gecikme ve gecikme alan öğe sayısı.
  static const staggerStep = Duration(milliseconds: 30);
  static const staggerCount = 8;

  /// İskelet en az bu kadar görünür (bir kare yanıp sönmesin).
  static const minSkeleton = Duration(milliseconds: 300);

  /// Bilgi mesajının (SnackBar) ekranda kalma süresi.
  static const snack = Duration(seconds: 4);

  /// Hareketi azalt açıksa (ya da testlerde) sıfır süre.
  static Duration of(BuildContext context, Duration d) =>
      Motion.of(context) ? d : Duration.zero;

  /// Sıralı giriş gecikmesi: ilk [staggerCount] öğe 30'ar ms arayla,
  /// sonrakiler gecikmesiz.
  static Duration stagger(int index) =>
      index <= 0 || index >= staggerCount ? Duration.zero : staggerStep * index;

  /// Alt sayfa ve pencere açılış/kapanış stili.
  static AnimationStyle overlayStyle(BuildContext context) => AnimationStyle(
    duration: of(context, slow),
    reverseDuration: of(context, base),
    curve: enter,
    reverseCurve: exit,
  );
}
