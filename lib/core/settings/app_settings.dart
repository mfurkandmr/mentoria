import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';
import '../../features/tracking/data/pomodoro_alarm.dart';
import '../sound/app_sounds.dart';

/// Uygulama başlarken yüklenir (main.dart). Testlerde null olabilir.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.language = AppLanguage.tr,
    this.sounds = true,
    this.pomodoroTone = AlarmTone.fallback,
  });

  final ThemeMode themeMode;
  final AppLanguage language;

  /// Bızz'a dokununca ve açılışta çalan sesler.
  final bool sounds;

  /// Pomodoro ve mola bitince çalan zil (ya da yalnızca titreşim).
  final AlarmTone pomodoroTone;

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppLanguage? language,
    bool? sounds,
    AlarmTone? pomodoroTone,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    language: language ?? this.language,
    sounds: sounds ?? this.sounds,
    pomodoroTone: pomodoroTone ?? this.pomodoroTone,
  );
}

/// Tema, dil ve ses tercihleri; cihazda kalıcı.
class SettingsNotifier extends Notifier<AppSettings> {
  static const _themeKey = 'theme_mode';
  static const _langKey = 'language';
  static const _soundsKey = 'sounds';
  static const _toneKey = 'pomodoro_tone';

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final theme =
        ThemeMode.values
            .where((m) => m.name == prefs?.getString(_themeKey))
            .firstOrNull ??
        ThemeMode.system;
    final lang =
        AppLanguage.values
            .where((l) => l.code == prefs?.getString(_langKey))
            .firstOrNull ??
        AppLanguage.tr;
    final sounds = prefs?.getBool(_soundsKey) ?? true;
    AppSounds.enabled = sounds;
    return AppSettings(
      themeMode: theme,
      language: lang,
      sounds: sounds,
      pomodoroTone: AlarmTone.fromKey(prefs?.getString(_toneKey)),
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs?.setString(_themeKey, mode.name);
  }

  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
    _prefs?.setString(_langKey, language.code);
  }

  void setPomodoroTone(AlarmTone tone) {
    state = state.copyWith(pomodoroTone: tone);
    _prefs?.setString(_toneKey, tone.key);
  }

  void setSounds(bool on) {
    state = state.copyWith(sounds: on);
    AppSounds.enabled = on;
    _prefs?.setBool(_soundsKey, on);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
