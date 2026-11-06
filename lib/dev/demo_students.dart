import '../features/student_management/data/student_management_repository.dart';
import '../features/student_registration/data/registration_repository.dart';
import 'demo_timetable.dart';

/// Bellekte öğrenci yönetimi (demo ve testler). Sınıf üyeliği ders programı
/// deposuyla ortak; atama öğrencinin programına da yansır.
class InMemoryStudentManagementRepository
    implements StudentManagementRepository {
  InMemoryStudentManagementRepository({
    required this.timetable,
    required Map<String, (String, String?)> students,
    Map<String, String> coachOf = const {},
    this.coaches = const {},
    Map<String, NumberFlag> flags = const {},
    this.isAdmin = true,
  }) : _students = {...students},
       _coachOf = {...coachOf},
       _flags = {...flags};

  final InMemoryTimetableRepository timetable;

  /// Koç kimliği → ad.
  final Map<String, String> coaches;
  final bool isAdmin;

  /// Öğrenci → (ad, numara).
  final Map<String, (String, String?)> _students;
  final Map<String, String> _coachOf;
  final Map<String, NumberFlag> _flags;
  final _attempted = <String, String>{};

  /// Numara değişiklikleri (öğrenci, eski, yeni) — testler için.
  final numberHistory = <(String, String?, String?)>[];

  @override
  Future<List<ManagedStudent>> fetchStudents() async {
    final out = [
      for (final e in _students.entries)
        ManagedStudent(
          id: e.key,
          fullName: e.value.$1,
          studentNumber: e.value.$2,
          classroomId: timetable.classOf(e.key)?.$1,
          classroomName: timetable.classOf(e.key)?.$2,
          coachId: _coachOf[e.key],
          coachName: coaches[_coachOf[e.key]],
          flag: _flags[e.key],
          attemptedNumber: _attempted[e.key],
        ),
    ]..sort((a, b) => a.fullName.compareTo(b.fullName));
    return out;
  }

  void _check(String id) {
    if (!_students.containsKey(id)) throw StateError('NOT_ALLOWED');
  }

  @override
  Future<void> assignToClass(
    List<String> studentIds,
    String? classroomId,
  ) async {
    if (classroomId != null) {
      final setup = await timetable.fetchSetup();
      final c = setup.classrooms
          .where((x) => x.classroom.id == classroomId)
          .firstOrNull;
      if (c == null || !c.active) throw StateError('TIMETABLE_BAD_REF');
    }
    for (final s in studentIds) {
      _check(s);
      timetable.moveStudent(s, classroomId);
    }
  }

  @override
  Future<void> setStudentNumber(String studentId, String? number) async {
    _check(studentId);
    final n = number?.replaceAll(RegExp(r'\s'), '');
    if (n != null && n.isNotEmpty && !isValidStudentNumber(n)) {
      throw StateError('INVALID_NUMBER');
    }
    if (n != null &&
        _students.entries.any((e) => e.key != studentId && e.value.$2 == n)) {
      throw StateError('NUMBER_TAKEN');
    }
    final old = _students[studentId]!;
    final next = (n == null || n.isEmpty) ? null : n;
    _students[studentId] = (old.$1, next);
    if (old.$2 != next) numberHistory.add((studentId, old.$2, next));
    if (next != null && _flags[studentId] != NumberFlag.notInList) {
      _flags.remove(studentId);
      _attempted.remove(studentId);
    }
  }

  @override
  Future<bool> isNumberAvailable(String studentId, String number) async =>
      !_students.entries.any((e) => e.key != studentId && e.value.$2 == number);

  @override
  Future<void> clearFlag(String studentId) async {
    _check(studentId);
    _flags.remove(studentId);
    _attempted.remove(studentId);
  }

  @override
  Future<void> setCoach(String studentId, String coachId) async {
    if (!isAdmin) throw StateError('NOT_ALLOWED');
    _check(studentId);
    _coachOf[studentId] = coachId;
  }
}

/// Bellekte kayıt modu ve beklenen öğrenci listesi.
class InMemoryRegistrationRepository implements RegistrationRepository {
  InMemoryRegistrationRepository({
    this.mode = RegistrationMode.free,
    List<ExpectedStudent> expected = const [],
  }) : _expected = {for (final e in expected) e.number: e};

  RegistrationMode mode;
  final Map<String, ExpectedStudent> _expected;

  @override
  Future<RegistrationMode> fetchMode() async => mode;

  @override
  Future<void> setMode(RegistrationMode mode) async => this.mode = mode;

  @override
  Future<List<ExpectedStudent>> fetchExpected() async =>
      _expected.values.toList()..sort((a, b) => a.number.compareTo(b.number));

  @override
  Future<ImportResult> importExpected(
    List<ExpectedStudent> rows, {
    bool replace = false,
  }) async {
    var ins = 0, upd = 0, del = 0;
    final numbers = {for (final r in rows) r.number};
    for (final r in rows) {
      if (!isValidStudentNumber(r.number) || r.fullName.trim().length < 2) {
        throw StateError('BAD_ROW ${r.number}');
      }
      final old = _expected[r.number];
      old == null ? ins++ : upd++;
      _expected[r.number] = ExpectedStudent(
        number: r.number,
        fullName: r.fullName,
        className: r.className,
        guardianPhone: r.guardianPhone,
        matched: old?.matched ?? false,
      );
    }
    if (replace) {
      final gone = [
        for (final e in _expected.values)
          if (!e.matched && !numbers.contains(e.number)) e.number,
      ];
      for (final n in gone) {
        _expected.remove(n);
      }
      del = gone.length;
    }
    return ImportResult(inserted: ins, updated: upd, removed: del);
  }
}
