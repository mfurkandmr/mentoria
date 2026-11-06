import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/features/schedule_generator/domain/constraints.dart';
import 'package:mentoria/features/schedule_generator/domain/models.dart';
import 'package:mentoria/features/schedule_generator/domain/schedule_generator.dart';

/// [days] gün × [perDay] ders saati (09:00'dan 40 dk ders, 10 dk teneffüs).
List<TimeSlot> slots(int days, int perDay) => [
  for (var d = 1; d <= days; d++)
    for (var k = 1; k <= perDay; k++)
      TimeSlot(
        id: 'd$d-$k',
        day: d,
        seq: k,
        start: 9 * 60 + (k - 1) * 50,
        end: 9 * 60 + (k - 1) * 50 + 40,
      ),
];

void expectValid(GenerationInput input, GenerationResult r) {
  expect(validateHard(input, r.entries), isEmpty, reason: '${r.conflicts}');
}

void main() {
  group('basit', () {
    final input = GenerationInput(
      slots: slots(2, 4),
      teachers: const [
        Teacher(id: 'ahmet', name: 'Ahmet Hoca', branches: {'Matematik'}),
        Teacher(id: 'ayse', name: 'Ayşe Hoca', branches: {'Türkçe'}),
      ],
      classrooms: const [
        Classroom(id: 'say1', name: 'Sayısal-1'),
        Classroom(id: 'ea1', name: 'Eşit Ağırlık-1'),
      ],
      lessons: const [
        ClassLesson(
          id: 'l1',
          classroomId: 'say1',
          branch: 'Matematik',
          weeklyHours: 3,
        ),
        ClassLesson(
          id: 'l2',
          classroomId: 'say1',
          branch: 'Türkçe',
          weeklyHours: 2,
        ),
        ClassLesson(
          id: 'l3',
          classroomId: 'ea1',
          branch: 'Matematik',
          weeklyHours: 2,
        ),
        ClassLesson(
          id: 'l4',
          classroomId: 'ea1',
          branch: 'Türkçe',
          weeklyHours: 3,
        ),
      ],
      timeLimitMs: 2000,
    );

    test('2 öğretmen, 2 sınıf: çakışmasız tam çözüm', () {
      final r = ScheduleGenerator.generate(input);
      expect(r.complete, isTrue, reason: '${r.conflicts}');
      expect(r.conflicts, isEmpty);
      expect(r.entries, hasLength(10));
      expectValid(input, r);
    });

    test('aynı girdi ve tohum: aynı program', () {
      final a = ScheduleGenerator.generate(input);
      final b = ScheduleGenerator.generate(input);
      expect(a.entries.toSet(), b.entries.toSet());
    });

    test('JSON üzerinden (isolate) aynı sonuç', () {
      final direct = ScheduleGenerator.generate(input);
      final viaJson = GenerationResult.fromJson(
        ScheduleGenerator.generateJson(
          GenerationInput.fromJson(input.toJson()).toJson(),
        ),
      );
      expect(viaJson.entries.toSet(), direct.entries.toSet());
      expect(viaJson.softScore, direct.softScore);
    });
  });

  group('imkânsız', () {
    test('talep > müsaitlik: açık çakışma raporu, çökmez', () {
      final input = GenerationInput(
        slots: slots(5, 6),
        teachers: const [
          Teacher(
            id: 'ahmet',
            name: 'Ahmet Hoca',
            branches: {'Matematik'},
            availability: [
              AvailabilityRange(day: 2, start: 9 * 60, end: 13 * 60),
              AvailabilityRange(day: 4, start: 9 * 60, end: 13 * 60),
            ],
          ),
        ],
        classrooms: const [
          Classroom(id: 'say1', name: 'Sayısal-1'),
          Classroom(id: 'say2', name: 'Sayısal-2'),
        ],
        lessons: const [
          ClassLesson(
            id: 'l1',
            classroomId: 'say1',
            branch: 'Matematik',
            weeklyHours: 6,
            teacherId: 'ahmet',
          ),
          ClassLesson(
            id: 'l2',
            classroomId: 'say2',
            branch: 'Matematik',
            weeklyHours: 6,
            teacherId: 'ahmet',
          ),
        ],
        timeLimitMs: 2000,
      );
      final r = ScheduleGenerator.generate(input);
      // 09:00-13:00 aralığına 50 dakikalık arayla 5 ders girer: 2 gün × 5 = 10.
      final c = r.conflicts.firstWhere(
        (c) => c.kind == ConflictKind.teacherOverAvailability,
      );
      expect((c.teacherName, c.need, c.have), ('Ahmet Hoca', 12, 10));
      expect(r.complete, isFalse);
      expect(r.unassigned.fold<int>(0, (s, u) => s + u.missingHours), 2);
      expect(r.entries, hasLength(10));
      expect(validateHard(input, r.entries, requireComplete: false), isEmpty);
      expect(
        r.conflicts.where((c) => c.kind == ConflictKind.noCommonSlot),
        isNotEmpty,
      );
    });

    test('branşa öğretmen yok, üst sınır ve şablon aşımı raporlanır', () {
      final input = GenerationInput(
        slots: slots(1, 3),
        teachers: const [
          Teacher(
            id: 'a',
            name: 'Ali Hoca',
            branches: {'Fizik'},
            maxWeeklyHours: 1,
          ),
        ],
        classrooms: const [Classroom(id: 'c', name: 'Sayısal-1')],
        lessons: const [
          ClassLesson(
            id: 'f',
            classroomId: 'c',
            branch: 'Fizik',
            weeklyHours: 2,
          ),
          ClassLesson(
            id: 'k',
            classroomId: 'c',
            branch: 'Kimya',
            weeklyHours: 2,
          ),
        ],
        timeLimitMs: 1000,
      );
      final r = ScheduleGenerator.generate(input);
      final kinds = r.conflicts.map((c) => c.kind).toSet();
      expect(
        kinds,
        containsAll([
          ConflictKind.noTeacherForBranch,
          ConflictKind.teacherOverMax,
          ConflictKind.classroomOverSlots,
        ]),
      );
      expect(r.entries, hasLength(1));
      expect(validateHard(input, r.entries, requireComplete: false), isEmpty);
    });
  });

  group('kilitli', () {
    test('kilitli ders yerinden oynamaz, kalanı çevresine yerleşir', () {
      const locked = ScheduleEntry(
        teacherId: 'ahmet',
        classroomId: 'say1',
        timeSlotId: 'd1-4',
        branch: 'Matematik',
        locked: true,
      );
      final input = GenerationInput(
        slots: slots(3, 4),
        teachers: const [
          Teacher(id: 'ahmet', name: 'Ahmet Hoca', branches: {'Matematik'}),
          Teacher(id: 'ayse', name: 'Ayşe Hoca', branches: {'Fizik'}),
        ],
        classrooms: const [Classroom(id: 'say1', name: 'Sayısal-1')],
        lessons: const [
          ClassLesson(
            id: 'm',
            classroomId: 'say1',
            branch: 'Matematik',
            weeklyHours: 4,
          ),
          ClassLesson(
            id: 'f',
            classroomId: 'say1',
            branch: 'Fizik',
            weeklyHours: 4,
          ),
        ],
        locked: const [locked],
        timeLimitMs: 2000,
      );
      final r = ScheduleGenerator.generate(input);
      expect(r.complete, isTrue, reason: '${r.conflicts}');
      expect(r.entries, contains(locked));
      expect(r.entries.where((e) => e.timeSlotId == 'd1-4'), [locked]);
      expectValid(input, r);
    });

    test('kurala aykırı kilit raporlanır ama korunur', () {
      const bad = ScheduleEntry(
        teacherId: 'ahmet',
        classroomId: 'say1',
        timeSlotId: 'd1-1',
        branch: 'Matematik',
        locked: true,
      );
      final input = GenerationInput(
        slots: slots(1, 2),
        teachers: const [
          Teacher(
            id: 'ahmet',
            name: 'Ahmet Hoca',
            branches: {'Matematik'},
            availability: [AvailabilityRange(day: 2, start: 0, end: 24 * 60)],
          ),
        ],
        classrooms: const [Classroom(id: 'say1', name: 'Sayısal-1')],
        lessons: const [
          ClassLesson(
            id: 'm',
            classroomId: 'say1',
            branch: 'Matematik',
            weeklyHours: 1,
          ),
        ],
        locked: const [bad],
        timeLimitMs: 500,
      );
      final r = ScheduleGenerator.generate(input);
      expect(r.entries, [bad]);
      expect(
        r.conflicts.map((c) => c.kind),
        contains(ConflictKind.lockedInvalid),
      );
    });
  });

  group('doğrulayıcı', () {
    final input = GenerationInput(
      slots: slots(1, 2),
      teachers: const [
        Teacher(id: 't', name: 'T', branches: {'Matematik'}, maxWeeklyHours: 1),
      ],
      classrooms: const [
        Classroom(id: 'a', name: 'A'),
        Classroom(id: 'b', name: 'B'),
      ],
      rooms: const [Room(id: 'r', name: 'D-1')],
      lessons: const [
        ClassLesson(
          id: 'la',
          classroomId: 'a',
          branch: 'Matematik',
          weeklyHours: 1,
        ),
        ClassLesson(
          id: 'lb',
          classroomId: 'b',
          branch: 'Matematik',
          weeklyHours: 1,
        ),
      ],
      locked: const [
        ScheduleEntry(
          teacherId: 't',
          classroomId: 'a',
          timeSlotId: 'd1-2',
          branch: 'Matematik',
          locked: true,
        ),
      ],
    );

    test('yedi sert kuralın her birini yakalar', () {
      final rules = validateHard(input, const [
        ScheduleEntry(
          teacherId: 't',
          classroomId: 'a',
          timeSlotId: 'd1-1',
          branch: 'Matematik',
          roomId: 'r',
        ),
        ScheduleEntry(
          teacherId: 't',
          classroomId: 'b',
          timeSlotId: 'd1-1',
          branch: 'Matematik',
          roomId: 'r',
        ),
        ScheduleEntry(
          teacherId: 'x',
          classroomId: 'a',
          timeSlotId: 'd1-1',
          branch: 'Matematik',
        ),
      ]).map((v) => v.rule).toSet();
      expect(rules, HardRule.values.toSet());
    });

    test('elle taşımada çakışmalar', () {
      const entries = [
        ScheduleEntry(
          teacherId: 't',
          classroomId: 'a',
          timeSlotId: 'd1-1',
          branch: 'Matematik',
          roomId: 'r',
        ),
        ScheduleEntry(
          teacherId: 'u',
          classroomId: 'b',
          timeSlotId: 'd1-2',
          branch: 'Türkçe',
          roomId: 'r',
        ),
      ];
      final p = moveProblems(input, entries, 0, 'd1-2');
      expect(p, containsAll([HardRule.roomClash]));
      expect(moveProblems(input, entries, 0, 'd1-1'), isEmpty);
    });
  });

  test('20 öğretmen / 15 sınıf: süre sınırında tam ve geçerli', () {
    const branches = [
      'Matematik',
      'Fizik',
      'Kimya',
      'Biyoloji',
      'Türkçe',
      'Edebiyat',
      'Tarih',
      'Coğrafya',
      'Geometri',
      'İngilizce',
    ];
    const hours = [4, 3, 3, 2, 4, 3, 2, 2, 2, 3]; // 28 saat / sınıf
    final teachers = [
      for (var i = 0; i < 20; i++)
        Teacher(
          id: 't$i',
          name: 'Öğretmen $i',
          branches: {branches[i % branches.length]},
          maxWeeklyHours: 40,
          // Yarısı pazartesi gelmiyor.
          availability: i.isEven
              ? const []
              : [
                  for (var d = 2; d <= 6; d++)
                    AvailabilityRange(day: d, start: 0, end: 24 * 60),
                ],
        ),
    ];
    final classrooms = [
      for (var c = 0; c < 15; c++)
        Classroom(id: 'c$c', name: 'Sınıf $c', homeRoomId: 'r$c'),
    ];
    final input = GenerationInput(
      slots: slots(6, 8),
      teachers: teachers,
      classrooms: classrooms,
      rooms: [for (var c = 0; c < 15; c++) Room(id: 'r$c', name: 'D-$c')],
      lessons: [
        for (var c = 0; c < 15; c++)
          for (var b = 0; b < branches.length; b++)
            ClassLesson(
              id: 'c$c-$b',
              classroomId: 'c$c',
              branch: branches[b],
              weeklyHours: hours[b],
            ),
      ],
      timeLimitMs: 8000,
    );
    final sw = Stopwatch()..start();
    final r = ScheduleGenerator.generate(input);
    expect(sw.elapsedMilliseconds, lessThan(12000));
    expect(r.complete, isTrue, reason: '${r.conflicts}');
    expect(r.entries, hasLength(420));
    expectValid(input, r);
    // İyileştirme puanı yerleştirme sonrasından kötü olamaz.
    expect(r.softScore, lessThanOrEqualTo(softScore(input, r.entries)));
  });
}
