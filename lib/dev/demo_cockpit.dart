import '../core/constants/exam_subjects.dart';
import '../features/admin/data/cockpit_repository.dart';

/// Bellekte müdür kokpiti (demo ve testler için).
class InMemoryCockpitRepository implements CockpitRepository {
  InMemoryCockpitRepository({
    CockpitData? data,
    this.error,
    List<ActivityWeek>? weeks,
  }) : _data = data ?? demoCockpitData(),
       weeks = weeks ?? demoActivityWeeks();

  /// Eğilim grafiği verisi (en eskisi önce).
  List<ActivityWeek> weeks;

  /// Testler hata halini görmek için verir; fetch bunu fırlatır.
  Object? error;
  CockpitData _data;

  /// Gönderilen koç bildirimleri: (öğrenci, sebep).
  final notified = <(String, String)>[];
  final _lastNotified = <String, DateTime>{};
  var _seq = 0;

  @override
  Future<CockpitData> fetch() async {
    if (error != null) throw error!;
    return _data;
  }

  @override
  Future<List<ActivityWeek>> fetchWeeks({int weeks = 8}) async {
    if (error != null) throw error!;
    final all = this.weeks;
    return all.length <= weeks ? all : all.sublist(all.length - weeks);
  }

  @override
  Future<void> addExamPlan(String name, ExamType type, DateTime on) async {
    final today = DateTime.now();
    if (on.isBefore(DateTime(today.year, today.month, today.day - 1))) {
      throw Exception('EXAM_PLAN_BAD_DATE');
    }
    final plans = [
      ..._data.examPlans,
      ExamPlan(
        id: 'plan-${++_seq}',
        name: name.trim(),
        examType: type,
        plannedOn: DateTime(on.year, on.month, on.day),
      ),
    ]..sort((a, b) => a.plannedOn.compareTo(b.plannedOn));
    _data = _copy(examPlans: plans);
  }

  @override
  Future<void> deleteExamPlan(String id) async {
    _data = _copy(
      examPlans: [
        for (final p in _data.examPlans)
          if (p.id != id) p,
      ],
    );
  }

  @override
  Future<void> setCoachPhone(String coachId, String? phone) async {
    final p = (phone ?? '').trim();
    if (p.isNotEmpty && !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(p)) {
      throw Exception('check constraint');
    }
    _data = _copy(
      coaches: [
        for (final c in _data.coaches)
          c.coachId == coachId
              ? CoachStat(
                  coachId: c.coachId,
                  name: c.name,
                  phone: p.isEmpty ? null : p,
                  students: c.students,
                  active: c.active,
                  meetingsPlanned: c.meetingsPlanned,
                  meetingsHeld: c.meetingsHeld,
                )
              : c,
      ],
    );
  }

  @override
  Future<void> notifyCoach(String studentId, String reason) async {
    final last = _lastNotified[studentId];
    if (last != null && DateTime.now().difference(last).inHours < 6) {
      throw Exception('COACH_ALERT_RECENT');
    }
    _lastNotified[studentId] = DateTime.now();
    notified.add((studentId, reason));
  }

  CockpitData _copy({List<ExamPlan>? examPlans, List<CoachStat>? coaches}) =>
      CockpitData(
        students: _data.students,
        studentsPrev: _data.studentsPrev,
        active: _data.active,
        activePrev: _data.activePrev,
        questions: _data.questions,
        questionsPrev: _data.questionsPrev,
        minutes: _data.minutes,
        minutesPrev: _data.minutesPrev,
        examPlans: examPlans ?? _data.examPlans,
        inactive: _data.inactive,
        netDrops: _data.netDrops,
        overdue: _data.overdue,
        coaches: coaches ?? _data.coaches,
      );
}

/// Demo: son 8 hafta (en eskisi önce), bu hafta 3 öğrencinin 2'si aktif.
List<ActivityWeek> demoActivityWeeks() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  const active = [1, 2, 2, 3, 2, 3, 3, 2];
  const questions = [420, 610, 700, 980, 860, 1150, 1105, 1240];
  return [
    for (var i = 0; i < 8; i++)
      ActivityWeek(
        start: today.subtract(Duration(days: 7 * (8 - i) - 1)),
        end: today.subtract(Duration(days: 7 * (7 - i))),
        students: 3,
        active: active[i],
        questions: questions[i],
      ),
  ];
}

/// Demo kurumu: 3 öğrenci, 2 koç; her dikkat listesinde bir öğrenci.
CockpitData demoCockpitData() {
  final now = DateTime.now();
  return CockpitData(
    students: 3,
    studentsPrev: 3,
    active: 2,
    activePrev: 3,
    questions: 1240,
    questionsPrev: 1105,
    minutes: 1530,
    minutesPrev: 1610,
    examPlans: [
      ExamPlan(
        id: 'plan-demo-1',
        name: 'TYT Genel Deneme 4',
        examType: ExamType.tyt,
        plannedOn: DateTime(now.year, now.month, now.day + 3),
      ),
      ExamPlan(
        id: 'plan-demo-2',
        name: 'AYT Genel Deneme 2',
        examType: ExamType.ayt,
        plannedOn: DateTime(now.year, now.month, now.day + 10),
      ),
    ],
    inactive: [
      InactiveStudent(
        studentId: 'demo-can',
        name: 'Can Kaya',
        coachId: 'demo-coach',
        coachName: 'Ayşe Koç',
        seenAt: now.subtract(const Duration(days: 9)),
      ),
    ],
    netDrops: const [
      NetDropStudent(
        studentId: 'demo-zeynep',
        name: 'Zeynep Arslan',
        coachId: 'demo-coach-2',
        coachName: 'Burak Yıldız',
        examType: ExamType.tyt,
        lastNet: 61.5,
        prevNet: 68,
      ),
    ],
    overdue: [
      OverdueStudent(
        studentId: 'demo-can',
        name: 'Can Kaya',
        coachId: 'demo-coach',
        coachName: 'Ayşe Koç',
        count: 2,
        amount: 4500,
        oldestDue: DateTime(now.year, now.month, now.day - 12),
      ),
    ],
    coaches: const [
      CoachStat(
        coachId: 'demo-coach',
        name: 'Ayşe Koç',
        phone: '+905321112233',
        students: 2,
        active: 1,
        meetingsPlanned: 4,
        meetingsHeld: 3,
      ),
      CoachStat(
        coachId: 'demo-coach-2',
        name: 'Burak Yıldız',
        students: 1,
        active: 1,
        meetingsPlanned: 2,
        meetingsHeld: 0,
      ),
    ],
  );
}
