import '../features/schedule_generator/data/timetable_repository.dart';
import '../features/schedule_generator/domain/models.dart';
import '../features/schedule_generator/domain/schedule_generator.dart';
import 'demo_rich.dart';

class _Schedule {
  _Schedule(this.info, this.entries);

  ScheduleInfo info;
  List<ScheduleEntry> entries;
}

/// Bellekte tutulan ders programı (demo ve testler için).
///
/// [viewerId] / [viewerRole]: `myTimetable` kimin gözünden (öğretmen:
/// profile_id eşleşmesi, öğrenci: sınıfı, veli: [children]).
class InMemoryTimetableRepository implements TimetableRepository {
  InMemoryTimetableRepository({
    TimetableSetup setup = const TimetableSetup(),
    this.viewerId = 'demo-admin',
    this.viewerRole = 'admin',
    this.children = const [],
  }) : _slots = [...setup.slots],
       _teachers = [...setup.teachers],
       _rooms = [...setup.rooms],
       _classrooms = [...setup.classrooms],
       _lessons = [...setup.lessons];

  final String viewerId;
  final String viewerRole;
  final List<String> children;

  List<TimeSlot> _slots;
  final List<TeacherRecord> _teachers;
  final List<Room> _rooms;
  final List<ClassroomRecord> _classrooms;
  List<ClassLesson> _lessons;
  final _schedules = <_Schedule>[];
  int _id = 0;

  String _next(String p) => '$p-${_id++}';

  /// Öğretmenler: kimlik → ad (demo finans aynı öğretmenlere ödeme yazar).
  Map<String, String> get teacherNames => {
    for (final t in _teachers) t.teacher.id: t.teacher.name,
  };

