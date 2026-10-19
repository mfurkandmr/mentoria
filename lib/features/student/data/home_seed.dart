import 'dart:async';

import 'package:flutter/foundation.dart';

/// Öğrenci ana sayfasının verisini tek istekte (`student_home` RPC) çekip
/// Supabase repository'lerine bir kerelik "tohum" olarak verir.
///
/// Ana sayfa açılınca soru kayıtları, oturumlar, hedefler, denemeler, konu
/// ilerlemesi ve ödevler için ayrı ayrı istek atılıyordu. Deneme sonucu
/// açıklanınca binlerce öğrenci aynı anda girdiğinde bu, sunucuya düşen istek
/// sayısını katlıyor. Şimdi [prime] tek RPC'yi başlatır; repository'ler ilk
/// okumada [take] ile paketten kendi parçasını alır. Her parça bir kez
/// kullanılır, sonraki yenilemeler (kayıt ekleme, ekran tazeleme) yine normal
/// sorguyla gelir. Paket gelmezse (hata, eski sunucu) repository'ler sessizce
/// normal sorguya döner.
abstract final class HomeSeed {
  /// Bu süreden eski paket kullanılmaz.
  static const maxAge = Duration(seconds: 30);

  static String? _student;
  static DateTime? _since;
  static DateTime? _at;
  static Future<Map<String, dynamic>?>? _bundle;
  static final _taken = <String>{};

  /// Ana sayfa için paketi çekmeye başlar (öncekini bırakır).
  static void prime(
    String studentId,
    DateTime since,
    Future<Map<String, dynamic>> Function() load,
  ) {
    _student = studentId;
    _since = since;
    _at = DateTime.now();
    _taken.clear();
    _bundle = load().then<Map<String, dynamic>?>(
      (b) => b,
      onError: (Object e) {
        debugPrint('Ana sayfa paketi alınamadı, tek tek çekilecek: $e');
        return null;
      },
    );
  }

  /// [key] parçasını bir kez verir; paket yoksa, eskiyse, başka öğrencininse
  /// ya da [since] paketinkiyle aynı değilse null (normal sorguya dön).
  static Future<({Object? value})?> take(
    String studentId,
    String key, {
    DateTime? since,
  }) async {
    final bundle = _bundle;
    final at = _at;
    if (bundle == null || at == null || _student != studentId) return null;
    if (DateTime.now().difference(at) > maxAge) return null;
    if (since != null && since != _since) return null;
    if (!_taken.add(key)) return null;
    final b = await bundle;
    if (b == null || !b.containsKey(key)) return null;
    return (value: b[key]);
  }

  @visibleForTesting
  static void reset() {
    _student = null;
    _since = null;
    _at = null;
    _bundle = null;
    _taken.clear();
  }
}
