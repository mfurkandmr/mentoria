import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import '../core/constants/exam_subjects.dart';
import '../core/branding/branding.dart';
import '../core/theme/app_fonts.dart';
import '../features/assignments/data/assignment_repository.dart';
import '../features/avatar/data/avatar_models.dart';
import '../features/avatar/data/avatar_repository.dart';
import '../features/ranking/data/ranking_repository.dart';
import '../features/tenants/data/tenant_repository.dart';
import '../features/notifications/data/notification_repository.dart';
import '../features/account/data/account_repository.dart';
import '../features/admin/data/admin_repository.dart';
import '../features/auth/data/profile.dart';
import '../features/coaching/data/coaching_repository.dart';
import '../features/meetings/data/meeting_repository.dart';
import '../features/mistakes/data/mistake_repository.dart';
import '../features/learn/data/daily_question_repository.dart';
import '../features/learn/data/practice_repository.dart';
import '../features/tracking/data/tracking_models.dart';
import '../features/tracking/data/tracking_repository.dart';

/// Bellekte tutulan takip deposu (demo ve testler için).
class InMemoryTrackingRepository implements TrackingRepository {
  InMemoryTrackingRepository({List<Topic>? topics}) : _topics = topics ?? [];

  final List<Topic> _topics;
  final _logs = <String, List<QuestionLog>>{};
  final _progress = <String, Map<int, TopicStatus>>{};
  final _sessions = <String, List<StudySession>>{};
  final _goals = <String, Goals>{};
  int _id = 1;

  List<QuestionLog> logsOf(String s) => _logs[s] ?? const [];
  List<StudySession> sessionsOf(String s) => _sessions[s] ?? const [];

  @override
  Future<List<QuestionLog>> fetchQuestionLogs(
    String studentId, {
    required DateTime since,
  }) async => [
    for (final l in logsOf(studentId))
      if (!l.loggedOn.isBefore(dateOnly(since))) l,
  ]..sort((a, b) => b.loggedOn.compareTo(a.loggedOn));

  @override
  Future<void> addQuestionLog(String studentId, QuestionLogDraft d) async {
    final topic = _topics.where((t) => t.id == d.topicId).firstOrNull;
    _logs
        .putIfAbsent(studentId, () => [])
        .add(
          QuestionLog(
            id: 'q${_id++}',
            subjectCode: d.subjectCode,
            topicId: d.topicId,
            topicName: topic?.name,
            correct: d.correct,
            wrong: d.wrong,
            blank: d.blank,
            loggedOn: dateOnly(d.loggedOn),
            source: d.source,
          ),
        );
  }

  @override
  Future<void> deleteQuestionLog(String id) async {
    for (final l in _logs.values) {
      l.removeWhere((x) => x.id == id);
    }
  }

  @override
  Future<List<Topic>> fetchTopics() async => [..._topics];

  @override
  Future<Map<int, TopicStatus>> fetchTopicProgress(String studentId) async => {
    ...?_progress[studentId],
  };

  @override
  Future<void> setTopicStatus(
    String studentId,
    int topicId,
    TopicStatus s,
  ) async => _progress.putIfAbsent(studentId, () => {})[topicId] = s;

  @override
  Future<List<StudySession>> fetchSessions(
    String studentId, {
    required DateTime since,
  }) async => [
    for (final s in sessionsOf(studentId))
      if (!s.startedAt.isBefore(since)) s,
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<void> addSession(
    String studentId, {
    required SessionType type,
    required DateTime startedAt,
    required int durationSec,
    String? subjectCode,
  }) async {
    _sessions
        .putIfAbsent(studentId, () => [])
        .add(
          StudySession(
            id: 's${_id++}',
            subjectCode: subjectCode,
            type: type,
            startedAt: startedAt,
            durationSec: durationSec,
          ),
        );
  }

  @override
  Future<void> deleteSession(String id) async {
    for (final l in _sessions.values) {
      l.removeWhere((x) => x.id == id);
    }
  }

  @override
  Future<Goals> fetchGoals(String studentId) async =>
      _goals[studentId] ?? const Goals();

  @override
  Future<void> saveGoals(String studentId, Goals goals) async =>
      _goals[studentId] = goals;
}

/// Bellekte tutulan görev / not deposu.
class InMemoryCoachingRepository implements CoachingRepository {
  final _tasks = <String, List<CoachTask>>{};
  final _notes = <String, List<CoachNote>>{};
  int _id = 1;

  int pendingOf(String s) => (_tasks[s] ?? const [])
      .where((t) => t.status == TaskStatus.pending)
      .length;

