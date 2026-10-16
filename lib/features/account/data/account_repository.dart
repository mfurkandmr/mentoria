import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';

/// Profil ekranında düzenlenebilen alanlar.
class ProfileDetails {
  const ProfileDetails({required this.fullName, this.examYear, this.field});

  final String fullName;
  final int? examYear;
  final FieldType? field;
}

/// Velinin bağlı olduğu öğrenci.
class ChildRef {
  const ChildRef({required this.id, required this.fullName});

  final String id;
  final String fullName;
}

abstract interface class AccountRepository {
  Future<ProfileDetails> fetchDetails();
  Future<void> updateDetails(ProfileDetails details);

  /// Öğrenci: velisi için davet kodu üretir.
  Future<String> createParentInvite();

  /// Öğrenci: bağlı veli sayısı.
  Future<int> parentCount();

  /// Veli: bağlı olduğu öğrenciler.
  Future<List<ChildRef>> fetchChildren();

  /// Öğrenci: bekleyen hesap silme talebinin tarihi (yoksa null).
  Future<DateTime?> fetchDeletionRequest();

  /// Öğrenci: hesabının silinmesini koçundan ister. Hesabı koçu siler.
  Future<void> requestAccountDeletion();

  /// Öğrenci: hesap silme talebini geri alır.
  Future<void> cancelAccountDeletion();
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<ProfileDetails> fetchDetails() async {
    final r = await _client
        .from('profiles')
        .select('full_name, exam_year, field')
        .eq('id', _uid)
        .single();
    return ProfileDetails(
      fullName: r['full_name'] as String,
      examYear: r['exam_year'] as int?,
      field: FieldType.fromDb(r['field'] as String?),
    );
  }

  @override
  Future<void> updateDetails(ProfileDetails d) => _client
      .from('profiles')
      .update({
        'full_name': d.fullName,
        'exam_year': d.examYear,
        'field': d.field?.db,
      })
      .eq('id', _uid);

  @override
  Future<String> createParentInvite() async {
    final code = await _client.rpc(
      'create_invite',
      params: {'p_target_role': 'parent'},
    );
    return code as String;
  }

  @override
  Future<int> parentCount() async {
    final rows = await _client
        .from('parent_students')
        .select('parent_id')
        .eq('student_id', _uid);
    return rows.length;
  }

  @override
  Future<List<ChildRef>> fetchChildren() async {
    final links = await _client
        .from('parent_students')
        .select('student_id')
        .eq('parent_id', _uid);
    final ids = [for (final l in links) l['student_id'] as String];
    if (ids.isEmpty) return [];
    final rows = await _client
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', ids)
        .order('full_name');
    return [
      for (final r in rows)
        ChildRef(id: r['id'] as String, fullName: r['full_name'] as String),
    ];
  }

  @override
  Future<DateTime?> fetchDeletionRequest() async {
    final r = await _client
        .from('account_deletion_requests')
        .select('requested_at')
        .eq('student_id', _uid)
        .maybeSingle();
    return r == null
        ? null
        : DateTime.parse(r['requested_at'] as String).toLocal();
  }

  @override
  Future<void> requestAccountDeletion() async {
    try {
      await _client.rpc('request_account_deletion');
    } on PostgrestException catch (e) {
      // Zaten bekleyen bir talep var: sonuç aynı.
      if (!e.message.contains('ALREADY_REQUESTED')) rethrow;
    }
  }

  @override
  Future<void> cancelAccountDeletion() =>
      _client.from('account_deletion_requests').delete().eq('student_id', _uid);
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(ref.watch(supabaseClientProvider)),
);

final profileDetailsProvider = FutureProvider<ProfileDetails>(
  (ref) => ref.watch(accountRepositoryProvider).fetchDetails(),
);

final childrenProvider = FutureProvider<List<ChildRef>>(
  (ref) => ref.watch(accountRepositoryProvider).fetchChildren(),
);

final parentCountProvider = FutureProvider<int>(
  (ref) => ref.watch(accountRepositoryProvider).parentCount(),
);

/// Öğrencinin bekleyen hesap silme talebi (yoksa null).
final deletionRequestProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(accountRepositoryProvider).fetchDeletionRequest(),
);
