// Maarif Modeli müfredatı ve konu bazlı toplu ödev (NOTLAR §104).
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/grade_levels.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/assignments/data/assignment_repository.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';

void main() {
  const eskiTopic = Topic(
    id: 1,
    subjectCode: 'TYT_MAT',
    name: 'Kümeler',
    sort: 1,
  );
  const eskiAyt = Topic(
    id: 2,
    subjectCode: 'AYT_MAT',
    name: 'Trigonometri',
    sort: 1,
  );
  const maarif9 = Topic(
    id: 10,
    subjectCode: 'TYT_MAT',
    name: 'Sayı Kümeleri ve İşlem Özellikleri',
    sort: 1,
    curriculum: 'maarif',
    grade: 9,
    groupName: 'Sayılar',
  );
  const maarif10 = Topic(
    id: 11,
    subjectCode: 'TYT_MAT',
    name: 'Sayma',
    sort: 1,
    curriculum: 'maarif',
    grade: 10,
    groupName: 'Sayma, Algoritma Ve Bilişim',
  );
  const all = [eskiTopic, eskiAyt, maarif9, maarif10];

  test('müfredat seçilmediyse sınıftan türetilir', () {
    expect(defaultCurriculum(9), curriculumMaarif);
    expect(defaultCurriculum(11), curriculumMaarif);
    expect(defaultCurriculum(12), curriculumEski);
    expect(defaultCurriculum(null), curriculumEski);
    expect(effectiveCurriculum(9, null), curriculumMaarif);
    expect(effectiveCurriculum(9, curriculumEski), curriculumEski);
    expect(effectiveCurriculum(12, curriculumMaarif), curriculumMaarif);
    expect(effectiveCurriculum(12, 'bilinmeyen'), curriculumEski);
  });

  test('Maarif öğrencisi yalnızca kendi sınıfının Maarif konularını görür', () {
    final ids = [
      for (final t in topicsForGrade(all, 9, curriculum: curriculumMaarif))
        t.id,
    ];
    expect(ids, [10]);
    final ids10 = [
      for (final t in topicsForGrade(all, 10, curriculum: curriculumMaarif))
        t.id,
    ];
    expect(ids10, [11]);
    // 12. sınıfta Maarif seçilirse yalnızca 12. sınıf Maarif konuları gelir.
    expect(topicsForGrade(all, 12, curriculum: curriculumMaarif), isEmpty);
  });

  test('eski müfredatta Maarif konuları hiç görünmez', () {
    final ids12 = [for (final t in topicsForGrade(all, 12)) t.id];
    expect(ids12, [1, 2]);
    // Varsayılan (parametresiz) çağrı eski davranışı korur.
    expect(topicsForGrade(all, null).any((t) => t.isMaarif), isFalse);
    // 9. sınıf, eski müfredat: eşlemedeki konular (Kümeler 9. sınıf).
    expect(
      [
        for (final t in topicsForGrade(all, 9, curriculum: curriculumEski))
          t.id,
      ],
      [1],
    );
  });

  test('toplu ödev: her öğrenciye ayrı kayıt ve bildirim, sınır 30', () async {
    final notifications = InMemoryNotificationRepository();
    final repo = InMemoryAssignmentRepository(notifications: notifications);
    const items = [
      AssignmentItemDraft(
        subjectCode: 'TYT_MAT',
        topicId: 10,
        topicName: 'Sayı Kümeleri ve İşlem Özellikleri',
        note: '2 test',
      ),
    ];
    final ids = await repo.sendAssignmentToMany(
      studentIds: ['a', 'b', 'a'],
      title: 'Haftalık ödev',
      items: items,
    );
    expect(ids, hasLength(2), reason: 'yinelenen öğrenci tek sayılır');
    for (final s in ['a', 'b']) {
      final list = await repo.fetchAssignments(s);
      expect(list, hasLength(1));
      expect(list.single.items.single.questionCount, isNull);
      expect(list.single.items.single.note, '2 test');
    }
    expect(
      () => repo.sendAssignmentToMany(
        studentIds: [for (var i = 0; i < 31; i++) 's$i'],
        title: 'x',
        items: items,
      ),
      throwsStateError,
    );
    expect(
      () => repo.sendAssignmentToMany(studentIds: [], title: 'x', items: items),
      throwsStateError,
    );
  });
}