  @override
  Future<List<CoachTask>> fetchTasks(String studentId) async =>
      [...?_tasks[studentId]]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> createTask(String studentId, TaskDraft d) async {
    _tasks
        .putIfAbsent(studentId, () => [])
        .add(
          CoachTask(
            id: 't${_id++}',
            title: d.title,
            description: d.description,
            subjectCode: d.subjectCode,
            targetQuestions: d.targetQuestions,
            dueOn: d.dueOn,
            status: TaskStatus.pending,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> setTaskStatus(String taskId, TaskStatus status) async {
    for (final list in _tasks.values) {
      final i = list.indexWhere((t) => t.id == taskId);
      if (i < 0) continue;
      final t = list[i];
      list[i] = CoachTask(
        id: t.id,
        title: t.title,
        description: t.description,
        subjectCode: t.subjectCode,
        targetQuestions: t.targetQuestions,
        dueOn: t.dueOn,
        status: status,
        createdAt: t.createdAt,
        completedAt: status == TaskStatus.done ? DateTime.now() : null,
      );
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    for (final l in _tasks.values) {
      l.removeWhere((t) => t.id == taskId);
    }
  }

  @override
  Future<List<CoachNote>> fetchNotes(String studentId) async =>
      [...?_notes[studentId]]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> addNote(String studentId, String body) async => _notes
      .putIfAbsent(studentId, () => [])
      .add(CoachNote(id: 'n${_id++}', body: body, createdAt: DateTime.now()));

  @override
  Future<void> deleteNote(String noteId) async {
    for (final l in _notes.values) {
      l.removeWhere((n) => n.id == noteId);
    }
  }
}

class InMemoryAccountRepository implements AccountRepository {
  InMemoryAccountRepository(
    this._details, {
    this.children = const [],
    this.userId = 'demo-student',
    Map<String, DateTime>? deletionRequests,
  }) : deletionRequests = deletionRequests ?? {};

  ProfileDetails _details;
  final List<ChildRef> children;
  final String userId;

  /// Koç deposuyla paylaşılan hesap silme talepleri.
  final Map<String, DateTime> deletionRequests;
  final int _parents = 1;
  int _code = 0;

  @override
  Future<ProfileDetails> fetchDetails() async => _details;

  @override
  Future<void> updateDetails(ProfileDetails details) async =>
      _details = details;

  @override
  Future<String> createParentInvite() async => 'VELI${1000 + _code++}';

  @override
  Future<int> parentCount() async => _parents;

  @override
  Future<List<ChildRef>> fetchChildren() async => [...children];

  @override
  Future<DateTime?> fetchDeletionRequest() async => deletionRequests[userId];

  @override
  Future<void> requestAccountDeletion() async =>
      deletionRequests.putIfAbsent(userId, DateTime.now);

  @override
  Future<void> cancelAccountDeletion() async => deletionRequests.remove(userId);
}

class InMemoryAdminRepository implements AdminRepository {
  InMemoryAdminRepository(this._org, this._members, {required this.onReassign});

  OrgInfo _org;
  final List<OrgMember> _members;
  final _invites = <OrgInvite>[];

  /// Öğrencinin koçu değiştiğinde koç deposunu günceller.
  final void Function(String studentId, String coachId) onReassign;

  @override
  Future<OrgInfo> fetchOrg() async => _org;

  @override
  Future<void> renameOrg(String name) async => _org = OrgInfo(
    id: _org.id,
    name: name,
    seatLimit: _org.seatLimit,
    licenseExpiresAt: _org.licenseExpiresAt,
  );

  @override
  Future<List<OrgMember>> fetchMembers() async => [..._members];

  String _add(UserRole role, int maxUses, [String? coachId]) {
    final code =
        '${role == UserRole.coach ? 'KOC' : 'OGR'}${1000 + _invites.length}';
    _invites.insert(
      0,
      OrgInvite(
        code: code,
        role: role,
        maxUses: maxUses,
        usedCount: 0,
        expiresAt: DateTime.now().add(const Duration(days: 14)),
        coachId: coachId,
      ),
    );
    return code;
  }

  @override
  Future<String> createCoachInvite({int maxUses = 1}) async =>
      _add(UserRole.coach, maxUses);

  @override
  Future<String> createStudentInvite({
    required String coachId,
    int maxUses = 1,
  }) async => _add(UserRole.student, maxUses, coachId);

  @override
  Future<List<OrgInvite>> fetchActiveInvites() async => [..._invites];

  @override
  Future<void> deleteInvite(String code) async =>
      _invites.removeWhere((i) => i.code == code);

  @override
  Future<void> reassignCoach(String studentId, String newCoachId) async =>
      onReassign(studentId, newCoachId);
}

/// Demo için kısa konu listesi (her derse birkaç başlık).
List<Topic> demoTopics() {
  const names = <String, List<String>>{
    'TYT_TUR': [
      'Sözcükte Anlam',
      'Cümlede Anlam',
      'Paragraf',
      'Yazım Kuralları',
      'Noktalama İşaretleri',
    ],
    'TYT_MAT': [
      'Temel Kavramlar',
      'Sayı Basamakları',
      'Rasyonel Sayılar',
      'Problemler',
      'Fonksiyonlar',
      'Olasılık',
    ],
    'TYT_FIZ': ['Madde ve Özellikleri', 'Hareket ve Kuvvet', 'Enerji', 'Optik'],
    'TYT_KIM': [
      'Atom ve Periyodik Sistem',
      'Karışımlar',
      'Asitler, Bazlar ve Tuzlar',
    ],
    'TYT_BIY': ['Hücre ve Organeller', 'Kalıtım', 'Ekosistem Ekolojisi'],
    'TYT_TAR': ['Tarih ve Zaman', 'Milli Mücadele'],
    'TYT_COG': ['Harita Bilgisi', 'İklim Bilgisi'],
    'TYT_FEL': ['Bilgi Felsefesi', 'Ahlak Felsefesi'],
    'TYT_DIN': ['Bilgi ve İnanç', 'İslam ve İbadet'],
    'AYT_MAT': [
      'Polinomlar',
      'İkinci Dereceden Denklemler',
      'Parabol',
      'Trigonometri',
      'Logaritma',
      'Limit ve Süreklilik',
      'Türev',
      'İntegral',
    ],
    'AYT_FIZ': [
      'Vektörler',
      'Atışlar',
      'Elektriksel Kuvvet ve Alan',
      'Çembersel Hareket',
    ],
    'AYT_KIM': ['Gazlar', 'Kimyasal Denge', 'Organik Bileşikler'],
    'AYT_BIY': ['Sinir Sistemi', 'Protein Sentezi', 'Bitki Biyolojisi'],
    'AYT_EDB': [
      'Şiir Bilgisi',
      'Divan Edebiyatı',
      'Cumhuriyet Dönemi Türk Edebiyatı',
    ],
    'YDT_YD': ['Kelime Bilgisi', 'Dil Bilgisi', 'Paragraf'],
  };
  var id = 1;
  return [
    for (final e in names.entries)
      for (var i = 0; i < e.value.length; i++)
        Topic(id: id++, subjectCode: e.key, name: e.value[i], sort: i + 1),
  ];
}

/// Örnek soru kayıtları, çalışma oturumları, konu ilerlemesi ve hedefler.
Future<void> seedDemoTracking(
  InMemoryTrackingRepository repo,
  String studentId, {
  double scale = 1,
}) async {
  final today = dateOnly(DateTime.now());
  const plan = [
    ('TYT_MAT', 40, 30, 6),
    ('TYT_TUR', 30, 24, 4),
    ('TYT_FIZ', 20, 13, 4),
    ('AYT_MAT', 25, 15, 6),
    ('TYT_KIM', 15, 10, 3),
    ('TYT_BIY', 15, 11, 2),
  ];
  for (var d = 0; d < 21; d++) {
    if (d % 6 == 5) continue; // haftada bir gün boş
    final day = today.subtract(Duration(days: d));
    for (var k = 0; k < 2; k++) {
      final p = plan[(d + k) % plan.length];
      final total = (p.$2 * scale).round();
      final correct = (p.$3 * scale).round();
      final wrong = (p.$4 * scale).round();
      await repo.addQuestionLog(
        studentId,
        QuestionLogDraft(
          subjectCode: p.$1,
          correct: correct,
          wrong: wrong,
          blank: total - correct - wrong,
          loggedOn: day,
          source: k == 0 ? '3D Yayınları' : null,
        ),
      );
    }
    await repo.addSession(
      studentId,
      type: SessionType.pomodoro,
      startedAt: day.add(const Duration(hours: 19)),
      durationSec: ((50 + (d * 7) % 40) * 60 * scale).round(),
      subjectCode: plan[d % plan.length].$1,
    );
  }
  final topics = await repo.fetchTopics();
  for (var i = 0; i < topics.length; i++) {
    final status = switch (i % 5) {
      0 || 1 => TopicStatus.done,
      2 => TopicStatus.inProgress,
      3 => TopicStatus.review,
      _ => TopicStatus.notStarted,
    };
    if (scale < 1 && i % 2 == 0) continue;
    await repo.setTopicStatus(studentId, topics[i].id, status);
  }
  await repo.saveGoals(
    studentId,
    const Goals(
      dailyQuestions: 150,
      dailyMinutes: 240,
      targetUniversity: 'Boğaziçi Üniversitesi',
      targetDepartment: 'Bilgisayar Mühendisliği',
      targetRank: 5000,
    ),
  );
}

Future<void> seedDemoCoaching(
  InMemoryCoachingRepository repo,
  String studentId,
) async {
  final today = dateOnly(DateTime.now());
  await repo.createTask(
    studentId,
    TaskDraft(
      title: 'Paragraf: 3 gün boyunca günde 40 soru',
      subjectCode: 'TYT_TUR',
      targetQuestions: 120,
      dueOn: today.add(const Duration(days: 3)),
    ),
  );
  await repo.createTask(
    studentId,
    TaskDraft(
      title: 'Türev konu tekrarı + 60 soru',
      subjectCode: 'AYT_MAT',
      targetQuestions: 60,
      dueOn: today.add(const Duration(days: 5)),
      description: 'Önce konu özetini çıkar, sonra kolaydan zora 60 soru.',
    ),
  );
  await repo.createTask(
    studentId,
    TaskDraft(
      title: 'Fizik deneme analizi',
      dueOn: today.subtract(const Duration(days: 1)),
    ),
  );
  // Liste yeniden eskiye sıralı; sıraya güvenmeden başlığa göre bul.
  final tasks = await repo.fetchTasks(studentId);
  await repo.setTaskStatus(
    tasks.firstWhere((t) => t.title == 'Fizik deneme analizi').id,
    TaskStatus.done,
  );
  await repo.addNote(
    studentId,
    'Matematikte netlerin çok güzel artıyor! Bu hafta geometriye ağırlık verelim, özellikle üçgenler.',
  );
}

/// Bellekte bildirimler; yeni bildirim eklenince akış güncellenir.
class InMemoryNotificationRepository implements NotificationRepository {
  final _items = <AppNotification>[];
  final _changes = StreamController<void>.broadcast();
  var _seq = 0;

  void add(
    String userId,
    NotificationKind kind,
    Map<String, dynamic> data, {
    String? refId,
    DateTime? at,
    bool read = false,
  }) {
    final created = at ?? DateTime.now();
    _items.add(
      AppNotification(
        id: 'n${_seq++}',
        kind: kind,
        data: {...data, '_user': userId},
        refId: refId,
        createdAt: created,
        readAt: read ? created : null,
      ),
    );
    _changes.add(null);
  }

  List<AppNotification> _of(String userId) =>
      _items.where((n) => n.data['_user'] == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<AppNotification>> watch(String userId) async* {
    yield _of(userId);
    await for (final _ in _changes.stream) {
      yield _of(userId);
    }
  }

  @override
  Future<void> markAllRead(String userId) async {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].data['_user'] == userId) _items[i] = _items[i].markRead();
    }
    _changes.add(null);
  }

  @override
  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0) _items[i] = _items[i].markRead();
    _changes.add(null);
  }
}

/// Bellekte ödev paketleri (demo ve testler için).
class InMemoryAssignmentRepository implements AssignmentRepository {
  InMemoryAssignmentRepository({
    required this.notifications,
    this.senderName = 'Ayşe Koç',
  });

