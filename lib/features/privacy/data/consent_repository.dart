import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Yayımlanan KVKK metinlerinin sürümü. Metin değişince artırılır; rıza
/// kayıtları hangi sürüme verildiğini tutar (bkz. docs/kvkk).
const legalVersion = '1.1';

/// Rıza türleri (veritabanındaki `consents.kind`).
enum ConsentKind {
  /// Aydınlatma metnini okudum (rıza değil, teyit).
  privacyNotice('privacy_notice'),

  /// Başarı sıralaması ve avatar liderliğinde görünmek.
  ranking('ranking'),

  /// (18+) Davet ettiğim velinin verilerimi görmesi.
  parentView('parent_view'),

  /// (18-) Veli onayı: veliden ya da kurum beyanından.
  guardianApproval('guardian_approval');

  const ConsentKind(this.db);
  final String db;
}

/// Bir kişinin KVKK durumu (`consent_status` RPC).
class ConsentStatus {
  const ConsentStatus({
    this.birthYear,
    this.minor = true,
    this.privacyNotice = false,
    this.ranking = false,
    this.parentView = false,
    this.guardianApproval = false,
    this.guardianSource,
    this.rankingVisible = false,
    this.hasParent = false,
    this.history = const [],
  });

  factory ConsentStatus.fromJson(Map<String, dynamic> j) => ConsentStatus(
    birthYear: j['birth_year'] as int?,
    minor: j['minor'] as bool? ?? true,
    privacyNotice: j['privacy_notice'] as bool? ?? false,
    ranking: j['ranking'] as bool? ?? false,
    parentView: j['parent_view'] as bool? ?? false,
    guardianApproval: j['guardian_approval'] as bool? ?? false,
    guardianSource: j['guardian_source'] as String?,
    rankingVisible: j['ranking_visible'] as bool? ?? false,
    hasParent: j['has_parent'] as bool? ?? false,
    history: [
      for (final h in (j['history'] as List? ?? const []))
        ConsentEvent.fromJson((h as Map).cast<String, dynamic>()),
    ],
  );

  /// Doğum yılı girilmemişse null (küçük sayılır).
  final int? birthYear;
  final bool minor;
  final bool privacyNotice;
  final bool ranking;
  final bool parentView;
  final bool guardianApproval;

  /// Veli onayını kim verdi: 'parent' ya da 'institution'.
  final String? guardianSource;

  /// Sıralamalarda görünüyor mu (rıza + 18 altında veli onayı).
  final bool rankingVisible;
  final bool hasParent;
  final List<ConsentEvent> history;

  /// 18 yaşından küçük ve veli onayı yok.
  bool get awaitingGuardian => minor && !guardianApproval;

  ConsentStatus copyWith({
    int? birthYear,
    bool? minor,
    bool? ranking,
    bool? parentView,
    bool? guardianApproval,
    String? guardianSource,
    bool? hasParent,
    List<ConsentEvent>? history,
  }) {
    final m = minor ?? this.minor;
    final g = guardianApproval ?? this.guardianApproval;
    final r = ranking ?? this.ranking;
    return ConsentStatus(
      birthYear: birthYear ?? this.birthYear,
      minor: m,
      privacyNotice: privacyNotice,
      ranking: r,
      parentView: parentView ?? this.parentView,
      guardianApproval: g,
      guardianSource: g ? (guardianSource ?? this.guardianSource) : null,
      rankingVisible: r && (!m || g),
      hasParent: hasParent ?? this.hasParent,
      history: history ?? this.history,
    );
  }
}

/// 18 yaşından küçük mü (yalnızca doğum yılından; o yıl 18'ini dolduranlar
/// yıl bitene kadar küçük sayılır, sunucudaki `is_minor` ile aynı).
bool isMinorBirthYear(int? birthYear, {DateTime? now}) =>
    birthYear == null || birthYear >= (now ?? DateTime.now()).year - 18;

/// Rıza geçmişinde bir satır.
class ConsentEvent {
  const ConsentEvent({
    required this.kind,
    required this.granted,
    required this.version,
    required this.source,
    required this.at,
  });

  factory ConsentEvent.fromJson(Map<String, dynamic> j) => ConsentEvent(
    kind: j['kind'] as String,
    granted: j['granted'] as bool,
    version: j['version'] as String,
    source: j['source'] as String,
    at: DateTime.parse(j['at'] as String).toLocal(),
  );

  final String kind;
  final bool granted;
  final String version;
  final String source;
  final DateTime at;
}

abstract interface class ConsentRepository {
  /// Kendi durumum ya da ([userId]) görebildiğim öğrencinin durumu.
  Future<ConsentStatus> status({String? userId});

  /// Rıza ver / geri çek. [studentId] verilirse veli olarak çocuğum için.
  Future<void> setConsent(
    ConsentKind kind, {
    required bool granted,
    String? studentId,
  });

  /// Doğum yılı: kendim (bir kez) ya da koç/müdür olarak öğrencim için.
  Future<void> setBirthYear(int year, {String? userId});

  /// KVKK md. 11: verilerimin tamamı (JSON'a çevrilebilir).
  Future<Map<String, dynamic>> exportMyData();
}

class SupabaseConsentRepository implements ConsentRepository {
  SupabaseConsentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ConsentStatus> status({String? userId}) async {
    final r = await _client.rpc('consent_status', params: {'p_user': ?userId});
    return ConsentStatus.fromJson((r as Map).cast<String, dynamic>());
  }

  @override
  Future<void> setConsent(
    ConsentKind kind, {
    required bool granted,
    String? studentId,
  }) => _client.rpc(
    'set_consent',
    params: {
      'p_kind': kind.db,
      'p_granted': granted,
      'p_version': legalVersion,
      'p_student': ?studentId,
    },
  );

  @override
  Future<void> setBirthYear(int year, {String? userId}) => _client.rpc(
    'set_birth_year',
    params: {'p_year': year, 'p_user': ?userId},
  );

  @override
  Future<Map<String, dynamic>> exportMyData() async {
    final r = await _client.rpc('export_my_data');
    final data = (r as Map).cast<String, dynamic>();
    // auth.users kullanıcı yetkisiyle okunamadığı için e-posta oturumdan.
    final email = _client.auth.currentUser?.email;
    return {
      if (email != null) 'account': {'email': email},
      ...data,
    };
  }
}

final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => SupabaseConsentRepository(ref.watch(supabaseClientProvider)),
);

/// Kendi KVKK durumum (giriş yapan kişi değişince yenilenir).
final myConsentStatusProvider = FutureProvider<ConsentStatus>((ref) async {
  ref.watch(currentProfileProvider.select((p) => p.value?.id));
  return ref.watch(consentRepositoryProvider).status();
});

/// Görebildiğim bir öğrencinin (velisi/koçu olarak) KVKK durumu.
final studentConsentStatusProvider =
    FutureProvider.family<ConsentStatus, String>(
      (ref, studentId) =>
          ref.watch(consentRepositoryProvider).status(userId: studentId),
    );
