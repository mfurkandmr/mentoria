import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';

enum BookKind {
  questionBank('question_bank'),
  practiceExams('practice_exams'),
  lecture('lecture'),
  other('other');

  const BookKind(this.db);

  final String db;

  static BookKind fromDb(String? v) =>
      values.firstWhere((k) => k.db == v, orElse: () => BookKind.other);

  String get label => switch (this) {
    questionBank => tr('Soru bankası'),
    practiceExams => tr('Deneme kitabı'),
    lecture => tr('Konu anlatımı'),
    other => tr('Diğer'),
  };
}

enum PoolStatus {
  active('active'),
  pending('pending'),
  inactive('inactive');

  const PoolStatus(this.db);

  final String db;

  static PoolStatus fromDb(String? v) =>
      values.firstWhere((k) => k.db == v, orElse: () => PoolStatus.active);
}

enum StudentBookStatus {
  active('active'),
  finished('finished'),
  dropped('dropped');

  const StudentBookStatus(this.db);

  final String db;

  static StudentBookStatus fromDb(String? v) => values.firstWhere(
    (k) => k.db == v,
    orElse: () => StudentBookStatus.active,
  );

  String get label => switch (this) {
    active => tr('Devam ediyor'),
    finished => tr('Bitti'),
    dropped => tr('Bırakıldı'),
  };
}

/// Kurum havuzundaki kitap (ya da öğrencinin talebi).
class Book {
  const Book({
    required this.id,
    required this.name,
    required this.publisher,
    this.subjectCode,
    this.kind = BookKind.questionBank,
    this.status = PoolStatus.active,
    this.requestedBy,
  });

  final String id;
  final String name;
  final String publisher;

  /// TYT_MAT gibi; karma kitapta null.
  final String? subjectCode;
  final BookKind kind;
  final PoolStatus status;
  final String? requestedBy;

  String get subjectName => subjectCode == null
      ? tr('Karma')
      : '${subjectCode!.split('_').first} ${subjectByCode(subjectCode!).name}';

  Book copyWith({PoolStatus? status, String? name, String? publisher}) => Book(
    id: id,
    name: name ?? this.name,
    publisher: publisher ?? this.publisher,
    subjectCode: subjectCode,
    kind: kind,
    status: status ?? this.status,
    requestedBy: requestedBy,
  );
}

/// Öğrencinin bir kitabı ve toplam ilerlemesi.
class StudentBook {
  const StudentBook({
    required this.id,
    required this.book,
    required this.status,
    required this.startedOn,
    this.addedRole,
    this.questions = 0,
    this.correct = 0,
    this.wrong = 0,
    this.blank = 0,
    this.lastStudied,
    this.entries = 0,
  });

  final String id;
  final Book book;
  final StudentBookStatus status;
  final DateTime startedOn;
  final String? addedRole;
  final int questions;
  final int correct;
  final int wrong;
  final int blank;
  final DateTime? lastStudied;
  final int entries;
}

/// Dönem hakkı ve kitaplar.
class BooksOverview {
  const BooksOverview({
    required this.term,
    required this.currentTerm,
    required this.limit,
    required this.used,
    required this.books,
    this.terms = const [],
  });

  final String term;
  final String currentTerm;
  final int limit;
  final int used;
  final List<StudentBook> books;
  final List<String> terms;

  bool get isCurrent => term == currentTerm;
  bool get full => used >= limit;
}

class BookProgress {
  const BookProgress({
    required this.id,
    required this.studentBookId,
    required this.studiedOn,
    this.topicId,
    this.topicText,
    this.pageFrom,
    this.pageTo,
    this.questions,
    this.correct,
    this.wrong,
    this.blank,
    this.note,
    this.enteredRole,
    this.createdBy,
    this.createdAt,
  });

  factory BookProgress.fromJson(Map<String, dynamic> j) => BookProgress(
    id: j['id'] as String,
    studentBookId: j['student_book_id'] as String,
    studiedOn: DateTime.parse(j['studied_on'] as String),
    topicId: j['topic_id'] as int?,
    topicText: j['topic_text'] as String?,
    pageFrom: j['page_from'] as int?,
    pageTo: j['page_to'] as int?,
    questions: j['questions'] as int?,
    correct: j['correct'] as int?,
    wrong: j['wrong'] as int?,
    blank: j['blank'] as int?,
    note: j['note'] as String?,
    enteredRole: j['entered_role'] as String?,
    createdBy: j['created_by'] as String?,
    createdAt: j['created_at'] == null
        ? null
        : DateTime.parse(j['created_at'] as String).toLocal(),
  );

