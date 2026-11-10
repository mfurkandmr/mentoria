import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';

/// Kurum müdürü kokpiti (NOTLAR §59). Sunucuda tek çağrı: `admin_cockpit()`.
///
/// "Bu hafta" son 7 gün, "geçen hafta" ondan önceki 7 gündür (öğrenci
/// özetleriyle aynı). Koç görüşmeleri pazartesi başlayan bu haftadır.
class CockpitData {
  const CockpitData({
    required this.students,
    required this.studentsPrev,
    required this.active,
    required this.activePrev,
    required this.questions,
    required this.questionsPrev,
    required this.minutes,
    required this.minutesPrev,
    this.examPlans = const [],
    this.inactive = const [],
    this.netDrops = const [],
    this.overdue = const [],
    this.coaches = const [],
  });

  factory CockpitData.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) => [
      for (final r in (j[key] as List? ?? const []))
        f(Map<String, dynamic>.from(r as Map)),
    ];
    return CockpitData(
      students: _int(j['students']),
      studentsPrev: _int(j['students_prev']),
      active: _int(j['active']),
      activePrev: _int(j['active_prev']),
      questions: _int(j['questions']),
      questionsPrev: _int(j['questions_prev']),
      minutes: _int(j['minutes']),
      minutesPrev: _int(j['minutes_prev']),
      examPlans: list('exam_plans', ExamPlan.fromJson),
      inactive: list('inactive', InactiveStudent.fromJson),
      netDrops: list('net_drops', NetDropStudent.fromJson),
      overdue: list('overdue', OverdueStudent.fromJson),
      coaches: list('coaches', CoachStat.fromJson),
    );
  }

  final int students;

  /// 7 gün önce kayıtlı olan öğrenci sayısı.
  final int studentsPrev;
  final int active;
  final int activePrev;
  final int questions;
  final int questionsPrev;
  final int minutes;
  final int minutesPrev;

  /// Bugünden itibaren planlı denemeler, en yakını önce.
  final List<ExamPlan> examPlans;

  /// 7+ gündür uygulamaya girmeyenler (hiç girmeyen önce).
  final List<InactiveStudent> inactive;

  /// Son iki denemede (aynı tür) 3+ net düşenler; en çok düşen önce.
  final List<NetDropStudent> netDrops;

  /// Vadesi geçmiş, ödenmemiş taksiti olanlar; en eski önce.
  final List<OverdueStudent> overdue;
  final List<CoachStat> coaches;

  ExamPlan? get nextExam => examPlans.isEmpty ? null : examPlans.first;

  int get attentionCount => inactive.length + netDrops.length + overdue.length;
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double _double(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime? _date(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

class ExamPlan {
  const ExamPlan({
    required this.id,
    required this.name,
    required this.examType,
    required this.plannedOn,
  });

  factory ExamPlan.fromJson(Map<String, dynamic> j) => ExamPlan(
    id: j['id'] as String,
    name: j['name'] as String,
    examType: ExamType.fromDb(j['exam_type'] as String? ?? 'TYT'),
    plannedOn: DateTime.parse(j['planned_on'] as String),
  );

  final String id;
  final String name;
  final ExamType examType;
  final DateTime plannedOn;

  /// Bugünden kaç gün sonra (bugün 0).
  int daysFrom(DateTime now) => DateTime(
    plannedOn.year,
    plannedOn.month,
    plannedOn.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
}

/// Dikkat listesindeki her satırın ortak alanları.
sealed class AttentionStudent {
  const AttentionStudent({
    required this.studentId,
    required this.name,
    this.coachId,
    this.coachName,
  });

  final String studentId;
  final String name;
  final String? coachId;
  final String? coachName;
}

class InactiveStudent extends AttentionStudent {
  const InactiveStudent({
    required super.studentId,
    required super.name,
    super.coachId,
    super.coachName,
    this.seenAt,
  });

  factory InactiveStudent.fromJson(Map<String, dynamic> j) => InactiveStudent(
    studentId: j['student_id'] as String,
    name: j['full_name'] as String? ?? '',
    coachId: j['coach_id'] as String?,
    coachName: j['coach_name'] as String?,
    seenAt: _date(j['seen_at']),
  );

  /// Son açılış ya da son çalışma kaydı; hiç yoksa null.
  final DateTime? seenAt;

  int? daysSince(DateTime now) =>
      seenAt == null ? null : now.difference(seenAt!).inDays;
}

class NetDropStudent extends AttentionStudent {
  const NetDropStudent({
    required super.studentId,
    required super.name,
    super.coachId,
    super.coachName,
    required this.examType,
    required this.lastNet,
    required this.prevNet,
  });

  factory NetDropStudent.fromJson(Map<String, dynamic> j) => NetDropStudent(
    studentId: j['student_id'] as String,
    name: j['full_name'] as String? ?? '',
    coachId: j['coach_id'] as String?,
    coachName: j['coach_name'] as String?,
    examType: ExamType.fromDb(j['exam_type'] as String? ?? 'TYT'),
    lastNet: _double(j['last_net']),
    prevNet: _double(j['prev_net']),
  );

  final ExamType examType;
  final double lastNet;
  final double prevNet;

  double get drop => prevNet - lastNet;
}

class OverdueStudent extends AttentionStudent {
  const OverdueStudent({
    required super.studentId,
    required super.name,
    super.coachId,
    super.coachName,
    required this.count,
    required this.amount,
    this.oldestDue,
  });

  factory OverdueStudent.fromJson(Map<String, dynamic> j) => OverdueStudent(
    studentId: j['student_id'] as String,
    name: j['full_name'] as String? ?? '',
    coachId: j['coach_id'] as String?,
    coachName: j['coach_name'] as String?,
    count: _int(j['count']),
    amount: _double(j['amount']),
    oldestDue: j['oldest_due'] == null
        ? null
        : DateTime.parse(j['oldest_due'] as String),
  );

  final int count;
  final double amount;
  final DateTime? oldestDue;
}

class CoachStat {
  const CoachStat({
    required this.coachId,
    required this.name,
    required this.students,
    required this.active,
    required this.meetingsPlanned,
    required this.meetingsHeld,
    this.phone,
  });

  factory CoachStat.fromJson(Map<String, dynamic> j) => CoachStat(
    coachId: j['coach_id'] as String,
    name: j['full_name'] as String? ?? '',
    phone: j['phone'] as String?,
    students: _int(j['students']),
    active: _int(j['active']),
    meetingsPlanned: _int(j['meetings_planned']),
    meetingsHeld: _int(j['meetings_held']),
  );

  final String coachId;
  final String name;
  final String? phone;
  final int students;

  /// Bu hafta aktif öğrencisi.
  final int active;
  final int meetingsPlanned;
  final int meetingsHeld;

  /// Öğrencilerinin aktiflik oranı (öğrencisi yoksa null).
  double? get activeRatio => students == 0 ? null : active / students;
}

/// Eğilim grafiğinin bir haftası (7 günlük dilim, [end] dahil).
class ActivityWeek {
  const ActivityWeek({
    required this.start,
    required this.end,
    required this.students,
    required this.active,
    required this.questions,
  });

  factory ActivityWeek.fromJson(Map<String, dynamic> j) => ActivityWeek(
    start: DateTime.parse(j['start'] as String),
    end: DateTime.parse(j['end'] as String),
    students: _int(j['students']),
    active: _int(j['active']),
    questions: _int(j['questions']),
  );

  final DateTime start;
  final DateTime end;

  /// O haftanın sonunda kayıtlı öğrenci.
  final int students;
  final int active;
  final int questions;
}

abstract interface class CockpitRepository {
  Future<CockpitData> fetch();

  /// Son [weeks] hafta, en eskisi önce (müdür: kurum, koç: kendi öğrencileri).
  Future<List<ActivityWeek>> fetchWeeks({int weeks = 8});

  Future<void> addExamPlan(String name, ExamType type, DateTime on);

  Future<void> deleteExamPlan(String id);

  /// [phone] null ya da boşsa numara silinir. Biçim: +905321112233.
  Future<void> setCoachPhone(String coachId, String? phone);

  /// Koça uygulama içi bildirim + push. Aynı öğrenci için 6 saatte bir
  /// (`COACH_ALERT_RECENT`).
  Future<void> notifyCoach(String studentId, String reason);
}

class SupabaseCockpitRepository implements CockpitRepository {
  SupabaseCockpitRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CockpitData> fetch() async {
    final r = await _client.rpc('admin_cockpit');
    return CockpitData.fromJson(Map<String, dynamic>.from(r as Map));
  }

  @override
  Future<List<ActivityWeek>> fetchWeeks({int weeks = 8}) async {
    final r = await _client.rpc('activity_weeks', params: {'p_weeks': weeks});
    return [
      for (final w in r as List)
        ActivityWeek.fromJson(Map<String, dynamic>.from(w as Map)),
    ];
  }

  @override
  Future<void> addExamPlan(String name, ExamType type, DateTime on) =>
      _client.rpc(
        'add_exam_plan',
        params: {'p_name': name.trim(), 'p_type': type.db, 'p_on': _ymd(on)},
      );

  @override
  Future<void> deleteExamPlan(String id) =>
      _client.rpc('delete_exam_plan', params: {'p_id': id});

  @override
  Future<void> setCoachPhone(String coachId, String? phone) => _client.rpc(
    'set_coach_phone',
    params: {'p_coach': coachId, 'p_phone': phone},
  );

  @override
  Future<void> notifyCoach(String studentId, String reason) => _client.rpc(
    'notify_coach_about_student',
    params: {'p_student': studentId, 'p_reason': reason},
  );
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final cockpitRepositoryProvider = Provider<CockpitRepository>(
  (ref) => SupabaseCockpitRepository(sessionClient(ref)),
);

final cockpitProvider = FutureProvider.autoDispose<CockpitData>(
  (ref) => ref.watch(cockpitRepositoryProvider).fetch(),
);

/// Son 8 haftanın etkinliği (kokpit eğilim grafiği).
final activityWeeksProvider = FutureProvider.autoDispose<List<ActivityWeek>>(
  (ref) => ref.watch(cockpitRepositoryProvider).fetchWeeks(),
);