  final InMemoryNotificationRepository notifications;
  final String senderName;
  final _byStudent = <String, List<Assignment>>{};
  var _seq = 0;

  @override
  Future<List<Assignment>> fetchAssignments(String studentId) async =>
      [...?_byStudent[studentId]]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> sendAssignment({
    required String studentId,
    required String title,
    required List<AssignmentItemDraft> items,
    DateTime? dueOn,
    String? note,
    DateTime? at,
  }) async {
    if (items.isEmpty) throw StateError('EMPTY_ASSIGNMENT');
    final id = 'a${_seq++}';
    (_byStudent[studentId] ??= []).add(
      Assignment(
        id: id,
        title: title,
        note: note,
        dueOn: dueOn,
        createdAt: at ?? DateTime.now(),
        coachName: senderName,
        items: [
          for (final d in items)
            AssignmentItem(
              id: 'i${_seq++}',
              subjectCode: d.subjectCode,
              topicId: d.topicId,
              topicName: d.topicName,
              questionCount: d.questionCount,
              note: d.note,
              done: false,
            ),
        ],
      ),
    );
    notifications.add(
      studentId,
      NotificationKind.assignment,
      {'title': title, 'items': items.length, 'from': senderName},
      refId: id,
      at: at,
    );
  }

  @override
  Future<void> setItemDone(String itemId, bool done) async {
    for (final list in _byStudent.values) {
      for (var a = 0; a < list.length; a++) {
        final items = list[a].items;
        final i = items.indexWhere((x) => x.id == itemId);
        if (i < 0) continue;
        final updated = [...items]..[i] = items[i].copyWith(done: done);
        final old = list[a];
        list[a] = Assignment(
          id: old.id,
          title: old.title,
          note: old.note,
          dueOn: old.dueOn,
          createdAt: old.createdAt,
          coachName: old.coachName,
          items: updated,
        );
        return;
      }
    }
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    for (final list in _byStudent.values) {
      list.removeWhere((a) => a.id == assignmentId);
    }
  }
}

/// Örnek ödev ve bildirimler.
Future<void> seedDemoAssignments(
  InMemoryAssignmentRepository repo,
  String studentId,
  List<Topic> topics,
) async {
  final now = DateTime.now();
  Topic topic(String code, String name) =>
      topics.firstWhere((t) => t.subjectCode == code && t.name == name);
  AssignmentItemDraft item(String code, String name, int count) {
    final t = topic(code, name);
    return AssignmentItemDraft(
      subjectCode: code,
      topicId: t.id,
      topicName: t.name,
      questionCount: count,
    );
  }

  await repo.sendAssignment(
    studentId: studentId,
    title: 'Hafta sonu kampı',
    items: [
      item('TYT_MAT', 'Problemler', 40),
      item('TYT_TUR', 'Paragraf', 30),
      item('TYT_FIZ', 'Hareket ve Kuvvet', 20),
    ],
    dueOn: dateOnly(now).subtract(const Duration(days: 1)),
    at: now.subtract(const Duration(days: 5)),
  );
  final first = (await repo.fetchAssignments(studentId)).first;
  for (final i in first.items) {
    await repo.setItemDone(i.id, true);
  }
  await repo.sendAssignment(
    studentId: studentId,
    title: 'AYT Matematik: Parabol haftası',
    note:
        'Önce konu anlatımını izle, sonra soruları çöz. Takıldığın soruları işaretle.',
    items: [
      item('AYT_MAT', 'İkinci Dereceden Denklemler', 25),
      item('AYT_MAT', 'Parabol', 40),
      const AssignmentItemDraft(subjectCode: 'TYT_TUR', questionCount: 30),
    ],
    dueOn: dateOnly(now).add(const Duration(days: 4)),
    at: now.subtract(const Duration(hours: 2)),
  );
  final second = (await repo.fetchAssignments(studentId)).first;
  await repo.setItemDone(second.items.first.id, true);

  final n = repo.notifications;
  await n.markAllRead(studentId);
  n.add(studentId, NotificationKind.exam, {
    'name': 'Özdebir TYT-4',
    'type': 'TYT',
  }, at: now.subtract(const Duration(minutes: 40)));
  n.add(
    studentId,
    NotificationKind.note,
    {'body': 'Paragraf netlerin harika gidiyor, aynen devam!'},
    at: now.subtract(const Duration(days: 1)),
    read: true,
  );
}

/// Bellekte dershaneler (demo ve testler için).
class InMemoryTenantRepository implements TenantRepository {
  InMemoryTenantRepository({
    required List<Branding> tenants,
    required this.myTenantId,
    this.superAdmin = false,
  }) : _tenants = [...tenants];

