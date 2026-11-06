import '../features/student_books/data/books_repository.dart';

class _StudentBookRow {
  _StudentBookRow(
    this.id,
    this.studentId,
    this.bookId,
    this.term,
    this.status,
    this.startedOn,
    this.addedRole,
  );

  final String id;
  final String studentId;
  final String bookId;
  final String term;
  StudentBookStatus status;
  final DateTime startedOn;
  final String addedRole;
}

/// Bellekte kitap takibi (demo ve testler). Sunucudaki kurallar: öğrenci
/// yalnızca talep ekler, dönemde eklenen toplam kayıt sınırı (7), öğrenci
/// kitabını değiştiremez/silemez, kendi çalışmasını 24 saat düzenler.
class InMemoryBooksRepository implements BooksRepository {
  InMemoryBooksRepository({
    required this.viewerId,
    required this.viewerRole,
    this.managed = const {},
    this.children = const {},
    List<Book> pool = const [],
    this.now,
  }) : _pool = [...pool];

  final String viewerId;

  /// 'student' | 'coach' | 'admin' | 'parent'.
  final String viewerRole;

  /// Koç/müdürün yönettiği öğrenciler.
  final Set<String> managed;

  /// Velinin çocukları.
  final Set<String> children;

  /// Testler için sabit zaman.
  final DateTime Function()? now;

  final List<Book> _pool;
  final _books = <_StudentBookRow>[];
  final _limits = <(String, String), int>{};
  final _progress = <BookProgress>[];
  int _id = 0;

  /// Gönderilen bildirimler (öğrenci, sonuç) — testler için.
  final notifications = <(String, String)>[];

  DateTime get _now => now?.call() ?? DateTime.now();
  String get _term => termOf(_now);
  bool get _isManager => viewerRole == 'coach' || viewerRole == 'admin';
  String _next(String p) => '$p-${_id++}';

  bool _canView(String student) =>
      student == viewerId ||
      (_isManager && managed.contains(student)) ||
      (viewerRole == 'parent' && children.contains(student));

  void _manage(String student) {
    if (!_isManager || !managed.contains(student)) {
      throw StateError('NOT_ALLOWED');
    }
  }

  /// Demo: havuz, öğrencinin üç kitabı ve birkaç çalışması, bir talep.
  factory InMemoryBooksRepository.demo({
    required String viewerId,
    required String viewerRole,
    Set<String> managed = const {},
    Set<String> children = const {},
  }) {
    const pool = [
      Book(
        id: 'b-1',
        name: 'TYT Matematik Soru Bankası',
        publisher: '3D Yayınları',
        subjectCode: 'TYT_MAT',
      ),
      Book(
        id: 'b-2',
        name: 'TYT Paragraf',
        publisher: 'Karekök',
        subjectCode: 'TYT_TUR',
      ),
      Book(
        id: 'b-3',
        name: 'TYT Fizik Soru Bankası',
        publisher: 'Palme',
        subjectCode: 'TYT_FIZ',
      ),
      Book(
        id: 'b-4',
        name: 'TYT Deneme Seti',
        publisher: 'Toprak',
        kind: BookKind.practiceExams,
      ),
      Book(
        id: 'b-5',
        name: 'AYT Matematik Konu Anlatımı',
        publisher: 'Acil',
        subjectCode: 'AYT_MAT',
        kind: BookKind.lecture,
      ),
      Book(
        id: 'b-6',
        name: 'TYT Kimya Soru Bankası',
        publisher: '3D Yayınları',
        subjectCode: 'TYT_KIM',
      ),
      Book(
        id: 'b-7',
        name: 'TYT Biyoloji Soru Bankası',
        publisher: 'Palme',
        subjectCode: 'TYT_BIY',
      ),
      Book(
        id: 'b-8',
        name: 'TYT Tarih Soru Bankası',
        publisher: 'Karekök',
        subjectCode: 'TYT_TAR',
      ),
      Book(
        id: 'b-req',
        name: 'Bilgi Sarmal TYT Geometri',
        publisher: 'Bilgi Sarmal',
        subjectCode: 'TYT_MAT',
        status: PoolStatus.pending,
        requestedBy: 'demo-student',
      ),
    ];
    final repo = InMemoryBooksRepository(
      viewerId: viewerId,
      viewerRole: viewerRole,
      managed: managed,
      children: children,
      pool: pool,
    );
    final term = repo._term;
    final today = DateTime.now();
    for (final (i, b) in ['b-1', 'b-2', 'b-4'].indexed) {
      repo._books.add(
        _StudentBookRow(
          'sb-$i',
          'demo-student',
          b,
          term,
          i == 2 ? StudentBookStatus.finished : StudentBookStatus.active,
          today.subtract(Duration(days: 40 - i * 10)),
          'student',
        ),
      );
    }
    for (var d = 0; d < 5; d++) {
      repo._progress.add(
        BookProgress(
          id: 'bp-$d',
          studentBookId: d.isEven ? 'sb-0' : 'sb-1',
          studiedOn: DateTime(today.year, today.month, today.day - d * 2),
          topicText: d.isEven ? 'Problemler' : 'Paragrafta anlam',
          pageFrom: 20 + d * 10,
          pageTo: 29 + d * 10,
          questions: 40,
          correct: 28 + d,
          wrong: 8 - d,
          blank: 4,
          enteredRole: 'student',
          createdBy: 'demo-student',
          createdAt: today.subtract(Duration(days: d * 2)),
        ),
      );
    }
    return repo;
  }