  /// Demo kurumu: 6 gün × 6 ders saati, 6 öğretmen (biri demo koç
  /// hesabına bağlı), 3 sınıf, 3 derslik ve yayında bir program.
  factory InMemoryTimetableRepository.demo({
    String viewerId = 'demo-admin',
    String viewerRole = 'admin',
    List<String> children = const ['demo-student'],
  }) {
    final slots = [
      for (var d = 1; d <= 6; d++)
        for (var k = 1; k <= 6; k++)
          TimeSlot(
            id: 'slot-$d-$k',
            day: d,
            seq: k,
            start: 9 * 60 + (k - 1) * 50,
            end: 9 * 60 + (k - 1) * 50 + 40,
          ),
    ];
    const mornings = [
      AvailabilityRange(day: 1, start: 9 * 60, end: 13 * 60),
      AvailabilityRange(day: 2, start: 9 * 60, end: 13 * 60),
      AvailabilityRange(day: 3, start: 9 * 60, end: 13 * 60),
      AvailabilityRange(day: 4, start: 9 * 60, end: 13 * 60),
      AvailabilityRange(day: 5, start: 9 * 60, end: 13 * 60),
      AvailabilityRange(day: 6, start: 9 * 60, end: 13 * 60),
    ];
    const teachers = [
      TeacherRecord(
        Teacher(
          id: 't-ahmet',
          name: 'Ahmet Kaya',
          branches: {'Matematik', 'Geometri'},
          maxWeeklyHours: 24,
        ),
      ),
      TeacherRecord(
        Teacher(
          id: 't-ayse',
          name: 'Ayşe Koç',
          branches: {'Türkçe', 'Edebiyat'},
          maxWeeklyHours: 24,
        ),
        profileId: 'demo-coach',
      ),
      TeacherRecord(
        Teacher(
          id: 't-mehmet',
          name: 'Mehmet Arslan',
          branches: {'Fizik'},
          maxWeeklyHours: 16,
          availability: mornings,
        ),
        // Öğretmen hesabıyla kayıt olmuş (demo öğretmen paneli).
        profileId: 'demo-teacher',
      ),
      TeacherRecord(
        Teacher(
          id: 't-zeynep',
          name: 'Zeynep Şahin',
          branches: {'Kimya', 'Biyoloji'},
          maxWeeklyHours: 20,
        ),
      ),
      TeacherRecord(
        Teacher(
          id: 't-can',
          name: 'Can Yurt',
          branches: {'Tarih', 'Coğrafya'},
          maxWeeklyHours: 20,
        ),
      ),
      TeacherRecord(
        Teacher(
          id: 't-elif',
          name: 'Elif Demir',
          branches: {'Matematik'},
          maxWeeklyHours: 20,
        ),
      ),
    ];
    const rooms = [
      Room(id: 'r-1', name: 'D-1', capacity: 20),
      Room(id: 'r-2', name: 'D-2', capacity: 20),
      Room(id: 'r-3', name: 'D-3', capacity: 20),
    ];
    // Kalabalık demoda öğrenciler sınıflarına dağılır.
    List<String> classOfRich(String classroomId) => [
      if (demoRichEnabled)
        for (final s in [richZeynep, ...richStudents])
          if (s.classroomId == classroomId) s.id,
    ];
    final classrooms = [
      ClassroomRecord(
        const Classroom(id: 'c-say', name: 'Sayısal-1', homeRoomId: 'r-1'),
        level: '12',
        field: 'SAY',
        studentIds: ['demo-student', 'demo-can', ...classOfRich('c-say')],
      ),
      ClassroomRecord(
        const Classroom(id: 'c-ea', name: 'Eşit Ağırlık-1', homeRoomId: 'r-2'),
        level: '12',
        field: 'EA',
        studentIds: classOfRich('c-ea'),
      ),
      ClassroomRecord(
        const Classroom(id: 'c-soz', name: 'Sözel-1', homeRoomId: 'r-3'),
        level: 'graduate',
        field: 'SOZ',
        studentIds: classOfRich('c-soz'),
      ),
    ];
    var n = 0;
    ClassLesson l(String c, String b, int h, [String? t]) => ClassLesson(
      id: 'l-${n++}',
      classroomId: c,
      branch: b,
      weeklyHours: h,
      teacherId: t,
    );
    final lessons = [
      l('c-say', 'Matematik', 6, 't-ahmet'),
      l('c-say', 'Geometri', 2, 't-ahmet'),
      l('c-say', 'Fizik', 4),
      l('c-say', 'Kimya', 3),
      l('c-say', 'Biyoloji', 3),
      l('c-say', 'Türkçe', 3),
      l('c-ea', 'Matematik', 6),
      l('c-ea', 'Edebiyat', 4),
      l('c-ea', 'Tarih', 3),
      l('c-ea', 'Coğrafya', 3),
      l('c-ea', 'Türkçe', 3),
      l('c-soz', 'Edebiyat', 4),
      l('c-soz', 'Tarih', 4),
      l('c-soz', 'Coğrafya', 4),
      l('c-soz', 'Türkçe', 3),
    ];
    final setup = TimetableSetup(
      slots: slots,
      teachers: teachers,
      rooms: rooms,
      classrooms: classrooms,
      lessons: lessons,
    );
    final repo = InMemoryTimetableRepository(
      setup: setup,
      viewerId: viewerId,
      viewerRole: viewerRole,
      children: children,
    );
    final result = ScheduleGenerator.generate(setup.toInput(timeLimitMs: 400));
    repo._schedules.add(
      _Schedule(
        ScheduleInfo(
          id: 'sch-demo',
          name: 'Güz dönemi',
          term: '2026-2027',
          published: true,
          softScore: result.softScore,
          createdAt: DateTime(2026, 9, 1),
        ),
        result.entries,
      ),
    );
    return repo;
  }

  @override
  Future<TimetableSetup> fetchSetup() async => TimetableSetup(
    slots: [..._slots],
    teachers: [..._teachers],
    rooms: [..._rooms],
    classrooms: [..._classrooms],
    lessons: [..._lessons],
  );

  @override
  Future<void> saveTimeSlots(List<TimeSlot> slots) async {
    final byKey = {for (final s in _slots) '${s.day}|${s.seq}': s.id};
    _slots = [
      for (final s in slots)
        TimeSlot(
          id: byKey['${s.day}|${s.seq}'] ?? _next('slot'),
          day: s.day,
          seq: s.seq,
          start: s.start,
          end: s.end,
        ),
    ];
    final ids = {for (final s in _slots) s.id};
    for (final sch in _schedules) {
      sch.entries = [
        for (final e in sch.entries)
          if (ids.contains(e.timeSlotId)) e,
      ];
    }
  }

