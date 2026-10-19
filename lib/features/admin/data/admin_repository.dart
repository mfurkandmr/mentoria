import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';

class OrgInfo {
  const OrgInfo({
    required this.id,
    required this.name,
    required this.seatLimit,
    this.licenseExpiresAt,
  });

  final String id;
  final String name;
  final int seatLimit;
  final DateTime? licenseExpiresAt;

  bool get licenseExpired =>
      licenseExpiresAt != null && licenseExpiresAt!.isBefore(DateTime.now());
}

class OrgMember {
  const OrgMember({
    required this.id,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final DateTime createdAt;
}

/// Kurumdaki bir davet kodu (müdür görünümü).
class OrgInvite {
  const OrgInvite({
    required this.code,
    required this.role,
    required this.maxUses,
    required this.usedCount,
    required this.expiresAt,
    this.coachId,
  });

  final String code;
  final UserRole role;
  final int maxUses;
  final int usedCount;
  final DateTime expiresAt;
  final String? coachId;

  int get remaining => maxUses - usedCount;
}

abstract interface class AdminRepository {
  Future<OrgInfo> fetchOrg();
  Future<void> renameOrg(String name);
  Future<List<OrgMember>> fetchMembers();
  Future<String> createCoachInvite({int maxUses = 1});

  /// [guardianStatement]: kurum, 18 yaşından küçük öğrencilerin veli
  /// onayını kendisinin aldığını beyan eder (KVKK; bkz. docs/kvkk).
  Future<String> createStudentInvite({
    required String coachId,
    int maxUses = 1,
    bool guardianStatement = false,
  });
  Future<List<OrgInvite>> fetchActiveInvites();
  Future<void> deleteInvite(String code);
  Future<void> reassignCoach(String studentId, String newCoachId);
}

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OrgInfo> fetchOrg() async {
    final r = await _client
        .from('organizations')
        .select('id, name, seat_limit, license_expires_at')
        .single();
    return OrgInfo(
      id: r['id'] as String,
      name: r['name'] as String,
      seatLimit: r['seat_limit'] as int,
      licenseExpiresAt: r['license_expires_at'] == null
          ? null
          : DateTime.parse(r['license_expires_at'] as String).toLocal(),
    );
  }

  @override
  Future<void> renameOrg(String name) async {
    final org = await fetchOrg();
    await _client.from('organizations').update({'name': name}).eq('id', org.id);
  }

  @override
  Future<List<OrgMember>> fetchMembers() async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name, role, created_at')
        .order('full_name');
    return [
      for (final r in rows)
        OrgMember(
          id: r['id'] as String,
          fullName: r['full_name'] as String,
          role: UserRole.fromName(r['role'] as String),
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<String> createCoachInvite({int maxUses = 1}) async {
    final code = await _client.rpc(
      'create_invite',
      params: {'p_target_role': 'coach', 'p_max_uses': maxUses},
    );
    return code as String;
  }

  @override
  Future<String> createStudentInvite({
    required String coachId,
    int maxUses = 1,
    bool guardianStatement = false,
  }) async {
    final code = await _client.rpc(
      'create_invite',
      params: {
        'p_target_role': 'student',
        'p_coach': coachId,
        'p_max_uses': maxUses,
        if (guardianStatement) 'p_guardian_statement': true,
      },
    );
    return code as String;
  }

  @override
  Future<List<OrgInvite>> fetchActiveInvites() async {
    final rows = await _client
        .from('invite_codes')
        .select('code, target_role, max_uses, used_count, expires_at, coach_id')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        if ((r['used_count'] as int) < (r['max_uses'] as int))
          OrgInvite(
            code: r['code'] as String,
            role: UserRole.fromName(r['target_role'] as String),
            maxUses: r['max_uses'] as int,
            usedCount: r['used_count'] as int,
            expiresAt: DateTime.parse(r['expires_at'] as String).toLocal(),
            coachId: r['coach_id'] as String?,
          ),
    ];
  }

  @override
  Future<void> deleteInvite(String code) =>
      _client.from('invite_codes').delete().eq('code', code);

  @override
  Future<void> reassignCoach(String studentId, String newCoachId) => _client
      .from('coach_students')
      .update({'coach_id': newCoachId})
      .eq('student_id', studentId);
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(ref.watch(supabaseClientProvider)),
);

final orgProvider = FutureProvider<OrgInfo>(
  (ref) => ref.watch(adminRepositoryProvider).fetchOrg(),
);

final orgMembersProvider = FutureProvider<List<OrgMember>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchMembers(),
);

final orgInvitesProvider = FutureProvider<List<OrgInvite>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchActiveInvites(),
);