  @override
  Future<List<Book>> fetchPool() async => [
    for (final b in _pool)
      if (b.status == PoolStatus.active ||
          b.requestedBy == viewerId ||
          _isManager)
        b,
  ]..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<Book> addBook({
    required String name,
    required String publisher,
    String? subjectCode,
    BookKind kind = BookKind.questionBank,
  }) async {
    if (viewerRole == 'parent') throw StateError('NOT_ALLOWED');
    final key = (bookKey(name), bookKey(publisher));
    if (_pool.any((b) => (bookKey(b.name), bookKey(b.publisher)) == key)) {
      throw const BookExistsException();
    }
    final b = Book(
      id: _next('book'),
      name: name.trim(),
      publisher: publisher.trim(),
      subjectCode: subjectCode,
      kind: kind,
      status: viewerRole == 'student' ? PoolStatus.pending : PoolStatus.active,
      requestedBy: viewerRole == 'student' ? viewerId : null,
    );
    _pool.add(b);
    return b;
  }

  void _replace(Book b) {
    final i = _pool.indexWhere((x) => x.id == b.id);
    if (i >= 0) _pool[i] = b;
  }

  @override
  Future<void> updateBook(Book book) async {
    if (!_isManager) throw StateError('NOT_ALLOWED');
    _replace(book);
  }

  @override
  Future<void> deleteBook(String id) async {
    if (!_isManager) throw StateError('NOT_ALLOWED');
    _pool.removeWhere((b) => b.id == id);
    _books.removeWhere((b) => b.bookId == id);
  }

  @override
  Future<void> approve(String id) async {
    if (!_isManager) throw StateError('NOT_ALLOWED');
    final b = _pool.firstWhere((x) => x.id == id);
    _replace(b.copyWith(status: PoolStatus.active));
    if (b.requestedBy != null) notifications.add((b.requestedBy!, 'approved'));
  }

  @override
  Future<void> merge(String requestId, String intoId) async {
    if (!_isManager) throw StateError('NOT_ALLOWED');
    final r = _pool.firstWhere((x) => x.id == requestId);
    _pool.removeWhere((x) => x.id == requestId);
    if (r.requestedBy != null) notifications.add((r.requestedBy!, 'approved'));
  }

  @override
  Future<void> reject(String requestId, {String? reason}) async {
    if (!_isManager) throw StateError('NOT_ALLOWED');
    final r = _pool.firstWhere((x) => x.id == requestId);
    _pool.removeWhere((x) => x.id == requestId);
    if (r.requestedBy != null) notifications.add((r.requestedBy!, 'rejected'));
  }

  @override
  Future<(int, int)> importBooks(List<Book> rows) async {
    var ins = 0, skip = 0;
    for (final b in rows) {
      try {
        await addBook(
          name: b.name,
          publisher: b.publisher,
          subjectCode: b.subjectCode,
          kind: b.kind,
        );
        ins++;
      } on BookExistsException {
        skip++;
      }
    }
    return (ins, skip);
  }

  int _limitOf(String student, String term) => _limits[(student, term)] ?? 7;

  @override
  Future<BooksOverview> overview(String studentId, {String? term}) async {
    if (!_canView(studentId)) throw StateError('NOT_ALLOWED');
    final t = term ?? _term;
    final rows = [
      for (final b in _books)
        if (b.studentId == studentId && b.term == t) b,
    ];
    return BooksOverview(
      term: t,
      currentTerm: _term,
      limit: _limitOf(studentId, t),
      used: rows.length,
      terms: {
        for (final b in _books)
          if (b.studentId == studentId) b.term,
      }.toList()..sort(),
      books: [
        for (final r in rows)
          () {
            final p = [
              for (final x in _progress)
                if (x.studentBookId == r.id) x,
            ];
            return StudentBook(
              id: r.id,
              book: _pool.firstWhere((b) => b.id == r.bookId),
              status: r.status,
              startedOn: r.startedOn,
              addedRole: r.addedRole,
              questions: p.fold(0, (s, x) => s + x.solved),
              correct: p.fold(0, (s, x) => s + (x.correct ?? 0)),
              wrong: p.fold(0, (s, x) => s + (x.wrong ?? 0)),
              blank: p.fold(0, (s, x) => s + (x.blank ?? 0)),
              lastStudied: p.isEmpty
                  ? null
                  : p
                        .map((x) => x.studiedOn)
                        .reduce((a, b) => a.isAfter(b) ? a : b),
              entries: p.length,
            );
          }(),
      ],
    );
  }