  @override
  Future<String> saveTeacher(Teacher teacher, {String? profileId}) async {
    final id = teacher.id.isEmpty ? _next('teacher') : teacher.id;
    final rec = TeacherRecord(
      Teacher(
        id: id,
        name: teacher.name.trim(),
        branches: teacher.branches,
        maxWeeklyHours: teacher.maxWeeklyHours,
        availability: teacher.availability,
      ),
      profileId: profileId,
    );
    final i = _teachers.indexWhere((t) => t.teacher.id == id);
    i < 0 ? _teachers.add(rec) : _teachers[i] = rec;
    return id;
  }

  @override
  Future<void> deleteTeacher(String id) async {
    _teachers.removeWhere((t) => t.teacher.id == id);
    _lessons = [
      for (final l in _lessons)
        l.teacherId == id
            ? ClassLesson(
                id: l.id,
                classroomId: l.classroomId,
                branch: l.branch,
                weeklyHours: l.weeklyHours,
                maxPerDay: l.maxPerDay,
              )
            : l,
    ];
    for (final s in _schedules) {
      s.entries.removeWhere((e) => e.teacherId == id);
    }
  }

  /// Öğretmen hesabının kaydı (`my_teacher()` gibi).
  TeacherRecord? teacherOf(String profileId) =>
      _teachers.where((t) => t.profileId == profileId).firstOrNull;

  /// Öğretmenin branşlarını değiştirir (`set_my_teacher_branches`).
  void setBranches(String profileId, Set<String> branches) {
    final i = _teachers.indexWhere((t) => t.profileId == profileId);
    if (i < 0) throw StateError('NOT_ALLOWED');
    final t = _teachers[i].teacher;
    _teachers[i] = TeacherRecord(
      Teacher(
        id: t.id,
        name: t.name,
        branches: branches,
        maxWeeklyHours: t.maxWeeklyHours,
        availability: t.availability,
      ),
      profileId: profileId,
    );
  }

  /// `merge_teachers`: [fromId]'nin (hesaplı) dersleri [keepId]'ye
  /// (hesapsız) geçer, [keepId] hesaba bağlanır, [fromId] silinir.
  void mergeTeachers(String keepId, String fromId) {
    final ki = _teachers.indexWhere((t) => t.teacher.id == keepId);
    final fi = _teachers.indexWhere((t) => t.teacher.id == fromId);
    if (ki < 0 || fi < 0 || keepId == fromId) throw StateError('NOT_ALLOWED');
    final keep = _teachers[ki];
    final from = _teachers[fi];
    if (keep.profileId != null || from.profileId == null) {
      throw StateError('TEACHER_MERGE_BAD_PAIR');
    }
    for (final s in _schedules) {
      final busy = {
        for (final e in s.entries)
          if (e.teacherId == keepId) e.timeSlotId,
      };
      if (s.entries.any(
        (e) => e.teacherId == fromId && busy.contains(e.timeSlotId),
      )) {
        throw StateError('TEACHER_MERGE_CONFLICT');
      }
    }
    for (final s in _schedules) {
      s.entries = [
        for (final e in s.entries)
          e.teacherId == fromId
              ? ScheduleEntry(
                  teacherId: keepId,
                  classroomId: e.classroomId,
                  timeSlotId: e.timeSlotId,
                  branch: e.branch,
                  roomId: e.roomId,
                  locked: e.locked,
                )
              : e,
      ];
    }
    _lessons = [
      for (final l in _lessons)
        l.teacherId == fromId
            ? ClassLesson(
                id: l.id,
                classroomId: l.classroomId,
                branch: l.branch,
                weeklyHours: l.weeklyHours,
                teacherId: keepId,
                maxPerDay: l.maxPerDay,
              )
            : l,
    ];
    final k = keep.teacher;
    _teachers[ki] = TeacherRecord(
      Teacher(
        id: k.id,
        name: k.name,
        branches: {
          ...k.branches,
          ...from.teacher.branches.where((b) => b != 'Genel'),
        },
        maxWeeklyHours: k.maxWeeklyHours,
        availability: k.availability.isNotEmpty
            ? k.availability
            : from.teacher.availability,
      ),
      profileId: from.profileId,
    );
    _teachers.removeAt(fi);
  }

