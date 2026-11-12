import '../features/tutoring/data/tutoring_repository.dart';

class _Req {
  _Req({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.date,
    this.topic,
  });

  final String id;
  final String sessionId;
  final String studentId;
  final DateTime date;
  final String? topic;
  TutoringStatus status = TutoringStatus.pending;
  String? reason;
}

/// Bellekte soru çözümü oturumları ve talepler (demo ve testler için).
/// Sunucudaki kuralların aynısı: 14 gün, günde 3 etkin talep, kontenjan,
/// kararı yalnızca oturumun öğretmeni verir.
class InMemoryTutoringRepository implements TutoringRepository {
  InMemoryTutoringRepository({
    required this.viewerId,
    required this.viewerRole,
    required this.teacherNames,
    this.teacherProfiles = const {},
    this.studentNames = const {},
    this.now,
  });

  final String viewerId;
  final String viewerRole;

  /// Öğretmen kimliği → ad / hesap.
  final Map<String, String> teacherNames;
  final Map<String, String> teacherProfiles;
  final Map<String, String> studentNames;

  final DateTime Function()? now;

  final _sessions = <TutoringSession>[];
  final _requests = <_Req>[];
  int _id = 0;

  DateTime get _now => now?.call() ?? DateTime.now();
  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  /// Demo: öğretmen başına iki oturum, öğrenciden bir onaylı bir bekleyen.
  factory InMemoryTutoringRepository.demo({
    required String viewerId,
    required String viewerRole,
    required Map<String, String> teacherNames,
    Map<String, String> teacherProfiles = const {'t-mehmet': 'demo-teacher'},
    Map<String, String> studentNames = const {},
  }) {
    final repo = InMemoryTutoringRepository(
      viewerId: viewerId,
      viewerRole: viewerRole,
      teacherNames: teacherNames,
      teacherProfiles: teacherProfiles,
      studentNames: studentNames,
    );
    for (var d = 1; d <= 6; d++) {
      repo._sessions.add(
        TutoringSession(
          id: 'ts-fizik-$d',
          teacherId: 't-mehmet',
          teacherName: teacherNames['t-mehmet'],
          kind: TutoringKind.questionSolving,
          day: d,
          start: 15 * 60,
          end: 16 * 60,
          capacity: 4,
          branch: 'Fizik',
          roomName: 'D-1',
        ),
      );
    }
    repo._sessions.addAll([
      TutoringSession(
        id: 'ts-mat-birebir',
        teacherId: 't-ahmet',
        teacherName: teacherNames['t-ahmet'],
        kind: TutoringKind.privateLesson,
        day: 3,
        start: 16 * 60 + 30,
        end: 17 * 60 + 10,
        branch: 'Matematik',
      ),
      TutoringSession(
        id: 'ts-kimya-etut',
        teacherId: 't-zeynep',
        teacherName: teacherNames['t-zeynep'],
        kind: TutoringKind.etut,
        day: 5,
        start: 17 * 60,
        end: 18 * 60,
        capacity: 12,
        branch: 'Kimya',
      ),
    ]);
    // İki gün sonrası ve üç gün sonrası Fizik: bir onaylı, bir bekleyen.
    final t = repo._today;
    for (final (i, sid) in ['demo-student', 'demo-can'].indexed) {
      final date = t.add(Duration(days: 2 + i));
      final r = _Req(
        id: 'tr-${repo._id++}',
        sessionId: 'ts-fizik-${date.weekday == 7 ? 1 : date.weekday}',
        studentId: sid,
        date: date.weekday == 7 ? date.add(const Duration(days: 1)) : date,
        topic: i == 0 ? 'Elektrik devreleri' : 'Dalgalar',
      );
      if (i == 0) r.status = TutoringStatus.approved;
      repo._requests.add(r);
    }
    return repo;
  }

  /// Ders programının gördüğü oturumlar (demo; NOTLAR §95).
  List<TutoringSession> get sessions => List.unmodifiable(_sessions);

  /// Testler için: kurallara bakmadan oturum ekler.
  void seedSession(TutoringSession s) => _sessions.add(s);

  TutoringSession _session(String id) => _sessions.firstWhere(
    (s) => s.id == id,
    orElse: () => throw StateError('TUTOR_SESSION_NOT_FOUND'),
  );

