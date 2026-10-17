import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/config/env.dart';
import '../core/constants/exam_subjects.dart';
import '../features/assignments/data/assignment_repository.dart';
import '../features/avatar/data/avatar_repository.dart';
import '../features/ranking/data/ranking_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/notifications/data/notification_repository.dart';
import '../features/tenants/data/tenant_repository.dart';
import '../features/auth/data/profile.dart';
import '../features/coach/data/coach_repository.dart';
import '../features/exams/data/exam.dart';
import '../features/exams/data/exam_repository.dart';
import '../features/account/data/account_repository.dart';
import '../features/admin/data/admin_repository.dart';
import '../features/coaching/data/coaching_repository.dart';
import '../features/meetings/data/meeting_repository.dart';
import '../features/mistakes/data/mistake_repository.dart';
import '../features/learn/data/daily_question_repository.dart';
import '../features/learn/data/practice_repository.dart';
import '../features/tracking/data/tracking_models.dart';
import '../features/tracking/data/tracking_repository.dart';
import 'demo_repositories.dart';

/// Demo modunda Supabase yerine kullanılan sahte veriler.
/// `DEMO_ROLE` = `student` (varsayılan) | `coach` | `admin` | `parent`.
/// [successRanking]: kurumda başarı sıralaması açık mı (testler için).
Future<List<Override>> buildDemoOverrides([
  String? role,
  bool successRanking = true,
]) async {
  role ??= Env.demoRole;
  final exams = InMemoryExamRepository.demo();
  seedDemoBatches(exams);
  final topics = demoTopics();
  final tracking = InMemoryTrackingRepository(topics: topics);
  final notifications = InMemoryNotificationRepository();
  final assignments = InMemoryAssignmentRepository(
    notifications: notifications,
  );
  await seedDemoAssignments(assignments, 'demo-student', topics);
  final coaching = InMemoryCoachingRepository();
  final practice = InMemoryPracticeRepository();
  seedDemoPractice(practice, 'demo-student');
  await seedDemoTracking(tracking, 'demo-student');
  await seedDemoTracking(tracking, 'demo-can', scale: 0.5);
  await seedDemoCoaching(coaching, 'demo-student');
  // Can hesabının silinmesini istemiş (koç panelinde rozet görünsün).
  final deletionRequests = {
    'demo-can': DateTime.now().subtract(const Duration(days: 1)),
  };

  final coach = InMemoryCoachRepository(
    exams,
    demoStudents(),
    tracking: tracking,
    coaching: coaching,
    coaches: {
      'demo-student': 'demo-coach',
      'demo-can': 'demo-coach',
      'demo-zeynep': 'demo-coach-2',
    },
    coachNames: const {
      'demo-coach': 'Ayşe Koç',
      'demo-coach-2': 'Burak Yıldız',
    },
    deletionRequests: deletionRequests,
  );

  final meetingCoaches = {
    'demo-student': 'demo-coach',
    'demo-can': 'demo-coach',
    'demo-zeynep': 'demo-coach-2',
  };
  final meetings = InMemoryMeetingRepository(
    myId: switch (role) {
      'coach' => 'demo-coach',
      'admin' => 'demo-admin',
      'parent' => 'demo-parent',
      _ => 'demo-student',
    },
    canView: switch (role) {
      'coach' => (s) => meetingCoaches[s] == 'demo-coach',
      'admin' => (_) => true,
      _ => (s) => s == 'demo-student',
    },
    names: {
      for (final e in demoStudents().entries) e.key: e.value.$1,
      'demo-coach': 'Ayşe Koç',
      'demo-coach-2': 'Burak Yıldız',
    },
  );
  seedDemoMeetings(meetings);
  final mistakes = InMemoryMistakeRepository(
    canView: switch (role) {
      'coach' => (s) => meetingCoaches[s] == 'demo-coach',
      'admin' => (_) => true,
      _ => (s) => s == 'demo-student',
    },
  );
  seedDemoMistakes(mistakes);
  // Öğrenciye yarınki görüşmenin hatırlatması.
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  notifications.add(
    'demo-student',
    NotificationKind.meeting,
    {
      'coach': 'Ayşe Koç',
      'at': DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        11,
      ).toUtc().toIso8601String(),
      'route': '/student',
    },
    at: DateTime.now().subtract(const Duration(hours: 1)),
  );

  final profile = switch (role) {
    'coach' => const Profile(
      id: 'demo-coach',
      fullName: 'Ayşe Koç',
      role: UserRole.coach,
    ),
    'admin' => const Profile(
      id: 'demo-admin',
      fullName: 'Mehmet Demir',
      role: UserRole.admin,
    ),
    'parent' => const Profile(
      id: 'demo-parent',
      fullName: 'Selin Yılmaz',
      role: UserRole.parent,
    ),
    _ => const Profile(
      id: 'demo-student',
      fullName: 'Elif Yılmaz',
      role: UserRole.student,
    ),
  };

  final account = InMemoryAccountRepository(
    ProfileDetails(
      fullName: profile.fullName,
      examYear: role == 'student' ? 2027 : null,
      field: role == 'student' ? FieldType.say : null,
    ),
    children: const [ChildRef(id: 'demo-student', fullName: 'Elif Yılmaz')],
    userId: profile.id,
    deletionRequests: deletionRequests,
  );

  final now = DateTime.now();
  final admin = InMemoryAdminRepository(
    OrgInfo(
      id: 'demo-org',
      name: 'Bal Akademi',
      seatLimit: 50,
      licenseExpiresAt: DateTime(now.year + 1, now.month, now.day),
    ),
    [
      OrgMember(
        id: 'demo-admin',
        fullName: 'Mehmet Demir',
        role: UserRole.admin,
        createdAt: now,
      ),
      OrgMember(
        id: 'demo-coach',
        fullName: 'Ayşe Koç',
        role: UserRole.coach,
        createdAt: now,
      ),
      OrgMember(
        id: 'demo-coach-2',
        fullName: 'Burak Yıldız',
        role: UserRole.coach,
        createdAt: now,
      ),
      for (final e in demoStudents().entries)
        OrgMember(
          id: e.key,
          fullName: e.value.$1,
          role: UserRole.student,
          createdAt: now,
        ),
      OrgMember(
        id: 'demo-parent',
        fullName: 'Selin Yılmaz',
        role: UserRole.parent,
        createdAt: now,
      ),
    ],
    onReassign: coach.reassign,
  );

  // Demo öğrencisi: 3 gün seri saçı ve ilk deneme kıyafeti açık; ekranı
  // açınca 1000 soru pelerini "yeni açıldı" olarak kazanır.
  // Başarı sıralaması demoda açık; demo öğrencisi TYT'de 1. (kral tacı).
  late final InMemoryAvatarRepository avatars;
  final ranking = InMemorySuccessRankingRepository(
    enabled: successRanking,
    isAdmin: role == 'admin',
    myId: profile.id,
    myAvatar: () => avatars.myAvatar,
  );
  avatars = InMemoryAvatarRepository(
    avatar: role == 'student' ? {'hair': 4, 'skin': 7, 'outfit': 12} : null,
    unlocked: role == 'student' ? {4, 12} : {},
    pendingUnlocks: role == 'student' ? [14] : [],
    rewardRanks: ranking.rewardRanks,
  );

  return [
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: profile.id,
        fullName: profile.fullName,
        role: profile.role,
        avatar: avatars.myAvatar,
      ),
    ),
    avatarRepositoryProvider.overrideWithValue(avatars),
    successRankingRepositoryProvider.overrideWithValue(ranking),
    examRepositoryProvider.overrideWithValue(exams),
    coachRepositoryProvider.overrideWithValue(coach),
    trackingRepositoryProvider.overrideWithValue(tracking),
    coachingRepositoryProvider.overrideWithValue(coaching),
    accountRepositoryProvider.overrideWithValue(account),
    adminRepositoryProvider.overrideWithValue(admin),
    assignmentRepositoryProvider.overrideWithValue(assignments),
    notificationRepositoryProvider.overrideWithValue(notifications),
    meetingRepositoryProvider.overrideWithValue(meetings),
    mistakeRepositoryProvider.overrideWithValue(mistakes),
    practiceRepositoryProvider.overrideWithValue(practice),
    dailyQuestionRepositoryProvider.overrideWithValue(
      InMemoryDailyQuestionRepository(
        myId: role == 'student' ? 'demo-student' : null,
        pastCorrectDays: 4,
      ),
    ),
    tenantRepositoryProvider.overrideWithValue(
      InMemoryTenantRepository(
        tenants: demoTenants(),
        myTenantId: Env.demoTenant == 'yildiz' ? 'demo-yildiz' : 'demo-tenant',
        // Demo müdürü dershane yönetim panelini de görebilsin.
        superAdmin: role == 'admin',
      ),
    ),
  ];
}

