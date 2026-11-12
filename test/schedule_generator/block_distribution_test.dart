// 2'li blok dağılımı (NOTLAR §96): bir sınıfın bir dersi günlere 2 saatlik
// bitişik bloklar hâlinde dağılır: 3 → 2+1, 4 → 2+2, 5 → 2+2+1, 6 → 2+2+2.
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/features/schedule_generator/domain/constraints.dart';
import 'package:mentoria/features/schedule_generator/domain/models.dart';
import 'package:mentoria/features/schedule_generator/domain/schedule_generator.dart';

import 'schedule_generator_test.dart' show slots;

/// Ders → gün → o gündeki saat sıraları.
Map<String, Map<int, List<int>>> byLessonDay(
  GenerationInput input,
  List<ScheduleEntry> entries,
) {
  final slotOf = {for (final s in input.slots) s.id: s};
  final out = <String, Map<int, List<int>>>{};
  for (final e in entries) {
    final s = slotOf[e.timeSlotId]!;
    out
        .putIfAbsent('${e.classroomId}|${e.branch}', () => {})
        .putIfAbsent(s.day, () => [])
        .add(s.seq);
  }
  return out;
}

List<int> pattern(Map<int, List<int>> days) =>
    [for (final d in days.values) d.length]..sort((a, b) => b - a);

bool contiguous(List<int> seqs) {
  final s = [...seqs]..sort();
  return s.last - s.first + 1 == s.length;
}

void main() {
  const expected = {
    3: [2, 1],
    4: [2, 2],
    5: [2, 2, 1],
    6: [2, 2, 2],
  };

  GenerationInput input(int seed) => GenerationInput(
    slots: slots(5, 7),
    seed: seed,
    timeLimitMs: 1500,
    teachers: const [
      Teacher(id: 't3', name: 'Üç', branches: {'Fizik'}),
      Teacher(id: 't4', name: 'Dört', branches: {'Kimya'}),
      Teacher(id: 't5', name: 'Beş', branches: {'Türkçe'}),
      Teacher(id: 't6', name: 'Altı', branches: {'Matematik'}),
    ],
    classrooms: const [
      Classroom(id: 'a', name: '12-A'),
      Classroom(id: 'b', name: '12-B'),
    ],
    lessons: [
      for (final c in ['a', 'b']) ...[
        ClassLesson(
          id: '$c-f',
          classroomId: c,
          branch: 'Fizik',
          weeklyHours: 3,
        ),
        ClassLesson(
          id: '$c-k',
          classroomId: c,
          branch: 'Kimya',
          weeklyHours: 4,
        ),
        ClassLesson(
          id: '$c-t',
          classroomId: c,
          branch: 'Türkçe',
          weeklyHours: 5,
        ),
        ClassLesson(
          id: '$c-m',
          classroomId: c,
          branch: 'Matematik',
          weeklyHours: 6,
        ),
      ],
    ],
  );

  for (final seed in [1, 2, 3]) {
    test('dersler 2li bloklara bölünür (tohum $seed)', () {
      final i = input(seed);
      final r = ScheduleGenerator.generate(i);
      expect(r.unassigned, isEmpty);
      expect(validateHard(i, r.entries), isEmpty);
      final hours = {
        for (final l in i.lessons)
          '${l.classroomId}|${l.branch}': l.weeklyHours,
      };
      for (final MapEntry(key: k, value: days) in byLessonDay(
        i,
        r.entries,
      ).entries) {
        expect(pattern(days), expected[hours[k]], reason: '$k: $days');
        for (final seqs in days.values) {
          expect(contiguous(seqs), isTrue, reason: '$k blok bitişik: $days');
        }
      }
    });
  }

  test('puan: 1+1+1 ve aralı blok cezalı, 2+1 cezasız', () {
    final i = GenerationInput(
      slots: slots(3, 4),
      teachers: const [
        Teacher(id: 't', name: 'T', branches: {'Fizik'}),
      ],
      classrooms: const [Classroom(id: 'a', name: 'A')],
      lessons: const [
        ClassLesson(id: 'l', classroomId: 'a', branch: 'Fizik', weeklyHours: 3),
      ],
    );
    ScheduleEntry e(String slot) => ScheduleEntry(
      teacherId: 't',
      classroomId: 'a',
      timeSlotId: slot,
      branch: 'Fizik',
    );
    final good = softScore(i, [e('d1-1'), e('d1-2'), e('d2-1')]);
    final spread = softScore(i, [e('d1-1'), e('d2-1'), e('d3-1')]);
    final gapped = softScore(i, [e('d1-1'), e('d1-3'), e('d2-1')]);
    expect(good, 0);
    expect(spread, greaterThan(good));
    expect(gapped, greaterThan(good));
  });

  test('planlanan bölünüş', () {
    expect(blockPlan(1), [1]);
    expect(blockPlan(3), [2, 1]);
    expect(blockPlan(4), [2, 2]);
    expect(blockPlan(5), [2, 2, 1]);
    expect(blockPlan(6), [2, 2, 2]);
  });

  test('günde en çok 1 saat seçilen derste blok kuralı yok', () {
    final i = GenerationInput(
      slots: slots(3, 4),
      teachers: const [
        Teacher(id: 't', name: 'T', branches: {'Fizik'}),
      ],
      classrooms: const [Classroom(id: 'a', name: 'A')],
      lessons: const [
        ClassLesson(
          id: 'l',
          classroomId: 'a',
          branch: 'Fizik',
          weeklyHours: 3,
          maxPerDay: 1,
        ),
      ],
    );
    final r = ScheduleGenerator.generate(i);
    expect(pattern(byLessonDay(i, r.entries).values.single), [1, 1, 1]);
    expect(r.softScore, 0);
  });
}
