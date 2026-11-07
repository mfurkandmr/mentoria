import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_version.dart';

/// Web panelindeki yakalanmayan hataları `report_client_error` ile kaydeder
/// (Crashlytics web'de yok; NOTLAR §66). KVKK: kimliksiz; kullanıcı kimliği
/// gönderilmez, adres yalnızca yol olarak (sorgu ve # kısmı olmadan).
///
/// Bir oturumda aynı hata bir kez, toplam en fazla [maxPerSession] hata
/// gönderilir (hata döngüsünde sunucuyu doldurmasın). Gönderim hatası
/// sessizce yutulur: hata kaydı uygulamayı asla bozmaz.
class WebErrorReporter {
  WebErrorReporter(this._send, {String Function()? path})
    : _path = path ?? (() => Uri.base.path);

  final Future<void> Function(Map<String, dynamic> params) _send;
  final String Function() _path;

  static const maxPerSession = 20;
  final _seen = <String>{};
  int _sent = 0;

  @visibleForTesting
  int get sentCount => _sent;

  void report(Object error, StackTrace? stack) {
    if (_sent >= maxPerSession) return;
    final message = error.toString();
    final stackText = stack?.toString();
    final key = '$message|${stackText?.split('\n').first ?? ''}';
    if (!_seen.add(key)) return;
    _sent++;
    unawaited(
      _send(
        params(message: message, stack: stackText, path: _path()),
      ).catchError((Object _) {}),
    );
  }

  @visibleForTesting
  static Map<String, dynamic> params({
    required String message,
    String? stack,
    required String path,
  }) => {
    'p_message': message.length > 1000 ? message.substring(0, 1000) : message,
    'p_stack': stack == null || stack.length <= 8000
        ? stack
        : stack.substring(0, 8000),
    'p_url_path': path.split('?').first.split('#').first,
    'p_platform': 'web',
    'p_app_version': '$appVersion+$appBuild',
    // Tarayıcının tam kimliği yerine yalnızca işletim sistemi türü.
    'p_user_agent': 'web/${defaultTargetPlatform.name}',
  };
}