/// Demo koçunun öğrencileri: id → (ad, okul no).
Map<String, (String, String?)> demoStudents() => {
  'demo-student': ('Elif Yılmaz', '1042'),
  'demo-can': ('Can Kaya', null),
  'demo-zeynep': ('Zeynep Arslan', '1077'),
};

/// Bellekte tutulan deneme deposu (demo ve testler için), öğrenci bazında.
class InMemoryExamRepository implements ExamRepository {
  InMemoryExamRepository([Map<String, List<Exam>>? seed])
    : _byStudent = {
        for (final e in (seed ?? {}).entries) e.key: [...e.value],
      };

  factory InMemoryExamRepository.demo() {
    final elif = _demoExams();
    return InMemoryExamRepository({
      'demo-student': elif,
      // Can: ilk üç TYT denemesine benzer, daha düşük netler.
      'demo-can': [
        for (final e in elif.where((e) => e.examType == ExamType.tyt).take(3))
          Exam(
            id: 'can-${e.id}',
            examType: e.examType,
            name: e.name,
            publisher: e.publisher,
            takenOn: e.takenOn,
            results: [
              for (final r in e.results)
                SubjectResult(
                  code: r.code,
                  correct: (r.correct * 0.8).floor(),
                  wrong: r.wrong,
                  blank: r.blank + r.correct - (r.correct * 0.8).floor(),
                ),
            ],
          ),
      ],
    });
  }

