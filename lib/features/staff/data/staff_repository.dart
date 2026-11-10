import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';

/// Görev.
enum StaffJob {
  teacher('teacher'),
  coach('coach'),
  assistantManager('assistant_manager'),
  guidance('guidance'),
  secretary('secretary'),
  accounting('accounting'),
  cleaning('cleaning'),
  security('security'),
  other('other');

  const StaffJob(this.db);

  final String db;

  static StaffJob fromDb(String? v) => StaffJob.values.firstWhere(
    (j) => j.db == v,
    orElse: () => StaffJob.other,
  );

  String get label => switch (this) {
    StaffJob.teacher => tr('Öğretmen'),
    StaffJob.coach => tr('Koç'),
    StaffJob.assistantManager => tr('Müdür yardımcısı'),
    StaffJob.guidance => tr('Rehber öğretmen'),
    StaffJob.secretary => tr('Sekreter'),
    StaffJob.accounting => tr('Muhasebe'),
    StaffJob.cleaning => tr('Temizlik'),
    StaffJob.security => tr('Güvenlik'),
    StaffJob.other => tr('Diğer'),
  };
}

/// Çalışma şekli.
enum StaffEmployment {
  full('full'),
  part('part'),
  hourly('hourly');

  const StaffEmployment(this.db);

  final String db;

  static StaffEmployment fromDb(String? v) => StaffEmployment.values.firstWhere(
    (e) => e.db == v,
    orElse: () => StaffEmployment.full,
  );

  String get label => switch (this) {
    StaffEmployment.full => tr('Tam zamanlı'),
    StaffEmployment.part => tr('Yarı zamanlı'),
    StaffEmployment.hourly => tr('Ders saati ücretli'),
  };
}

enum LeaveKind {
  annual('annual'),
  sick('sick'),
  unpaid('unpaid'),
  excuse('excuse'),
  other('other');

  const LeaveKind(this.db);

  final String db;

  static LeaveKind fromDb(String? v) => LeaveKind.values.firstWhere(
    (k) => k.db == v,
    orElse: () => LeaveKind.other,
  );

  String get label => switch (this) {
    LeaveKind.annual => tr('Yıllık izin'),
    LeaveKind.sick => tr('Raporlu'),
    LeaveKind.unpaid => tr('Ücretsiz izin'),
    LeaveKind.excuse => tr('Mazeret izni'),
    LeaveKind.other => tr('Diğer'),
  };
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

String? _ymd(DateTime? d) => d == null
    ? null
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

/// Çalışan kartı. Kimlik numarası bilerek tutulmaz (KVKK).
class StaffMember {
  const StaffMember({
    this.id = '',
    required this.fullName,
    this.job = StaffJob.other,
    this.employment = StaffEmployment.full,
    this.phone,
    this.email,
    this.startOn,
    this.endOn,
    this.monthlySalary = 0,
    this.annualLeaveDays = 14,
    this.emergencyName,
    this.emergencyPhone,
    this.note,
    this.profileId,
    this.teacherId,
  });

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
    id: j['id'] as String,
    fullName: j['full_name'] as String,
    job: StaffJob.fromDb(j['job'] as String?),
    employment: StaffEmployment.fromDb(j['employment'] as String?),
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    startOn: _date(j['start_on']),
    endOn: _date(j['end_on']),
    monthlySalary: (j['monthly_salary'] as num? ?? 0).toDouble(),
    annualLeaveDays: j['annual_leave_days'] as int? ?? 14,
    emergencyName: j['emergency_name'] as String?,
    emergencyPhone: j['emergency_phone'] as String?,
    note: j['note'] as String?,
    profileId: j['profile_id'] as String?,
    teacherId: j['teacher_id'] as String?,
  );

  final String id;
  final String fullName;
  final StaffJob job;
  final StaffEmployment employment;
  final String? phone;
  final String? email;
  final DateTime? startOn;

  /// İşten ayrılış günü; o günden sonra ayrılmış sayılır, kayıt kalır.
  final DateTime? endOn;
  final double monthlySalary;
  final int annualLeaveDays;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? note;