  final String id;
  final String studentBookId;
  final DateTime studiedOn;
  final int? topicId;
  final String? topicText;
  final int? pageFrom;
  final int? pageTo;
  final int? questions;
  final int? correct;
  final int? wrong;
  final int? blank;
  final String? note;
  final String? enteredRole;
  final String? createdBy;
  final DateTime? createdAt;

  int get solved => questions ?? ((correct ?? 0) + (wrong ?? 0) + (blank ?? 0));

  /// Öğrenci kendi kaydını 24 saat düzenleyebilir.
  bool editableBy(String userId, {required bool manager, DateTime? now}) =>
      manager ||
      (createdBy == userId &&
          createdAt != null &&
          (now ?? DateTime.now()).difference(createdAt!) <
              const Duration(hours: 24));

  Map<String, dynamic> toRow() => {
    'student_book_id': studentBookId,
    'studied_on': _ymd(studiedOn),
    'topic_id': topicId,
    'topic_text': topicText,
    'page_from': pageFrom,
    'page_to': pageTo,
    'questions': questions,
    'correct': correct,
    'wrong': wrong,
    'blank': blank,
    'note': note,
  };
}

/// Çalışma kaydı doğrulaması (sunucudakiyle aynı); sorun yoksa null.
String? validateProgress(BookProgress p, {DateTime? today}) {
  final t = today ?? DateTime.now();
  final day = DateTime(t.year, t.month, t.day);
  if (p.studiedOn.isAfter(day)) return tr('Tarih ileride olamaz.');
  if (p.pageFrom != null && p.pageTo != null && p.pageTo! < p.pageFrom!) {
    return tr('Bitiş sayfası başlangıçtan küçük olamaz.');
  }
  final sum = (p.correct ?? 0) + (p.wrong ?? 0) + (p.blank ?? 0);
  if (p.questions != null && sum > p.questions!) {
    return tr('Doğru + yanlış + boş, soru sayısını geçemez.');
  }
  return null;
}

class BookUsage {
  const BookUsage({
    required this.students,
    required this.avgQuestions,
    required this.totalQuestions,
  });

  final int students;
  final double avgQuestions;
  final int totalQuestions;
}

/// Denemede başarısı düşük ama kitapla çalışılmamış konu.
class TopicGap {
  const TopicGap({
    required this.topicId,
    required this.topicName,
    required this.subjectCode,
    required this.answered,
    required this.rate,
  });

  final int topicId;
  final String topicName;
  final String? subjectCode;
  final int answered;
  final int rate;
}

/// Dönem sınırı doldu.
class BookLimitException implements Exception {
  const BookLimitException();
}

