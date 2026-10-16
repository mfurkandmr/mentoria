import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Paylaşılabilir linkler.
///
/// Kök adres `APP_LINK_BASE` ile verilebilir (ör. web sürümünün adresi).
/// Verilmezse web'de uygulamanın kendi adresi (`/#` yönlendirmesiyle),
/// mobilde `mentoria://app` derin bağlantısı kullanılır.
class AppLinks {
  const AppLinks._();

  static String get _base {
    if (Env.appLinkBase.isNotEmpty) {
      return Env.appLinkBase.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) return '${Uri.base.origin}/#';
    return 'mentoria://app';
  }

  /// Davet linki: açınca kayıt ekranı kod dolu ve dershanenin markasıyla gelir.
  static String invite(String code) => '$_base/join/${code.toUpperCase()}';

  /// Dershane linki: giriş ekranı o dershanenin markasıyla açılır.
  static String tenant(String slug) => '$_base/t/$slug';
}
