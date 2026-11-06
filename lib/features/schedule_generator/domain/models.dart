// Ders programı üretimi: saf Dart modeller (Flutter ve Supabase'den
// bağımsız). Hepsi JSON'a çevrilebilir; üretim bir isolate'te (compute) ya
// da ileride sunucuda aynı girdiyle çalıştırılabilir.

/// "09:40" ya da "09:40:00" → gece yarısından dakika.
int parseClock(String s) {
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Dakika → "09:40".
String formatClock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// Sayısal ağırlıklı branşlar (mümkünse sabaha).
const numericBranches = {'Matematik', 'Geometri', 'Fizik'};

/// Uygulamadaki hazır branş listesi (serbest metin de girilebilir).
const commonBranches = [
  'Matematik',
  'Geometri',
  'Fizik',
  'Kimya',
  'Biyoloji',
  'Türkçe',
  'Edebiyat',
  'Tarih',
  'Coğrafya',
  'Felsefe',
  'Din Kültürü',
  'İngilizce',
  'Rehberlik',
];

class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.day,
    required this.seq,
    required this.start,
    required this.end,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> j) => TimeSlot(
    id: j['id'] as String,
    day: j['day'] as int,
    seq: j['seq'] as int,
    start: j['start'] as int,
    end: j['end'] as int,
  );

  final String id;

  /// 1 = pazartesi … 7 = pazar.
  final int day;

  /// Gün içindeki sıra (1'den).
  final int seq;

  /// Gece yarısından dakika.
  final int start;
  final int end;

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'seq': seq,
    'start': start,
    'end': end,
  };
}

class AvailabilityRange {
  const AvailabilityRange({
    required this.day,
    required this.start,
    required this.end,
  });

  factory AvailabilityRange.fromJson(Map<String, dynamic> j) =>
      AvailabilityRange(
        day: j['day'] as int,
        start: j['start'] as int,
        end: j['end'] as int,
      );

  final int day;
  final int start;
  final int end;

  bool covers(TimeSlot s) => s.day == day && s.start >= start && s.end <= end;

  Map<String, dynamic> toJson() => {'day': day, 'start': start, 'end': end};
}

class Teacher {
  const Teacher({
    required this.id,
    required this.name,
    required this.branches,
    this.maxWeeklyHours = 30,
    this.availability = const [],
  });

  factory Teacher.fromJson(Map<String, dynamic> j) => Teacher(
    id: j['id'] as String,
    name: j['name'] as String,
    branches: {for (final b in j['branches'] as List) b as String},
    maxWeeklyHours: j['max'] as int,
    availability: [
      for (final a in j['availability'] as List)
        AvailabilityRange.fromJson(Map<String, dynamic>.from(a as Map)),
    ],
  );

  final String id;
  final String name;
  final Set<String> branches;
  final int maxWeeklyHours;

  /// Müsait aralıklar; boşsa her saat müsait.
  final List<AvailabilityRange> availability;

  bool availableAt(TimeSlot s) =>
      availability.isEmpty || availability.any((a) => a.covers(s));

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'branches': branches.toList(),
    'max': maxWeeklyHours,
    'availability': [for (final a in availability) a.toJson()],
  };
}

class Room {
  const Room({required this.id, required this.name, this.capacity});

  factory Room.fromJson(Map<String, dynamic> j) => Room(
    id: j['id'] as String,
    name: j['name'] as String,
    capacity: j['capacity'] as int?,
  );

  final String id;
  final String name;
  final int? capacity;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'capacity': capacity,
  };
}

class Classroom {
  const Classroom({
    required this.id,
    required this.name,
    this.homeRoomId,
    this.size = 0,
  });

  factory Classroom.fromJson(Map<String, dynamic> j) => Classroom(
    id: j['id'] as String,
    name: j['name'] as String,
    homeRoomId: j['home_room'] as String?,
    size: j['size'] as int? ?? 0,
  );

  final String id;
  final String name;

  /// Sınıfın kendi dersliği; yoksa boş bir derslik verilir (varsa).
  final String? homeRoomId;

  /// Öğrenci sayısı (derslik kapasitesi için; 0 = bilinmiyor).
  final int size;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'home_room': homeRoomId,
    'size': size,
  };
}

