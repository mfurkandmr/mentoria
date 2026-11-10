import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Web panelinde yakalanmayan bir hata (`client_errors`, NOTLAR §66).
/// Kimliksiz: kullanıcı bilgisi yok; aynı hata aynı sürümde tek satır.
class ClientError {
  const ClientError({
    required this.id,
    required this.message,
    required this.appVersion,
    required this.platform,
    required this.count,
    required this.firstSeen,
    required this.lastSeen,
    this.stack,
    this.urlPath,
    this.userAgent,
  });

  factory ClientError.fromJson(Map<String, dynamic> j) => ClientError(
    id: (j['id'] as num).toInt(),
    message: j['message'] as String,
    appVersion: j['app_version'] as String? ?? '',
    platform: j['platform'] as String? ?? 'web',
    count: (j['count'] as num?)?.toInt() ?? 1,
    firstSeen: DateTime.parse(j['first_seen'] as String),
    lastSeen: DateTime.parse(j['last_seen'] as String),
    stack: j['stack'] as String?,
    urlPath: j['url_path'] as String?,
    userAgent: j['user_agent'] as String?,
  );

  final int id;
  final String message;
  final String appVersion;
  final String platform;
  final int count;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String? stack;
  final String? urlPath;
  final String? userAgent;
}

abstract interface class ClientErrorRepository {
  /// Son görülene göre en yeni hatalar (yalnızca süper admin okur).
  Future<List<ClientError>> recent({int limit = 200});

  /// Çözülen hatayı listeden kaldırır.
  Future<void> delete(int id);
}

class SupabaseClientErrorRepository implements ClientErrorRepository {
  SupabaseClientErrorRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ClientError>> recent({int limit = 200}) async {
    final rows = await _client
        .from('client_errors')
        .select()
        .order('last_seen', ascending: false)
        .limit(limit);
    return [for (final r in rows) ClientError.fromJson(r)];
  }

  @override
  Future<void> delete(int id) =>
      _client.from('client_errors').delete().eq('id', id);
}

final clientErrorRepositoryProvider = Provider<ClientErrorRepository>(
  (ref) => SupabaseClientErrorRepository(sessionClient(ref)),
);

final clientErrorsProvider = FutureProvider.autoDispose<List<ClientError>>(
  (ref) => ref.watch(clientErrorRepositoryProvider).recent(),
);
