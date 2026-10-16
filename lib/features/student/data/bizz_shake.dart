import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Telefon sallanınca haber verir. Yerçekimi çıkarılmış ivmede kısa süre
/// içinde birkaç güçlü sarsıntı aranır; cebe koyma, yürüme gibi tek
/// sarsıntılar sayılmaz.
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    Stream<({double x, double y, double z})>? source,
    DateTime Function()? clock,
    this.threshold = 14,
    this.hits = 3,
    this.window = const Duration(milliseconds: 900),
    this.cooldown = const Duration(seconds: 2),
  }) : _clock = clock ?? DateTime.now {
    _sub = (source ?? _sensor()).listen(_onEvent, onError: (_) {});
  }

  final VoidCallback onShake;

  /// m/s²: bu ivmenin üstü bir sarsıntı.
  final double threshold;

  /// [window] içinde kaç sarsıntı gerekir.
  final int hits;
  final Duration window;

  /// Algılandıktan sonra bu süre yeni sallama sayılmaz.
  final Duration cooldown;

  final DateTime Function() _clock;
  late final StreamSubscription<({double x, double y, double z})> _sub;
  final _peaks = <DateTime>[];
  DateTime? _quietUntil;

  static Stream<({double x, double y, double z})> _sensor() {
    // Web, masaüstü ve testlerde ivmeölçer yok.
    if (kIsWeb ||
        Platform.environment.containsKey('FLUTTER_TEST') ||
        !(Platform.isAndroid || Platform.isIOS)) {
      return const Stream.empty();
    }
    return userAccelerometerEventStream(
      // Arayüz hızı (~15 Hz) sallamayı yakalamaya yeter, pili yormaz.
      samplingPeriod: SensorInterval.uiInterval,
    ).map((e) => (x: e.x, y: e.y, z: e.z));
  }

  void _onEvent(({double x, double y, double z}) e) {
    final now = _clock();
    if (_quietUntil != null && now.isBefore(_quietUntil!)) return;
    final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (g < threshold) return;
    // Aynı sarsıntının ardışık örnekleri tek sayılır.
    if (_peaks.isNotEmpty &&
        now.difference(_peaks.last) < const Duration(milliseconds: 120)) {
      return;
    }
    _peaks
      ..add(now)
      ..removeWhere((t) => now.difference(t) > window);
    if (_peaks.length >= hits) {
      _peaks.clear();
      _quietUntil = now.add(cooldown);
      onShake();
    }
  }

  void dispose() => _sub.cancel();
}

/// Arı değişimi en fazla [maxPerHour] kez / saat. Kullanımlar telefonda
/// saklanır; uygulama kapatılıp açılsa da sınır geçerli.
class BizzSwapLimit {
  BizzSwapLimit(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const maxPerHour = 2;
  static const _key = 'bizz_swap_times';
  static const _hour = Duration(hours: 1);

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  List<DateTime> _recent() {
    final now = _clock();
    return (_prefs.getStringList(_key) ?? const [])
        .map((s) => DateTime.fromMillisecondsSinceEpoch(int.tryParse(s) ?? 0))
        .where((t) => now.difference(t) < _hour && !t.isAfter(now))
        .toList()
      ..sort();
  }

  /// Şu an kullanılabiliyorsa `null`, değilse yeniden kullanılabilmesine
  /// kalan süre.
  Duration? waitTime() {
    final recent = _recent();
    if (recent.length < maxPerHour) return null;
    return recent[recent.length - maxPerHour].add(_hour).difference(_clock());
  }

  /// Hak varsa kullanır ve `true` döner.
  bool tryUse() {
    if (waitTime() != null) return false;
    final times = [..._recent(), _clock()];
    _prefs.setStringList(_key, [
      for (final t in times) '${t.millisecondsSinceEpoch}',
    ]);
    return true;
  }
}
