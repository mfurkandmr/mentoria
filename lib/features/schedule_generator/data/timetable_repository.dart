import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/models.dart';

/// Öğretmen + uygulama hesabı bağlantısı (profile_id doluysa o koç
/// hesabı yayındaki programını kendi panelinde görür).
class TeacherRecord {
  const TeacherRecord(this.teacher, {this.profileId});

  final Teacher teacher;
  final String? profileId;
}

/// Sınıf + seviye, alan ve öğrencileri.
class ClassroomRecord {
  const ClassroomRecord(
    this.classroom, {
    this.level,
    this.field,
    this.studentIds = const [],
    this.capacity,
    this.active = true,
  });

  final Classroom classroom;

  /// '9'…'12' ya da 'graduate'.
  final String? level;

  /// 'SAY' | 'EA' | 'SOZ' | 'DIL'.
  final String? field;
  final List<String> studentIds;

  /// Sınıf mevcudu üst sınırı (isteğe bağlı).
  final int? capacity;

  /// Pasif sınıfa öğrenci atanmaz.
  final bool active;
}

/// Kurumun bütün program ayarları.
class TimetableSetup {
  const TimetableSetup({
    this.slots = const [],
    this.teachers = const [],
    this.rooms = const [],
    this.classrooms = const [],
    this.lessons = const [],
  });

  final List<TimeSlot> slots;
  final List<TeacherRecord> teachers;
  final List<Room> rooms;
  final List<ClassroomRecord> classrooms;
  final List<ClassLesson> lessons;

  bool get isEmpty =>
      slots.isEmpty ||
      teachers.isEmpty ||
      classrooms.isEmpty ||
      lessons.isEmpty;

  /// Üretici girdisi (sınıf mevcudu öğrenci sayısından).
  GenerationInput toInput({
    List<ScheduleEntry> locked = const [],
    int timeLimitMs = 10000,
    int seed = 1,
  }) => GenerationInput(
    slots: slots,
    teachers: [for (final t in teachers) t.teacher],
    rooms: rooms,
    classrooms: [
      for (final c in classrooms)
        Classroom(
          id: c.classroom.id,
          name: c.classroom.name,
          homeRoomId: c.classroom.homeRoomId,
          size: c.studentIds.length,
        ),
    ],
    lessons: lessons,
    locked: locked,
    timeLimitMs: timeLimitMs,
    seed: seed,
  );
}

class ScheduleInfo {
  const ScheduleInfo({
    required this.id,
    required this.name,
    required this.published,
    required this.createdAt,
    this.term,
    this.softScore,
    this.publishedAt,
  });

  factory ScheduleInfo.fromJson(Map<String, dynamic> j) => ScheduleInfo(
    id: j['id'] as String,
    name: j['name'] as String,
    term: j['term'] as String?,
    published: j['status'] == 'published',
    softScore: j['soft_score'] as int?,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    publishedAt: j['published_at'] == null
        ? null
        : DateTime.parse(j['published_at'] as String).toLocal(),
  );

  final String id;
  final String name;
  final String? term;
  final bool published;
  final int? softScore;
  final DateTime createdAt;

  /// Son yayınlanma zamanı.
  final DateTime? publishedAt;
}

/// Yayındaki programdan bir ders (öğretmen / öğrenci / veli görünümü).
class TimetableItem {
  const TimetableItem({
    required this.day,
    required this.seq,
    required this.start,
    required this.end,
    required this.branch,
    required this.classroomName,
    required this.teacherName,
    this.studentId,
    this.roomName,
    this.scheduleName = '',
  });

  factory TimetableItem.fromJson(Map<String, dynamic> j) => TimetableItem(
    studentId: j['student_id'] as String?,
    scheduleName: j['schedule_name'] as String? ?? '',
    day: j['day'] as int,
    seq: j['seq'] as int,
    start: parseClock(j['start_time'] as String),
    end: parseClock(j['end_time'] as String),
    branch: j['branch'] as String,
    classroomName: j['classroom_name'] as String,
    teacherName: j['teacher_name'] as String,
    roomName: j['room_name'] as String?,
  );

  /// Veli görünümünde hangi çocuk için (öğretmende null).
  final String? studentId;
  final String scheduleName;
  final int day;
  final int seq;
  final int start;
  final int end;
  final String branch;
  final String classroomName;
  final String teacherName;
  final String? roomName;
}

abstract interface class TimetableRepository {
  Future<TimetableSetup> fetchSetup();