/// Bir sınıfın bir dersten haftalık ihtiyacı.
class ClassLesson {
  const ClassLesson({
    required this.id,
    required this.classroomId,
    required this.branch,
    required this.weeklyHours,
    this.teacherId,
    this.maxPerDay = 2,
  });

  factory ClassLesson.fromJson(Map<String, dynamic> j) => ClassLesson(
    id: j['id'] as String,
    classroomId: j['classroom'] as String,
    branch: j['branch'] as String,
    weeklyHours: j['hours'] as int,
    teacherId: j['teacher'] as String?,
    maxPerDay: j['max_per_day'] as int? ?? 2,
  );

  final String id;
  final String classroomId;
  final String branch;
  final int weeklyHours;

  /// Doluysa bu öğretmen kesin; boşsa branşı tutan biri seçilir.
  final String? teacherId;

  /// Günde en çok kaç saat (yumuşak kısıt).
  final int maxPerDay;

  Map<String, dynamic> toJson() => {
    'id': id,
    'classroom': classroomId,
    'branch': branch,
    'hours': weeklyHours,
    'teacher': teacherId,
    'max_per_day': maxPerDay,
  };
}

class ScheduleEntry {
  const ScheduleEntry({
    required this.teacherId,
    required this.classroomId,
    required this.timeSlotId,
    required this.branch,
    this.roomId,
    this.locked = false,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> j) => ScheduleEntry(
    teacherId: j['teacher_id'] as String,
    classroomId: j['classroom_id'] as String,
    timeSlotId: j['time_slot_id'] as String,
    branch: j['branch'] as String,
    roomId: j['room_id'] as String?,
    locked: j['locked'] as bool? ?? false,
  );

  final String teacherId;
  final String classroomId;
  final String timeSlotId;
  final String branch;
  final String? roomId;

  /// Müdürün sabitlediği ders: algoritma yerini değiştirmez.
  final bool locked;

  ScheduleEntry copyWith({
    String? timeSlotId,
    String? roomId,
    bool clearRoom = false,
    bool? locked,
  }) => ScheduleEntry(
    teacherId: teacherId,
    classroomId: classroomId,
    timeSlotId: timeSlotId ?? this.timeSlotId,
    branch: branch,
    roomId: clearRoom ? null : roomId ?? this.roomId,
    locked: locked ?? this.locked,
  );

  Map<String, dynamic> toJson() => {
    'teacher_id': teacherId,
    'classroom_id': classroomId,
    'time_slot_id': timeSlotId,
    'branch': branch,
    'room_id': roomId,
    'locked': locked,
  };

  @override
  bool operator ==(Object other) =>
      other is ScheduleEntry &&
      other.teacherId == teacherId &&
      other.classroomId == classroomId &&
      other.timeSlotId == timeSlotId &&
      other.branch == branch &&
      other.roomId == roomId &&
      other.locked == locked;

  @override
  int get hashCode =>
      Object.hash(teacherId, classroomId, timeSlotId, branch, roomId, locked);
}

class GenerationInput {
  const GenerationInput({
    required this.slots,
    required this.teachers,
    required this.classrooms,
    required this.lessons,
    this.rooms = const [],
    this.locked = const [],
    this.timeLimitMs = 10000,
    this.seed = 1,
  });

  factory GenerationInput.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => [
      for (final e in j[k] as List) f(Map<String, dynamic>.from(e as Map)),
    ];
    return GenerationInput(
      slots: list('slots', TimeSlot.fromJson),
      teachers: list('teachers', Teacher.fromJson),
      classrooms: list('classrooms', Classroom.fromJson),
      lessons: list('lessons', ClassLesson.fromJson),
      rooms: list('rooms', Room.fromJson),
      locked: list('locked', ScheduleEntry.fromJson),
      timeLimitMs: j['time_limit_ms'] as int,
      seed: j['seed'] as int,
    );
  }

  final List<TimeSlot> slots;
  final List<Teacher> teachers;
  final List<Classroom> classrooms;
  final List<ClassLesson> lessons;
  final List<Room> rooms;

  /// Kilitli dersler: aynen sonuçta kalır.
  final List<ScheduleEntry> locked;

  /// Toplam süre sınırı (yerleştirme + iyileştirme).
  final int timeLimitMs;

  /// Rastgelelik tohumu (aynı girdi + tohum = aynı program).
  final int seed;