  bool _active(_Req r) =>
      r.status == TutoringStatus.pending || r.status == TutoringStatus.approved;

  int _taken(String sessionId, DateTime date) => _requests
      .where(
        (r) =>
            r.sessionId == sessionId &&
            r.date == date &&
            r.status == TutoringStatus.approved,
      )
      .length;

  TutoringRequest _view(_Req r) {
    final s = _session(r.sessionId);
    return TutoringRequest(
      id: r.id,
      sessionId: s.id,
      date: r.date,
      kind: s.kind,
      start: s.start,
      end: s.end,
      status: r.status,
      branch: s.branch,
      teacherName: teacherNames[s.teacherId],
      studentId: r.studentId,
      studentName: studentNames[r.studentId] ?? r.studentId,
      topic: r.topic,
      rejectReason: r.reason,
      capacity: s.capacity,
    );
  }

  int _order(TutoringRequest a, TutoringRequest b) {
    final d = a.date.compareTo(b.date);
    return d != 0 ? d : a.start.compareTo(b.start);
  }

  @override
  Future<List<TutoringSession>> fetchSessions() async {
    if (viewerRole != 'admin') return const [];
    return [
      for (final s in _sessions)
        TutoringSession(
          id: s.id,
          teacherId: s.teacherId,
          teacherName: teacherNames[s.teacherId],
          kind: s.kind,
          day: s.day,
          start: s.start,
          end: s.end,
          capacity: s.capacity,
          branch: s.branch,
          roomId: s.roomId,
          roomName: s.roomName,
          note: s.note,
          active: s.active,
        ),
    ]..sort((a, b) {
      final d = a.day.compareTo(b.day);
      return d != 0 ? d : a.start.compareTo(b.start);
    });
  }

  @override
  Future<void> saveSession(TutoringSession s) async {
    if (viewerRole != 'admin') throw StateError('TUTOR_NOT_ADMIN');
    if (!teacherNames.containsKey(s.teacherId)) {
      throw StateError('TUTOR_BAD_REF');
    }
    if (s.end <= s.start) throw StateError('check');
    final id = s.id.isEmpty ? 'ts-${_id++}' : s.id;
    if (s.active &&
        _sessions.any(
          (o) =>
              o.id != id &&
              o.active &&
              o.teacherId == s.teacherId &&
              o.day == s.day &&
              o.start < s.end &&
              s.start < o.end,
        )) {
      throw StateError('TUTOR_SESSION_OVERLAP');
    }
    final saved = TutoringSession(
      id: id,
      teacherId: s.teacherId,
      teacherName: teacherNames[s.teacherId],
      kind: s.kind,
      day: s.day,
      start: s.start,
      end: s.end,
      capacity: s.kind == TutoringKind.privateLesson ? 1 : s.capacity,
      branch: (s.branch?.trim().isEmpty ?? true) ? null : s.branch!.trim(),
      roomId: s.roomId,
      roomName: s.roomName,
      note: s.note,
      active: s.active,
    );
    final i = _sessions.indexWhere((o) => o.id == id);
    i < 0 ? _sessions.add(saved) : _sessions[i] = saved;
  }

