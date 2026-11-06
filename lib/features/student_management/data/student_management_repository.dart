import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';

/// Öğrenci numarası işareti (serbest kayıt ya da listeye geçişte).
enum NumberFlag {
  badFormat('bad_format'),
  duplicate('duplicate'),
  notInList('not_in_list');

  const NumberFlag(this.db);

  final String db;

  static NumberFlag? fromDb(String? v) {
    for (final f in values) {
      if (f.db == v) return f;
    }
    return null;
  }

  String get label => switch (this) {
    badFormat => tr('Numara biçimi hatalı'),
    duplicate => tr('Kullanımdaki numarayı denedi'),
    notInList => tr('Numara kurum listesinde yok'),
  };
}

/// Öğrenci numarası kuralı: yalnızca rakam, 1-20 karakter.
bool isValidStudentNumber(String s) => RegExp(r'^\d{1,20}$').hasMatch(s);

/// Ad benzerliği için sadeleştirme: küçük harf, Türkçe harfler düz, boşluk tek.
String normalizeName(String s) {
  const map = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'i̇': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  var t = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  map.forEach((k, v) => t = t.replaceAll(k, v));
  return t
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// İki ad arasındaki düzenleme uzaklığı (Levenshtein).
int editDistance(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

class ManagedStudent {
  const ManagedStudent({
    required this.id,
    required this.fullName,
    this.studentNumber,
    this.classroomId,
    this.classroomName,
    this.coachId,
    this.coachName,
    this.flag,
    this.attemptedNumber,
    this.source,
  });

  factory ManagedStudent.fromJson(Map<String, dynamic> j) => ManagedStudent(
    id: j['student_id'] as String,
    fullName: j['full_name'] as String? ?? '',
    studentNumber: j['student_number'] as String?,
    classroomId: j['classroom_id'] as String?,
    classroomName: j['classroom_name'] as String?,
    coachId: j['coach_id'] as String?,
    coachName: j['coach_name'] as String?,
    flag: NumberFlag.fromDb(j['number_flag'] as String?),
    attemptedNumber: j['attempted_number'] as String?,
    source: j['registration_source'] as String?,
  );

  final String id;
  final String fullName;
  final String? studentNumber;
  final String? classroomId;
  final String? classroomName;
  final String? coachId;
  final String? coachName;
  final NumberFlag? flag;

  /// Kayıtta denenip alınamayan numara.
  final String? attemptedNumber;

  /// 'matched' (listeden) | 'free' | null (eski kayıt).
  final String? source;

  bool get hasClass => classroomId != null;

  ManagedStudent copyWith({
    String? studentNumber,
    String? classroomId,
    String? classroomName,
    bool clearClass = false,
    String? coachId,
    String? coachName,
    NumberFlag? flag,
    bool clearFlag = false,
    bool clearAttempted = false,
  }) => ManagedStudent(
    id: id,
    fullName: fullName,
    studentNumber: studentNumber ?? this.studentNumber,
    classroomId: clearClass ? null : classroomId ?? this.classroomId,
    classroomName: clearClass ? null : classroomName ?? this.classroomName,
    coachId: coachId ?? this.coachId,
    coachName: coachName ?? this.coachName,
    flag: clearFlag ? null : flag ?? this.flag,
    attemptedNumber: clearAttempted ? null : attemptedNumber,
    source: source,
  );
}

/// Şüpheli öğrenci: neden(ler)iyle.
class SuspiciousStudent {
  const SuspiciousStudent(this.student, this.reasons);

  final ManagedStudent student;
  final List<String> reasons;
}

/// Serbest kayıtta (ya da listeye geçişte) dikkat edilecek öğrenciler:
/// numara işareti, numarasız, sınıfsız ve adı çok benzeyen kayıtlar.
List<SuspiciousStudent> suspiciousStudents(List<ManagedStudent> students) {
  final norm = {for (final s in students) s.id: normalizeName(s.fullName)};
  final similar = <String, List<String>>{};
  for (var i = 0; i < students.length; i++) {
    for (var j = i + 1; j < students.length; j++) {
      final a = norm[students[i].id]!, b = norm[students[j].id]!;
      if (a.length < 5 || b.length < 5) continue;
      final d = editDistance(a, b);
      if (d <= (a.length > 12 ? 2 : 1)) {
        similar.putIfAbsent(students[i].id, () => []).add(students[j].fullName);
        similar.putIfAbsent(students[j].id, () => []).add(students[i].fullName);
      }
    }
  }
  return [
    for (final s in students)
      if (s.flag != null ||
          s.studentNumber == null ||
          !s.hasClass ||
          similar.containsKey(s.id))
        SuspiciousStudent(s, [
          if (s.flag != null)
            s.flag == NumberFlag.duplicate && s.attemptedNumber != null
                ? tr('{n} numarasını denedi (kullanımda)', {
                    'n': s.attemptedNumber!,
                  })
                : s.flag!.label,
          if (s.studentNumber == null && s.flag != NumberFlag.duplicate)
            tr('Numarası yok'),
          if (!s.hasClass) tr('Sınıfı yok'),
          if (similar[s.id] case final names?)
            tr('Benzer ad: {names}', {'names': names.join(', ')}),
        ]),
  ];
}

abstract interface class StudentManagementRepository {
  /// Yönettiğim öğrenciler (müdür: kurum, koç: kendi öğrencileri).
  Future<List<ManagedStudent>> fetchStudents();

  /// [classroomId] null: sınıftan çıkar.
  Future<void> assignToClass(List<String> studentIds, String? classroomId);

  /// Yalnızca rakam; kullanımdaysa `NUMBER_TAKEN`.
  Future<void> setStudentNumber(String studentId, String? number);
  Future<bool> isNumberAvailable(String studentId, String number);
  Future<void> clearFlag(String studentId);

  /// Yalnızca müdür.
  Future<void> setCoach(String studentId, String coachId);
}

class SupabaseStudentManagementRepository
    implements StudentManagementRepository {
  SupabaseStudentManagementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ManagedStudent>> fetchStudents() async => [
    for (final r in await _client.rpc('managed_students_list') as List)
      ManagedStudent.fromJson(Map<String, dynamic>.from(r as Map)),
  ];

  @override
  Future<void> assignToClass(List<String> studentIds, String? classroomId) =>
      _client.rpc(
        'assign_students_to_class',
        params: {'p_students': studentIds, 'p_classroom': classroomId},
      );

  @override
  Future<void> setStudentNumber(String studentId, String? number) =>
      _client.rpc(
        'set_student_number',
        params: {'p_student': studentId, 'p_number': number},
      );

  @override
  Future<bool> isNumberAvailable(String studentId, String number) async =>
      await _client.rpc(
            'student_number_available',
            params: {'p_student': studentId, 'p_number': number},
          )
          as bool;

  @override
  Future<void> clearFlag(String studentId) =>
      _client.rpc('clear_number_flag', params: {'p_student': studentId});

  @override
  Future<void> setCoach(String studentId, String coachId) => _client.rpc(
    'set_student_coach',
    params: {'p_student': studentId, 'p_coach': coachId},
  );
}

final studentManagementRepositoryProvider =
    Provider<StudentManagementRepository>(
      (ref) => SupabaseStudentManagementRepository(
        ref.watch(supabaseClientProvider),
      ),
    );

final managedStudentsProvider = FutureProvider<List<ManagedStudent>>(
  (ref) => ref.watch(studentManagementRepositoryProvider).fetchStudents(),
);