  @override
  Future<String> saveRoom(Room room) async {
    final id = room.id.isEmpty ? _next('room') : room.id;
    final r = Room(id: id, name: room.name, capacity: room.capacity);
    final i = _rooms.indexWhere((x) => x.id == id);
    i < 0 ? _rooms.add(r) : _rooms[i] = r;
    return id;
  }

  @override
  Future<void> deleteRoom(String id) async =>
      _rooms.removeWhere((r) => r.id == id);

  @override
  Future<String> saveClassroom(
    Classroom classroom, {
    String? level,
    String? field,
    int? capacity,
    bool active = true,
  }) async {
    final id = classroom.id.isEmpty ? _next('class') : classroom.id;
    final i = _classrooms.indexWhere((c) => c.classroom.id == id);
    final rec = ClassroomRecord(
      Classroom(id: id, name: classroom.name, homeRoomId: classroom.homeRoomId),
      level: level,
      field: field,
      capacity: capacity,
      active: active,
      studentIds: i < 0 ? const [] : _classrooms[i].studentIds,
    );
    i < 0 ? _classrooms.add(rec) : _classrooms[i] = rec;
    return id;
  }

  @override
  Future<void> deleteClassroom(String id) async {
    if (_classrooms.any(
      (c) => c.classroom.id == id && c.studentIds.isNotEmpty,
    )) {
      throw StateError('CLASSROOM_NOT_EMPTY');
    }
    _classrooms.removeWhere((c) => c.classroom.id == id);
    _lessons.removeWhere((l) => l.classroomId == id);
    for (final s in _schedules) {
      s.entries.removeWhere((e) => e.classroomId == id);
    }
  }

  @override
  Future<void> setClassroomStudents(
    String classroomId,
    List<String> studentIds,
  ) async {
    final keep = studentIds.toSet();
    for (var i = 0; i < _classrooms.length; i++) {
      final c = _classrooms[i];
      final List<String> next;
      if (c.classroom.id == classroomId) {
        next = [...keep];
      } else {
        // Öğrenci tek sınıfta: buraya alınanlar öteki sınıftan çıkar.
        next = [
          for (final s in c.studentIds)
            if (!keep.contains(s)) s,
        ];
      }
      _classrooms[i] = ClassroomRecord(
        c.classroom,
        level: c.level,
        field: c.field,
        capacity: c.capacity,
        active: c.active,
        studentIds: next,
      );
    }
  }

  /// Tek öğrencinin sınıfı (null: sınıftan çıkar).
  void moveStudent(String studentId, String? classroomId) {
    for (var i = 0; i < _classrooms.length; i++) {
      final c = _classrooms[i];
      final ids = [
        for (final s in c.studentIds)
          if (s != studentId) s,
      ];
      if (c.classroom.id == classroomId) ids.add(studentId);
      _classrooms[i] = ClassroomRecord(
        c.classroom,
        level: c.level,
        field: c.field,
        capacity: c.capacity,
        active: c.active,
        studentIds: ids,
      );
    }
  }

  /// Öğrencinin sınıfı (id, ad).
  (String, String)? classOf(String studentId) {
    for (final c in _classrooms) {
      if (c.studentIds.contains(studentId)) {
        return (c.classroom.id, c.classroom.name);
      }
    }
    return null;
  }

  @override
  Future<void> saveLessons(
    String classroomId,
    List<ClassLesson> lessons,
  ) async {
    _lessons = [
      for (final l in _lessons)
        if (l.classroomId != classroomId) l,
      for (final l in lessons)
        ClassLesson(
          id: _next('lesson'),
          classroomId: classroomId,
          branch: l.branch,
          weeklyHours: l.weeklyHours,
          teacherId: l.teacherId,
          maxPerDay: l.maxPerDay,
        ),
    ];
  }

  @override
  Future<List<ScheduleInfo>> fetchSchedules() async => [
    for (final s in _schedules.reversed) s.info,
  ];

  @override
  Future<String> createSchedule(String name, {String? term}) async {
    final id = _next('sch');
    _schedules.add(
      _Schedule(
        ScheduleInfo(
          id: id,
          name: name,
          term: term,
          published: false,
          createdAt: DateTime.now(),
        ),
        [],
      ),
    );
    return id;
  }