  /// Ders saati şablonu: (gün, sıra) aynı kalan saatlerin kimliği korunur
  /// (programdaki dersleri silinmesin); kaldırılanlar silinir.
  Future<void> saveTimeSlots(List<TimeSlot> slots);

  /// Yeni öğretmen için `teacher.id` boş; kimlik döner. Müsaitlik
  /// tamamen yenilenir.
  Future<String> saveTeacher(Teacher teacher, {String? profileId});
  Future<void> deleteTeacher(String id);

  Future<String> saveRoom(Room room);
  Future<void> deleteRoom(String id);

  Future<String> saveClassroom(
    Classroom classroom, {
    String? level,
    String? field,
    int? capacity,
    bool active = true,
  });

  /// İçinde öğrenci varsa sunucu `CLASSROOM_NOT_EMPTY` verir.
  Future<void> deleteClassroom(String id);

  /// Sınıfın öğrencileri: listede olmayanlar sınıftan çıkar, listedekiler
  /// (başka sınıftaysa oradan) bu sınıfa taşınır. Öğrenci tek sınıftadır.
  Future<void> setClassroomStudents(
    String classroomId,
    List<String> studentIds,
  );

  /// Sınıfın ders ihtiyaçları tamamen yenilenir.
  Future<void> saveLessons(String classroomId, List<ClassLesson> lessons);

  Future<List<ScheduleInfo>> fetchSchedules();
  Future<String> createSchedule(String name, {String? term});
  Future<void> deleteSchedule(String id);
  Future<List<ScheduleEntry>> fetchEntries(String scheduleId);
  Future<void> saveEntries(
    String scheduleId,
    List<ScheduleEntry> entries, {
    int? softScore,
  });

  /// Yayınla (kurumdaki öteki yayındaki program taslağa döner).
  Future<void> publish(String scheduleId);
  Future<void> unpublish(String scheduleId);

  /// Öğretmen / öğrenci / veli: yayındaki programdan beni ilgilendirenler.
  Future<List<TimetableItem>> myTimetable();

  /// Öğrencinin sınıfı (kimlik, ad); sınıfı yoksa null.
  Future<(String, String)?> myClassroom();

  /// Yayınlanırsa etkilenecek (sınıf, öğrenci) sayısı.
  Future<(int, int)> scheduleReach(String scheduleId);
}

String _clock(int m) => '${formatClock(m)}:00';

class SupabaseTimetableRepository implements TimetableRepository {
  SupabaseTimetableRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<TimetableSetup> fetchSetup() async {
    final results = await Future.wait([
      _client.from('time_slots').select().order('day').order('seq'),
      _client
          .from('teachers')
          .select('*, teacher_availability(day, start_time, end_time)')
          .order('full_name'),
      _client.from('rooms').select().order('name'),
      _client
          .from('classrooms')
          .select('*, classroom_students(student_id)')
          .order('name'),
      _client.from('class_lessons').select().order('branch'),
    ]);
    List<Map<String, dynamic>> rows(int i) => [
      for (final r in results[i] as List) Map<String, dynamic>.from(r as Map),
    ];
    return TimetableSetup(
      slots: [
        for (final r in rows(0))
          TimeSlot(
            id: r['id'] as String,
            day: r['day'] as int,
            seq: r['seq'] as int,
            start: parseClock(r['start_time'] as String),
            end: parseClock(r['end_time'] as String),
          ),
      ],
      teachers: [
        for (final r in rows(1))
          TeacherRecord(
            Teacher(
              id: r['id'] as String,
              name: r['full_name'] as String,
              branches: {for (final b in r['branches'] as List) b as String},
              maxWeeklyHours: r['max_weekly_hours'] as int,
              availability: [
                for (final a in r['teacher_availability'] as List? ?? const [])
                  AvailabilityRange(
                    day: a['day'] as int,
                    start: parseClock(a['start_time'] as String),
                    end: parseClock(a['end_time'] as String),
                  ),
              ],
            ),
            profileId: r['profile_id'] as String?,
          ),
      ],
      rooms: [
        for (final r in rows(2))
          Room(
            id: r['id'] as String,
            name: r['name'] as String,
            capacity: r['capacity'] as int?,
          ),
      ],
      classrooms: [
        for (final r in rows(3))
          ClassroomRecord(
            Classroom(
              id: r['id'] as String,
              name: r['name'] as String,
              homeRoomId: r['home_room_id'] as String?,
            ),
            level: r['level'] as String?,
            field: r['field'] as String?,
            capacity: r['capacity'] as int?,
            active: r['active'] as bool? ?? true,
            studentIds: [
              for (final s in r['classroom_students'] as List? ?? const [])
                s['student_id'] as String,
            ],
          ),
      ],
      lessons: [
        for (final r in rows(4))
          ClassLesson(
            id: r['id'] as String,
            classroomId: r['classroom_id'] as String,
            branch: r['branch'] as String,
            weeklyHours: r['weekly_hours'] as int,
            teacherId: r['teacher_id'] as String?,
            maxPerDay: r['max_per_day'] as int,
          ),
      ],
    );
  }

