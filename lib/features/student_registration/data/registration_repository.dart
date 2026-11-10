import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Öğrenci kayıt modu: liste ile eşleşmeli ya da serbest.
enum RegistrationMode {
  list('list'),
  free('free');

  const RegistrationMode(this.db);

  final String db;

  static RegistrationMode fromDb(String? v) =>
      v == 'list' ? RegistrationMode.list : RegistrationMode.free;
}

/// Kurumun beklenen öğrenci listesinden bir satır.
class ExpectedStudent {
  const ExpectedStudent({
    required this.number,
    required this.fullName,
    this.className,
    this.guardianPhone,
    this.matched = false,
  });

  factory ExpectedStudent.fromJson(Map<String, dynamic> j) => ExpectedStudent(
    number: j['student_number'] as String,
    fullName: j['full_name'] as String,
    className: j['class_name'] as String?,
    guardianPhone: j['guardian_phone'] as String?,
    matched: j['status'] == 'matched',
  );

  final String number;
  final String fullName;
  final String? className;

  /// "+905XXXXXXXXX".
  final String? guardianPhone;
  final bool matched;

  Map<String, dynamic> toImportJson() => {
    'number': number,
    'name': fullName,
    'class': className,
    'phone': guardianPhone,
  };
}

/// İçe aktarma sonucu.
class ImportResult {
  const ImportResult({
    required this.inserted,
    required this.updated,
    required this.removed,
  });

  final int inserted;
  final int updated;
  final int removed;
}

abstract interface class RegistrationRepository {
  Future<RegistrationMode> fetchMode();

  /// Yalnızca müdür. Listeye geçince mevcut öğrenciler listeyle
  /// karşılaştırılır, eşleşmeyenler şüpheli işaretlenir.
  Future<void> setMode(RegistrationMode mode);

  /// Yalnızca müdür: beklenen öğrenci listesi.
  Future<List<ExpectedStudent>> fetchExpected();

  /// [replace]: listede olmayan ve henüz eşleşmemiş satırlar silinir.
  Future<ImportResult> importExpected(
    List<ExpectedStudent> rows, {
    bool replace = false,
  });
}

class SupabaseRegistrationRepository implements RegistrationRepository {
  SupabaseRegistrationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RegistrationMode> fetchMode() async {
    final row = await _client
        .from('organizations')
        .select('student_registration_mode')
        .maybeSingle();
    return RegistrationMode.fromDb(
      row?['student_registration_mode'] as String?,
    );
  }

  @override
  Future<void> setMode(RegistrationMode mode) =>
      _client.rpc('set_registration_mode', params: {'p_mode': mode.db});

  @override
  Future<List<ExpectedStudent>> fetchExpected() async => [
    for (final r
        in await _client
            .from('expected_students')
            .select(
              'student_number, full_name, class_name, guardian_phone, status',
            )
            .order('student_number'))
      ExpectedStudent.fromJson(Map<String, dynamic>.from(r)),
  ];

  @override
  Future<ImportResult> importExpected(
    List<ExpectedStudent> rows, {
    bool replace = false,
  }) async {
    final r = Map<String, dynamic>.from(
      await _client.rpc(
            'import_expected_students',
            params: {
              'p_rows': [for (final x in rows) x.toImportJson()],
              'p_replace': replace,
            },
          )
          as Map,
    );
    return ImportResult(
      inserted: r['inserted'] as int? ?? 0,
      updated: r['updated'] as int? ?? 0,
      removed: r['removed'] as int? ?? 0,
    );
  }
}

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => SupabaseRegistrationRepository(sessionClient(ref)),
);

final registrationModeProvider = FutureProvider<RegistrationMode>(
  (ref) => ref.watch(registrationRepositoryProvider).fetchMode(),
);

final expectedStudentsProvider = FutureProvider<List<ExpectedStudent>>(
  (ref) => ref.watch(registrationRepositoryProvider).fetchExpected(),
);
