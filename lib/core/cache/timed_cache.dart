import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kısa süreli bellek önbelleği: aynı anahtar [ttl] içinde yeniden istenirse
/// sunucuya gidilmez, eldeki cevap (ya da süren istek) kullanılır.
///
/// Sekme/ekran değiştirip geri gelince listelerin baştan indirilmesini
/// önler. Aşağı çekip yenilemede [clear] çağrılır. Hatalı cevap saklanmaz.
class TimedCache<K, V> {
  TimedCache({this.ttl = const Duration(minutes: 2)});

  final Duration ttl;
  final _items = <K, ({DateTime at, Future<V> value})>{};

  Future<V> get(K key, Future<V> Function() load) {
    final hit = _items[key];
    if (hit != null && DateTime.now().difference(hit.at) < ttl) {
      return hit.value;
    }
    final value = load();
    final entry = (at: DateTime.now(), value: value);
    _items[key] = entry;
    unawaited(
      value.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_items[key], entry)) _items.remove(key);
        },
      ),
    );
    return value;
  }

  void clear() => _items.clear();
}

extension CacheForRef on Ref {
  /// autoDispose bir provider'ı, dinleyen kalmasa da [duration] boyunca
  /// bellekte tutar (ekrana geri dönünce yeniden indirilmez).
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