  @override
  Future<void> deleteSchedule(String id) async =>
      _schedules.removeWhere((s) => s.info.id == id);

  _Schedule _find(String id) => _schedules.firstWhere((s) => s.info.id == id);

  @override
  Future<List<ScheduleEntry>> fetchEntries(String scheduleId) async => [
    ..._find(scheduleId).entries,
  ];

  @override
  Future<void> saveEntries(
    String scheduleId,
    List<ScheduleEntry> entries, {
    int? softScore,
  }) async {
    // Sunucudaki tekil indeksler gibi: aynı saatte öğretmen/sınıf/derslik.
    final seen = <String>{};
    for (final e in entries) {
      if (!seen.add('t${e.teacherId}|${e.timeSlotId}') ||
          !seen.add('c${e.classroomId}|${e.timeSlotId}') ||
          (e.roomId != null && !seen.add('r${e.roomId}|${e.timeSlotId}'))) {
        throw StateError('duplicate key value violates unique constraint');
      }
    }
    final s = _find(scheduleId);
    s.entries = [...entries];
    s.info = _copy(s.info, softScore: softScore);
  }

  ScheduleInfo _copy(
    ScheduleInfo i, {
    bool? published,
    int? softScore,
    DateTime? publishedAt,
  }) => ScheduleInfo(
    id: i.id,
    name: i.name,
    term: i.term,
    published: published ?? i.published,
    softScore: softScore ?? i.softScore,
    createdAt: i.createdAt,
    publishedAt: publishedAt ?? i.publishedAt,
  );

  @override
  Future<void> publish(String scheduleId) async {
    for (final s in _schedules) {
      final mine = s.info.id == scheduleId;
      s.info = _copy(
        s.info,
        published: mine,
        publishedAt: mine ? DateTime.now() : null,
      );
    }
  }

  @override
  Future<void> unpublish(String scheduleId) async {
    final s = _find(scheduleId);
    s.info = _copy(s.info, published: false);
  }

  @override
  Future<(int, int)> scheduleReach(String scheduleId) async {
    final classes = {for (final e in _find(scheduleId).entries) e.classroomId};
    final students = {
      for (final c in _classrooms)
        if (classes.contains(c.classroom.id)) ...c.studentIds,
    };
    return (classes.length, students.length);
  }

  @override
  Future<(String, String)?> myClassroom() async =>
      viewerRole == 'student' ? classOf(viewerId) : null;

  @override
  Future<List<TimetableItem>> myTimetable() async {
    final published = _schedules.where((s) => s.info.published).firstOrNull;
    if (published == null) return const [];
    final slots = {for (final s in _slots) s.id: s};
    final teachers = {for (final t in _teachers) t.teacher.id: t};
    final classes = {for (final c in _classrooms) c.classroom.id: c};
    final rooms = {for (final r in _rooms) r.id: r.name};
    TimetableItem item(ScheduleEntry e, String? student) {
      final s = slots[e.timeSlotId]!;
      return TimetableItem(
        studentId: student,
        scheduleName: published.info.name,
        day: s.day,
        seq: s.seq,
        start: s.start,
        end: s.end,
        branch: e.branch,
        classroomName: classes[e.classroomId]?.classroom.name ?? '',
        teacherName: teachers[e.teacherId]?.teacher.name ?? '',
        roomName: rooms[e.roomId],
      );
    }

    final students = switch (viewerRole) {
      'student' => [viewerId],
      'parent' => children,
      _ => const <String>[],
    };
    final out = <TimetableItem>[
      for (final e in published.entries)
        if (slots.containsKey(e.timeSlotId) &&
            teachers[e.teacherId]?.profileId == viewerId)
          item(e, null),
      for (final sid in students)
        for (final e in published.entries)
          if (slots.containsKey(e.timeSlotId) &&
              (classes[e.classroomId]?.studentIds.contains(sid) ?? false))
            item(e, sid),
    ];
    out.sort((a, b) {
      final d = a.day.compareTo(b.day);
      return d != 0 ? d : a.seq.compareTo(b.seq);
    });
    return out;
  }
}
