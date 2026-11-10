import '../features/staff/data/staff_repository.dart';
import 'demo_rich.dart';

/// Bellekte personel (demo ve testler için). Sunucudaki kurallarla: aynı kişide
/// izin tarihleri çakışamaz, bir koç / öğretmene tek kart bağlanır.
class InMemoryStaffRepository implements StaffRepository {
  InMemoryStaffRepository({
    List<StaffMember> staff = const [],
    List<StaffLeave> leaves = const [],
  }) : _staff = [...staff],
       _leaves = [...leaves];

  final List<StaffMember> _staff;
  final List<StaffLeave> _leaves;
  int _id = 0;

  /// Karttaki ad (finans deposu personel ödemesinde adı buradan yazar).
  String? nameOf(String id) =>
      _staff.where((s) => s.id == id).firstOrNull?.fullName;

  /// Maaşı olan çalışanlar: kimlik → maaş (demo ödemeleri için).
  Map<String, double> salaries() => {
    for (final s in _staff)
      if (s.monthlySalary > 0 && s.endOn == null) s.id: s.monthlySalary,
  };

  /// Demo kurumu: koç / öğretmen dışındaki çalışanlar, koçlardan birinin kartı
  /// ve bu yılın izinleri (biri bugün izinde).
  factory InMemoryStaffRepository.demo({DateTime? now}) {
    final t = now ?? DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    final repo = InMemoryStaffRepository(
      staff: [
        StaffMember(
          id: 'staff-hale',
          fullName: 'Hale Yurt',
          job: StaffJob.secretary,
          phone: '+905550002001',
          email: 'hale@balakademi.example',
          startOn: DateTime(today.year - 2, 9, 1),
          monthlySalary: 24000,
          annualLeaveDays: 14,
          emergencyName: 'Kemal Yurt',
          emergencyPhone: '+905550002002',
        ),
        StaffMember(
          id: 'staff-sevim',
          fullName: 'Sevim Taş',
          job: StaffJob.cleaning,
          employment: StaffEmployment.part,
          phone: '+905550002003',
          startOn: DateTime(today.year - 1, 2, 15),
          monthlySalary: 12000,
        ),
        StaffMember(
          id: 'staff-ayse',
          fullName: 'Ayşe Koç',
          job: StaffJob.coach,
          phone: '+905321112233',
          startOn: DateTime(today.year - 3, 8, 20),
          annualLeaveDays: 20,
          profileId: 'demo-coach',
        ),
        if (demoRichEnabled) ...[
          StaffMember(
            id: 'staff-tolga',
            fullName: 'Tolga Sarı',
            job: StaffJob.assistantManager,
            phone: '+905550002004',
            startOn: DateTime(today.year - 4, 8, 1),
            monthlySalary: 30000,
            annualLeaveDays: 20,
          ),
          StaffMember(
            id: 'staff-pinar',
            fullName: 'Pınar Uslu',
            job: StaffJob.guidance,
            phone: '+905550002005',
            startOn: DateTime(today.year - 2, 8, 15),
            monthlySalary: 26000,
          ),
          StaffMember(
            id: 'staff-nuri',
            fullName: 'Nuri Bozkurt',
            job: StaffJob.security,
            phone: '+905550002006',
            startOn: DateTime(today.year - 1, 9, 1),
            monthlySalary: 18000,
          ),
          StaffMember(
            id: 'staff-gamze',
            fullName: 'Gamze Tuna',
            job: StaffJob.accounting,
            employment: StaffEmployment.part,
            phone: '+905550002007',
            startOn: DateTime(today.year - 3, 1, 10),
            endOn: DateTime(today.year, today.month - 1, 28),
            monthlySalary: 18000,
            note: 'Ayrıldı; devir teslim yapıldı.',
          ),
        ],
      ],
    );
    repo._leaves.addAll([
      StaffLeave(
        id: 'leave-1',
        staffId: 'staff-hale',
        startOn: DateTime(today.year, 7, 7),
        endOn: DateTime(today.year, 7, 11),
      ),
      StaffLeave(
        id: 'leave-2',
        staffId: 'staff-sevim',
        kind: LeaveKind.sick,
        startOn: today.subtract(const Duration(days: 1)),
        endOn: today.add(const Duration(days: 1)),
      ),
      StaffLeave(
        id: 'leave-3',
        staffId: 'staff-ayse',
        kind: LeaveKind.excuse,
        startOn: DateTime(today.year, 3, 2),
        endOn: DateTime(today.year, 3, 2),
      ),
    ]);
    return repo;
  }

  @override
  Future<List<StaffMember>> fetchStaff() async =>
      [..._staff]..sort((a, b) => a.fullName.compareTo(b.fullName));

  @override
  Future<String> saveStaff(StaffMember m) async {
    final id = m.id.isEmpty ? 'staff-${_id++}' : m.id;
    if (_staff.any(
      (s) =>
          s.id != id &&
          ((m.profileId != null && s.profileId == m.profileId) ||
              (m.teacherId != null && s.teacherId == m.teacherId)),
    )) {
      throw StateError('STAFF_BAD_REF');
    }
    final next = StaffMember(
      id: id,
      fullName: m.fullName.trim(),
      job: m.job,
      employment: m.employment,
      phone: m.phone,
      email: m.email,
      startOn: m.startOn,
      endOn: m.endOn,
      monthlySalary: m.monthlySalary,
      annualLeaveDays: m.annualLeaveDays,
      emergencyName: m.emergencyName,
      emergencyPhone: m.emergencyPhone,
      note: m.note,
      profileId: m.profileId,
      teacherId: m.teacherId,
    );
    final i = _staff.indexWhere((s) => s.id == id);
    if (i < 0) {
      _staff.add(next);
    } else {
      _staff[i] = next;
    }
    return id;
  }

  @override
  Future<void> deleteStaff(String id) async {
    _staff.removeWhere((s) => s.id == id);
    _leaves.removeWhere((l) => l.staffId == id);
  }

  @override
  Future<List<StaffLeave>> fetchLeaves() async =>
      [..._leaves]..sort((a, b) => b.startOn.compareTo(a.startOn));

  @override
  Future<void> addLeave(StaffLeave l) async {
    if (l.endOn.isBefore(l.startOn)) throw StateError('check');
    if (_leaves.any(
      (x) =>
          x.staffId == l.staffId &&
          !x.startOn.isAfter(l.endOn) &&
          !x.endOn.isBefore(l.startOn),
    )) {
      throw StateError('STAFF_LEAVE_OVERLAP');
    }
    _leaves.add(
      StaffLeave(
        id: 'leave-n${_id++}',
        staffId: l.staffId,
        kind: l.kind,
        startOn: l.startOn,
        endOn: l.endOn,
        note: l.note,
      ),
    );
  }

  @override
  Future<void> deleteLeave(String id) async =>
      _leaves.removeWhere((l) => l.id == id);
}
