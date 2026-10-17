import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../../avatar/data/avatar_models.dart';

/// Arkadaş düellosu: iki öğrenci aynı 10 soruyu çözer. Kazanan daha çok
/// doğru yapan; eşitlikte testi daha kısa sürede bitiren. Puan ve süre
/// sunucuda hesaplanır (`finish_duel`).
const duelQuestionCount = 10;

/// Başladıktan sonra bitirmek için süre (sunucuyla aynı).
const duelTimeLimit = Duration(minutes: 30);

enum DuelStatus {
  /// Sıra bende (davet geldi ya da başladım, bitirmedim).
  yourTurn('your_turn'),

  /// Ben bitirdim, rakip bekleniyor.
  waiting('waiting'),
  done('done'),
  expired('expired');

  const DuelStatus(this.db);
  final String db;

  static DuelStatus fromDb(String v) =>
      values.firstWhere((s) => s.db == v, orElse: () => expired);
}

enum DuelResult {
  won,
  lost,
  draw;

  static DuelResult? fromDb(String? v) =>
      values.where((r) => r.name == v).firstOrNull;
}

class Duel {
  const Duel({
    required this.id,
    required this.subject,
    required this.isChallenger,
    required this.opponentName,
    required this.opponentAvatar,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.myCorrect,
    this.myMs,
    this.theirFinished = false,
    this.theirCorrect,
    this.theirMs,
    this.result,
  });

  factory Duel.fromJson(Map<String, dynamic> j) => Duel(
    id: j['id'] as String,
    subject: j['subject_code'] as String,
    isChallenger: j['is_challenger'] as bool,
    opponentName: j['opponent_name'] as String,
    opponentAvatar: AvatarConfig.fromJson(
      j['opponent_avatar'] == null
          ? null
          : Map<String, dynamic>.from(j['opponent_avatar'] as Map),
    ),
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    expiresAt: DateTime.parse(j['expires_at'] as String).toLocal(),
    status: DuelStatus.fromDb(j['status'] as String),
    myCorrect: j['my_correct'] as int?,
    myMs: j['my_ms'] as int?,
    theirFinished: j['their_finished'] as bool? ?? false,
    theirCorrect: j['their_correct'] as int?,
    theirMs: j['their_ms'] as int?,
    result: DuelResult.fromDb(j['result'] as String?),
  );

  final String id;
  final String subject;
  final bool isChallenger;
  final String opponentName;
  final AvatarConfig opponentAvatar;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DuelStatus status;

  /// Benim sonucum (bitirdiysem).
  final int? myCorrect;
  final int? myMs;

  final bool theirFinished;

  /// Rakibin sonucu; yalnızca ben bitirdikten sonra gelir.
  final int? theirCorrect;
  final int? theirMs;
  final DuelResult? result;

  bool get started => myCorrect != null;
}

class DuelOpponent {
  const DuelOpponent({
    required this.id,
    required this.name,
    required this.avatar,
  });

  factory DuelOpponent.fromJson(Map<String, dynamic> j) => DuelOpponent(
    id: j['student_id'] as String,
    name: j['display_name'] as String,
    avatar: AvatarConfig.fromJson(
      j['avatar'] == null
          ? null
          : Map<String, dynamic>.from(j['avatar'] as Map),
    ),
  );

  final String id;
  final String name;
  final AvatarConfig avatar;
}

/// Sunucunun reddettiği durumlar (`DUEL_*`).
enum DuelError {
  alreadyOpen('DUEL_ALREADY_OPEN'),
  dailyLimit('DUEL_DAILY_LIMIT'),
  expired('DUEL_EXPIRED'),
  timeout('DUEL_TIMEOUT'),
  alreadyFinished('DUEL_ALREADY_FINISHED'),
  other('');

  const DuelError(this.code);
  final String code;
}

class DuelException implements Exception {
  const DuelException(this.error);
  final DuelError error;

  static DuelException from(Object e) {
    final msg = e is PostgrestException ? e.message : '$e';
    return DuelException(
      DuelError.values.firstWhere(
        (d) => d.code.isNotEmpty && msg.contains(d.code),
        orElse: () => DuelError.other,
      ),
    );
  }

  @override
  String toString() => 'DuelException(${error.code})';
}

abstract interface class DuelRepository {
  Future<List<DuelOpponent>> fetchOpponents();
  Future<List<Duel>> fetchDuels();

  /// Yeni düello; kimliğini döner.
  Future<String> create(String opponentId, String subject);

  /// Süreyi başlatır (bir kez) ve soru kimliklerini verir.
  Future<List<String>> start(String duelId);

  /// [answers]: 10 şık indeksi, boş için -1.
  Future<void> finish(String duelId, List<int> answers);
}

class SupabaseDuelRepository implements DuelRepository {
  SupabaseDuelRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PostgrestException catch (e) {
      throw DuelException.from(e);
    }
  }

  @override
  Future<List<DuelOpponent>> fetchOpponents() async {
    final rows = await _client.rpc('duel_opponents') as List;
    return [for (final r in rows) DuelOpponent.fromJson(r)];
  }

  @override
  Future<List<Duel>> fetchDuels() async {
    final rows = await _client.rpc('my_duels') as List;
    return [for (final r in rows) Duel.fromJson(r)];
  }

  @override
  Future<String> create(String opponentId, String subject) => _guard(
    () async =>
        await _client.rpc(
              'create_duel',
              params: {'p_opponent': opponentId, 'p_subject': subject},
            )
            as String,
  );

  @override
  Future<List<String>> start(String duelId) => _guard(() async {
    final ids = await _client.rpc('start_duel', params: {'p_duel': duelId});
    return [for (final id in ids as List) id as String];
  });

  @override
  Future<void> finish(String duelId, List<int> answers) => _guard(
    () => _client.rpc(
      'finish_duel',
      params: {'p_duel': duelId, 'p_answers': answers},
    ),
  );
}

final duelRepositoryProvider = Provider<DuelRepository>(
  (ref) => SupabaseDuelRepository(ref.watch(supabaseClientProvider)),
);

final duelsProvider = FutureProvider<List<Duel>>(
  (ref) => ref.watch(duelRepositoryProvider).fetchDuels(),
);

final duelOpponentsProvider = FutureProvider<List<DuelOpponent>>(
  (ref) => ref.watch(duelRepositoryProvider).fetchOpponents(),
);