  final Map<String, List<Exam>> _byStudent;
  int _nextId = 1000;

  /// Bu oturumda (koçun/müdürün kendisi) girilen denemeler: deneme id → paket.
  final Map<String, String> _batchOf = {};

  List<Exam> examsOf(String studentId) => _byStudent[studentId] ?? const [];

  @override
  Future<List<Exam>> fetchExams({required String studentId}) async =>
      [...examsOf(studentId)]..sort((a, b) => Exam.byDate(b, a));

  @override
  Future<void> createExam({
    required String studentId,
    required ExamDraft draft,
  }) async => seedMine(
    studentId,
    draft,
    batchId: draft.batchId ?? newBatchId(),
    createdAt: DateTime.now(),
  );

  /// Kendi girdiğim bir deneme ekler (demo için geçmiş tarihli de olabilir).
  void seedMine(
    String studentId,
    ExamDraft draft, {
    required String batchId,
    required DateTime createdAt,
  }) {
    final id = '${_nextId++}';
    _batchOf[id] = batchId;
    _byStudent
        .putIfAbsent(studentId, () => [])
        .add(
          Exam(
            id: id,
            examType: draft.examType,
            field: draft.field,
            name: draft.name,
            publisher: draft.publisher,
            takenOn: draft.takenOn,
            results: draft.results,
            createdAt: createdAt,
          ),
        );
  }

  Iterable<Exam> get _all => _byStudent.values.expand((l) => l);