  Map<String, dynamic> toJson() => {
    'slots': [for (final s in slots) s.toJson()],
    'teachers': [for (final t in teachers) t.toJson()],
    'classrooms': [for (final c in classrooms) c.toJson()],
    'lessons': [for (final l in lessons) l.toJson()],
    'rooms': [for (final r in rooms) r.toJson()],
    'locked': [for (final e in locked) e.toJson()],
    'time_limit_ms': timeLimitMs,
    'seed': seed,
  };
}

/// Neden programın tamamlanamadığı (ya da kilitli bir dersin kuralı
/// bozduğu). Metni arayüz [kind] ve alanlardan kurar.
enum ConflictKind {
  /// Sınıfın dersine o branşta öğretmen yok.
  noTeacherForBranch,

  /// Öğretmene atanan saat, haftalık en çok ders saatini aşıyor.
  teacherOverMax,

  /// Öğretmene atanan saat, müsait saatlerinden fazla.
  teacherOverAvailability,

  /// Sınıfın haftalık ders ihtiyacı, şablondaki ders saatinden fazla.
  classroomOverSlots,

  /// Kilitli derslerin sayısı haftalık ihtiyacı aşıyor.
  lockedOverHours,

  /// Kilitli ders bir sert kuralı bozuyor (çakışma ya da müsait değil).
  lockedInvalid,

  /// Öğretmenle sınıfın ortak boş saati yetmedi.
  noCommonSlot,
}

class Conflict {
  const Conflict(
    this.kind, {
    this.teacherName,
    this.classroomName,
    this.branch,
    this.need = 0,
    this.have = 0,
  });

  factory Conflict.fromJson(Map<String, dynamic> j) => Conflict(
    ConflictKind.values.byName(j['kind'] as String),
    teacherName: j['teacher'] as String?,
    classroomName: j['classroom'] as String?,
    branch: j['branch'] as String?,
    need: j['need'] as int? ?? 0,
    have: j['have'] as int? ?? 0,
  );

  final ConflictKind kind;
  final String? teacherName;
  final String? classroomName;
  final String? branch;

  /// İstenen (saat).
  final int need;

  /// Olan (saat).
  final int have;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'teacher': teacherName,
    'classroom': classroomName,
    'branch': branch,
    'need': need,
    'have': have,
  };

  @override
  String toString() =>
      '${kind.name}(${teacherName ?? ''} ${classroomName ?? ''} '
      '${branch ?? ''} $need/$have)';
}

/// Yerleştirilemeyen saatler.
class UnassignedLesson {
  const UnassignedLesson({
    required this.lessonId,
    required this.classroomId,
    required this.branch,
    required this.missingHours,
  });

  factory UnassignedLesson.fromJson(Map<String, dynamic> j) => UnassignedLesson(
    lessonId: j['lesson'] as String,
    classroomId: j['classroom'] as String,
    branch: j['branch'] as String,
    missingHours: j['missing'] as int,
  );

  final String lessonId;
  final String classroomId;
  final String branch;
  final int missingHours;

  Map<String, dynamic> toJson() => {
    'lesson': lessonId,
    'classroom': classroomId,
    'branch': branch,
    'missing': missingHours,
  };
}

class GenerationResult {
  const GenerationResult({
    required this.entries,
    required this.unassigned,
    required this.conflicts,
    required this.softScore,
    required this.durationMs,
  });

  factory GenerationResult.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => [
      for (final e in j[k] as List) f(Map<String, dynamic>.from(e as Map)),
    ];
    return GenerationResult(
      entries: list('entries', ScheduleEntry.fromJson),
      unassigned: list('unassigned', UnassignedLesson.fromJson),
      conflicts: list('conflicts', Conflict.fromJson),
      softScore: j['soft_score'] as int,
      durationMs: j['duration_ms'] as int,
    );
  }

  final List<ScheduleEntry> entries;
  final List<UnassignedLesson> unassigned;
  final List<Conflict> conflicts;

  /// Yumuşak kısıt ceza puanı: 0 en iyisi, düşük daha iyi.
  final int softScore;
  final int durationMs;

  /// Bütün saatler yerleşti mi.
  bool get complete => unassigned.isEmpty;

  Map<String, dynamic> toJson() => {
    'entries': [for (final e in entries) e.toJson()],
    'unassigned': [for (final u in unassigned) u.toJson()],
    'conflicts': [for (final c in conflicts) c.toJson()],
    'soft_score': softScore,
    'duration_ms': durationMs,
  };
}
