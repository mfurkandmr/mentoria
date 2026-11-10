import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

/// Son görülme: uygulama açılınca ve öne gelince `touch_last_seen()`.
/// Sunucu saatte en çok bir kez yazar; müdür kokpitindeki "7+ gündür
/// girmeyen" listesi buradan gelir (NOTLAR §59).
abstract interface class PresenceRepository {
  Future<void> touch();
}

class SupabasePresenceRepository implements PresenceRepository {
  SupabasePresenceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> touch() async {
    if (_client.auth.currentSession == null) return;
    await _client.rpc('touch_last_seen');
  }
}

/// Demo ve testler: hiçbir şey yazmaz.
class NoopPresenceRepository implements PresenceRepository {
  const NoopPresenceRepository();

  @override
  Future<void> touch() async {}
}

final presenceRepositoryProvider = Provider<PresenceRepository>(
  (ref) => SupabasePresenceRepository(sessionClient(ref)),
);

/// Giriş yapılınca ve uygulama öne gelince son görülmeyi yazar. Hata
/// kullanıcıya yansımaz (bir sonraki açılışta yeniden denenir).
final presenceBootstrapProvider = Provider<void>((ref) {
  final repo = ref.watch(presenceRepositoryProvider);
  void touch() => unawaited(repo.touch().catchError((Object _) {}));
  final lifecycle = AppLifecycleListener(onResume: touch);
  ref.onDispose(lifecycle.dispose);
  ref.listen(currentProfileProvider, (_, next) {
    if (next.value != null) touch();
  }, fireImmediately: true);
});
