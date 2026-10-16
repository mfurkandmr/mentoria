import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import 'avatar_models.dart';

abstract interface class AvatarRepository {
  /// Parça kataloğu (küçük; oturum boyunca bir kez çekilir).
  Future<List<AvatarItem>> fetchCatalog();

  /// Öğrencinin açtığı parça id'leri.
  Future<Set<int>> fetchMyUnlocks();

  /// Hak edilen parçaları sunucuda açar; YENİ açılanları döndürür.
  Future<List<int>> claimUnlocks();

  Future<void> saveAvatar(AvatarConfig config);

  /// Aynı dershanede haftalık sıralama (sayfalı).
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    int limit = 20,
    int offset = 0,
  });
}

class SupabaseAvatarRepository implements AvatarRepository {
  SupabaseAvatarRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AvatarItem>> fetchCatalog() async {
    final rows = await _client
        .from('avatar_items')
        .select('id, category, asset_name, unlock_rule, sort')
        .eq('is_active', true)
        .order('category')
        .order('sort');
    return [for (final r in rows) AvatarItem.fromJson(r)];
  }

  @override
  Future<Set<int>> fetchMyUnlocks() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = await _client
        .from('user_unlocked_items')
        .select('item_id')
        .eq('user_id', uid);
    return {for (final r in rows) r['item_id'] as int};
  }

  @override
  Future<List<int>> claimUnlocks() async {
    final res = await _client.rpc<List<dynamic>>('claim_avatar_unlocks');
    return [for (final v in res) v as int];
  }

  @override
  Future<void> saveAvatar(AvatarConfig config) => _client
      .from('profiles')
      .update({'avatar': config.toJson()})
      .eq('id', _client.auth.currentUser!.id);

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'avatar_leaderboard',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    return [
      for (final r in rows)
        LeaderboardEntry.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }
}

final avatarRepositoryProvider = Provider<AvatarRepository>(
  (ref) => SupabaseAvatarRepository(ref.watch(supabaseClientProvider)),
);

/// Katalog: id → parça. Oturum boyunca önbellekte kalır.
final avatarCatalogProvider = FutureProvider<Map<int, AvatarItem>>((ref) async {
  final items = await ref.watch(avatarRepositoryProvider).fetchCatalog();
  return {for (final i in items) i.id: i};
});

/// Açılan parçalar. Önce sunucuya hak edilenleri açtırır, sonra listeyi okur.
/// Yeni açılanlar [AvatarUnlocks.fresh] içinde (kutlama için).
class AvatarUnlocks {
  const AvatarUnlocks({required this.unlocked, this.fresh = const []});

  final Set<int> unlocked;
  final List<int> fresh;
}

final avatarUnlocksProvider = FutureProvider<AvatarUnlocks>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return const AvatarUnlocks(unlocked: {});
  final repo = ref.watch(avatarRepositoryProvider);
  final fresh = await repo.claimUnlocks();
  final unlocked = await repo.fetchMyUnlocks();
  return AvatarUnlocks(unlocked: unlocked, fresh: fresh);
});