  @override
  Future<void> saveTimeSlots(List<TimeSlot> slots) async {
    final existing = [
      for (final r in await _client.from('time_slots').select('id, day, seq'))
        Map<String, dynamic>.from(r),
    ];
    final byKey = {
      for (final r in existing) '${r['day']}|${r['seq']}': r['id'] as String,
    };
    final keep = <String>{};
    for (final s in slots) {
      final row = {
        'day': s.day,
        'seq': s.seq,
        'start_time': _clock(s.start),
        'end_time': _clock(s.end),
      };
      final id = byKey['${s.day}|${s.seq}'];
      if (id != null) {
        keep.add(id);
        await _client.from('time_slots').update(row).eq('id', id);
      } else {
        await _client.from('time_slots').insert(row);
      }
    }
    final drop = [
      for (final id in byKey.values)
        if (!keep.contains(id)) id,
    ];
    if (drop.isNotEmpty) {
      await _client.from('time_slots').delete().inFilter('id', drop);
    }
  }

  @override
  Future<String> saveTeacher(Teacher teacher, {String? profileId}) async {
    final row = {
      'full_name': teacher.name,
      'branches': teacher.branches.toList(),
      'max_weekly_hours': teacher.maxWeeklyHours,
      'profile_id': profileId,
    };
    final String id;
    if (teacher.id.isEmpty) {
      id =
          (await _client
                  .from('teachers')
                  .insert(row)
                  .select('id')
                  .single())['id']
              as String;
    } else {
      id = teacher.id;
      await _client.from('teachers').update(row).eq('id', id);
      await _client.from('teacher_availability').delete().eq('teacher_id', id);
    }
    if (teacher.availability.isNotEmpty) {
      await _client.from('teacher_availability').insert([
        for (final a in teacher.availability)
          {
            'teacher_id': id,
            'day': a.day,
            'start_time': _clock(a.start),
            'end_time': _clock(a.end),
          },
      ]);
    }
    return id;
  }

  @override
  Future<void> deleteTeacher(String id) =>
      _client.from('teachers').delete().eq('id', id);

  @override
  Future<String> saveRoom(Room room) async {
    final row = {'name': room.name, 'capacity': room.capacity};
    if (room.id.isEmpty) {
      return (await _client
              .from('rooms')
              .insert(row)
              .select('id')
              .single())['id']
          as String;
    }
    await _client.from('rooms').update(row).eq('id', room.id);
    return room.id;
  }

  @override
  Future<void> deleteRoom(String id) =>
      _client.from('rooms').delete().eq('id', id);

  @override
  Future<String> saveClassroom(
    Classroom classroom, {
    String? level,
    String? field,
    int? capacity,
    bool active = true,
  }) async {
    final row = {
      'name': classroom.name,
      'home_room_id': classroom.homeRoomId,
      'level': level,
      'field': field,
      'capacity': capacity,
      'active': active,
    };
    if (classroom.id.isEmpty) {
      return (await _client
              .from('classrooms')
              .insert(row)
              .select('id')
              .single())['id']
          as String;
    }
    await _client.from('classrooms').update(row).eq('id', classroom.id);
    return classroom.id;
  }

  @override
  Future<void> deleteClassroom(String id) =>
      _client.from('classrooms').delete().eq('id', id);

  @override
  Future<void> setClassroomStudents(
    String classroomId,
    List<String> studentIds,
  ) async {
    final current = {
      for (final r
          in await _client
              .from('classroom_students')
              .select('student_id')
              .eq('classroom_id', classroomId))
        r['student_id'] as String,
    };
    final keep = studentIds.toSet();
    final remove = [
      for (final s in current)
        if (!keep.contains(s)) s,
    ];
    final add = [
      for (final s in keep)
        if (!current.contains(s)) s,
    ];
    if (remove.isNotEmpty) {
      await _client.rpc(
        'assign_students_to_class',
        params: {'p_students': remove, 'p_classroom': null},
      );
    }
    if (add.isNotEmpty) {
      await _client.rpc(
        'assign_students_to_class',
        params: {'p_students': add, 'p_classroom': classroomId},
      );
    }
  }