  /// Koç hesabı ya da ders programındaki öğretmen bağlantısı.
  final String? profileId;
  final String? teacherId;

  bool isActive(DateTime today) => endOn == null || !endOn!.isBefore(today);

  Map<String, dynamic> toRow() => {
    'full_name': fullName,
    'job': job.db,
    'employment': employment.db,
    'phone': phone,
    'email': email,
    'start_on': _ymd(startOn),
    'end_on': _ymd(endOn),
    'monthly_salary': monthlySalary,
    'annual_leave_days': annualLeaveDays,
    'emergency_name': emergencyName,
    'emergency_phone': emergencyPhone,
    'note': note,
    'profile_id': profileId,
    'teacher_id': teacherId,
  };
}

class StaffLeave {
  const StaffLeave({
    this.id = '',
    required this.staffId,
    this.kind = LeaveKind.annual,
    required this.startOn,
    required this.endOn,
    this.note,
  });

  factory StaffLeave.fromJson(Map<String, dynamic> j) => StaffLeave(
    id: j['id'] as String,
    staffId: j['staff_id'] as String,
    kind: LeaveKind.fromDb(j['kind'] as String?),
    startOn: DateTime.parse(j['start_on'] as String),
    endOn: DateTime.parse(j['end_on'] as String),
    note: j['note'] as String?,
  );

  final String id;
  final String staffId;
  final LeaveKind kind;
  final DateTime startOn;
  final DateTime endOn;
  final String? note;

  int get days => endOn.difference(startOn).inDays + 1;

  bool covers(DateTime day) => !day.isBefore(startOn) && !day.isAfter(endOn);

  /// Bu iznin verilen yıla düşen gün sayısı (yıl sonunu aşan izin için).
  int daysInYear(int year) {
    final from = startOn.isBefore(DateTime(year)) ? DateTime(year) : startOn;
    final to = endOn.isAfter(DateTime(year, 12, 31))
        ? DateTime(year, 12, 31)
        : endOn;
    return to.isBefore(from) ? 0 : to.difference(from).inDays + 1;
  }
}

/// O yıl kullanılan yıllık izin günü.
int annualLeaveUsed(Iterable<StaffLeave> leaves, String staffId, int year) =>
    leaves
        .where((l) => l.staffId == staffId && l.kind == LeaveKind.annual)
        .fold(0, (s, l) => s + l.daysInYear(year));

/// Personel listesinin bir satırı: kartı olan çalışan, kartı henüz açılmamış koç
/// ya da ders programındaki öğretmen. [key] adreste kullanılır.
class PersonnelEntry {
  const PersonnelEntry({
    required this.key,
    required this.name,
    required this.job,
    this.staff,
    this.coachId,
    this.teacherId,
    this.branches = const {},
  });

  final String key;
  final String name;
  final StaffJob job;
  final StaffMember? staff;
  final String? coachId;
  final String? teacherId;
  final Set<String> branches;

  bool isActive(DateTime today) => staff?.isActive(today) ?? true;
}

/// Ders programındaki öğretmenin personel listesi için gereken kısmı.
class TeacherRef {
  const TeacherRef({
    required this.id,
    required this.name,
    this.profileId,
    this.branches = const {},
  });

  final String id;
  final String name;
  final String? profileId;
  final Set<String> branches;
}

