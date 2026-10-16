import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/i18n/i18n.dart';
import '../../../core/sound/app_sounds.dart';

/// Pomodoro bitince çalan zil (ya da yalnızca titreşim). Sesler
/// tool/make_sounds.py ile üretilir: uygulama içi önizleme için
/// assets/sounds/, Android bildirimi için android/app/src/main/res/raw/.
enum AlarmTone {
  bal('bal', 'Bal Kavanozu'),
  vizilti('vizilti', 'Arı Vızıltısı'),
  kristal('kristal', 'Kristal'),
  marimba('marimba', 'Marimba'),
  gong('gong', 'Gong'),
  vibrate('vibrate', 'Yalnızca titreşim');

  const AlarmTone(this.key, this.trLabel);
  final String key;
  final String trLabel;

  String get label => tr(trLabel);
  bool get silent => this == vibrate;
  String? get asset => silent ? null : 'sounds/pomodoro_$key.wav';

  /// Android'de bildirim sesi kanala bağlıdır: her zil ayrı kanal.
  String get channelId => 'pomodoro_$key';

  static const fallback = AlarmTone.bal;

  static AlarmTone fromKey(String? key) =>
      AlarmTone.values.where((t) => t.key == key).firstOrNull ?? fallback;
}

/// Pomodoro alarmı: süre bitince seçilen zil ya da titreşimle bildirim.
///
/// Bitiş anına **zamanlanmış yerel bildirim** kurulur; böylece uygulama arka
/// plandayken, hatta kapatılmışken de tam zamanında çalar. Çalışırken bildirim
/// çubuğunda geri sayan bir "Odak" bildirimi durur. Bildirim kurulamazsa
/// (web, izin yok) [schedule] false döner; zamanlayıcı ekrandayken sesi
/// uygulama kendisi çalar ([ringNow]).
class PomodoroAlarm {
  PomodoroAlarm._();

  static const _alarmId = 7001;
  static const _runningId = 7002;
  static const _runningChannel = 'pomodoro_running';
  static final _vibration = Int64List.fromList([0, 700, 300, 700, 300, 1000]);

  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<bool>? _ready;

  /// Testlerde yapılan işlemleri yakalamak için ("schedule bal …").
  @visibleForTesting
  static void Function(String event)? debugLog;

  static final bool _inTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Zamanlanmış bildirim bu platformda var mı?
  static bool get supported =>
      !kIsWeb && !_inTest && (Platform.isAndroid || Platform.isIOS);

  static Future<bool> _init() => _ready ??= () async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final t in AlarmTone.values) {
        await android?.createNotificationChannel(_channel(t));
      }
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _runningChannel,
          tr('Çalışan zamanlayıcı'),
          description: tr('Pomodoro sürerken geri sayım'),
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Pomodoro alarmı hazırlanamadı: $e');
      return false;
    }
  }();

  static AndroidNotificationChannel _channel(AlarmTone t) =>
      AndroidNotificationChannel(
        t.channelId,
        tr('Pomodoro: {tone}', {'tone': t.label}),
        description: tr('Pomodoro ve mola bitince'),
        importance: Importance.high,
        playSound: !t.silent,
        sound: t.silent
            ? null
            : RawResourceAndroidNotificationSound('pomodoro_${t.key}'),
        enableVibration: true,
        vibrationPattern: _vibration,
        // Zamanlayıcı gibi: alarm sesi seviyesinde çalar.
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

  static NotificationDetails _details(AlarmTone t) => NotificationDetails(
    android: AndroidNotificationDetails(
      t.channelId,
      tr('Pomodoro: {tone}', {'tone': t.label}),
      importance: Importance.high,
      priority: Priority.high,
      playSound: !t.silent,
      sound: t.silent
          ? null
          : RawResourceAndroidNotificationSound('pomodoro_${t.key}'),
      enableVibration: true,
      vibrationPattern: _vibration,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
    ),
    // iOS: özel ses dosyaları uygulama paketine eklenene kadar varsayılan ses.
    iOS: DarwinNotificationDetails(presentSound: !t.silent),
  );

  /// [at] anına alarmı kurar (önceki alarmın yerine). Kurulabildiyse true.
  static Future<bool> schedule({
    required DateTime at,
    required AlarmTone tone,
    required String title,
    required String body,
  }) async {
    debugLog?.call('schedule ${tone.key} ${at.toIso8601String()}');
    if (!supported || !await _init()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final allowed =
          await android?.requestNotificationsPermission() ??
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          true;
      if (!allowed) return false;
      final exact = await android?.canScheduleExactNotifications() ?? true;
      await _plugin.zonedSchedule(
        id: _alarmId,
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: _details(tone),
        // Tam alarm izni yoksa yine kurulur, ama birkaç dakika gecikebilir.
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
      return true;
    } catch (e) {
      debugPrint('Pomodoro alarmı kurulamadı: $e');
      return false;
    }
  }

  /// Bildirim çubuğunda süren sayaç: [endsAt] verilirse geri sayar,
  /// yoksa [startedAt]'tan ileri sayar (kronometre).
  static Future<void> showRunning({
    required String title,
    required String body,
    DateTime? endsAt,
    DateTime? startedAt,
  }) async {
    debugLog?.call('running $title');
    if (!supported || !await _init()) return;
    try {
      await _plugin.show(
        id: _runningId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _runningChannel,
            tr('Çalışan zamanlayıcı'),
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            showWhen: true,
            when:
                (endsAt ?? startedAt ?? DateTime.now()).millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: endsAt != null,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Sayaç bildirimi gösterilemedi: $e');
    }
  }

  /// Süren sayaç bildirimini kaldırır (çalmış alarm bildirimi kalır).
  static Future<void> cancelRunning() async {
    debugLog?.call('cancelRunning');
    if (!supported || !await _init()) return;
    try {
      await _plugin.cancel(id: _runningId);
    } catch (_) {}
  }

  /// Kurulu alarmı ve sayacı iptal eder (duraklatma, elle bitirme).
  static Future<void> cancel() async {
    debugLog?.call('cancel');
    if (!supported || !await _init()) return;
    try {
      await _plugin.cancel(id: _alarmId);
      await _plugin.cancel(id: _runningId);
    } catch (_) {}
  }

  /// Android 14+: tam zamanlı alarm izni verilmemişse false.
  static Future<bool> exactAllowed() async {
    if (!supported || !await _init()) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        true;
  }

  /// Sistem ayarlarında "Alarmlar ve hatırlatıcılar" iznini açar.
  static Future<void> requestExact() async {
    if (!supported || !await _init()) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
  }

  /// Seçim ekranında dinletme (genel "Sesler" ayarından bağımsız).
  static Future<void> preview(AlarmTone tone) => _ring(tone);

  /// Bildirim kurulamadıysa (web, izin yok) süre bitince uygulama içinden.
  static Future<void> ringNow(AlarmTone tone) {
    debugLog?.call('ring ${tone.key}');
    return _ring(tone);
  }

  static Future<void> _ring(AlarmTone tone) async {
    if (tone.silent) {
      for (var i = 0; i < 3; i++) {
        await HapticFeedback.vibrate();
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
      return;
    }
    await AppSounds.playAsset(tone.asset!, volume: 0.5);
  }
}