  @override
  Future<void> deleteExam(String examId) async {
    final exam = _all.where((e) => e.id == examId).firstOrNull;
    if (exam == null) return;
    if (!exam.editable) throw const ExamLockedException();
    for (final list in _byStudent.values) {
      list.removeWhere((e) => e.id == examId);
    }
    _batchOf.remove(examId);
  }

  @override
  Future<List<ExamBatch>> fetchMyBatches({
    int limit = 30,
    int offset = 0,
  }) async {
    final groups = <String, List<Exam>>{};
    for (final e in _all) {
      final b = _batchOf[e.id];
      if (b != null) groups.putIfAbsent(b, () => []).add(e);
    }
    final batches = [
      for (final MapEntry(key: id, value: exams) in groups.entries)
        _batch(id, exams),
    ]..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return batches.skip(offset).take(limit).toList();
  }

  ExamBatch _batch(String id, List<Exam> exams) {
    final first = exams.reduce(
      (a, b) => a.createdAt!.isBefore(b.createdAt!) ? a : b,
    );
    final last = exams.reduce(
      (a, b) => a.createdAt!.isAfter(b.createdAt!) ? a : b,
    );
    return ExamBatch(
      id: id,
      name: first.name,
      examType: first.examType,
      field: first.field,
      publisher: first.publisher,
      takenOn: first.takenOn,
      imported: exams.length > 1,
      uploadedAt: last.createdAt!,
      studentCount: exams.length,
      avgNet: exams.fold<double>(0, (s, e) => s + e.totalNet) / exams.length,
      editableUntil: first.createdAt!.add(Exam.editWindow),
      editable: exams.every((e) => e.editable),
    );
  }

  @override
  Future<int> deleteBatch(String batchId) async {
    final ids = {
      for (final e in _batchOf.entries)
        if (e.value == batchId) e.key,
    };
    final exams = _all.where((e) => ids.contains(e.id)).toList();
    if (exams.isEmpty) throw StateError('BATCH_NOT_FOUND');
    if (exams.any((e) => !e.editable)) throw const ExamLockedException();
    for (final list in _byStudent.values) {
      list.removeWhere((e) => ids.contains(e.id));
    }
    ids.forEach(_batchOf.remove);
    return exams.length;
  }
}

/// Bellekte tutulan koç deposu (demo ve testler için).
class InMemoryCoachRepository implements CoachRepository {
  InMemoryCoachRepository(
    this._exams,
    Map<String, (String, String?)> students, {
    this.tracking,
    this.coaching,
    Map<String, String>? coaches,
    this.coachNames = const {},
    Map<String, DateTime>? deletionRequests,
  }) : _students = {...students},
       _coachOf = {...?coaches},
       deletionRequests = deletionRequests ?? {};

  final InMemoryExamRepository _exams;
  final InMemoryTrackingRepository? tracking;
  final InMemoryCoachingRepository? coaching;
  final Map<String, (String, String?)> _students;
  final Map<String, String> _coachOf;
  final Map<String, String> coachNames;

  /// Öğrenci deposuyla paylaşılır: öğrencinin talebi koçta görünür.
  final Map<String, DateTime> deletionRequests;
  final _invites = <InviteCode>[];

  void reassign(String studentId, String coachId) =>
      _coachOf[studentId] = coachId;

