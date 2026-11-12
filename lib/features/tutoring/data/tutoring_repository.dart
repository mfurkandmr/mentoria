import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';

/// Soru çözümü / birebir ders / etüt (NOTLAR §87). Müdür haftalık oturumu
/// açar, öğrenci belirli bir güne talep eder, yalnızca öğretmen onaylar;
/// müdür talepleri görür. Koçla ilgisi yoktur (NOTLAR §95).
enum TutoringKind {
  questionSolving('question_solving', 'Soru çözümü'),
  privateLesson('private_lesson', 'Birebir ders'),
  etut('etut', 'Etüt');

  const TutoringKind(this.db, this.trLabel);
  final String db;
  final String trLabel;

  String get label => tr(trLabel);

  static TutoringKind fromDb(String? v) => TutoringKind.values.firstWhere(
    (k) => k.db == v,
    orElse: () => TutoringKind.questionSolving,
  );
}

enum TutoringStatus {
  pending('Onay bekliyor'),
  approved('Onaylandı'),
  rejected('Reddedildi'),
  cancelled('İptal edildi');

  const TutoringStatus(this.trLabel);
  final String trLabel;

  String get label => tr(trLabel);

  static TutoringStatus? fromDb(String? v) =>
      TutoringStatus.values.where((s) => s.name == v).firstOrNull;
}

