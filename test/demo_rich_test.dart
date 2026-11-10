import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_rich.dart';
import 'package:mentoria/features/admin/data/cockpit_repository.dart';
import 'package:mentoria/features/attendance/data/attendance_repository.dart';
import 'package:mentoria/features/coach/data/coach_repository.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/features/exams/data/exam_repository.dart';
import 'package:mentoria/features/exam_analysis/data/exam_report_repository.dart';
import 'package:mentoria/features/exam_analysis/domain/outcome_analysis.dart';
import 'package:mentoria/features/exam_import/domain/exam_scorer.dart';
import 'package:mentoria/features/finance/data/finance_repository.dart';
import 'package:mentoria/features/schedule_generator/data/timetable_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunum demosu: kalabalık kurum tutarlı mı? Küçük demo verisine bağlı testler
/// etkilenmesin diye bayrak yalnızca burada açılır.
void main() {
  late ProviderContainer c;

  setUp(() async {
    demoRichEnabled = true;
    SharedPreferences.setMockInitialValues({});
    c = ProviderContainer(overrides: await buildDemoOverrides('admin'));
  });

  tearDown(() {
    c.dispose();
    demoRichEnabled = false;
  });

  test('24 öğrenci 4 koça ve sınıflara dağılır', () async {
    final students = await c.read(coachRepositoryProvider).fetchStudents();
    expect(students, hasLength(24));
    expect(students.map((s) => s.id).toSet(), hasLength(24));
    expect(students.map((s) => s.coachId).toSet(), hasLength(4));
    expect(students.every((s) => s.coachName != null), isTrue);
    expect(
      students
          .where((s) => s.studentNumber != null)
          .map((s) => s.studentNumber),
      hasLength(23), // Can Kaya'nın numarası bilerek yok.
    );

    final setup = await c.read(timetableRepositoryProvider).fetchSetup();
    final inClass = {for (final r in setup.classrooms) ...r.studentIds};
    expect(inClass, hasLength(24));
  });

  test('deneme sonuçları geçerli ve başarı farklı', () async {
    final exams = c.read(examRepositoryProvider);
    final students = await c.read(coachRepositoryProvider).fetchStudents();
    final lastNets = <double>{};
    for (final s in students) {
      final list = await exams.fetchExams(studentId: s.id);
      expect(list, isNotEmpty, reason: s.fullName);
      lastNets.add(list.first.totalNet);
      for (final e in list) {
        for (final r in e.results) {
          expect(
            r.correct >= 0 && r.wrong >= 0 && r.blank >= 0,
            isTrue,
            reason: '${s.fullName} ${e.name} ${r.code}',
          );
        }
      }
    }
    expect(lastNets.length, greaterThan(10));
  });

  test('kokpit öteki ekranlarla aynı sayıları verir', () async {
    final cockpit = await c.read(cockpitRepositoryProvider).fetch();
    final students = await c.read(coachRepositoryProvider).fetchStudents();
    final fees = await c.read(financeRepositoryProvider).fetchFees();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    expect(cockpit.students, students.length);
    expect(
      cockpit.questions,
      students.fold<int>(0, (a, s) => a + s.weekQuestions),
    );
    expect(cockpit.coaches.fold<int>(0, (a, s) => a + s.students), 24);
    expect(
      cockpit.inactive.map((s) => s.name),
      containsAll(['Nisa Erdem', 'Arda Bulut']),
    );
    expect(cockpit.netDrops, isNotEmpty);
    expect(cockpit.overdue.map((o) => o.studentId).toSet(), {
      for (final f in fees)
        if (f.overdue(today).isNotEmpty) f.studentId,
    });
    final weeks = await c.read(cockpitRepositoryProvider).fetchWeeks();
    expect(weeks, hasLength(8));
    expect(weeks.last.questions, cockpit.questions);
    expect(weeks.last.active, cockpit.active);
    expect(weeks.last.students, cockpit.students);
  });

  test('finans dolu ve geçen ay kurum kârda görünür', () async {
    final repo = c.read(financeRepositoryProvider);
    final fees = await repo.fetchFees();
    final expenses = await repo.fetchExpenses();
    final incomes = await repo.fetchIncomes();
    expect(fees, hasLength(24));
    expect(incomes.length, greaterThan(1));
    expect(expenses.any((e) => e.teacherId != null), isTrue);
    expect(expenses.any((e) => e.coachId == 'demo-coach-3'), isTrue);

    final now = DateTime.now();
    final last = monthSummary(
      fees,
      expenses,
      DateTime(now.year, now.month - 1),
      today: DateTime(now.year, now.month, now.day),
      incomes: incomes,
    );
    expect(last.net, greaterThan(0));
    final teachers = await repo.fetchTeacherPayRates();
    final setup = await c.read(timetableRepositoryProvider).fetchSetup();
    expect(teachers.keys.toSet(), {
      for (final t in setup.teachers) t.teacher.id,
    });
  });

  test('yoklama geçmişi ve veli telefonları dolu', () async {
    final repo = c.read(attendanceRepositoryProvider);
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day - 1);
    if (day.weekday == DateTime.sunday) {
      day = day.subtract(const Duration(days: 1));
    }
    final rows = await repo.fetchDay(day);
    expect(rows, hasLength(24));
    expect(rows.every((r) => r.status != null), isTrue);
    expect(rows.where((r) => r.hasPhone).length, greaterThan(15));
  });

  test('koç yalnızca kendi öğrencilerini görür', () async {
    final coachView = ProviderContainer(
      overrides: await buildDemoOverrides('coach'),
    );
    addTearDown(coachView.dispose);
    final students = await coachView
        .read(coachRepositoryProvider)
        .fetchStudents();
    expect(students, hasLength(8));
    expect(students.every((s) => s.coachId == 'demo-coach'), isTrue);
    final now = DateTime.now();
    final rows = await coachView
        .read(attendanceRepositoryProvider)
        .fetchDay(DateTime(now.year, now.month, now.day));
    expect(rows, hasLength(8));
  });

  test('dikkat listeleri gerçekçi: az gecikme, birkaç net düşüşü', () async {
    final cockpit = await c.read(cockpitRepositoryProvider).fetch();
    expect(cockpit.netDrops.length, inInclusiveRange(2, 6));
    expect(cockpit.overdue.length, lessThanOrEqualTo(9));
  });

  test('demo öğrencisinin son denemesi önceki denemeden düşük değil', () async {
    final list = await c
        .read(examRepositoryProvider)
        .fetchExams(studentId: 'demo-student');
    final tyt = [
      for (final e in list)
        if (e.examType == ExamType.tyt) e,
    ];
    expect(tyt.first.results.length, greaterThan(2));
    expect(tyt.first.totalNet, greaterThanOrEqualTo(tyt[1].totalNet));
  });

  test(
    'kurum sınavı: demo öğrencisi üst sırada, trigonometri yanlışları görünür',
    () async {
      final report = c.read(examReportRepositoryProvider);
      final cards = await report.fetchCards('demo-student');
      final last = cards.reduce((a, b) => b.takenOn.isAfter(a.takenOn) ? b : a);
      expect(last.rankOrg, lessThanOrEqualTo(6));
      final card = await report.fetchCard(last.examId);
      expect(card.responses, hasLength(80));
      final wrong = card.responses.where(
        (r) => r.result == ResponseResult.wrong && r.subject == 'TYT_MAT',
      );
      expect(wrong, isNotEmpty);
      expect(wrong.every((r) => r.outcome == 'Trigonometri'), isTrue);
      expect(lostNetMap(card.outcomes).first.outcome, 'Trigonometri');
    },
  );

  test('bayrak kapalıyken küçük demo değişmez', () {
    demoRichEnabled = false;
    expect(demoStudents(), hasLength(3));
    expect(demoCoachNames(), hasLength(2));
    demoRichEnabled = true;
  });
}
