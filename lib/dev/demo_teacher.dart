import '../features/teacher/data/teacher_repository.dart';
import 'demo_timetable.dart';

/// Bellekte öğretmen kaydı: [InMemoryTimetableRepository]'deki teachers
/// listesini kullanır (demo ve testler için).
class InMemoryTeacherRepository implements TeacherRepository {
  InMemoryTeacherRepository(
    this.timetable, {
    this.viewerId = 'demo-teacher',
    this.orgName = 'Mentoria Demo Kurumu',
  });

  final InMemoryTimetableRepository timetable;
  final String viewerId;
  final String orgName;

  @override
  Future<MyTeacher?> myTeacher() async {
    final rec = timetable.teacherOf(viewerId);
    if (rec == null) return null;
    return MyTeacher(
      id: rec.teacher.id,
      fullName: rec.teacher.name,
      branches: rec.teacher.branches.toList(),
      orgName: orgName,
    );
  }

  @override
  Future<List<String>> setMyBranches(List<String> branches) async {
    final clean = <String>{
      for (final b in branches)
        if (b.trim().isNotEmpty)
          b.trim().length > 40 ? b.trim().substring(0, 40) : b.trim(),
    }.take(8).toList();
    if (clean.isEmpty) throw StateError('BRANCH_REQUIRED');
    timetable.setBranches(viewerId, clean.toSet());
    return clean;
  }

  @override
  Future<void> mergeTeachers({
    required String keepId,
    required String fromId,
  }) async => timetable.mergeTeachers(keepId, fromId);
}
