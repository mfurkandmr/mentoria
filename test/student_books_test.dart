import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_books.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/student_books/data/books_repository.dart';
import 'package:mentoria/features/student_books/presentation/book_pool_screen.dart';
import 'package:mentoria/features/student_books/presentation/books_screens.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  test('dönem: Eylül-Ocak Güz, Şubat-Ağustos Bahar', () {
    expect(termOf(DateTime(2026, 9, 1)), '2026-Güz');
    expect(termOf(DateTime(2027, 1, 31)), '2026-Güz');
    expect(termOf(DateTime(2027, 2, 1)), '2027-Bahar');
  });

  test('çalışma doğrulaması', () {
    BookProgress p({
      int? q,
      int? c,
      int? w,
      int? b,
      int? from,
      int? to,
      DateTime? day,
    }) => BookProgress(
      id: '',
      studentBookId: 'x',
      studiedOn: day ?? DateTime(2026, 11, 1),
      questions: q,
      correct: c,
      wrong: w,
      blank: b,
      pageFrom: from,
      pageTo: to,
    );
    final today = DateTime(2026, 11, 5);
    expect(
      validateProgress(p(q: 10, c: 8, w: 2, b: 1), today: today),
      isNotNull,
    );
    expect(validateProgress(p(q: 10, c: 8, w: 2), today: today), isNull);
    expect(validateProgress(p(from: 20, to: 10), today: today), isNotNull);
    expect(
      validateProgress(p(day: DateTime(2026, 11, 6)), today: today),
      isNotNull,
    );
  });

  test('benzer kitap ve Excel ders adı', () {
    const pool = [
      Book(
        id: 'a',
        name: 'TYT Matematik Soru Bankası',
        publisher: '3D Yayınları',
      ),
      Book(id: 'b', name: 'AYT Fizik', publisher: 'Palme'),
    ];
    const req = Book(
      id: 'r',
      name: 'TYT matematik soru bankasi',
      publisher: '3D',
      status: PoolStatus.pending,
    );
    expect(similarBooks(req, pool).map((b) => b.id), ['a']);
    expect(subjectFromText('TYT Matematik'), 'TYT_MAT');
    expect(subjectFromText('ayt fizik'), 'AYT_FIZ');
    expect(subjectFromText('Matematik'), isNull);
  });

  late InMemoryBooksRepository repo;

  Future<void> pump(
    WidgetTester t,
    Widget home, {
    String role = 'student',
    String viewer = 'demo-student',
  }) async {
    t.view.physicalSize = const Size(1080, 3200);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    repo = InMemoryBooksRepository.demo(
      viewerId: viewer,
      viewerRole: role,
      managed: const {'demo-student', 'demo-can'},
      children: const {'demo-student'},
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: await buildDemoOverrides(
          role,
          true,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          repo,
        ),
        child: MaterialApp(
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('öğrenci havuzdan kitap ekler; onay kutusu zorunlu', (t) async {
    await pump(t, const MyBooksScreen());
    expect(find.text('3 / 7 kitap kullanıldı'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('add-book')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pool-b-3')));
    await t.pumpAndSettle();
    expect(find.textContaining('kendin kaldıramazsın'), findsOneWidget);
    final confirm = t.widget<FilledButton>(
      find.byKey(const ValueKey('book-confirm')),
    );
    expect(confirm.onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('book-agree')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('book-confirm')));
    await t.pumpAndSettle();
    expect(find.text('4 / 7 kitap kullanıldı'), findsOneWidget);
    expect(find.text('TYT Fizik Soru Bankası'), findsOneWidget);
  });

  testWidgets('havuzda olmayan kitap talep edilir, listeye eklenmez', (
    t,
  ) async {
    await pump(t, const MyBooksScreen());
    await t.tap(find.byKey(const ValueKey('add-book')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('book-search')),
      'Hız Yayınları',
    );
    await t.pumpAndSettle();
    expect(find.text('Kitabı bulamadın mı? Talep et'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('request-book')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('book-name')), 'Hız TYT Kimya');
    await t.enterText(
      find.byKey(const ValueKey('book-publisher')),
      'Hız Yayınları',
    );
    await t.tap(find.byKey(const ValueKey('book-form-save')));
    await t.pumpAndSettle();
    expect(find.textContaining('Talebin iletildi'), findsOneWidget);
    final pool = await repo.fetchPool();
    final req = pool.firstWhere((b) => b.name == 'Hız TYT Kimya');
    expect(req.status, PoolStatus.pending);
    final o = await repo.overview('demo-student');
    expect(o.books.any((b) => b.book.id == req.id), isFalse);
    expect(o.used, 3);
  });

  testWidgets('hak dolunca ekleme engellenir', (t) async {
    await pump(t, const MyBooksScreen());
    for (final id in ['b-3', 'b-5', 'b-6', 'b-7']) {
      await repo.addStudentBook('demo-student', id);
    }
    // Bitti işaretlenen kitap hakkı boşaltmaz.
    expect(
      () => repo.addStudentBook('demo-student', 'b-8'),
      throwsA(isA<BookLimitException>()),
    );
    final container = ProviderScope.containerOf(
      t.element(find.byType(MyBooksScreen)),
    );
    container.invalidate(booksOverviewProvider);
    await t.pumpAndSettle();
    expect(find.text('7 / 7 kitap kullanıldı'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('add-book')));
    await t.pumpAndSettle();
    expect(find.textContaining('7 kitap hakkını kullandın'), findsOneWidget);
  });

  testWidgets('koç: limiti artırır, durumu değiştirir, siler', (t) async {
    await pump(
      t,
      const Scaffold(
        body: StudentBooksView(
          studentId: 'demo-student',
          viewer: BooksViewer.manager,
        ),
      ),
      role: 'coach',
      viewer: 'demo-coach',
    );
    expect(find.text('Kitapla desteklenmesi gereken konular'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('raise-limit')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('limit-plus')));
    await t.enterText(find.byKey(const ValueKey('limit-reason')), 'Ek kaynak');
    await t.tap(find.byKey(const ValueKey('limit-save')));
    await t.pumpAndSettle();
    expect(find.text('3 / 9 kitap kullanıldı'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('student-book-sb-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('book-manage')));
    await t.pumpAndSettle();
    await t.tap(find.text('Durum: Bitti'));
    await t.pumpAndSettle();
    var o = await repo.overview('demo-student');
    expect(
      o.books.firstWhere((b) => b.id == 'sb-0').status,
      StudentBookStatus.finished,
    );
    expect(o.used, 3);

    await t.tap(find.byKey(const ValueKey('student-book-sb-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('book-manage')));
    await t.pumpAndSettle();
    await t.tap(find.text('Listeden sil'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sil'));
    await t.pumpAndSettle();
    o = await repo.overview('demo-student');
    expect(o.used, 2);
    expect(find.text('2 / 9 kitap kullanıldı'), findsOneWidget);
  });

  testWidgets('öğrenci durumu değiştiremez; çalışma doğrulanır', (t) async {
    await pump(t, const MyBooksScreen());
    await t.tap(find.byKey(const ValueKey('student-book-sb-0')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('book-manage')), findsNothing);
    expect(
      () => repo.setStudentBookStatus('sb-0', StudentBookStatus.finished),
      throwsStateError,
    );

    await t.tap(find.byKey(const ValueKey('add-progress')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('p-questions')), '10');
    await t.enterText(find.byKey(const ValueKey('p-correct')), '8');
    await t.enterText(find.byKey(const ValueKey('p-wrong')), '2');
    await t.enterText(find.byKey(const ValueKey('p-blank')), '1');
    await t.tap(find.byKey(const ValueKey('progress-save')));
    await t.pumpAndSettle();
    expect(
      find.text('Doğru + yanlış + boş, soru sayısını geçemez.'),
      findsOneWidget,
    );
    await t.enterText(find.byKey(const ValueKey('p-blank')), '0');
    await t.tap(find.byKey(const ValueKey('progress-save')));
    await t.pumpAndSettle();
    final list = await repo.fetchProgress('sb-0');
    expect(
      list.where((p) => p.questions == 10 && p.correct == 8),
      hasLength(1),
    );
  });

  testWidgets('veli yalnızca okur', (t) async {
    await pump(
      t,
      const Scaffold(
        body: StudentBooksView(
          studentId: 'demo-student',
          viewer: BooksViewer.parent,
        ),
      ),
      role: 'parent',
      viewer: 'demo-parent',
    );
    expect(find.text('3 / 7 kitap kullanıldı'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-book')), findsNothing);
    expect(find.textContaining('Son 7 günde kitaplardan'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('student-book-sb-0')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-progress')), findsNothing);
    expect(() => repo.addStudentBook('demo-student', 'b-3'), throwsStateError);
  });

  testWidgets('havuz: bekleyen talep onaylanır, öğrenciye bildirim', (t) async {
    await pump(t, const BookPoolScreen(), role: 'admin', viewer: 'demo-admin');
    await t.tap(find.textContaining('Onay bekleyenler (1)'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pending-b-req')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('approve-request')));
    await t.pumpAndSettle();
    expect(repo.notifications, [('demo-student', 'approved')]);
    expect(find.textContaining('Onay bekleyenler (0)'), findsOneWidget);
  });

  testWidgets('havuz Excel önizlemesi', (t) async {
    await pump(
      t,
      const BookImportScreen(
        initialRows: [
          ['Kitap Adı', 'Yayın', 'Ders', 'Tür'],
          ['TYT Geometri', 'Bilgi Sarmal', 'TYT Matematik', 'Soru bankası'],
          ['Paragraf Deneme', 'Limit', 'Türkçe', 'Deneme'],
          ['', 'Eksik', '', ''],
        ],
      ),
      role: 'admin',
      viewer: 'demo-admin',
    );
    expect(find.text('2 kitap okundu'), findsOneWidget);
    expect(find.textContaining('1 satırda ders tanınmadı'), findsOneWidget);
    expect(
      find.textContaining('1 satırda ad ya da yayın eksik'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('books-import-go')));
    await t.pumpAndSettle();
    final pool = await repo.fetchPool();
    expect(
      pool.firstWhere((b) => b.name == 'TYT Geometri').subjectCode,
      'TYT_MAT',
    );
    expect(
      pool.firstWhere((b) => b.name == 'Paragraf Deneme').kind,
      BookKind.practiceExams,
    );
  });
}