  final List<Branding> _tenants;
  final String? myTenantId;
  final bool superAdmin;
  var _seq = 0;

  @override
  Future<Branding?> fetchMyTenant() async =>
      _tenants.where((t) => t.tenantId == myTenantId).firstOrNull;

  @override
  Future<Branding?> fetchBySlug(String slug) async => _tenants
      .where((t) => t.slug == slug.trim().toLowerCase() && t.isActive)
      .firstOrNull;

  @override
  Future<bool> isSuperAdmin() async => superAdmin;

  @override
  Future<List<Branding>> listTenants() async =>
      [..._tenants]..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<TenantCreated> createTenant(TenantDraft d) async {
    if (_tenants.any((t) => t.slug == d.slug)) throw StateError('SLUG_TAKEN');
    final id = 'tenant-${_seq++}';
    _tenants.add(
      Branding(
        tenantId: id,
        name: d.name,
        slug: d.slug,
        primary: Branding.parseHex(d.primaryHex)!,
        secondary: Branding.parseHex(d.secondaryHex)!,
      ),
    );
    return TenantCreated(tenantId: id, adminCode: 'DEMO${1000 + _seq}');
  }

  @override
  Future<void> updateTenant(Branding t) async {
    final i = _tenants.indexWhere((x) => x.tenantId == t.tenantId);
    if (i >= 0) _tenants[i] = t;
  }

  @override
  Future<String> uploadLogo(
    String tenantId,
    Uint8List bytes,
    String ext,
  ) async =>
      // Demo: dosya yüklenmez; veri adresiyle gösterilir.
      Uri.dataFromBytes(bytes, mimeType: 'image/$ext').toString();

  @override
  Future<String> createAdminInvite(String tenantId) async =>
      'DEMO${2000 + _seq++}';

