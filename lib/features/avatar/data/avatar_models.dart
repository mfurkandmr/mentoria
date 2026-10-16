import '../../../core/i18n/i18n.dart';

/// Avatar parça kategorileri. Sıra = çizim sırası (alttan üste).
enum AvatarCategory {
  skin('Ten'),
  outfit('Kıyafet'),
  hair('Saç'),
  accessory('Aksesuar');

  const AvatarCategory(this.trLabel);
  final String trLabel;

  String get label => tr(trLabel);

  /// Editördeki sekme sırası.
  static const editorOrder = [hair, skin, outfit, accessory];

  /// Aksesuar zorunlu değil ("yok" seçilebilir).
  bool get optional => this == accessory;

  static AvatarCategory? fromDb(String v) =>
      AvatarCategory.values.where((c) => c.name == v).firstOrNull;
}

/// Parça görsellerinin yolu. Gerçek çizimler gelince yalnızca dosyalar
/// değiştirilir (aynı adla) ya da burası güncellenir (ör. .png).
class AvatarAssets {
  const AvatarAssets._();

  static const root = 'assets/avatar';
  static const extension = 'svg';

  static String path(AvatarCategory category, String assetName) =>
      '$root/${category.name}/$assetName.$extension';

  /// Başarı sıralaması ödül katmanları (`assets/avatar/reward/`).
  static String reward(String assetName) =>
      '$root/reward/$assetName.$extension';
}

/// Başarı sıralaması ödülü (kurumdaki TYT sırası 1–5). Avatar JSON'unda
/// tutulmaz ve kalıcı açılmaz: sunucu o anki sıraya göre `reward_rank`
/// döndürür, uygulama avatarın üstüne ek katman olarak çizer.
enum AvatarReward {
  /// 1.: kral tacı (ilk 3'ün altın kanatlarıyla birlikte).
  king('Kral tacı'),

  /// 1–3.: altın arı kanatları.
  gold('Altın kanatlar'),

  /// 4–5.: gümüş arı kanatları.
  silver('Gümüş kanatlar');

  const AvatarReward(this.trLabel);
  final String trLabel;

  String get label => tr(trLabel);

  static AvatarReward? fromRank(int? rank) => switch (rank) {
    1 => king,
    2 || 3 => gold,
    4 || 5 => silver,
    _ => null,
  };

  /// Avatarın arkasına çizilen katman (kanatlar).
  String get backAsset => AvatarAssets.reward(
    this == silver ? 'reward_wings_silver' : 'reward_wings_gold',
  );

  /// En üste çizilen katman (taç).
  String? get frontAsset =>
      this == king ? AvatarAssets.reward('reward_crown_king') : null;
}

/// Parçanın açılma koşulu (sunucudaki `avatar_items.unlock_rule`).
class AvatarRule {
  const AvatarRule(this.data);

  final Map<String, dynamic> data;

  String get type => data['type'] as String? ?? 'free';
  bool get isFree => type == 'free';
}

/// Katalogdaki bir parça.
class AvatarItem {
  const AvatarItem({
    required this.id,
    required this.category,
    required this.assetName,
    required this.rule,
    this.sort = 0,
  });

  factory AvatarItem.fromJson(Map<String, dynamic> j) => AvatarItem(
    id: j['id'] as int,
    category: AvatarCategory.fromDb(j['category'] as String)!,
    assetName: j['asset_name'] as String,
    rule: AvatarRule(
      Map<String, dynamic>.from(
        j['unlock_rule'] as Map? ?? const {'type': 'free'},
      ),
    ),
    sort: j['sort'] as int? ?? 0,
  );

  final int id;
  final AvatarCategory category;
  final String assetName;
  final AvatarRule rule;
  final int sort;

  String get assetPath => AvatarAssets.path(category, assetName);
}

/// Öğrencinin seçimi: kategori → parça id. `profiles.avatar` JSON'u.
class AvatarConfig {
  const AvatarConfig(this.parts);

  factory AvatarConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return fallback;
    final parts = <AvatarCategory, int>{};
    for (final e in j.entries) {
      final c = AvatarCategory.fromDb(e.key);
      final v = e.value;
      if (c != null && v is int) parts[c] = v;
    }
    return parts.isEmpty ? fallback : AvatarConfig(parts);
  }

  /// Hiç seçim yapılmamışsa (ücretsiz başlangıç parçaları).
  static const fallback = AvatarConfig({
    AvatarCategory.skin: 6,
    AvatarCategory.outfit: 10,
    AvatarCategory.hair: 1,
  });

  final Map<AvatarCategory, int> parts;

  int? operator [](AvatarCategory c) => parts[c];

  AvatarConfig withPart(AvatarCategory c, int? id) {
    final next = Map<AvatarCategory, int>.from(parts);
    id == null ? next.remove(c) : next[c] = id;
    return AvatarConfig(next);
  }

  Map<String, int> toJson() => {
    for (final e in parts.entries) e.key.name: e.value,
  };

  @override
  bool operator ==(Object other) =>
      other is AvatarConfig &&
      other.parts.length == parts.length &&
      parts.entries.every((e) => other.parts[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(
    parts.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// Sıralamadaki bir satır (yalnızca görünen ad, avatar JSON'u ve puan).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.studentId,
    required this.displayName,
    required this.avatar,
    required this.weekQuestions,
    required this.isMe,
    this.rewardRank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    rank: j['rank'] as int,
    studentId: j['student_id'] as String,
    displayName: j['display_name'] as String,
    avatar: AvatarConfig.fromJson(
      j['avatar'] == null
          ? null
          : Map<String, dynamic>.from(j['avatar'] as Map),
    ),
    weekQuestions: j['week_questions'] as int,
    isMe: j['is_me'] as bool? ?? false,
    rewardRank: j['reward_rank'] as int?,
  );

  final int rank;
  final String studentId;
  final String displayName;
  final AvatarConfig avatar;
  final int weekQuestions;
  final bool isMe;

  /// Başarı sıralamasındaki ödül sırası (1–5) ya da null.
  final int? rewardRank;
}
