import '../features/attendance/data/attendance_repository.dart';

/// Bellekte tutulan yoklama (demo ve testler için). Sunucudaki kuralları
/// taklit eder: son 30 gün, aynı öğrenciye aynı gün bir SMS.
class InMemoryAttendanceRepository implements AttendanceRepository {
  InMemoryAttendanceRepository({
    required this.students,
    Map<String, (String?, String)> phones = const {},
    this.fallbackPhones = const {},
  }) : _phones = {...phones};

  /// Öğrenci kimliği → ad.
  final Map<String, String> students;

  /// Kurum finansında velisinin telefonu olan öğrenciler (koça gösterilmez).
  final Set<String> fallbackPhones;

  /// Öğrenci → (veli adı, telefon).
  final Map<String, (String?, String)> _phones;
  final _marks = <(String, String), AttendanceStatus>{};
  final _sms = <(String, String), DateTime>{};

  /// Sıraya alınan SMS'ler (telefon, metin) — testler için.
  final sentSms = <(String, String)>[];

  /// Demo: ilk öğrencinin velisinin telefonu var, dün yoklama alınmış.
  factory InMemoryAttendanceRepository.demo({
    required Map<String, String> students,
    DateTime? now,
  }) {
    final repo = InMemoryAttendanceRepository(
      students: students,
      phones: {
        if (students.isNotEmpty)
          students.keys.first: ('Selin Yılmaz', '+905321234567'),
      },
      fallbackPhones: students.keys.skip(1).take(1).toSet(),
    );
    final t = now ?? DateTime.now();
    final y = attendanceDay(DateTime(t.year, t.month, t.day - 1));
    var i = 0;
    for (final id in students.keys) {
      repo._marks[(id, y)] = i++ == 2
          ? AttendanceStatus.absent
          : AttendanceStatus.present;
    }
    return repo;
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Future<List<AttendanceRow>> fetchDay(DateTime day) async {
    final d = attendanceDay(day);
    final rows = [
      for (final e in students.entries)
        AttendanceRow(
          studentId: e.key,
          fullName: e.value,
          status: _marks[(e.key, d)],
          smsAt: _sms[(e.key, d)],
          hasPhone:
              _phones.containsKey(e.key) || fallbackPhones.contains(e.key),
          guardianName: _phones[e.key]?.$1,
          guardianPhone: _phones[e.key]?.$2,
        ),
    ]..sort((a, b) => a.fullName.compareTo(b.fullName));
    return rows;
  }

  @override
  Future<void> save(DateTime day, Map<String, AttendanceStatus?> marks) async {
    final today = _today();
    final d = DateTime(day.year, day.month, day.day);
    if (d.isAfter(today) || today.difference(d).inDays > 30) {
      throw StateError('ATTENDANCE_BAD_DATE');
    }
    final key = attendanceDay(d);
    for (final e in marks.entries) {
      if (!students.containsKey(e.key)) {
        throw StateError('ATTENDANCE_NOT_MANAGER');
      }
      final v = e.value;
      if (v == null) {
        _marks.remove((e.key, key));
      } else {
        _marks[(e.key, key)] = v;
      }
    }
  }

  @override
  Future<void> setGuardianPhone(
    String studentId, {
    String? name,
    String? phone,
  }) async {
    if (!students.containsKey(studentId)) {
      throw StateError('ATTENDANCE_NOT_MANAGER');
    }
    if (phone == null || phone.isEmpty) {
      _phones.remove(studentId);
    } else {
      final n = name?.trim();
      _phones[studentId] = (n == null || n.isEmpty ? null : n, phone);
    }
  }

  @override
  Future<AbsenceSmsResult> sendAbsenceSms(
    DateTime day,
    List<String> studentIds,
  ) async {
    final d = attendanceDay(day);
    var queued = 0, noPhone = 0, skipped = 0;
    for (final id in studentIds) {
      if (!students.containsKey(id)) {
        throw StateError('ATTENDANCE_NOT_MANAGER');
      }
      if (_marks[(id, d)] != AttendanceStatus.absent ||
          _sms.containsKey((id, d))) {
        skipped++;
        continue;
      }
      final phone =
          _phones[id]?.$2 ??
          (fallbackPhones.contains(id) ? '+905550000000' : null);
      if (phone == null) {
        noPhone++;
        continue;
      }
      _sms[(id, d)] = DateTime.now();
      sentSms.add((phone, '${students[id]} $d'));
      queued++;
    }
    return AbsenceSmsResult(queued: queued, noPhone: noPhone, skipped: skipped);
  }
}