/// Havuzda aynı ad + yayınla kitap var.
class BookExistsException implements Exception {
  const BookExistsException();
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Ad / yayın eşleştirme anahtarı (sunucudaki norm_key ile aynı).
String bookKey(String s) {
  const map = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  var t = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  map.forEach((k, v) => t = t.replaceAll(k, v));
  return t.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

abstract interface class BooksRepository {
  /// Havuz: aktifler; koç/müdürde bekleyen talepler de, öğrencide kendi talepleri.
  Future<List<Book>> fetchPool();

  /// Öğrenci: talep (durum sunucuda 'pending'). Koç/müdür: havuza ekler.
  Future<Book> addBook({
    required String name,
    required String publisher,
    String? subjectCode,
    BookKind kind = BookKind.questionBank,
  });
  Future<void> updateBook(Book book);
  Future<void> deleteBook(String id);
  Future<void> approve(String id);
  Future<void> merge(String requestId, String intoId);
  Future<void> reject(String requestId, {String? reason});

  /// Toplu ekleme; aynı ad + yayın atlanır. (eklenen, atlanan).
  Future<(int, int)> importBooks(List<Book> rows);

  Future<BooksOverview> overview(String studentId, {String? term});
  Future<void> addStudentBook(String studentId, String bookId);
  Future<void> setStudentBookStatus(String id, StudentBookStatus status);
  Future<void> deleteStudentBook(String id);
  Future<void> setLimit(String studentId, int limit, String reason);

  Future<List<BookProgress>> fetchProgress(String studentBookId);
  Future<void> addProgress(BookProgress p);
  Future<void> updateProgress(BookProgress p);
  Future<void> deleteProgress(String id);

  /// Kitap kimliği → kullanım (koç: kendi öğrencileri, müdür: kurum).
  Future<Map<String, BookUsage>> usage({String? classroomId});
  Future<List<TopicGap>> topicGaps(String studentId);
}

class SupabaseBooksRepository implements BooksRepository {
  SupabaseBooksRepository(this._client);

  final SupabaseClient _client;
  Map<int, String>? _codes;

  Future<Map<int, String>> _subjectCodes() async => _codes ??= {
    for (final r in await _client.from('subjects').select('id, code'))
      r['id'] as int: r['code'] as String,
  };

  Future<int?> _subjectId(String? code) async {
    if (code == null) return null;
    final codes = await _subjectCodes();
    return codes.entries.where((e) => e.value == code).firstOrNull?.key;
  }

  Book _book(Map r, Map<int, String> codes) => Book(
    id: r['id'] as String,
    name: r['name'] as String,
    publisher: r['publisher'] as String,
    subjectCode: codes[r['subject_id'] as int?],
    kind: BookKind.fromDb(r['kind'] as String?),
    status: PoolStatus.fromDb(r['status'] as String?),
    requestedBy: r['requested_by'] as String?,
  );

  Never _rethrow(Object e) {
    final m = '$e';
    if (m.contains('BOOK_LIMIT')) throw const BookLimitException();
    if (m.contains('23505') ||
        m.contains('books_unique') ||
        m.contains('duplicate')) {
      throw const BookExistsException();
    }
    throw e;
  }

  @override
  Future<List<Book>> fetchPool() async {
    final codes = await _subjectCodes();
    return [
      for (final r
          in await _client
              .from('books')
              .select(
                'id, name, publisher, subject_id, kind, status, requested_by',
              )
              .order('name'))
        _book(r, codes),
    ];
  }

  @override
  Future<Book> addBook({
    required String name,
    required String publisher,
    String? subjectCode,
    BookKind kind = BookKind.questionBank,
  }) async {
    try {
      final codes = await _subjectCodes();
      final r = await _client
          .from('books')
          .insert({
            'name': name.trim(),
            'publisher': publisher.trim(),
            'subject_id': await _subjectId(subjectCode),
            'kind': kind.db,
          })
          .select('id, name, publisher, subject_id, kind, status, requested_by')
          .single();
      return _book(r, codes);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> updateBook(Book book) async {
    try {
      await _client
          .from('books')
          .update({
            'name': book.name,
            'publisher': book.publisher,
            'subject_id': await _subjectId(book.subjectCode),
            'kind': book.kind.db,
            'status': book.status.db,
          })
          .eq('id', book.id);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> deleteBook(String id) =>
      _client.from('books').delete().eq('id', id);

  @override
  Future<void> approve(String id) =>
      _client.rpc('approve_book', params: {'p_book': id});

  @override
  Future<void> merge(String requestId, String intoId) => _client.rpc(
    'merge_book_request',
    params: {'p_request': requestId, 'p_into': intoId},
  );

  @override
  Future<void> reject(String requestId, {String? reason}) => _client.rpc(
    'reject_book_request',
    params: {'p_request': requestId, 'p_reason': reason},
  );

  @override
  Future<(int, int)> importBooks(List<Book> rows) async {
    final payload = [
      for (final b in rows)
        {
          'name': b.name,
          'publisher': b.publisher,
          'subject_id': await _subjectId(b.subjectCode),
          'kind': b.kind.db,
        },
    ];
    final r = Map<String, dynamic>.from(
      await _client.rpc('import_books', params: {'p_rows': payload}) as Map,
    );
    return (r['inserted'] as int? ?? 0, r['skipped'] as int? ?? 0);
  }

  @override
  Future<BooksOverview> overview(String studentId, {String? term}) async {
    final codes = await _subjectCodes();
    final j = Map<String, dynamic>.from(
      await _client.rpc(
            'student_books_overview',
            params: {'p_student': studentId, 'p_term': term},
          )
          as Map,
    );
    return BooksOverview(
      term: j['term'] as String,
      currentTerm: j['current_term'] as String,
      limit: j['limit'] as int,
      used: j['used'] as int,
      terms: [for (final t in j['terms'] as List) t as String]..sort(),
      books: [
        for (final b in j['books'] as List)
          StudentBook(
            id: b['id'] as String,
            book: Book(
              id: b['book_id'] as String,
              name: b['name'] as String,
              publisher: b['publisher'] as String,
              subjectCode: codes[b['subject_id'] as int?],
              kind: BookKind.fromDb(b['kind'] as String?),
            ),
            status: StudentBookStatus.fromDb(b['status'] as String?),
            startedOn: DateTime.parse(b['started_on'] as String),
            addedRole: b['added_role'] as String?,
            questions: (b['questions'] as num?)?.toInt() ?? 0,
            correct: (b['correct'] as num?)?.toInt() ?? 0,
            wrong: (b['wrong'] as num?)?.toInt() ?? 0,
            blank: (b['blank'] as num?)?.toInt() ?? 0,
            lastStudied: b['last_studied'] == null
                ? null
                : DateTime.parse(b['last_studied'] as String),
            entries: (b['entries'] as num?)?.toInt() ?? 0,
          ),
      ],
    );
  }

  @override
  Future<void> addStudentBook(String studentId, String bookId) async {
    try {
      await _client.from('student_books').insert({
        'student_id': studentId,
        'book_id': bookId,
      });
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> setStudentBookStatus(String id, StudentBookStatus status) =>
      _client.from('student_books').update({'status': status.db}).eq('id', id);

  @override
  Future<void> deleteStudentBook(String id) =>
      _client.from('student_books').delete().eq('id', id);

  @override
  Future<void> setLimit(String studentId, int limit, String reason) =>
      _client.rpc(
        'set_book_limit',
        params: {'p_student': studentId, 'p_limit': limit, 'p_reason': reason},
      );

  @override
  Future<List<BookProgress>> fetchProgress(String studentBookId) async => [
    for (final r
        in await _client
            .from('book_progress')
            .select()
            .eq('student_book_id', studentBookId)
            .order('studied_on', ascending: false)
            .order('created_at', ascending: false))
      BookProgress.fromJson(Map<String, dynamic>.from(r)),
  ];

  @override
  Future<void> addProgress(BookProgress p) =>
      _client.from('book_progress').insert(p.toRow());

  @override
  Future<void> updateProgress(BookProgress p) async {
    final row = p.toRow()..remove('student_book_id');
    final res = await _client
        .from('book_progress')
        .update(row)
        .eq('id', p.id)
        .select('id');
    if ((res as List).isEmpty) throw StateError('NOT_ALLOWED');
  }

  @override
  Future<void> deleteProgress(String id) async {
    final res = await _client
        .from('book_progress')
        .delete()
        .eq('id', id)
        .select('id');
    if ((res as List).isEmpty) throw StateError('NOT_ALLOWED');
  }

  @override
  Future<Map<String, BookUsage>> usage({String? classroomId}) async => {
    for (final r
        in await _client.rpc('book_usage', params: {'p_classroom': classroomId})
            as List)
      r['book_id'] as String: BookUsage(
        students: r['students'] as int,
        avgQuestions: (r['avg_questions'] as num?)?.toDouble() ?? 0,
        totalQuestions: r['total_questions'] as int? ?? 0,
      ),
  };

  @override
  Future<List<TopicGap>> topicGaps(String studentId) async {
    final codes = await _subjectCodes();
    return [
      for (final r
          in await _client.rpc('topic_gaps', params: {'p_student': studentId})
              as List)
        TopicGap(
          topicId: r['topic_id'] as int,
          topicName: r['topic_name'] as String,
          subjectCode: codes[r['subject_id'] as int?],
          answered: r['answered'] as int,
          rate: r['rate'] as int,
        ),
    ];
  }
}

final booksRepositoryProvider = Provider<BooksRepository>(
  (ref) => SupabaseBooksRepository(ref.watch(supabaseClientProvider)),
);

final bookPoolProvider = FutureProvider<List<Book>>(
  (ref) => ref.watch(booksRepositoryProvider).fetchPool(),
);

/// (öğrenci, dönem) → kitaplar ve hak. Dönem null: içinde bulunulan dönem.
final booksOverviewProvider =
    FutureProvider.family<BooksOverview, (String, String?)>(
      (ref, k) => ref.watch(booksRepositoryProvider).overview(k.$1, term: k.$2),
    );

final bookProgressProvider = FutureProvider.family<List<BookProgress>, String>(
  (ref, id) => ref.watch(booksRepositoryProvider).fetchProgress(id),
);

final bookUsageProvider = FutureProvider<Map<String, BookUsage>>(
  (ref) => ref.watch(booksRepositoryProvider).usage(),
);

final topicGapsProvider = FutureProvider.family<List<TopicGap>, String>(
  (ref, id) => ref.watch(booksRepositoryProvider).topicGaps(id),
);

/// Eğitim dönemi (sunucudaki term_of ile aynı): Eylül-Ocak "2026-Güz",
/// Şubat-Ağustos "2027-Bahar".
String termOf(DateTime d) => d.month >= 9
    ? '${d.year}-Güz'
    : d.month == 1
    ? '${d.year - 1}-Güz'
    : '${d.year}-Bahar';
