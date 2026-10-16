import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Uygulamaya özel sesler (assets/sounds, üretici: tool/make_sounds.py).
enum AppSound {
  // Seviyeler yüksek bulunduğu için yaklaşık yarıya indirildi (~−6 dB).

  /// Bızz'a dokununca: kısa vızıltı ve iki tını.
  bizzTap('sounds/bizz_tap.wav', 0.35),

  /// Açılış: Bızz uçarak gelir, konunca çan arpeji.
  intro('sounds/intro.wav', 0.3),

  /// Telefon sallanınca: yeni Bızz uçarak gelip çarpar (bkz. BizzSwap).
  bizzBump('sounds/bizz_bump.wav', 0.35),

  /// Uygulama açıkken bildirim kartı düşünce (telefon bildirimiyle aynı ses:
  /// android/app/src/main/res/raw/mentoria_bildirim.wav).
  notification('sounds/mentoria_bildirim.wav', 0.4);

  const AppSound(this.asset, this.volume);
  final String asset;
  final double volume;
}

/// Ses çalar. Ayarlardan kapatılabilir ([enabled], `SettingsNotifier`
/// eşitler). Telefon sessizdeyse çalmaz. Hata olursa uygulama sessiz devam
/// eder.
class AppSounds {
  AppSounds._();

  /// Kullanıcı tercihi (Profil → Görünüm, dil ve ses).
  static bool enabled = true;

  /// Testlerde çalınması istenen sesi yakalamak için.
  @visibleForTesting
  static void Function(AppSound sound)? debugOnPlay;

  // Testlerde ses eklentisi yoktur; oynatıcı hiç oluşturulmaz.
  static final bool _inTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static final _players = <AppSound, AudioPlayer>{};

  static Future<void> play(AppSound sound) async {
    if (!enabled) return;
    debugOnPlay?.call(sound);
    if (_inTest) return;
    try {
      if (await _phoneSilent()) return;
      final player = _players[sound] ??= await _create();
      // Art arda dokunuşta ses baştan çalsın.
      await player.stop();
      await player.play(AssetSource(sound.asset), volume: sound.volume);
    } catch (e) {
      debugPrint('Ses çalınamadı: $e');
    }
  }

  static AudioPlayer? _assetPlayer;

  /// Ayarlardaki "Sesler" anahtarından bağımsız tek bir ses dosyası çalar
  /// (ör. pomodoro zilini dinletme). Bir sonraki çağrı öncekini durdurur.
  static Future<void> playAsset(String asset, {double volume = 0.5}) async {
    debugOnPlayAsset?.call(asset);
    if (_inTest) return;
    try {
      final player = _assetPlayer ??= await _create();
      await player.stop();
      await player.play(AssetSource(asset), volume: volume);
    } catch (e) {
      debugPrint('Ses çalınamadı: $e');
    }
  }

  @visibleForTesting
  static void Function(String asset)? debugOnPlayAsset;

  static Future<AudioPlayer> _create() async {
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    // Kısa efektler için düşük gecikme (web bunu desteklemez).
    if (!kIsWeb) await player.setPlayerMode(PlayerMode.lowLatency);
    // Android: medya yolu (kulaklık takılıysa YALNIZCA kulaklıktan çalar;
    // "zil sesi" yolu kulaklık + hoparlörden birlikte çalıyordu), müziği
    // durdurmaz. Sessiz mod [_phoneSilent] ile ayrıca denetlenir.
    // iOS: "ambient" — sessiz anahtarına uyar, müziğe karışır.
    await player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {},
        ),
      ),
    );
    return player;
  }

  static const _channel = MethodChannel('mentoria/sound');

  /// Android'de telefon sessiz ya da titreşimde mi (MainActivity.kt).
  static Future<bool> _phoneSilent() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isSilent') ?? false;
    } catch (_) {
      return false;
    }
  }
}