/// Kartlar, koçlar ve öğretmenler tek listede: aynı kişi iki kez çıkmaz (koç
/// hesabına bağlı öğretmen ve karta bağlı koç / öğretmen birleşir).
List<PersonnelEntry> mergePersonnel({
  required List<StaffMember> staff,
  required Map<String, String> coaches,
  required List<TeacherRef> teachers,
}) {
  final teacherOfCoach = {
    for (final t in teachers)
      if (t.profileId != null) t.profileId!: t,
  };
  final byTeacher = {for (final t in teachers) t.id: t};
  final usedCoach = <String>{};
  final usedTeacher = <String>{};
  final out = <PersonnelEntry>[];
  for (final s in staff) {
    var teacher = byTeacher[s.teacherId];
    final coachId = coaches.containsKey(s.profileId)
        ? s.profileId
        : teacher?.profileId;
    teacher ??= teacherOfCoach[coachId];
    if (coachId != null) usedCoach.add(coachId);
    if (teacher != null) usedTeacher.add(teacher.id);
    out.add(
      PersonnelEntry(
        key: 's_${s.id}',
        name: s.fullName,
        job: s.job,
        staff: s,
        coachId: coachId,
        teacherId: teacher?.id,
        branches: teacher?.branches ?? const {},
      ),
    );
  }
  for (final e in coaches.entries) {
    if (usedCoach.contains(e.key)) continue;
    final teacher = teacherOfCoach[e.key];
    if (teacher != null) usedTeacher.add(teacher.id);
    out.add(
      PersonnelEntry(
        key: 'c_${e.key}',
        name: e.value,
        job: StaffJob.coach,
        coachId: e.key,
        teacherId: teacher?.id,
        branches: teacher?.branches ?? const {},
      ),
    );
  }
  for (final t in teachers) {
    if (usedTeacher.contains(t.id)) continue;
    out.add(
      PersonnelEntry(
        key: 't_${t.id}',
        name: t.name,
        job: StaffJob.teacher,
        teacherId: t.id,
        branches: t.branches,
      ),
    );
  }
  return out..sort((a, b) => a.name.compareTo(b.name));
}

abstract interface class StaffRepository {
  Future<List<StaffMember>> fetchStaff();

  /// Yeni kartta `id` boştur; kartın kimliğini döner.
  Future<String> saveStaff(StaffMember member);
  Future<void> deleteStaff(String id);

  /// Kurumdaki bütün izinler, en yeni önce.
  Future<List<StaffLeave>> fetchLeaves();
  Future<void> addLeave(StaffLeave leave);
  Future<void> deleteLeave(String id);
}

class SupabaseStaffRepository implements StaffRepository {
  SupabaseStaffRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StaffMember>> fetchStaff() async => [
    for (final r
        in await _client
            .from('staff_members')
            .select(
              'id, full_name, job, employment, phone, email, start_on, end_on, '
              'monthly_salary, annual_leave_days, emergency_name, emergency_phone, '
              'note, profile_id, teacher_id',
            )
            .order('full_name'))
      StaffMember.fromJson(r),
  ];

  @override
  Future<String> saveStaff(StaffMember m) async {
    if (m.id.isEmpty) {
      final row = await _client
          .from('staff_members')
          .insert(m.toRow())
          .select('id')
          .single();
      return row['id'] as String;
    }
    await _client.from('staff_members').update(m.toRow()).eq('id', m.id);
    return m.id;
  }

  @override
  Future<void> deleteStaff(String id) =>
      _client.from('staff_members').delete().eq('id', id);

  @override
  Future<List<StaffLeave>> fetchLeaves() async => [
    for (final r
        in await _client
            .from('staff_leaves')
            .select('id, staff_id, kind, start_on, end_on, note')
            .order('start_on', ascending: false))
      StaffLeave.fromJson(r),
  ];

  @override
  Future<void> addLeave(StaffLeave l) => _client.from('staff_leaves').insert({
    'staff_id': l.staffId,
    'kind': l.kind.db,
    'start_on': _ymd(l.startOn),
    'end_on': _ymd(l.endOn),
    'note': l.note,
  });

  @override
  Future<void> deleteLeave(String id) =>
      _client.from('staff_leaves').delete().eq('id', id);
}

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => SupabaseStaffRepository(ref.watch(supabaseClientProvider)),
);

final staffMembersProvider = FutureProvider<List<StaffMember>>(
  (ref) => ref.watch(staffRepositoryProvider).fetchStaff(),
);

final staffLeavesProvider = FutureProvider<List<StaffLeave>>(
  (ref) => ref.watch(staffRepositoryProvider).fetchLeaves(),
);