  @override
  Future<void> updateMyBranding(Branding b) async {
    final i = _tenants.indexWhere((x) => x.tenantId == myTenantId);
    if (i < 0) throw StateError('NOT_ALLOWED');
    final old = _tenants[i];
    _tenants[i] = old.copyWith(
      name: b.name,
      primary: b.primary,
      secondary: b.secondary,
      logoUrl: b.logoUrl,
      clearLogo: b.logoUrl == null,
      font: b.font,
    );
  }
}

/// Demo dershaneleri: varsayılan renkli "Bal Akademi" ve kendi markalı
/// "Yıldız Dershanesi" (`--dart-define=DEMO_TENANT=yildiz` ile denenir).
List<Branding> demoTenants() => [
  Branding(
    tenantId: 'demo-tenant',
    name: 'Bal Akademi',
    slug: 'bal-akademi',
    primary: Branding.mentoria.primary,
    secondary: Branding.mentoria.secondary,
  ),
  const Branding(
    tenantId: 'demo-yildiz',
    name: 'Yıldız Dershanesi',
    slug: 'yildiz',
    primary: Color(0xFF0EA5E9),
    secondary: Color(0xFFE5484D),
    // Beyaz etiket önizlemesinde yazı tipi de değişsin.
    font: AppFont.poppins,
  ),
];

/// Bellekte avatar kataloğu, açılan parçalar ve sıralama (demo ve testler).
/// Katalog, veritabanındaki parçaların aynısıdır (avatars + avatars_more).
class InMemoryAvatarRepository implements AvatarRepository {
  InMemoryAvatarRepository({
    Map<String, dynamic>? avatar,
    Set<int> unlocked = const {},
    this.pendingUnlocks = const [],
    this.rewardRanks,
  }) : myAvatar = avatar,
       _unlocked = {...unlocked};

  Map<String, dynamic>? myAvatar;
  final Set<int> _unlocked;

  /// Bir sonraki claimUnlocks çağrısında açılacak parçalar.
  List<int> pendingUnlocks;

  /// Başarı sıralaması ödülleri (öğrenci id → sıra), haftalık sıralamada
  /// avatarlara çizilir.
  final Map<String, int> Function()? rewardRanks;

  static final catalog = <AvatarItem>[
    for (final (id, cat, asset, rule, sort) in [
      (1, 'hair', 'hair_short', {'type': 'free'}, 1),
      (2, 'hair', 'hair_curly', {'type': 'free'}, 2),
      (3, 'hair', 'hair_bun', {'type': 'free'}, 3),
      (4, 'hair', 'hair_spiky', {'type': 'streak', 'days': 3}, 4),
      (
        5,
        'hair',
        'hair_rainbow',
        {'type': 'net', 'exam_type': 'TYT', 'value': 60},
        5,
      ),
      (6, 'skin', 'skin_light', {'type': 'free'}, 1),
      (7, 'skin', 'skin_tan', {'type': 'free'}, 2),
      (8, 'skin', 'skin_brown', {'type': 'free'}, 3),
      (9, 'skin', 'skin_dark', {'type': 'free'}, 4),
      (10, 'outfit', 'outfit_tee', {'type': 'free'}, 1),
      (11, 'outfit', 'outfit_hoodie', {'type': 'free'}, 2),
      (
        12,
        'outfit',
        'outfit_varsity',
        {'type': 'badge', 'badge': 'first_exam'},
        3,
      ),
      (13, 'outfit', 'outfit_bee', {'type': 'streak', 'days': 7}, 4),
      (
        14,
        'outfit',
        'outfit_cape',
        {'type': 'badge', 'badge': 'questions_1000'},
        5,
      ),
      (15, 'accessory', 'acc_glasses', {'type': 'free'}, 1),
      (
        16,
        'accessory',
        'acc_headphones',
        {'type': 'badge', 'badge': 'focus_master'},
        2,
      ),
      (17, 'accessory', 'acc_crown', {'type': 'streak', 'days': 30}, 3),
      // 20261018170000_avatars_more
      (18, 'skin', 'skin_fair', {'type': 'free'}, 5),
      (19, 'skin', 'skin_olive', {'type': 'free'}, 6),
      (20, 'hair', 'hair_long', {'type': 'free'}, 6),
      (21, 'hair', 'hair_ponytail', {'type': 'free'}, 7),
      (22, 'hair', 'hair_hijab', {'type': 'free'}, 8),
      (23, 'hair', 'hair_afro', {'type': 'free'}, 9),
      (24, 'hair', 'hair_wavy', {'type': 'free'}, 10),
      (25, 'hair', 'hair_braids', {'type': 'questions', 'count': 500}, 11),
      (26, 'hair', 'hair_mohawk', {'type': 'streak', 'days': 14}, 12),
      (
        27,
        'hair',
        'hair_galaxy',
        {'type': 'net', 'exam_type': 'AYT', 'value': 50},
        13,
      ),
      (
        28,
        'hair',
        'hair_golden',
        {'type': 'badge', 'badge': 'question_machine'},
        14,
      ),
      (29, 'outfit', 'outfit_uniform', {'type': 'free'}, 6),
      (30, 'outfit', 'outfit_sweater', {'type': 'free'}, 7),
      (31, 'outfit', 'outfit_labcoat', {'type': 'topics', 'count': 25}, 8),
      (32, 'outfit', 'outfit_jersey', {'type': 'exams', 'count': 5}, 9),
      (
        33,
        'outfit',
        'outfit_astronaut',
        {'type': 'study_minutes', 'minutes': 3000},
        10,
      ),
      (34, 'outfit', 'outfit_graduate', {'type': 'exams', 'count': 20}, 11),
      (35, 'accessory', 'acc_cap', {'type': 'free'}, 4),
      (36, 'accessory', 'acc_beanie', {'type': 'free'}, 5),
      (37, 'accessory', 'acc_flower', {'type': 'free'}, 6),
      (38, 'accessory', 'acc_bow', {'type': 'free'}, 7),
      (39, 'accessory', 'acc_pencil', {'type': 'questions', 'count': 250}, 8),
      (40, 'accessory', 'acc_sunglasses', {'type': 'streak', 'days': 5}, 9),
      (
        41,
        'accessory',
        'acc_bee_antenna',
        {'type': 'questions', 'count': 2000},
        10,
      ),
      (42, 'accessory', 'acc_grad_cap', {'type': 'exams', 'count': 10}, 11),
      (
        43,
        'accessory',
        'acc_halo',
        {'type': 'study_minutes', 'minutes': 6000},
        12,
      ),
    ])
      AvatarItem.fromJson({
        'id': id,
        'category': cat,
        'asset_name': asset,
        'unlock_rule': rule,
        'sort': sort,
      }),
  ];

