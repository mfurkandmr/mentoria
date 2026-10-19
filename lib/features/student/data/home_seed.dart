import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
///
/// Anında açılış: son gelen paket cihazda saklanır. Bir sonraki açılışta
/// ekran önce cihazdaki paketle hemen çizilir, taze paket gelince
/// `onFresh` ile ilgili provider'lar yenilenir (internet yokken de son
/// görülen ana sayfa açılır).
abstract final class HomeSeed {
  /// Bu süreden eski paket kullanılmaz.
  static const maxAge = Duration(seconds: 30);

  /// Cihazdaki paket bundan eskiyse gösterilmez.
  static const diskMaxAge = Duration(days: 7);

  static const _diskPrefix = 'home_bundle.';

  static SharedPreferences? _prefs;
  static String? _student;
  static DateTime? _since;
  static DateTime? _at;
  static bool _fromDisk = false;
  static bool _skipDiskOnce = false;
  static int _generation = 0;
  static Future<Map<String, dynamic>?>? _bundle;
  static final _taken = <String>{};

  /// main()'de bir kez; verilmezse cihaz önbelleği kullanılmaz (testler).
  static void init(SharedPreferences prefs) => _prefs = prefs;

  /// Sonraki [prime] cihazdaki paketi atlasın (aşağı çekip yenileme).
  static void skipDiskOnce() => _skipDiskOnce = true;

  /// Ana sayfa için paketi çekmeye başlar (öncekini bırakır). Cihazda paket
  /// varsa parçalar hemen ondan verilir; taze paket gelince [onFresh].
  static void prime(
    String studentId,
    DateTime since,
    Future<Map<String, dynamic>> Function() load, {
    void Function()? onFresh,
  }) {
    final generation = ++_generation;
    _student = studentId;
    _at = DateTime.now();
    _taken.clear();

    final cached = _skipDiskOnce ? null : _readDisk(studentId);
    _skipDiskOnce = false;
    final fresh = load();

    if (cached == null) {
      _since = since;
      _fromDisk = false;
      _bundle = fresh.then<Map<String, dynamic>?>(
        (b) {
          _writeDisk(studentId, b);
          return b;
        },
        onError: (Object e) {
          debugPrint('Ana sayfa paketi alınamadı, tek tek çekilecek: $e');
          return null;
        },
      );
      return;
    }

    _since = since;
    _fromDisk = true;
    _bundle = Future.value(cached);
    unawaited(
      fresh.then<void>(
        (b) {
          _writeDisk(studentId, b);
          // Bu arada yeniden prime edildiyse eski cevabı kullanma.
          if (generation != _generation) return;
          _fromDisk = false;
          _at = DateTime.now();
          _bundle = Future.value(b);
          _taken.clear();
          onFresh?.call();
        },
        onError: (Object e) {
          debugPrint('Ana sayfa tazelenemedi, cihazdaki gösteriliyor: $e');
        },
      ),
    );
  }

  /// [key] parçasını bir kez verir; paket yoksa, eskiyse, başka öğrencininse
  /// ya da [since] paketinkiyle aynı değilse null (normal sorguya dön).
  /// Cihazdaki paket [since]'e bakılmadan verilir (birazdan tazelenecek).
  static Future<({Object? value})?> take(
    String studentId,
    String key, {
    DateTime? since,
  }) async {
    final bundle = _bundle;
    final at = _at;
    if (bundle == null || at == null || _student != studentId) return null;
    if (DateTime.now().difference(at) > maxAge) return null;
    if (!_fromDisk && since != null && since != _since) return null;
    if (!_taken.add(key)) return null;
    final b = await bundle;
    if (b == null || !b.containsKey(key)) return null;
    return (value: b[key]);
  }

  static Map<String, dynamic>? _readDisk(String studentId) {
    final raw = _prefs?.getString('$_diskPrefix$studentId');
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.fromMillisecondsSinceEpoch(j['at'] as int);
      if (DateTime.now().difference(at) > diskMaxAge) return null;
      return (j['bundle'] as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('Cihazdaki ana sayfa okunamadı: $e');
      return null;
    }
  }

  static void _writeDisk(String studentId, Map<String, dynamic> bundle) {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(
      prefs.setString(
        '$_diskPrefix$studentId',
        jsonEncode({
          'at': DateTime.now().millisecondsSinceEpoch,
          'bundle': bundle,
        }),
      ),
    );
  }

  /// Çıkışta: cihazda başka hesabın ana sayfası kalmasın.
  static Future<void> clearDisk() async {
    final prefs = _prefs;
    reset();
    if (prefs == null) return;
    for (final k in prefs.getKeys().where((k) => k.startsWith(_diskPrefix))) {
      await prefs.remove(k);
    }
  }

  @visibleForTesting
  static void reset() {
    _generation++;
    _student = null;
    _since = null;
    _at = null;
    _fromDisk = false;
    _skipDiskOnce = false;
    _bundle = null;
    _taken.clear();
  }
}
