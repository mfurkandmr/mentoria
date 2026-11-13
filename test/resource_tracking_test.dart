// Kaynak takibi (NOTLAR §92): ders başına konu × kitap tablosu; öğrenci
// kutuyu işaretler, veli yalnızca görür.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/dev/demo_books.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/student_books/data/books_repository.dart';
import 'package:mentoria/features/student_books/presentation/books_screens.dart';
import 'package:mentoria/features/student_books/presentation/resource_tracking_screen.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';
import 'package:mentoria/features/tracking/data/tracking_repository.dart';
import 'package:mentoria/shared/motion.dart';

const _topics = [
  Topic(id: 1, subjectCode: 'TYT_MAT', name: 'Temel Kavramlar', sort: 1),
  Topic(id: 2, subjectCode: 'TYT_MAT', name: 'Polinomlar', sort: 2),
  Topic(id: 3, subjectCode: 'TYT_FIZ', name: 'Optik', sort: 1),
  Topic(id: 4, subjectCode: 'AYT_MAT', name: 'Türev', sort: 1),
];

const _pool = [
  Book(id: 'b1', name: '345 Allstar', publisher: '345', subjectCode: 'TYT_MAT'),
  Book(
    id: 'b2',
    name: 'Orijinal',
    publisher: 'Orijinal',
    subjectCode: 'TYT_MAT',
  ),
  Book(
    id: 'b3',
    name: 'Türev Fasikülü',
    publisher: 'X',
    subjectCode: 'AYT_MAT',
  ),
];

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  Future<InMemoryBooksRepository> seeded() async {
    final student = InMemoryBooksRepository(
      viewerId: 's1',
      viewerRole: 'student',
      pool: _pool,
    );
    for (final b in _pool) {
      await student.addStudentBook('s1', b.id);
    }
    return student;
  }

  Future<void> pump(
    WidgetTester t,
    BooksRepository books,
    BooksViewer viewer, {
    int? grade,
  }) async {
    t.view.physicalSize = const Size(1080, 4200);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final tracking = InMemoryTrackingRepository(topics: _topics);
    if (grade != null) await tracking.setGradeLevel('s1', grade);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          booksRepositoryProvider.overrideWithValue(books),
          trackingRepositoryProvider.overrideWithValue(tracking),
        ],
        child: MaterialApp(
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ResourceTrackingScreen(studentId: 's1', viewer: viewer),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('öğrenci konuyu kitap kitap işaretler', (t) async {
    final books = await seeded();
    final ids = [for (final b in (await books.overview('s1')).books) b.id];
    await pump(t, books, BooksViewer.student);

    // TYT: Matematik tablosu iki kitapla; kitabı olmayan Fizik yok.
    expect(find.text('TYT Matematik'), findsOneWidget);
    expect(find.text('345 Allstar'), findsOneWidget);
    expect(find.text('Orijinal'), findsOneWidget);
    expect(find.text('Temel Kavramlar'), findsOneWidget);
    expect(find.text('Optik'), findsNothing);
    expect(find.text('Türev'), findsNothing);
    expect(find.text('0 / 4'), findsOneWidget);

    await t.tap(find.byKey(ValueKey('mark-${ids[0]}-1')));
    await t.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
    expect(await books.fetchTopicMarks('s1'), {(ids[0], 1)});

    await t.tap(find.byKey(ValueKey('mark-${ids[0]}-1')));
    await t.pumpAndSettle();
    expect(await books.fetchTopicMarks('s1'), isEmpty);

    await t.tap(find.text('AYT'));
    await t.pumpAndSettle();
    expect(find.text('AYT Matematik'), findsOneWidget);
    expect(find.text('Türev'), findsOneWidget);
    expect(find.text('345 Allstar'), findsNothing);
  });

  testWidgets('10. sınıfta yalnızca o sınıfın konuları, sekmesiz', (t) async {
    final books = await seeded();
    await pump(t, books, BooksViewer.student, grade: 10);
    expect(find.byType(SegmentedButton<ExamType>), findsNothing);
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Polinomlar'), findsOneWidget);
    expect(find.text('Temel Kavramlar'), findsNothing);
    expect(find.text('Türev'), findsNothing);
  });

  testWidgets('veli görür ama işaretleyemez', (t) async {
    final student = await seeded();
    final ids = [for (final b in (await student.overview('s1')).books) b.id];
    await student.setTopicMark(ids[0], 1, true);
    final parent = _ReadOnly(student);
    await pump(t, parent, BooksViewer.parent);
    final box = t.widget<Checkbox>(find.byKey(ValueKey('mark-${ids[0]}-1')));
    expect(box.value, isTrue);
    expect(box.onChanged, isNull);
  });

  test(
    'bellekteki depo: yabancı koç göremez, olmayan kitap işaretlenemez',
    () async {
      final student = await seeded();
      final ids = [for (final b in (await student.overview('s1')).books) b.id];
      await student.setTopicMark(ids[0], 1, true);
      final stranger = InMemoryBooksRepository(
        viewerId: 'c9',
        viewerRole: 'coach',
        pool: _pool,
      );
      expect(() => stranger.fetchTopicMarks('s1'), throwsStateError);
      expect(() => student.setTopicMark('yok', 1, true), throwsStateError);
    },
  );
}

/// Velinin gördüğü: okuma öğrencinin deposundan, yazma yok.
class _ReadOnly implements BooksRepository {
  _ReadOnly(this._inner);
  final InMemoryBooksRepository _inner;

  @override
  Future<BooksOverview> overview(String studentId, {String? term}) =>
      _inner.overview(studentId, term: term);

  @override
  Future<Set<(String, int)>> fetchTopicMarks(String studentId) =>
      _inner.fetchTopicMarks(studentId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('NOT_ALLOWED');
}