  @override
  Future<void> addStudentBook(String studentId, String bookId) async {
    if (studentId != viewerId) _manage(studentId);
    final book = _pool.where((b) => b.id == bookId).firstOrNull;
    if (book == null || book.status != PoolStatus.active) {
      throw StateError('BOOK_NOT_IN_POOL');
    }
    final term = _term;
    if (_books.any(
      (b) => b.studentId == studentId && b.bookId == bookId && b.term == term,
    )) {
      throw StateError('duplicate');
    }
    final used = _books
        .where((b) => b.studentId == studentId && b.term == term)
        .length;
    if (used >= _limitOf(studentId, term)) throw const BookLimitException();
    _books.add(
      _StudentBookRow(
        _next('sb'),
        studentId,
        bookId,
        term,
        StudentBookStatus.active,
        _now,
        viewerRole,
      ),
    );
  }

  _StudentBookRow _row(String id) => _books.firstWhere((b) => b.id == id);

  @override
  Future<void> setStudentBookStatus(String id, StudentBookStatus status) async {
    final r = _row(id);
    _manage(r.studentId);
    r.status = status;
  }

  @override
  Future<void> deleteStudentBook(String id) async {
    final r = _row(id);
    _manage(r.studentId);
    _books.remove(r);
    _progress.removeWhere((p) => p.studentBookId == id);
  }

  @override
  Future<void> setLimit(String studentId, int limit, String reason) async {
    _manage(studentId);
    if (limit < 1 || limit > 50) throw StateError('BAD_LIMIT');
    _limits[(studentId, _term)] = limit;
  }

  @override
  Future<List<BookProgress>> fetchProgress(String studentBookId) async {
    final r = _row(studentBookId);
    if (!_canView(r.studentId)) throw StateError('NOT_ALLOWED');
    return [
      for (final p in _progress)
        if (p.studentBookId == studentBookId) p,
    ]..sort((a, b) => b.studiedOn.compareTo(a.studiedOn));
  }

  @override
  Future<void> addProgress(BookProgress p) async {
    final r = _row(p.studentBookId);
    if (r.studentId != viewerId) _manage(r.studentId);
    final problem = validateProgress(p, today: _now);
    if (problem != null) throw StateError(problem);
    _progress.add(
      BookProgress(
        id: _next('bp'),
        studentBookId: p.studentBookId,
        studiedOn: p.studiedOn,
        topicId: p.topicId,
        topicText: p.topicText,
        pageFrom: p.pageFrom,
        pageTo: p.pageTo,
        questions: p.questions,
        correct: p.correct,
        wrong: p.wrong,
        blank: p.blank,
        note: p.note,
        enteredRole: viewerRole,
        createdBy: viewerId,
        createdAt: _now,
      ),
    );
  }

  bool _canEdit(BookProgress p) {
    final r = _row(p.studentBookId);
    return p.editableBy(
      viewerId,
      manager: _isManager && managed.contains(r.studentId),
      now: _now,
    );
  }

  @override
  Future<void> updateProgress(BookProgress p) async {
    final i = _progress.indexWhere((x) => x.id == p.id);
    if (i < 0 || !_canEdit(_progress[i])) throw StateError('NOT_ALLOWED');
    final problem = validateProgress(p, today: _now);
    if (problem != null) throw StateError(problem);
    final old = _progress[i];
    _progress[i] = BookProgress(
      id: old.id,
      studentBookId: old.studentBookId,
      studiedOn: p.studiedOn,
      topicId: p.topicId,
      topicText: p.topicText,
      pageFrom: p.pageFrom,
      pageTo: p.pageTo,
      questions: p.questions,
      correct: p.correct,
      wrong: p.wrong,
      blank: p.blank,
      note: p.note,
      enteredRole: old.enteredRole,
      createdBy: old.createdBy,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> deleteProgress(String id) async {
    final p = _progress.where((x) => x.id == id).firstOrNull;
    if (p == null || !_canEdit(p)) throw StateError('NOT_ALLOWED');
    _progress.remove(p);
  }

  @override
  Future<Map<String, BookUsage>> usage({String? classroomId}) async {
    final per = <String, List<int>>{};
    for (final b in _books) {
      if (!_isManager || !managed.contains(b.studentId)) continue;
      final q = _progress
          .where((p) => p.studentBookId == b.id)
          .fold(0, (s, p) => s + p.solved);
      per.putIfAbsent(b.bookId, () => []).add(q);
    }
    return {
      for (final e in per.entries)
        e.key: BookUsage(
          students: e.value.length,
          avgQuestions: e.value.reduce((a, b) => a + b) / e.value.length,
          totalQuestions: e.value.reduce((a, b) => a + b),
        ),
    };
  }

  @override
  Future<List<TopicGap>> topicGaps(String studentId) async => [
    if (_canView(studentId) && studentId == 'demo-student')
      const TopicGap(
        topicId: 1,
        topicName: 'Üslü Sayılar',
        subjectCode: 'TYT_MAT',
        answered: 5,
        rate: 40,
      ),
  ];
}