  @override
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    _requests.removeWhere((r) => r.sessionId == id);
  }

  @override
  Future<List<TutoringSlot>> openSlots(DateTime from, {int days = 7}) async {
    if (viewerRole != 'student') return const [];
    final start = from.isBefore(_today) ? _today : from;
    final out = <TutoringSlot>[];
    for (var i = 0; i < days.clamp(1, 14); i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      if (d.difference(_today).inDays > 14) break;
      for (final s in _sessions) {
        if (!s.active || s.day != d.weekday) continue;
        if (d == _today && s.start <= _now.hour * 60 + _now.minute) continue;
        final mine = _requests
            .where(
              (r) =>
                  r.sessionId == s.id && r.date == d && r.studentId == viewerId,
            )
            .toList();
        final my = mine.where(_active).firstOrNull ?? mine.lastOrNull;
        out.add(
          TutoringSlot(
            sessionId: s.id,
            date: d,
            kind: s.kind,
            start: s.start,
            end: s.end,
            branch: s.branch,
            teacherName: teacherNames[s.teacherId] ?? '',
            roomName: s.roomName,
            capacity: s.capacity,
            taken: _taken(s.id, d),
            myRequestId: my?.id,
            myStatus: my?.status,
          ),
        );
      }
    }
    out.sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : a.start.compareTo(b.start);
    });
    return out;
  }

  @override
  Future<void> request(String sessionId, DateTime date, {String? topic}) async {
    if (viewerRole != 'student') throw StateError('NOT_ALLOWED');
    final s = _session(sessionId);
    final d = DateTime(date.year, date.month, date.day);
    if (d.weekday != s.day ||
        d.isBefore(_today) ||
        d.difference(_today).inDays > 14 ||
        (d == _today && s.start <= _now.hour * 60 + _now.minute)) {
      throw StateError('TUTOR_BAD_DATE');
    }
    if (_requests.any(
      (r) =>
          r.sessionId == sessionId &&
          r.date == d &&
          r.studentId == viewerId &&
          _active(r),
    )) {
      throw StateError('TUTOR_ALREADY_REQUESTED');
    }
    if (_requests
            .where((r) => r.studentId == viewerId && r.date == d && _active(r))
            .length >=
        3) {
      throw StateError('TUTOR_DAILY_LIMIT');
    }
    if (_taken(sessionId, d) >= s.capacity) {
      throw StateError('TUTOR_SESSION_FULL');
    }
    final t = topic?.trim();
    _requests.add(
      _Req(
        id: 'tr-${_id++}',
        sessionId: sessionId,
        studentId: viewerId,
        date: d,
        topic: (t == null || t.isEmpty) ? null : t,
      ),
    );
  }

  @override
  Future<void> cancel(String requestId) async {
    final r = _requests.firstWhere(
      (r) => r.id == requestId && r.studentId == viewerId && _active(r),
      orElse: () => throw StateError('NOT_ALLOWED'),
    );
    r.status = TutoringStatus.cancelled;
  }

  @override
  Future<List<TutoringRequest>> myRequests() async => [
    for (final r in _requests)
      if (r.studentId == viewerId &&
          !r.date.isBefore(_today) &&
          r.status != TutoringStatus.cancelled)
        _view(r),
  ]..sort(_order);

  Set<String> get _myTeacherIds => {
    for (final e in teacherProfiles.entries)
      if (e.value == viewerId) e.key,
  };

  @override
  Future<List<TutoringSession>> mySessions() async =>
      [
        for (final s in _sessions)
          if (s.active && _myTeacherIds.contains(s.teacherId)) s,
      ]..sort((a, b) {
        final d = a.day.compareTo(b.day);
        return d != 0 ? d : a.start.compareTo(b.start);
      });

  bool _inRange(DateTime d, DateTime from, int days) =>
      !d.isBefore(from) && d.difference(from).inDays < days;

  @override
  Future<List<TutoringRequest>> teacherRequests(
    DateTime from, {
    int days = 14,
  }) async {
    final mine = _myTeacherIds;
    return [
      for (final r in _requests)
        if (mine.contains(_session(r.sessionId).teacherId) &&
            _inRange(r.date, from, days) &&
            r.status != TutoringStatus.cancelled)
          _view(r),
    ]..sort(_order);
  }

  @override
  Future<void> decide(
    String requestId, {
    required bool approve,
    String? reason,
  }) async {
    final r = _requests.firstWhere(
      (r) => r.id == requestId,
      orElse: () => throw StateError('NOT_ALLOWED'),
    );
    final s = _session(r.sessionId);
    if (!_myTeacherIds.contains(s.teacherId)) throw StateError('NOT_ALLOWED');
    if (r.status != TutoringStatus.pending) {
      throw StateError('TUTOR_ALREADY_DECIDED');
    }
    if (approve && _taken(s.id, r.date) >= s.capacity) {
      throw StateError('TUTOR_SESSION_FULL');
    }
    r.status = approve ? TutoringStatus.approved : TutoringStatus.rejected;
    final t = reason?.trim();
    r.reason = approve || t == null || t.isEmpty ? null : t;
  }

  @override
  Future<List<TutoringRequest>> managedRequests(
    DateTime from, {
    int days = 14,
  }) async {
    // Yalnızca müdür; koçla ilgisi yok (NOTLAR §95).
    if (viewerRole != 'admin') return const [];
    return [
      for (final r in _requests)
        if (_inRange(r.date, from, days) &&
            r.status != TutoringStatus.cancelled)
          _view(r),
    ]..sort(_order);
  }
}
