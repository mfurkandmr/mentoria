// Soru çözümü / birebir oturumları ders programında (NOTLAR §95): üretici
// oturum saatine o öğretmene ve dersliğe ders koymaz; doğrulayıcı ve elle
// taşıma da aynı kuralı uygular. Kurulum sihirbazının müsaitliği bozulmaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/features/schedule_generator/data/timetable_repository.dart';
import 'package:mentoria/features/schedule_generator/domain/constraints.dart';
import 'package:mentoria/features/schedule_generator/domain/models.dart';
import 'package:mentoria/features/schedule_generator/domain/schedule_generator.dart';
import 'package:mentoria/features/tutoring/data/tutoring_repository.dart';

import 'schedule_generator_test.dart' show slots;

void main() {
  // Pazartesi 2. ders 09:50-10:30; oturum 10:00-11:00 → 2. ve 3. dersle kesişir.
  const session = TutoringSession(
    id: 'ts-1',
    teacherId: 'ahmet',
    kind: TutoringKind.questionSolving,
    day: 1,
    start: 10 * 60,
    end: 11 * 60,
    roomId: 'r-1',
  );

  TimetableSetup setup({List<TutoringSession> tutoring = const [session]}) =>
      TimetableSetup(
        slots: slots(1, 4),
        teachers: const [
          TeacherRecord(
            Teacher(id: 'ahmet', name: 'Ahmet Hoca', branches: {'Matematik'}),
          ),
        ],
        rooms: const [Room(id: 'r-1', name: 'D-1')],
        classrooms: const [
          ClassroomRecord(
            Classroom(id: 'say1', name: 'Sayısal-1', homeRoomId: 'r-1'),
          ),
        ],
        lessons: const [
          ClassLesson(
            id: 'l1',
            classroomId: 'say1',
            branch: 'Matematik',
            weeklyHours: 2,
          ),
        ],
        tutoring: tutoring,
      );

  test('üretici oturum saatine ders koymaz', () {
    final input = setup().toInput(timeLimitMs: 300);
    final r = ScheduleGenerator.generate(input);
    expect(r.unassigned, isEmpty);
    expect(validateHard(input, r.entries), isEmpty);
    expect(
      r.entries.map((e) => e.timeSlotId).toSet(),
      {'d1-1', 'd1-4'},
      reason: '2. ve 3. ders oturumla kesişiyor',
    );
  });

  test('oturum saatindeki ders doğrulayıcıda ve taşımada hata', () {
    final input = setup().toInput();
    const bad = ScheduleEntry(
      teacherId: 'ahmet',
      classroomId: 'say1',
      timeSlotId: 'd1-2',
      branch: 'Matematik',
      roomId: 'r-1',
    );
    final rules = validateHard(input, [
      bad,
    ], requireComplete: false).map((v) => v.rule).toSet();
    expect(
      rules,
      containsAll([HardRule.teacherUnavailable, HardRule.roomClash]),
    );

    const ok = ScheduleEntry(
      teacherId: 'ahmet',
      classroomId: 'say1',
      timeSlotId: 'd1-1',
      branch: 'Matematik',
      roomId: 'r-1',
    );
    expect(
      moveProblems(input, [ok], 0, 'd1-3'),
      containsAll([HardRule.teacherUnavailable, HardRule.roomClash]),
    );
    expect(moveProblems(input, [ok], 0, 'd1-4'), isEmpty);
  });

  test('kapalı oturum programı engellemez; müsaitlik değişmez', () {
    const closed = TutoringSession(
      id: 'ts-2',
      teacherId: 'ahmet',
      kind: TutoringKind.etut,
      day: 1,
      start: 10 * 60,
      end: 11 * 60,
      active: false,
    );
    final input = setup(tutoring: const [closed]).toInput();
    expect(input.teachers.single.blocked, isEmpty);

    final blocked = setup().toInput().teachers.single;
    final slot = slots(1, 4)[1];
    // Sihirbaz müsaitliği kaydederken oturum müsaitsizlik sayılmasın.
    expect(blocked.availableAt(slot), isTrue);
    expect(blocked.freeAt(slot), isFalse);
  });

  test('tabloda öğretmenin ve dersliğin oturumu bulunur', () {
    final s = setup();
    final slot = slots(1, 4)[2]; // 10:40-11:20
    expect(s.tutoringAt(slot, teacherId: 'ahmet'), [session]);
    expect(s.tutoringAt(slot, roomId: 'r-1'), [session]);
    expect(s.tutoringAt(slot, teacherId: 'başka'), isEmpty);
    expect(s.tutoringAt(slots(1, 4)[0], teacherId: 'ahmet'), isEmpty);
  });

  test('JSON gidiş-dönüşte dolu bloklar korunur (arka planda üretim)', () {
    final input = setup().toInput();
    final back = GenerationInput.fromJson(input.toJson());
    expect(back.teachers.single.blocked.single.start, 10 * 60);
    expect(back.rooms.single.blocked, hasLength(1));
  });
}
