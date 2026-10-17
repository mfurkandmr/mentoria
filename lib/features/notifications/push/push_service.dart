import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/auth_repository.dart';

/// Uygulama kapalıyken/arka plandayken gelen bildirim. Bildirimi sistem
/// kendisi gösterir; burada yapılacak bir şey yok (Firebase bu fonksiyonun
/// en üst düzeyde olmasını ister).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Firebase'i başlatır. Web, demo ve Supabase'siz çalıştırmada atlanır;
/// ayar dosyası yoksa ya da hata olursa uygulama bildirimsiz devam eder.
Future<bool> initFirebase() async {
  if (kIsWeb || Env.isDemo || !Env.isConfigured) return false;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    return true;
  } catch (e) {
    debugPrint('Firebase başlatılamadı, telefon bildirimleri kapalı: $e');
    return false;
  }
}

// firebase_messaging 17 klasik "registration token" API'sini yeni FID
// tabanlı register()/onRegistered lehine kullanımdan kaldırılmış işaretliyor.
// FCM HTTP v1 gönderimi (send-push) hâlâ registration token'ı hedef aldığı
// için bilerek bu API kullanılıyor; yeni API'ye geçiş NOTLAR.md'de.
// ignore_for_file: deprecated_member_use

/// Telefon bildirimleri (FCM): izin ister, cihaz adresini Supabase'e kaydeder,
/// çıkışta siler; bildirime dokununca ilgili ekranı açar.
///
/// Uygulama açıkken gelen bildirimler zaten uygulama içi kartla
/// (InAppNotifier) gösterildiği için burada ayrıca gösterilmez.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _started = false;
  String? _registeredFor;
  StreamSubscription<String>? _refresh;

  bool get _enabled => !kIsWeb && Firebase.apps.isNotEmpty;

  SupabaseClient get _client => _ref.read(supabaseClientProvider);

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Telefon bildirimlerinin Android kanalı: Mentoria'ya özel ses.
  /// Kimlik AndroidManifest'teki `default_notification_channel_id` ve
  /// send-push'taki `channel_id` ile aynı olmalı. Android kanal sesini
  /// sonradan değiştirmeye izin vermez; ses değişirse yeni kimlik verilmeli.
  static const channelId = 'mentoria_bildirim';

  static Future<void> _createChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              channelId,
              tr('Mentoria bildirimleri'),
              description: tr('Ödev, görüşme, mesaj ve deneme bildirimleri'),
              importance: Importance.high,
              sound: const RawResourceAndroidNotificationSound(channelId),
            ),
          );
    } catch (e) {
      debugPrint('Bildirim kanalı oluşturulamadı: $e');
    }
  }

  /// Bir kez: bildirim kanalı ve bildirime dokunma dinleyicileri.
  Future<void> start() async {
    if (!_enabled || _started) return;
    _started = true;
    await _createChannel();
    final messaging = FirebaseMessaging.instance;

    // Uygulama kapalıyken bildirime dokunularak açıldıysa.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _open(initial);
    // Arka plandayken bildirime dokunulduysa.
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
  }

  /// Giriş yapan kullanıcı için izin ister ve cihaz adresini kaydeder.
  Future<void> register(String userId) async {
    if (!_enabled || _registeredFor == userId) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token == null) return;
      await _save(token);
      _registeredFor = userId;

      await _refresh?.cancel();
      _refresh = messaging.onTokenRefresh.listen(_save);
    } catch (e) {
      debugPrint('Bildirim kaydı yapılamadı: $e');
    }
  }

  /// Çıkıştan ÖNCE çağrılır: bu cihaza artık bu hesabın bildirimi gelmesin.
  Future<void> unregister() async {
    if (!_enabled) return;
    try {
      await _refresh?.cancel();
      _refresh = null;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _client.rpc(
          'unregister_device_token',
          params: {'p_token': token},
        );
      }
    } catch (e) {
      debugPrint('Bildirim kaydı silinemedi: $e');
    } finally {
      _registeredFor = null;
    }
  }

  Future<void> _save(String token) => _client.rpc(
    'register_device_token',
    params: {'p_token': token, 'p_platform': _platform},
  );

  void _open(RemoteMessage m) {
    final route = m.data['route'];
    if (route is! String || !route.startsWith('/')) return;
    final router = _ref.read(routerProvider);
    // Ödev listesi üstüne açılır (geri tuşu çalışsın), diğerleri sekmeye gider.
    const {'/student/homework', '/student/mistakes'}.contains(route)
        ? router.push(route)
        : router.go(route);
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  // Çıkış yapmadan önce bu cihazın adresi silinsin.
  AuthRepository.beforeSignOut = service.unregister;
  ref.onDispose(() {
    if (AuthRepository.beforeSignOut == service.unregister) {
      AuthRepository.beforeSignOut = null;
    }
  });
  return service;
});

/// Uygulama kökünde izlenir: başlatır ve oturum açan kullanıcıyı kaydeder.
final pushBootstrapProvider = Provider<void>((ref) {
  final push = ref.watch(pushServiceProvider);
  unawaited(push.start());
  ref.listen(currentProfileProvider, (_, next) {
    final profile = next.value;
    if (profile != null) unawaited(push.register(profile.id));
  }, fireImmediately: true);
});
