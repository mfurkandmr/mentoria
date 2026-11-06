import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/admin/presentation/cockpit/cockpit_motion.dart';
import 'package:mentoria/features/admin/presentation/cockpit/cockpit_theme.dart';
import 'package:mentoria/features/attendance/data/attendance_repository.dart';
import 'package:mentoria/features/coach/data/coach_repository.dart';
import 'package:mentoria/features/exam_import/data/exam_admin_repository.dart';
import 'package:mentoria/features/exam_import/domain/exam_definition.dart';
import 'package:mentoria/features/pending_work/domain/pending_work.dart';
import 'package:mentoria/features/pending_work/presentation/pending_work_screen.dart';
import 'package:mentoria/features/student_books/data/books_repository.dart';
import 'package:mentoria/features/student_management/data/student_management_repository.dart';
import 'package:mentoria/shared/motion.dart';

final _now = DateTime(2026, 11, 6, 10);

/// Koç kaynaklarının hepsi boş (bekleyen iş yok).
List<Override> _emptyCoach({
  List<StudentSummary> summaries = const [],
  Map<String, DateTime> deletions = const {},
  bool booksFail = false,
  bool allFail = false,
}) {
  Never fail() => throw Exception('ağ yok');
  return [
    attendanceDayProvider.overrideWith(
      (ref, day) async => allFail ? fail() : const <AttendanceRow>[],
    ),
    bookPoolProvider.overrideWith(
      (ref) async => allFail || booksFail ? fail() : const [],
    ),
    orgExamsProvider.overrideWith((ref) async => allFail ? fail() : const []),
    deletionRequestsProvider.overrideWith(
      (ref) async => allFail ? fail() : deletions,
    ),
    studentSummariesProvider.overrideWith(
      (ref) async => allFail ? fail() : summaries,
    ),
    managedStudentsProvider.overrideWith(
      (ref) async => allFail ? fail() : const [],
    ),
  ];
}

final _visited = <String>[];