  @override
  Future<List<AvatarItem>> fetchCatalog() async => catalog;

  @override
  Future<Set<int>> fetchMyUnlocks() async => {..._unlocked};

  @override
  Future<List<int>> claimUnlocks() async {
    final fresh = pendingUnlocks.where((i) => !_unlocked.contains(i)).toList();
    _unlocked.addAll(fresh);
    pendingUnlocks = const [];
    return fresh;
  }

  @override
  Future<void> saveAvatar(AvatarConfig config) async {
    for (final id in config.parts.values) {
      final item = catalog.firstWhere((i) => i.id == id);
      if (!item.rule.isFree && !_unlocked.contains(id)) {
        throw StateError('AVATAR_ITEM_LOCKED');
      }
    }
    myAvatar = config.toJson();
  }

  @override
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    int limit = 20,
    int offset = 0,
  }) async {
    final all = [
      (
        'demo-zeynep',
        'Zeynep A.',
        {'hair': 3, 'skin': 9, 'outfit': 11, 'accessory': 15},
        412,
      ),
      (
        'demo-student',
        'Elif Y.',
        myAvatar ?? {'hair': 4, 'skin': 7, 'outfit': 12},
        305,
      ),
      ('demo-can', 'Can K.', {'hair': 2, 'skin': 8, 'outfit': 10}, 188),
      ('demo-ali', 'Ali D.', {'hair': 1, 'skin': 6, 'outfit': 11}, 120),
      (
        'demo-ece',
        'Ece T.',
        {'hair': 2, 'skin': 7, 'outfit': 10, 'accessory': 15},
        64,
      ),
    ];
    final rewards = rewardRanks?.call() ?? const {};
    return [
      for (final (i, e) in all.indexed.skip(offset).take(limit))
        LeaderboardEntry(
          rank: i + 1,
          studentId: e.$1,
          displayName: e.$2,
          avatar: AvatarConfig.fromJson(e.$3),
          weekQuestions: e.$4,
          isMe: e.$1 == 'demo-student',
          rewardRank: rewards[e.$1],
        ),
    ];
  }
}

/// Bellekte başarı sıralaması (demo ve testler için). Puanlar sabit; demo
/// öğrencisinin avatarı [myAvatar] ile güncel kalır.
class InMemorySuccessRankingRepository implements SuccessRankingRepository {
  InMemorySuccessRankingRepository({
    this.enabled = true,
    this.myId = 'demo-student',
    this.isAdmin = false,
    this.myAvatar,
  });

  bool enabled;
  final String myId;
  final bool isAdmin;
  final Map<String, dynamic>? Function()? myAvatar;

  /// id → (tam ad, avatar). Sunucudaki gibi: müdür tam adı, öğrenci ve koç
  /// yalnızca ilk iki harfi ("El***") görür.
  static const _students = <String, (String, Map<String, int>)>{
    'demo-student': ('Elif Yılmaz', {'hair': 4, 'skin': 7, 'outfit': 12}),
    'demo-zeynep': (
      'Zeynep Arslan',
      {'hair': 3, 'skin': 9, 'outfit': 11, 'accessory': 15},
    ),
    'demo-ali': ('Ali Demir', {'hair': 1, 'skin': 6, 'outfit': 11}),
    'demo-can': ('Can Kaya', {'hair': 2, 'skin': 8, 'outfit': 10}),
    'demo-ece': ('Ece Tan', {'hair': 2, 'skin': 7, 'outfit': 10}),
    'demo-mert': ('Mert Aydın', {'hair': 5, 'skin': 8, 'outfit': 13}),
    'demo-selin': ('Selin Koç', {'hair': 3, 'skin': 6, 'outfit': 11}),
  };

  String _displayName(String id) {
    final full = _students[id]!.$1;
    return isAdmin ? full : '${full.substring(0, 2)}***';
  }

  static const _scores = <String, List<(String, double, int)>>{
    'TYT': [
      ('demo-student', 84.25, 5),
      ('demo-zeynep', 81.5, 5),
      ('demo-ali', 76.0, 4),
      ('demo-can', 68.75, 3),
      ('demo-ece', 64.5, 5),
      ('demo-mert', 58.0, 2),
      ('demo-selin', 51.25, 1),
    ],
    'AYT-SAY': [
      ('demo-ali', 54.5, 3),
      ('demo-student', 52.75, 4),
      ('demo-mert', 41.0, 2),
    ],
    'AYT-EA': [('demo-zeynep', 61.25, 4), ('demo-ece', 44.5, 2)],
    'AYT-SOZ': [('demo-selin', 55.0, 1)],
  };

  List<SuccessRankEntry> _ranked(String key) {
    final rows = _scores[key] ?? const [];
    return [
      for (final (i, r) in rows.indexed)
        SuccessRankEntry(
          rank: i + 1,
          studentId: r.$1,
          displayName: _displayName(r.$1),
          avatar: AvatarConfig.fromJson(
            r.$1 == myId
                ? (myAvatar?.call() ?? _students[r.$1]!.$2)
                : _students[r.$1]!.$2,
          ),
          avgNet: r.$2,
          examCount: r.$3,
          rewardRank: enabled ? rewardRanks()[r.$1] : null,
          isMe: r.$1 == myId,
        ),
    ];
  }

  /// TYT ilk 5 → ödül sırası (kapalıyken boş).
  Map<String, int> rewardRanks() => {
    if (enabled)
      for (final (i, r) in _scores['TYT']!.take(5).indexed) r.$1: i + 1,
  };

  @override
  Future<SuccessStatus> fetchStatus() async {
    if (!enabled || isAdmin) return SuccessStatus(enabled: enabled);
    final me = _ranked('TYT').where((e) => e.isMe).firstOrNull;
    return SuccessStatus(
      enabled: true,
      rewardRank: me != null && me.rank <= 5 ? me.rank : null,
      tytRank: me?.rank,
      tytAvgNet: me?.avgNet,
    );
  }

