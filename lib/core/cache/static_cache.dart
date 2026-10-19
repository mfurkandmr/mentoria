import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Neredeyse hiç değişmeyen tabloları (dersler, konular, avatar parçaları)
/// cihazda saklar; her açılışta sunucuya gitmesin.
///
/// Bir kayıt [maxAge]'den eskiyse ya da [version] değiştiyse yeniden çekilir.
/// Seed'e yeni konu/ders/avatar eklenince [version]'ı artırmak yeter (ya da
/// süre dolunca kendiliğinden yenilenir). Aynı oturumda aynı anahtarı isteyen
/// tüm repository'ler tek isteği paylaşır.
abstract final class StaticCache {
  /// Seed değişince artır: tüm cihazlar ilk açılışta yeniden çeker.
  static const version = 1;

  static SharedPreferences? _prefs;
  static final _memory = <String, Future<List<Map<String, dynamic>>>>{};

  /// main()'de bir kez; verilmezse yalnızca bellekte tutulur (testler).
  static void init(SharedPreferences prefs) => _prefs = prefs;

  static String _key(String name) => 'static_cache.v$version.$name';

  /// [name] tablosunun satırları: önce bellek, sonra cihaz, yoksa [load].
  static Future<List<Map<String, dynamic>>> rows(
    String name,
    Future<List<Map<String, dynamic>>> Function() load, {
    Duration maxAge = const Duration(days: 3),
  }) {
    final hit = _memory[name];
    if (hit != null) return hit;
    final future = _read(name, maxAge) ?? _loadAndStore(name, load);
    _memory[name] = future;
    // Hata olursa bir sonraki çağrı yeniden denesin.
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          _memory.remove(name);
        },
      ),
    );
    return future;
  }

  static Future<List<Map<String, dynamic>>>? _read(
    String name,
    Duration maxAge,
  ) {
    final raw = _prefs?.getString(_key(name));
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.fromMillisecondsSinceEpoch(j['at'] as int);
      if (DateTime.now().difference(at) > maxAge) return null;
      return Future.value([
        for (final r in j['rows'] as List) (r as Map).cast<String, dynamic>(),
      ]);
    } catch (e) {
      debugPrint('Önbellek okunamadı ($name): $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _loadAndStore(
    String name,
    Future<List<Map<String, dynamic>>> Function() load,
  ) async {
    final rows = await load();
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(
        _key(name),
        jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, 'rows': rows}),
      );
    }
    return rows;
  }

  /// Ders kimlikleri ve kodları (`subjects`).
  static Future<List<Map<String, dynamic>>> subjects(SupabaseClient client) =>
      rows('subjects', () => client.from('subjects').select('id, code'));

  @visibleForTesting
  static void clearMemory() => _memory.clear();
}