/// "15:00" → 900.
int parseHm(String s) {
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String formatHm(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _parseDate(Object? v) {
  final d = DateTime.parse('$v');
  return DateTime(d.year, d.month, d.day);
}

/// Müdürün haftalık oturumu.
class TutoringSession {
  const TutoringSession({
    required this.id,
    required this.teacherId,
    required this.kind,
    required this.day,
    required this.start,
    required this.end,
    this.capacity = 1,
    this.teacherName,
    this.branch,
    this.roomId,
    this.roomName,
    this.note,
    this.active = true,
  });

  final String id;
  final String teacherId;
  final String? teacherName;
  final TutoringKind kind;

  /// 1 = pazartesi … 7 = pazar.
  final int day;

  /// Gece yarısından dakika.
  final int start;
  final int end;
  final int capacity;

  /// Boşsa öğretmenin ilk branşı.
  final String? branch;
  final String? roomId;
  final String? roomName;
  final String? note;
  final bool active;

  String get timeLabel => '${formatHm(start)}–${formatHm(end)}';
}

/// Öğrencinin gördüğü açık oturum (belirli bir gün).
class TutoringSlot {
  const TutoringSlot({
    required this.sessionId,
    required this.date,
    required this.kind,
    required this.start,
    required this.end,
    required this.teacherName,
    required this.capacity,
    required this.taken,
    this.branch,
    this.roomName,
    this.myRequestId,
    this.myStatus,
  });

  factory TutoringSlot.fromJson(Map<String, dynamic> j) => TutoringSlot(
    sessionId: j['session_id'] as String,
    date: _parseDate(j['on_date']),
    kind: TutoringKind.fromDb(j['kind'] as String?),
    start: parseHm(j['start_time'] as String),
    end: parseHm(j['end_time'] as String),
    branch: j['branch'] as String?,
    teacherName: j['teacher_name'] as String? ?? '',
    roomName: j['room_name'] as String?,
    capacity: (j['capacity'] as num).toInt(),
    taken: (j['taken'] as num? ?? 0).toInt(),
    myRequestId: j['my_request'] as String?,
    myStatus: TutoringStatus.fromDb(j['my_status'] as String?),
  );

  final String sessionId;
  final DateTime date;
  final TutoringKind kind;
  final int start;
  final int end;
  final String? branch;
  final String teacherName;
  final String? roomName;
  final int capacity;

  /// Onaylanmış talep sayısı.
  final int taken;
  final String? myRequestId;
  final TutoringStatus? myStatus;

  bool get full => taken >= capacity;

  /// Etkin talebim var (bekliyor ya da onaylı).
  bool get requested =>
      myStatus == TutoringStatus.pending || myStatus == TutoringStatus.approved;
}

/// Bir talep (öğrenci, öğretmen ya da koç görünümü).
class TutoringRequest {
  const TutoringRequest({
    required this.id,
    required this.sessionId,
    required this.date,
    required this.kind,
    required this.start,
    required this.end,
    required this.status,
    this.branch,
    this.teacherName,
    this.studentId,
    this.studentName,
    this.className,
    this.topic,
    this.rejectReason,
    this.capacity,
  });

  factory TutoringRequest.fromJson(Map<String, dynamic> j) => TutoringRequest(
    id: j['id'] as String,
    sessionId: j['session_id'] as String? ?? '',
    date: _parseDate(j['on_date']),
    kind: TutoringKind.fromDb(j['kind'] as String?),
    start: parseHm(j['start_time'] as String),
    end: parseHm(j['end_time'] as String),
    status:
        TutoringStatus.fromDb(j['status'] as String?) ?? TutoringStatus.pending,
    branch: j['branch'] as String?,
    teacherName: j['teacher_name'] as String?,
    studentId: j['student_id'] as String?,
    studentName: j['student_name'] as String?,
    className: j['class_name'] as String?,
    topic: j['topic'] as String?,
    rejectReason: j['reject_reason'] as String?,
    capacity: (j['capacity'] as num?)?.toInt(),
  );

  final String id;
  final String sessionId;
  final DateTime date;
  final TutoringKind kind;
  final int start;
  final int end;
  final TutoringStatus status;
  final String? branch;
  final String? teacherName;
  final String? studentId;
  final String? studentName;
  final String? className;
  final String? topic;
  final String? rejectReason;
  final int? capacity;

  String get timeLabel => '${formatHm(start)}–${formatHm(end)}';
}

/// Sunucu hata kodundan kullanıcı metni.
String tutoringErrorMessage(Object e) {
  final s = e.toString();
  if (s.contains('TUTOR_SESSION_FULL')) {
    return tr('Bu oturumun kontenjanı dolu.');
  }
  if (s.contains('TUTOR_ALREADY_REQUESTED')) {
    return tr('Bu oturuma zaten talebin var.');
  }
  if (s.contains('TUTOR_DAILY_LIMIT')) {
    return tr('Bir güne en çok 3 talep verebilirsin.');
  }
  if (s.contains('TUTOR_BAD_DATE')) {
    return tr('Bu oturum için talep süresi geçti.');
  }
  if (s.contains('TUTOR_SESSION_OVERLAP')) {
    return tr('Öğretmenin bu saatte başka bir oturumu var.');
  }
  if (s.contains('TUTOR_TEACHER_BUSY')) {
    return tr('Öğretmenin bu saatte programda dersi var.');
  }
  if (s.contains('TUTOR_ROOM_BUSY')) {
    return tr('Derslik bu saatte dolu (ders ya da başka oturum).');
  }
  if (s.contains('TUTOR_ALREADY_DECIDED')) {
    return tr('Bu talep için zaten karar verilmiş.');
  }
  return tr('Bir şeyler ters gitti. Lütfen tekrar dene.');
}

abstract interface class TutoringRepository {
  // Müdür
  Future<List<TutoringSession>> fetchSessions();
  Future<void> saveSession(TutoringSession session);
  Future<void> deleteSession(String id);

  // Öğrenci
  Future<List<TutoringSlot>> openSlots(DateTime from, {int days = 7});
  Future<void> request(String sessionId, DateTime date, {String? topic});
  Future<void> cancel(String requestId);
  Future<List<TutoringRequest>> myRequests();

  // Öğretmen
  Future<List<TutoringSession>> mySessions();
  Future<List<TutoringRequest>> teacherRequests(DateTime from, {int days = 14});
  Future<void> decide(
    String requestId, {
    required bool approve,
    String? reason,
  });

  // Müdür (kurum): salt okunur
  Future<List<TutoringRequest>> managedRequests(DateTime from, {int days = 14});
}

class SupabaseTutoringRepository implements TutoringRepository {
  SupabaseTutoringRepository(this._client);

  final SupabaseClient _client;

  List<Map<String, dynamic>> _rows(Object? r) => [
    for (final x in r as List) Map<String, dynamic>.from(x as Map),
  ];

  @override
  Future<List<TutoringSession>> fetchSessions() async {
    final rows = await _client
        .from('tutoring_sessions')
        .select('*, teachers(full_name), rooms(name)')
        .order('day')
        .order('start_time');
    return [
      for (final r in _rows(rows))
        TutoringSession(
          id: r['id'] as String,
          teacherId: r['teacher_id'] as String,
          teacherName: (r['teachers'] as Map?)?['full_name'] as String?,
          kind: TutoringKind.fromDb(r['kind'] as String?),
          day: r['day'] as int,
          start: parseHm(r['start_time'] as String),
          end: parseHm(r['end_time'] as String),
          capacity: r['capacity'] as int,
          branch: r['branch'] as String?,
          roomId: r['room_id'] as String?,
          roomName: (r['rooms'] as Map?)?['name'] as String?,
          note: r['note'] as String?,
          active: r['active'] as bool? ?? true,
        ),
    ];
  }

  @override
  Future<void> saveSession(TutoringSession s) async {
    final row = {
      'teacher_id': s.teacherId,
      'kind': s.kind.db,
      'day': s.day,
      'start_time': formatHm(s.start),
      'end_time': formatHm(s.end),
      'capacity': s.capacity,
      'branch': s.branch,
      'room_id': s.roomId,
      'note': s.note,
      'active': s.active,
    };
    if (s.id.isEmpty) {
      await _client.from('tutoring_sessions').insert(row);
    } else {
      await _client.from('tutoring_sessions').update(row).eq('id', s.id);
    }
  }

  @override
  Future<void> deleteSession(String id) =>
      _client.from('tutoring_sessions').delete().eq('id', id);

  @override
  Future<List<TutoringSlot>> openSlots(DateTime from, {int days = 7}) async => [
    for (final r in _rows(
      await _client.rpc(
        'open_tutoring_sessions',
        params: {'p_from': _date(from), 'p_days': days},
      ),
    ))
      TutoringSlot.fromJson(r),
  ];

  @override
  Future<void> request(String sessionId, DateTime date, {String? topic}) =>
      _client.rpc(
        'request_tutoring_session',
        params: {
          'p_session': sessionId,
          'p_date': _date(date),
          'p_topic': topic,
        },
      );

  @override
  Future<void> cancel(String requestId) =>
      _client.rpc('cancel_tutoring_request', params: {'p_id': requestId});

  @override
  Future<List<TutoringRequest>> myRequests() async => [
    for (final r in _rows(await _client.rpc('my_tutoring_requests')))
      TutoringRequest.fromJson(r),
  ];

  @override
  Future<List<TutoringSession>> mySessions() async => [
    for (final r in _rows(await _client.rpc('my_tutoring_sessions')))
      TutoringSession(
        id: r['id'] as String,
        teacherId: '',
        kind: TutoringKind.fromDb(r['kind'] as String?),
        day: r['day'] as int,
        start: parseHm(r['start_time'] as String),
        end: parseHm(r['end_time'] as String),
        capacity: r['capacity'] as int,
        branch: r['branch'] as String?,
        roomName: r['room_name'] as String?,
      ),
  ];

  @override
  Future<List<TutoringRequest>> teacherRequests(
    DateTime from, {
    int days = 14,
  }) async => [
    for (final r in _rows(
      await _client.rpc(
        'teacher_tutoring_requests',
        params: {'p_from': _date(from), 'p_days': days},
      ),
    ))
      TutoringRequest.fromJson(r),
  ];

  @override
  Future<void> decide(
    String requestId, {
    required bool approve,
    String? reason,
  }) => _client.rpc(
    'decide_tutoring_request',
    params: {'p_id': requestId, 'p_approve': approve, 'p_reason': reason},
  );

  @override
  Future<List<TutoringRequest>> managedRequests(
    DateTime from, {
    int days = 14,
  }) async => [
    for (final r in _rows(
      await _client.rpc(
        'managed_tutoring_requests',
        params: {'p_from': _date(from), 'p_days': days},
      ),
    ))
      TutoringRequest.fromJson(r),
  ];
}

final tutoringRepositoryProvider = Provider<TutoringRepository>(
  (ref) => SupabaseTutoringRepository(sessionClient(ref)),
);

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Müdür: kurumun haftalık oturumları.
final tutoringSessionsProvider = FutureProvider<List<TutoringSession>>(
  (ref) => ref.watch(tutoringRepositoryProvider).fetchSessions(),
);

/// Öğrenci: bugünden 7 günün açık oturumları.
final openTutoringSlotsProvider = FutureProvider<List<TutoringSlot>>(
  (ref) => ref.watch(tutoringRepositoryProvider).openSlots(_today()),
);

/// Öğrenci: kendi talepleri (bugünden itibaren).
final myTutoringRequestsProvider = FutureProvider<List<TutoringRequest>>(
  (ref) => ref.watch(tutoringRepositoryProvider).myRequests(),
);

/// Öğretmen: oturumları ve önümüzdeki 14 günün talepleri.
final myTutoringSessionsProvider = FutureProvider<List<TutoringSession>>(
  (ref) => ref.watch(tutoringRepositoryProvider).mySessions(),
);
final teacherTutoringRequestsProvider = FutureProvider<List<TutoringRequest>>(
  (ref) => ref.watch(tutoringRepositoryProvider).teacherRequests(_today()),
);

/// Müdür: önümüzdeki 14 günün talepleri.
final managedTutoringRequestsProvider = FutureProvider<List<TutoringRequest>>(
  (ref) => ref.watch(tutoringRepositoryProvider).managedRequests(_today()),
);