  @override
  Future<void> saveLessons(
    String classroomId,
    List<ClassLesson> lessons,
  ) async {
    await _client
        .from('class_lessons')
        .delete()
        .eq('classroom_id', classroomId);
    if (lessons.isEmpty) return;
    await _client.from('class_lessons').insert([
      for (final l in lessons)
        {
          'classroom_id': classroomId,
          'branch': l.branch,
          'weekly_hours': l.weeklyHours,
          'teacher_id': l.teacherId,
          'max_per_day': l.maxPerDay,
        },
    ]);
  }

  @override
  Future<List<ScheduleInfo>> fetchSchedules() async => [
    for (final r
        in await _client
            .from('schedules')
            .select()
            .order('created_at', ascending: false))
      ScheduleInfo.fromJson(Map<String, dynamic>.from(r)),
  ];

  @override
  Future<String> createSchedule(String name, {String? term}) async =>
      (await _client
              .from('schedules')
              .insert({'name': name, 'term': term})
              .select('id')
              .single())['id']
          as String;

  @override
  Future<void> deleteSchedule(String id) =>
      _client.from('schedules').delete().eq('id', id);

  @override
  Future<List<ScheduleEntry>> fetchEntries(String scheduleId) async => [
    for (final r
        in await _client
            .from('schedule_entries')
            .select(
              'teacher_id, classroom_id, room_id, time_slot_id, branch, locked',
            )
            .eq('schedule_id', scheduleId))
      ScheduleEntry.fromJson(Map<String, dynamic>.from(r)),
  ];

  @override
  Future<void> saveEntries(
    String scheduleId,
    List<ScheduleEntry> entries, {
    int? softScore,
  }) async {
    await _client.rpc(
      'save_schedule_entries',
      params: {
        'p_schedule': scheduleId,
        'p_entries': [for (final e in entries) e.toJson()],
        'p_soft_score': softScore,
      },
    );
  }

  @override
  Future<void> publish(String scheduleId) =>
      _client.rpc('publish_schedule', params: {'p_schedule': scheduleId});

  @override
  Future<void> unpublish(String scheduleId) => _client
      .from('schedules')
      .update({'status': 'draft'})
      .eq('id', scheduleId);

  @override
  Future<(int, int)> scheduleReach(String scheduleId) async {
    final r = await _client.rpc(
      'schedule_reach',
      params: {'p_schedule': scheduleId},
    );
    if (r is! Map) return (0, 0);
    return (r['classes'] as int? ?? 0, r['students'] as int? ?? 0);
  }

  @override
  Future<(String, String)?> myClassroom() async {
    final rows = await _client.rpc('my_classroom') as List;
    if (rows.isEmpty) return null;
    final r = Map<String, dynamic>.from(rows.first as Map);
    return (r['classroom_id'] as String, r['classroom_name'] as String);
  }

  @override
  Future<List<TimetableItem>> myTimetable() async => [
    for (final r in await _client.rpc('my_timetable') as List)
      TimetableItem.fromJson(Map<String, dynamic>.from(r as Map)),
  ];
}

final timetableRepositoryProvider = Provider<TimetableRepository>(
  (ref) => SupabaseTimetableRepository(ref.watch(supabaseClientProvider)),
);

final timetableSetupProvider = FutureProvider<TimetableSetup>(
  (ref) => ref.watch(timetableRepositoryProvider).fetchSetup(),
);

final schedulesProvider = FutureProvider<List<ScheduleInfo>>(
  (ref) => ref.watch(timetableRepositoryProvider).fetchSchedules(),
);

final scheduleEntriesProvider =
    FutureProvider.family<List<ScheduleEntry>, String>(
      (ref, id) => ref.watch(timetableRepositoryProvider).fetchEntries(id),
    );

final myTimetableProvider = FutureProvider<List<TimetableItem>>(
  (ref) => ref.watch(timetableRepositoryProvider).myTimetable(),
);

final myClassroomProvider = FutureProvider<(String, String)?>(
  (ref) => ref.watch(timetableRepositoryProvider).myClassroom(),
);