Future<void> _pump(
  WidgetTester t,
  List<Override> overrides, {
  String base = '/coach',
  Size size = const Size(1080, 2400),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  _visited.clear();
  Widget page(GoRouterState s) {
    _visited.add(s.uri.toString());
    return Scaffold(body: Text('sayfa ${s.uri}'));
  }

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            CockpitThemed(child: PendingWorkScreen(basePath: base)),
      ),
      GoRoute(path: '/:a/:b', builder: (_, s) => page(s)),
      GoRoute(path: '/:a/:b/:c', builder: (_, s) => page(s)),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    CockpitHaptics.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  group('pendingItems', () {
    test('sayısı sıfır olan iş listeye girmez', () {
      expect(
        pendingItems(
          now: _now,
          pendingBooks: 0,
          draftExams: 0,
          deletions: const {},
          unassigned: 0,
          flagged: 0,
          missingNumbers: 0,
          overdueCount: 0,
        ),
        isEmpty,
      );
    });

    test('önce riskler, sonra dikkat gerekenler', () {
      final items = pendingItems(
        now: _now,
        pendingBooks: 2,
        overdueCount: 3,
        overdueAmount: 4500,
      );
      expect(items.map((i) => i.id), ['pending-finance', 'pending-books']);
      expect(items.first.level, PendingLevel.risk);
      expect(items.last.level, PendingLevel.warn);
      // Rakam çıplak değil: yanında ne olduğu ve sebebi yazar.
      expect(items.first.count, 3);
      expect(items.first.title, 'taksidin vadesi geçti');
      expect(items.first.reason, contains('tahsil edilmedi'));
    });

    test('silme talebi: geçen gün sayısı ve KVKK süresi', () {
      final items = pendingItems(
        now: _now,
        deletions: {
          's2': DateTime(2026, 10, 1), // 36 gün: süre doldu
          's1': DateTime(2026, 10, 27), // 10 gün: 20 gün kaldı
        },
        names: const {'s1': 'Ali Yılmaz'},
      );
      // En eski talep önce.
      expect(items.map((i) => i.id), [
        'pending-deletion-s2',
        'pending-deletion-s1',
      ]);
      expect(items[0].count, 36);
      expect(items[0].reason, contains('süresi doldu'));
      expect(items[0].title, contains('Bir öğrenci'));
      expect(items[1].count, 10);
      expect(items[1].unit, 'gün');
      expect(items[1].title, contains('Ali Yılmaz'));
      expect(items[1].reason, contains('20 gün kaldı'));
      expect(items[1].route, '/students/s1');
    });

    test('yoklama: hiç alınmadıysa ya da işaretsiz kaldıysa', () {
      AttendanceCounts rows(List<AttendanceStatus?> s) => AttendanceCounts([
        for (final (i, st) in s.indexed)
          AttendanceRow(studentId: 's$i', fullName: 'Ö $i', status: st),
      ]);
      final none = pendingItems(now: _now, attendance: rows([null, null]));
      expect(none.single.count, 2);
      expect(none.single.title, contains('alınmadı'));

      final some = pendingItems(
        now: _now,
        attendance: rows([AttendanceStatus.present, null, null]),
      );
      expect(some.single.count, 2);
      expect(some.single.title, contains('işaretsiz'));

      expect(
        pendingItems(now: _now, attendance: rows([AttendanceStatus.present])),
        isEmpty,
      );
    });

    test('kurum hesabı uyarısı rakamsız ve adressiz (destekle çözülür)', () {
      final items = pendingItems(
        now: _now,
        orgAlerts: [
          (
            level: PendingLevel.risk,
            title: 'Öğrenci krediniz bitti',
            message: 'Yeni öğrenci eklenemez.',
          ),
        ],
      );
      expect(items.single.count, isNull);
      expect(items.single.route, isNull);
    });
  });

  group('ekran halleri', () {
    testWidgets('yükleniyor: iskelet', (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceDayProvider.overrideWith(
              (ref, d) => Completer<List<AttendanceRow>>().future,
            ),
            bookPoolProvider.overrideWith(
              (ref) => Completer<List<Book>>().future,
            ),
            orgExamsProvider.overrideWith(
              (ref) => Completer<List<ExamDefinition>>().future,
            ),
            deletionRequestsProvider.overrideWith(
              (ref) => Completer<Map<String, DateTime>>().future,
            ),
            studentSummariesProvider.overrideWith(
              (ref) => Completer<List<StudentSummary>>().future,
            ),
            managedStudentsProvider.overrideWith(
              (ref) => Completer<List<ManagedStudent>>().future,
            ),
          ],
          child: const MaterialApp(
            home: CockpitThemed(child: PendingWorkScreen(basePath: '/coach')),
          ),
        ),
      );
      await t.pump();
      expect(find.byKey(const ValueKey('pending-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-empty')), findsNothing);
    });

    testWidgets('boş: kendi metni', (t) async {
      await _pump(t, _emptyCoach());
      expect(find.byKey(const ValueKey('pending-empty')), findsOneWidget);
      expect(find.text('Bekleyen işin yok, her şey güncel.'), findsOneWidget);
      expect(find.textContaining('veri bulunamadı'), findsNothing);
    });

    testWidgets('hata: hepsi alınamadıysa tekrar dene', (t) async {
      await _pump(t, _emptyCoach(allFail: true));
      expect(find.byKey(const ValueKey('pending-error')), findsOneWidget);
      expect(
        find.text(
          'Bekleyen işler yüklenemedi. Bağlantını kontrol edip tekrar dene.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('kısmi hata: gelmeyen kaynak ayrı satır, gerisi görünür', (
      t,
    ) async {
      await _pump(t, _emptyCoach(booksFail: true));
      expect(
        find.byKey(const ValueKey('pending-failed-books')),
        findsOneWidget,
      );
      expect(find.text('Kitap havuzu bilgisi alınamadı'), findsOneWidget);
      expect(find.text('Gelen kaynaklarda bekleyen iş yok.'), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-empty')), findsNothing);
    });

    testWidgets('filtre boş: acil iş yokken Acil seçilirse', (t) async {
      await _pump(
        t,
        _emptyCoach(
          summaries: const [
            StudentSummary(id: 's1', fullName: 'Ali', examCount: 0),
          ],
        ),
      );
      expect(find.byKey(const ValueKey('pending-numbers')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pending-filter-urgent')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pending-filter-empty')),
        findsOneWidget,
      );
      expect(find.text('Diğer 1 bekleyen iş Tümü sekmesinde.'), findsOneWidget);
      await t.tap(find.text('Tümünü göster'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pending-numbers')), findsOneWidget);
    });

    testWidgets('önce acil olanlar; 5 satır, sonra "Tümünü gör (N)"', (
      t,
    ) async {
      await _pump(
        t,
        _emptyCoach(
          summaries: const [
            StudentSummary(id: 's1', fullName: 'Ali', examCount: 0),
          ],
          deletions: {
            for (var i = 0; i < 6; i++) 'd$i': DateTime(2026, 11, 1 + i % 5),
          },
        ),
      );
      final rows = find.byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('pending-'),
      );
      expect(rows, findsNWidgets(5));
      // Dikkat satırı (numara eksik) acillerin altında, ilk 5'te değil.
      expect(find.byKey(const ValueKey('pending-numbers')), findsNothing);
      expect(find.text('Tümünü gör (7)'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pending-show-all')));
      await t.pumpAndSettle();
      expect(rows, findsNWidgets(7));
      expect(find.byKey(const ValueKey('pending-numbers')), findsOneWidget);

      // Satıra dokununca ilgili sayfa (koç kökünden).
      await t.ensureVisible(find.byKey(const ValueKey('pending-numbers')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('pending-numbers')));
      await t.pumpAndSettle();
      expect(_visited, ['/coach/roster']);
    });

    testWidgets('geniş ekranda özet ve filtre tek satırda, içerik ortada', (
      t,
    ) async {
      await _pump(
        t,
        _emptyCoach(
          summaries: const [
            StudentSummary(id: 's1', fullName: 'Ali', examCount: 0),
          ],
        ),
        size: const Size(3600, 2400),
      );
      final urgent = t.getRect(
        find.byKey(const ValueKey('pending-summary-urgent')),
      );
      final filter = t.getRect(
        find.byKey(const ValueKey('pending-filter-all')),
      );
      expect(filter.center.dy, closeTo(urgent.center.dy, urgent.height));
      final list = t.getRect(find.byKey(const ValueKey('pending-list')));
      expect(list.width, lessThanOrEqualTo(840));
      expect(list.center.dx, closeTo(1200 / 2, 1));
    });

    testWidgets('müdür (demo verisi): hatasız açılır, özet görünür', (t) async {
      await _pump(t, await buildDemoOverrides('admin'), base: '/admin');
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('pending-summary-all')), findsOneWidget);
    });
  });

  testWidgets('üst çubuk rozeti: iş sayısı, acil varsa risk renginde', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: _emptyCoach(
          deletions: {'d1': DateTime(2026, 11, 1)},
          summaries: const [
            StudentSummary(id: 's1', fullName: 'Ali', examCount: 0),
          ],
        ),
        child: MaterialApp(
          home: CockpitThemed(
            child: Scaffold(
              appBar: AppBar(
                actions: const [PendingWorkButton(basePath: '/coach')],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final badge = t.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(find.text('2'), findsOneWidget);
    final ctx = t.element(find.byType(Badge));
    expect(badge.backgroundColor, ctx.cockpit.risk);
  });
}
