import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Kredi bu sayının altına düşünce müdür ve koçlara uyarı gösterilir.
const lowCreditThreshold = 50;

/// Kurumun öğrenci kredisi. Her yeni öğrenci 1 kredi harcar (sunucuda
/// `consume_student_credit`); öğrenci silinse de kredi geri gelmez.
///
/// Uygulamada fiyat, satın alma ya da ödeme yoktur: kredi yalnızca platform
/// yöneticisi tarafından yüklenir. Kullanıcıya yalnızca "yöneticinizle
/// iletişime geçin" denir.
class OrgCredits {
  const OrgCredits({required this.balance, this.isActive = true});

  factory OrgCredits.fromJson(Map<String, dynamic> j) => OrgCredits(
    balance: j['credit_balance'] as int? ?? 0,
    isActive: j['is_active'] as bool? ?? true,
  );

  final int balance;
  final bool isActive;

  /// Yeni öğrenci eklenebilir mi?
  bool get canAddStudent => isActive && balance > 0;
  bool get low => balance < lowCreditThreshold;
}

abstract interface class OrgCreditsRepository {
  /// Müdür ve koç için kurumun kredisi; diğer roller için null.
  Future<OrgCredits?> fetchCredits();

  /// Kurum davet kodu (MENTORIA-XXXXXX); yalnızca müdür görür.
  Future<String?> fetchOrgCode();

  /// Yeni kurum kodu üretir; eskisi hemen geçersiz olur (yalnızca müdür).
  Future<String> regenerateOrgCode();
}

class SupabaseOrgCreditsRepository implements OrgCreditsRepository {
  SupabaseOrgCreditsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OrgCredits?> fetchCredits() async {
    final r = await _client.rpc('my_org_credits');
    return r is Map ? OrgCredits.fromJson(Map<String, dynamic>.from(r)) : null;
  }

  @override
  Future<String?> fetchOrgCode() async =>
      await _client.rpc('my_org_invite_code') as String?;

  @override
  Future<String> regenerateOrgCode() async =>
      await _client.rpc('regenerate_org_invite_code') as String;
}

final orgCreditsRepositoryProvider = Provider<OrgCreditsRepository>(
  (ref) => SupabaseOrgCreditsRepository(ref.watch(supabaseClientProvider)),
);

final orgCreditsProvider = FutureProvider<OrgCredits?>(
  (ref) => ref.watch(orgCreditsRepositoryProvider).fetchCredits(),
);

final orgCodeProvider = FutureProvider<String?>(
  (ref) => ref.watch(orgCreditsRepositoryProvider).fetchOrgCode(),
);