  @override
  Future<void> setEnabled(bool value) async {
    if (!isAdmin) throw StateError('NOT_ALLOWED');
    enabled = value;
  }

  @override
  Future<List<SuccessRankEntry>> fetchRanking({
    required ExamType examType,
    FieldType? field,
    int limit = 20,
    int offset = 0,
  }) async {
    if (!enabled && !isAdmin) throw const RankingDisabledException();
    final key = examType == ExamType.ayt
        ? 'AYT-${(field ?? FieldType.say).db}'
        : 'TYT';
    return _ranked(key).skip(offset).take(limit).toList();
  }
}

/// Bellekte koç–öğrenci görüşmeleri. [canView] rol bazlı görünürlüğü,
/// [names] kişi adlarını taklit eder.
class InMemoryMeetingRepository implements MeetingRepository {
  InMemoryMeetingRepository({
    required this.myId,
    required this.canView,
    this.names = const {},
  });

  final String myId;
  final bool Function(String studentId) canView;
  final Map<String, String> names;
  final _schedules = <MeetingSchedule>[];
  final _statuses = <(String, DateTime), MeetingStatus>{};
  var _id = 0;

  @override
  Future<List<MeetingSchedule>> fetchSchedules({String? studentId}) async => [
    for (final s in _schedules)
      if (canView(s.studentId) &&
          (studentId == null || s.studentId == studentId))
        s,
  ]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

  @override
  Future<Map<(String, DateTime), MeetingStatus>> fetchStatuses({
    String? studentId,
    required DateTime from,
    required DateTime to,
  }) async {
    final visible = {
      for (final s in await fetchSchedules(studentId: studentId)) s.id,
    };
    return {
      for (final e in _statuses.entries)
        if (visible.contains(e.key.$1) &&
            !e.key.$2.isBefore(dateOnly(from)) &&
            !e.key.$2.isAfter(dateOnly(to)))
          e.key: e.value,
    };
  }

  /// Demo verisi için: koç kimliği verilerek plan ekler.
  String add(MeetingDraft d, {required String coachId}) {
    final id = 'm${_id++}';
    _schedules.add(
      MeetingSchedule(
        id: id,
        coachId: coachId,
        studentId: d.studentId,
        firstDate: dateOnly(d.firstDate),
        hour: d.hour,
        minute: d.minute,
        durationMin: d.durationMin,
        repeatWeekly: d.repeatWeekly,
        note: d.note,
        coachName: names[coachId],
        studentName: names[d.studentId],
      ),
    );
    return id;
  }

  @override
  Future<void> createSchedule(MeetingDraft d) async => add(d, coachId: myId);

  @override
  Future<void> endSchedule(String scheduleId) async {
    final i = _schedules.indexWhere((s) => s.id == scheduleId);
    if (i < 0) return;
    final s = _schedules[i];
    final today = dateOnly(DateTime.now());
    final marked = _statuses.keys.any((k) => k.$1 == scheduleId);
    if (!marked && !s.firstDate.isBefore(today)) {
      _schedules.removeAt(i);
      return;
    }
    _schedules[i] = MeetingSchedule(
      id: s.id,
      coachId: s.coachId,
      studentId: s.studentId,
      firstDate: s.firstDate,
      hour: s.hour,
      minute: s.minute,
      durationMin: s.durationMin,
      repeatWeekly: s.repeatWeekly,
      untilDate: today,
      note: s.note,
      coachName: s.coachName,
      studentName: s.studentName,
    );
  }

  @override
  Future<void> setStatus(
    String scheduleId,
    DateTime day,
    MeetingStatus? status,
  ) async {
    final s = _schedules.firstWhere((s) => s.id == scheduleId);
    final d = dateOnly(day);
    if (!s.occursOn(d)) throw StateError('NO_MEETING_THAT_DAY');
    if ((status == MeetingStatus.held || status == MeetingStatus.missed) &&
        d.isAfter(dateOnly(DateTime.now()))) {
      throw StateError('MEETING_IN_FUTURE');
    }
    if (status == null) {
      _statuses.remove((scheduleId, d));
    } else {
      _statuses[(scheduleId, d)] = status;
    }
  }
}

/// Demo görüşmeleri: Ayşe Koç'un Elif ile haftalık rutini (geçen hafta
/// yapıldı), Can ile haftalık rutini (geçen hafta yapılmadı); Burak Yıldız'ın
/// Zeynep ile rutini. Günler bugüne göre seçilir ki "bu hafta" dolu görünsün.
void seedDemoMeetings(InMemoryMeetingRepository repo) {
  final today = dateOnly(DateTime.now());
  final week = weekStartOf(today);
  DateTime day(int weekday, int weeksAgo) =>
      DateTime(week.year, week.month, week.day + weekday - 1 - 7 * weeksAgo);

  final elif = repo.add(
    MeetingDraft(
      studentId: 'demo-student',
      firstDate: day(DateTime.tuesday, 3),
      hour: 11,
      minute: 0,
      note: 'Haftalık değerlendirme',
    ),
    coachId: 'demo-coach',
  );
  final can = repo.add(
    MeetingDraft(
      studentId: 'demo-can',
      firstDate: day(DateTime.thursday, 2),
      hour: 16,
      minute: 30,
    ),
    coachId: 'demo-coach',
  );
  final zeynep = repo.add(
    MeetingDraft(
      studentId: 'demo-zeynep',
      firstDate: day(DateTime.monday, 2),
      hour: 10,
      minute: 0,
    ),
    coachId: 'demo-coach-2',
  );
  repo._statuses[(elif, day(DateTime.tuesday, 1))] = MeetingStatus.held;
  repo._statuses[(can, day(DateTime.thursday, 1))] = MeetingStatus.missed;
  repo._statuses[(zeynep, day(DateTime.monday, 1))] = MeetingStatus.held;
  // Bu haftanın geçmiş günleri: Elif'inki yapıldı, Zeynep'inki yapıldı.
  if (!day(DateTime.tuesday, 0).isAfter(today)) {
    repo._statuses[(elif, day(DateTime.tuesday, 0))] = MeetingStatus.held;
  }
  if (!day(DateTime.monday, 0).isAfter(today)) {
    repo._statuses[(zeynep, day(DateTime.monday, 0))] = MeetingStatus.held;
  }
}

