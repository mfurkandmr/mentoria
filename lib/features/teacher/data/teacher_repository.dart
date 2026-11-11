import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Öğretmenin kurumdaki kaydı (`my_teacher()`): kayıt olunca kurumun
/// öğretmen listesine kendiliğinden eklenen satır (NOTLAR §86).
class MyTeacher {
  const MyTeacher({
    required this.id,
    required this.fullName,
    required this.branches,
    required this.orgName,
  });

  factory MyTeacher.fromJson(Map<String, dynamic> j) => MyTeacher(
    id: j['id'] as String,
    fullName: j['full_name'] as String,
    branches: [for (final b in j['branches'] as List? ?? const []) b as String],
    orgName: j['org_name'] as String? ?? '',
  );

  final String id;
  final String fullName;
  final List<String> branches;
  final String orgName;

  /// Kayıtta branş seçilmediyse sunucu 'Genel' yazar.
  bool get needsBranches =>
      branches.isEmpty || (branches.length == 1 && branches.first == 'Genel');
}

abstract interface class TeacherRepository {
  /// Kurum öğretmen kaydını sildiyse null.
  Future<MyTeacher?> myTeacher();

  /// Temizlenmiş branş listesini döner (`BRANCH_REQUIRED`: liste boş).
  Future<List<String>> setMyBranches(List<String> branches);

  /// Müdür: elle eklenmiş hesapsız öğretmeni ([keepId]) kayıt olan
  /// hesabın satırıyla ([fromId]) birleştirir. Program, ücret ve gider
  /// bağlantıları korunur; aynı saatte iki dersi varsa
  /// `TEACHER_MERGE_CONFLICT`.
  Future<void> mergeTeachers({required String keepId, required String fromId});
}

class SupabaseTeacherRepository implements TeacherRepository {
  SupabaseTeacherRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MyTeacher?> myTeacher() async {
    final rows = await _client.rpc('my_teacher') as List;
    if (rows.isEmpty) return null;
    return MyTeacher.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  @override
  Future<List<String>> setMyBranches(List<String> branches) async {
    final r = await _client.rpc(
      'set_my_teacher_branches',
      params: {'p_branches': branches},
    );
    return [for (final b in r as List) b as String];
  }

  @override
  Future<void> mergeTeachers({
    required String keepId,
    required String fromId,
  }) => _client.rpc(
    'merge_teachers',
    params: {'p_keep': keepId, 'p_from': fromId},
  );
}

final teacherRepositoryProvider = Provider<TeacherRepository>(
  (ref) => SupabaseTeacherRepository(sessionClient(ref)),
);

final myTeacherProvider = FutureProvider<MyTeacher?>(
  (ref) => ref.watch(teacherRepositoryProvider).myTeacher(),
);

/// Aynı kişi olabilecek öğretmen çiftleri: hesabı olmayan (elle eklenmiş)
/// ve hesabı olan (kayıtla gelen) satırların adı aynıysa.
List<({String keepId, String fromId, String name})> teacherMergeCandidates(
  List<({String id, String name, bool hasAccount})> teachers,
) {
  String key(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final manual = <String, String>{};
  for (final t in teachers) {
    if (!t.hasAccount) manual.putIfAbsent(key(t.name), () => t.id);
  }
  return [
    for (final t in teachers)
      if (t.hasAccount && manual[key(t.name)] != null)
        (keepId: manual[key(t.name)]!, fromId: t.id, name: t.name),
  ];
}