  @override
  Future<List<StudentSummary>> fetchStudents() async {
    final weekAgo = dateOnly(DateTime.now()).subtract(const Duration(days: 6));
    final list = [
      for (final e in _students.entries)
        () {
          final exams = [..._exams.examsOf(e.key)]
            ..sort((a, b) => Exam.byDate(b, a));
          final last = exams.firstOrNull;
          final logs = tracking?.logsOf(e.key) ?? const [];
          final sessions = tracking?.sessionsOf(e.key) ?? const [];
          final coachId = _coachOf[e.key];
          return StudentSummary(
            id: e.key,
            fullName: e.value.$1,
            studentNumber: e.value.$2,
            examCount: exams.length,
            lastExamName: last?.name,
            lastExamType: last?.examType,
            lastTotalNet: last?.totalNet,
            lastTakenOn: last?.takenOn,
            weekQuestions: logs
                .where((l) => !l.loggedOn.isBefore(weekAgo))
                .fold(0, (s, l) => s + l.total),
            weekMinutes:
                sessions
                    .where((x) => !x.startedAt.isBefore(weekAgo))
                    .fold(0, (s, x) => s + x.durationSec) ~/
                60,
            pendingTasks: coaching?.pendingOf(e.key) ?? 0,
            coachId: coachId,
            coachName: coachNames[coachId],
          );
        }(),
    ];
    return list..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  Future<void> setStudentNumber(String studentId, String? number) async {
    final value = number?.trim().toUpperCase();
    final taken = _students.entries.any(
      (e) => e.key != studentId && value != null && e.value.$2 == value,
    );
    if (taken) {
      throw const StudentNumberException(
        'Bu numara kurumda başka bir öğrenciye ait.',
      );
    }
    final current = _students[studentId]!;
    _students[studentId] = (current.$1, value);
  }

  @override
  Future<String> createStudentInvite({int maxUses = 1}) async {
    final code = 'DEMO${1000 + _invites.length}';
    _invites.insert(
      0,
      InviteCode(
        code: code,
        maxUses: maxUses,
        usedCount: 0,
        expiresAt: DateTime.now().add(const Duration(days: 14)),
      ),
    );
    return code;
  }

  @override
  Future<List<InviteCode>> fetchActiveStudentInvites() async => [..._invites];

  @override
  Future<void> deleteStudent(String studentId) async {
    _students.remove(studentId);
    _coachOf.remove(studentId);
    deletionRequests.remove(studentId);
  }

  @override
  Future<Map<String, DateTime>> fetchDeletionRequests() async => {
    for (final e in deletionRequests.entries)
      if (_students.containsKey(e.key)) e.key: e.value,
  };
}

List<Exam> _demoExams() {
  final today = DateTime.now();
  DateTime daysAgo(int d) => DateTime(today.year, today.month, today.day - d);

  SubjectResult r(String code, int correct, int wrong) {
    final total = subjectByCode(code).questionCount;
    return SubjectResult(
      code: code,
      correct: correct,
      wrong: wrong,
      blank: total - correct - wrong,
    );
  }

  // [türkçe D/Y, sosyal D (4 ders), mat D/Y, fen D (3 ders)]
  const tyt = [
    (24, 8, [3, 2, 3, 4], 14, 10, [3, 3, 2]),
    (26, 7, [3, 3, 3, 4], 15, 9, [3, 3, 3]),
    (25, 6, [4, 3, 3, 4], 18, 8, [4, 3, 3]),
    (28, 6, [4, 3, 3, 5], 17, 9, [4, 4, 3]),
    (29, 5, [4, 3, 4, 5], 20, 7, [4, 4, 4]),
    (31, 4, [4, 4, 4, 5], 21, 8, [5, 4, 4]),
    (30, 5, [4, 4, 4, 5], 23, 6, [5, 5, 4]),
    (33, 4, [4, 4, 4, 5], 24, 6, [5, 5, 5]),
  ];
  const publishers = ['3D', 'Limit', 'Bilgi Sarmal', 'Özdebir'];

  return [
    for (var i = 0; i < tyt.length; i++)
      Exam(
        id: 'tyt-$i',
        examType: ExamType.tyt,
        name: 'Türkiye Geneli TYT ${i + 1}',
        publisher: publishers[i % publishers.length],
        takenOn: daysAgo(7 * (tyt.length - i)),
        results: [
          r('TYT_TUR', tyt[i].$1, tyt[i].$2),
          r('TYT_TAR', tyt[i].$3[0], 1),
          r('TYT_COG', tyt[i].$3[1], 1),
          r('TYT_FEL', tyt[i].$3[2], 1),
          r('TYT_DIN', tyt[i].$3[3], 0),
          r('TYT_MAT', tyt[i].$4, tyt[i].$5),
          r('TYT_FIZ', tyt[i].$6[0], 2),
          r('TYT_KIM', tyt[i].$6[1], 1),
          r('TYT_BIY', tyt[i].$6[2], 1),
        ],
      ),
    for (var i = 0; i < 4; i++)
      Exam(
        id: 'ayt-$i',
        examType: ExamType.ayt,
        field: FieldType.say,
        name: 'AYT Sayısal Deneme ${i + 1}',
        publisher: publishers[(i + 1) % publishers.length],
        takenOn: daysAgo(14 * (4 - i) + 3),
        results: [
          r('AYT_MAT', 14 + i * 3, 8 - i),
          r('AYT_FIZ', 5 + i, 4),
          r('AYT_KIM', 6 + i, 3),
          r('AYT_BIY', 7 + i, 3),
        ],
      ),
  ];
}

/// Demo koçunun yüklemeleri (Denemeler ekranı): 2 gün önceki Excel yüklemesi
/// silinebilir, 12 gün önceki kilitli.
void seedDemoBatches(InMemoryExamRepository exams) {
  final now = DateTime.now();
  ExamDraft draft(String name, DateTime day, int mat, int tur) => ExamDraft(
    examType: ExamType.tyt,
    name: name,
    publisher: 'Bilgi Sarmal',
    takenOn: DateTime(day.year, day.month, day.day),
    imported: true,
    results: [
      SubjectResult(code: 'TYT_TUR', correct: tur, wrong: 4, blank: 0),
      SubjectResult(code: 'TYT_MAT', correct: mat, wrong: 6, blank: 0),
    ],
  );
  final recent = now.subtract(const Duration(days: 2));
  final old = now.subtract(const Duration(days: 12));
  for (final (student, mat, tur) in [
    ('demo-student', 31, 34),
    ('demo-can', 22, 28),
  ]) {
    exams.seedMine(
      student,
      draft('Bilgi Sarmal TYT-6', recent, mat, tur),
      batchId: 'demo-batch-recent',
      createdAt: recent,
    );
    exams.seedMine(
      student,
      draft('Bilgi Sarmal TYT-5', old, mat - 3, tur - 2),
      batchId: 'demo-batch-old',
      createdAt: old,
    );
  }
}

/// Demo öğrencisinin hata defteri: bugün tekrarı gelen, ilerleyen ve
/// öğrenilmiş kartlar (fotoğrafsız; yer tutucu çizilir).
void seedDemoMistakes(InMemoryMistakeRepository repo) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  MistakeCard card(
    int i,
    String subject,
    String note, {
    int stage = 0,
    int dueIn = 0,
    int fails = 0,
    bool mastered = false,
  }) => MistakeCard(
    id: 'demo-mistake-$i',
    studentId: 'demo-student',
    subjectCode: subject,
    note: note,
    stage: mastered ? 4 : stage,
    fails: fails,
    dueOn: today.add(Duration(days: dueIn)),
    createdAt: now.subtract(Duration(days: 10 + i)),
    masteredAt: mastered ? now.subtract(const Duration(days: 2)) : null,
  );
  repo.cards.addAll([
    card(
      1,
      'TYT_MAT',
      'Problemler: yaş problemi, denklemi ters kurdum',
      fails: 1,
    ),
    card(
      2,
      'TYT_FIZ',
      'Kuvvet ve hareket: sürtünme yönünü karıştırdım',
      stage: 1,
    ),
    card(
      3,
      'TYT_TUR',
      'Paragraf: ana düşünce, iki şık arasında kaldım',
      stage: 2,
      dueIn: 4,
    ),
    card(4, 'TYT_KIM', 'Mol hesabı: birim dönüşümü', stage: 1, dueIn: 2),
    card(5, 'TYT_MAT', 'Üslü sayılar: negatif üs', mastered: true),
  ]);
}