/// Bellekte hata defteri (demo ve testler). Fotoğraflar bellekte tutulur.
class InMemoryMistakeRepository implements MistakeRepository {
  InMemoryMistakeRepository({required this.canView, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final bool Function(String studentId) canView;
  final DateTime Function() _clock;
  final cards = <MistakeCard>[];
  final photos = <String, Uint8List>{};
  var _id = 0;

  @override
  Future<List<MistakeCard>> fetchCards(String studentId) async {
    if (!canView(studentId)) return const [];
    return [
      for (final c in cards)
        if (c.studentId == studentId) c,
    ]..sort((a, b) => a.dueOn.compareTo(b.dueOn));
  }

  @override
  Future<void> addCard(String studentId, MistakeDraft d) async {
    final now = _clock();
    final id = 'mistake-${++_id}';
    String? path;
    if (d.photo != null) {
      path = '$studentId/$id.${d.photoExtension}';
      photos[path] = d.photo!;
    }
    cards.add(
      MistakeCard(
        id: id,
        studentId: studentId,
        subjectCode: d.subjectCode,
        topicId: d.topicId,
        note: d.note,
        photoPath: path,
        dueOn: DateTime(now.year, now.month, now.day + 1),
        createdAt: now,
      ),
    );
  }

  @override
  Future<MistakeCard> review(MistakeCard card, {required bool solved}) async {
    final i = cards.indexWhere((c) => c.id == card.id);
    final next = cards[i].reviewed(solved: solved, now: _clock());
    cards[i] = next;
    return next;
  }

  @override
  Future<void> deleteCard(MistakeCard card) async {
    cards.removeWhere((c) => c.id == card.id);
    photos.remove(card.photoPath);
  }

  @override
  Future<Uint8List?> loadPhoto(String path) async => photos[path];
}

/// Bellekte günlük soru cevapları; sunucudaki günlük hak sınırı burada da.
class InMemoryPracticeRepository implements PracticeRepository {
  InMemoryPracticeRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final answers = <String, List<PracticeAnswer>>{};

  @override
  Future<List<PracticeAnswer>> fetchAnswers(String studentId) async => [
    ...?answers[studentId],
  ];

  @override
  Future<void> submit(
    String studentId, {
    required String subject,
    required String questionId,
    required bool correct,
  }) async {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final list = answers.putIfAbsent(studentId, () => []);
    final used = list
        .where((a) => a.subject == subject && a.answeredOn == today)
        .length;
    if (used >= practiceDailyLimit(subject)) throw const DailyLimitReached();
    list.add(
      PracticeAnswer(
        subject: subject,
        questionId: questionId,
        correct: correct,
        answeredOn: today,
      ),
    );
  }
}

/// Günün Sorusu (demo): ders güne göre döner, soru öğrenci + güne göre.
/// Seri, önceki günlerin doğru cevaplarıyla başlatılabilir ([pastCorrectDays]).
class InMemoryDailyQuestionRepository implements DailyQuestionRepository {
  InMemoryDailyQuestionRepository({
    this.myId,
    int pastCorrectDays = 0,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    final today = _today();
    for (var k = 1; k <= pastCorrectDays; k++) {
      answers[today.subtract(Duration(days: k))] = true;
    }
  }

  /// Öğrenci değilse null.
  final String? myId;
  final DateTime Function() _clock;
  final answers = <DateTime, bool>{};

  DateTime _today() {
    final n = _clock();
    return DateTime(n.year, n.month, n.day);
  }

  String questionFor(DateTime day) {
    final d = day.difference(DateTime(2026)).inDays;
    final h = myId.hashCode.abs();
    final subject = tytPracticeSubjects[(d + h) % tytPracticeSubjects.length];
    final pool = practiceDailyLimit(subject) * 30;
    final n = 1 + (d * 7919 + h) % pool;
    return '$subject-${n.toString().padLeft(4, '0')}';
  }

  @override
  Future<DailyQuestionState?> fetchToday() async {
    if (myId == null) return null;
    final today = _today();
    var day = answers.containsKey(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (answers[day] == true) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return DailyQuestionState(
      questionId: questionFor(today),
      answered: answers.containsKey(today),
      correct: answers[today],
      streak: streak,
    );
  }

  @override
  Future<void> answer(
    String studentId, {
    required String questionId,
    required bool correct,
  }) async {
    final today = _today();
    if (answers.containsKey(today) || questionId != questionFor(today)) {
      throw StateError('NOT_TODAYS_QUESTION');
    }
    answers[today] = correct;
  }
}

/// Demo öğrencisine son 7 güne yayılmış Eğitim cevapları (koçun karnesi boş
/// görünmesin). Bugün boş bırakılır; öğrencinin günlük hakkı tam kalsın.
void seedDemoPractice(InMemoryPracticeRepository repo, String studentId) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  const plan = {
    'TYT_MAT': (12, 0.75),
    'TYT_TUR': (10, 0.85),
    'TYT_FIZ': (6, 0.45),
  };
  final list = repo.answers.putIfAbsent(studentId, () => []);
  var n = 0;
  for (var k = 6; k >= 1; k--) {
    final day = today.subtract(Duration(days: k));
    for (final MapEntry(key: subject, value: (count, rate)) in plan.entries) {
      final c = k.isEven ? count : count ~/ 2;
      for (var i = 0; i < c; i++) {
        n++;
        list.add(
          PracticeAnswer(
            subject: subject,
            questionId: '$subject-${n.toString().padLeft(4, '0')}',
            correct: (i + 1) / c <= rate,
            answeredOn: day,
          ),
        );
      }
    }
  }
}
