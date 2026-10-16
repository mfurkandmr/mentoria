import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';
import '../../avatar/data/avatar_models.dart';

/// Giriş yapan kullanıcının başarı sıralaması durumu.
class SuccessStatus {
  const SuccessStatus({
    required this.enabled,
    this.rewardRank,
    this.tytRank,
    this.tytAvgNet,
  });

  factory SuccessStatus.fromJson(Map<String, dynamic> j) => SuccessStatus(
    enabled: j['enabled'] as bool? ?? false,
    rewardRank: j['reward_rank'] as int?,
    tytRank: j['tyt_rank'] as int?,
    tytAvgNet: (j['tyt_avg_net'] as num?)?.toDouble(),
  );

  static const off = SuccessStatus(enabled: false);

  /// Kurumda sıralama açık mı (müdür açar).
  final bool enabled;

  /// TYT sırası 1–5 ise ödül sırası; değilse null.
  final int? rewardRank;

  /// Öğrencinin TYT sırası ve son 5 deneme ortalaması (denemesi yoksa null).
  final int? tytRank;
  final double? tytAvgNet;

  AvatarReward? get reward => AvatarReward.fromRank(rewardRank);
}

/// Sıralamadaki bir satır (yalnızca görünen ad, avatar JSON'u ve puan).
class SuccessRankEntry {
  const SuccessRankEntry({
    required this.rank,
    required this.studentId,
    required this.displayName,
    required this.avatar,
    required this.avgNet,
    required this.examCount,
    required this.isMe,
    this.rewardRank,
  });

  factory SuccessRankEntry.fromJson(Map<String, dynamic> j) => SuccessRankEntry(
    rank: j['rank'] as int,
    studentId: j['student_id'] as String,
    displayName: j['display_name'] as String,
    avatar: AvatarConfig.fromJson(
      j['avatar'] == null
          ? null
          : Map<String, dynamic>.from(j['avatar'] as Map),
    ),
    avgNet: (j['avg_net'] as num).toDouble(),
    examCount: j['exam_count'] as int,
    rewardRank: j['reward_rank'] as int?,
    isMe: j['is_me'] as bool? ?? false,
  );

  final int rank;
  final String studentId;
  final String displayName;
  final AvatarConfig avatar;

  /// Son 5 denemenin (ya da daha azının) ortalama toplam neti.
  final double avgNet;
  final int examCount;
  final int? rewardRank;
  final bool isMe;
}

/// Sıralama kapalıyken öğrenci/koç listeyi isterse.
class RankingDisabledException implements Exception {
  const RankingDisabledException();
}

abstract interface class SuccessRankingRepository {
  Future<SuccessStatus> fetchStatus();

  /// Yalnızca kurum müdürü.
  Future<void> setEnabled(bool enabled);

  /// TYT ya da AYT (alanıyla) sıralaması, sayfalı.
  /// Kapalıyken [RankingDisabledException] (müdür hariç).
  Future<List<SuccessRankEntry>> fetchRanking({
    required ExamType examType,
    FieldType? field,
    int limit = 20,
    int offset = 0,
  });
}

class SupabaseSuccessRankingRepository implements SuccessRankingRepository {
  SupabaseSuccessRankingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SuccessStatus> fetchStatus() async {
    final rows = await _client.rpc<List<dynamic>>('my_success_status');
    if (rows.isEmpty) return SuccessStatus.off;
    return SuccessStatus.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  @override
  Future<void> setEnabled(bool enabled) =>
      _client.rpc<void>('set_success_ranking', params: {'p_enabled': enabled});

  @override
  Future<List<SuccessRankEntry>> fetchRanking({
    required ExamType examType,
    FieldType? field,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'success_leaderboard',
        params: {
          'p_exam_type': examType.db,
          'p_field': examType == ExamType.ayt ? field?.db : null,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return [
        for (final r in rows)
          SuccessRankEntry.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
    } on PostgrestException catch (e) {
      if (e.message.contains('RANKING_DISABLED')) {
        throw const RankingDisabledException();
      }
      rethrow;
    }
  }
}

final successRankingRepositoryProvider = Provider<SuccessRankingRepository>(
  (ref) => SupabaseSuccessRankingRepository(ref.watch(supabaseClientProvider)),
);

/// Kendi durumum (sıralama açık mı, ödülüm). Oturum değişince yenilenir.
final successStatusProvider = FutureProvider<SuccessStatus>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return SuccessStatus.off;
  return ref.watch(successRankingRepositoryProvider).fetchStatus();
});

/// Kendi avatarımda çizilecek ödül (yüklenirken ya da hata olursa yok).
final myAvatarRewardProvider = Provider<AvatarReward?>(
  (ref) => ref.watch(successStatusProvider).value?.reward,
);
