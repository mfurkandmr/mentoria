import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/coaching/data/coaching_repository.dart';
import 'package:mentoria/features/tracking/data/tracking_repository.dart';
import 'package:mentoria/features/auth/data/auth_repository.dart';
import 'package:mentoria/features/auth/data/profile.dart';
import 'package:mentoria/features/coach/data/coach_repository.dart';
import 'package:mentoria/features/coach/presentation/coach_home_screen.dart';
import 'package:mentoria/features/coach/presentation/student_detail_screen.dart';
import 'package:mentoria/features/exams/data/exam_repository.dart';
import 'package:mentoria/features/exams/presentation/add_exam_screen.dart';
import 'package:mentoria/features/exams/presentation/exams_screen.dart';

const _coach = Profile(id: 'c1', fullName: 'Test Koç', role: UserRole.coach);
const _student = Profile(
  id: 'demo-student',
  fullName: 'Elif Yılmaz',
  role: UserRole.student,
);

Widget _app({
  required GoRouter router,
  required Profile profile,
  required InMemoryExamRepository exams,
  Map<String, (String, String?)>? students,
}) {
  return ProviderScope(
    overrides: [
      currentProfileProvider.overrideWith((ref) async => profile),
      examRepositoryProvider.overrideWithValue(exams),
      coachRepositoryProvider.overrideWithValue(
        InMemoryCoachRepository(exams, students ?? demoStudents()),
      ),
      trackingRepositoryProvider.overrideWithValue(
        InMemoryTrackingRepository(topics: demoTopics()),
      ),
      coachingRepositoryProvider.overrideWithValue(
        InMemoryCoachingRepository(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

/// Koç paneli rotaları (gerçek uygulamadaki /coach ağacının aynısı).
GoRouter _coachRouter([String initial = '/coach']) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/coach',
      builder: (_, _) => const CoachHomeScreen(),
      routes: [
        GoRoute(
          path: 'students/:id',
          builder: (_, s) =>
              StudentDetailScreen(studentId: s.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'exams/new',
              builder: (_, s) => AddExamScreen(
                studentId: s.pathParameters['id']!,
                initialType: ExamType.values.firstWhere(
                  (t) => t.db == s.uri.queryParameters['type'],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

Finder _cell(String code, int column) => find
    .descendant(
      of: find.byKey(ValueKey('subject-$code')),
      matching: find.byType(TextField),
    )
    .at(column);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });

  testWidgets('koç öğrenciye deneme girer, listede görünür', (tester) async {
    _phone(tester);
    final exams = InMemoryExamRepository();
    await tester.pumpWidget(
      _app(
        router: _coachRouter('/coach/students/s1'),
        profile: _coach,
        exams: exams,
        students: {'s1': ('Ali Veli', '7')},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Okul no: 7'), findsOneWidget);
    await tester.tap(find.text('Denemeler'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz TYT denemesi yok'), findsOneWidget);
    await tester.tap(find.text('TYT denemesi gir'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Deneme adı'),
      'Türkiye Geneli 1',
    );
    await tester.enterText(_cell('TYT_TUR', 0), '30');
    await tester.enterText(_cell('TYT_TUR', 1), '8');
    await tester.enterText(_cell('TYT_MAT', 0), '20');
    await tester.enterText(_cell('TYT_MAT', 1), '4');
    await tester.pump();
    // 30 - 8/4 = 28, 20 - 4/4 = 19 → 47
    expect(find.text('47'), findsOneWidget);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final saved = await exams.fetchExams(studentId: 's1');
    expect(saved, hasLength(1));
    expect(saved.single.results.map((r) => r.code), ['TYT_TUR', 'TYT_MAT']);
    // Boş girilmediği için kalan sorular boş sayılır: 40 - 30 - 8
    expect(saved.single.results.first.blank, 2);
    expect(find.text('Türkiye Geneli 1'), findsOneWidget);
    expect(find.text('47 net'), findsOneWidget);
  });

  testWidgets('soru sayısını aşan ders kaydedilmez', (tester) async {
    _phone(tester);
    final exams = InMemoryExamRepository();
    await tester.pumpWidget(
      _app(
        router: _coachRouter('/coach/students/s1/exams/new?type=TYT'),
        profile: _coach,
        exams: exams,
        students: {'s1': ('Ali Veli', null)},
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Deneme adı'), 'X');
    await tester.enterText(_cell('TYT_TAR', 0), '5');
    await tester.enterText(_cell('TYT_TAR', 1), '2');
    await tester.pump();
    expect(find.text('5 soruyu geçti'), findsOneWidget);

    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(await exams.fetchExams(studentId: 's1'), isEmpty);
  });

  testWidgets('öğrenci denemelerini salt okunur görür', (tester) async {
    _phone(tester);
    final router = GoRouter(
      initialLocation: '/student/exams',
      routes: [
        GoRoute(path: '/student/exams', builder: (_, _) => const ExamsScreen()),
      ],
    );
    await tester.pumpWidget(
      _app(
        router: router,
        profile: _student,
        exams: InMemoryExamRepository.demo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Son net'), findsOneWidget);
    expect(find.text('Toplam net gelişimi'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Ders bazlı gelişim'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Ders bazlı gelişim'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.textContaining('denemesi gir'), findsNothing);

    // Detayda silme yok
    await tester.dragUntilVisible(
      find.text('Türkiye Geneli TYT 8'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.text('Türkiye Geneli TYT 8'));
    await tester.pumpAndSettle();
    expect(find.text('Toplam net'), findsOneWidget);
    expect(find.text('Denemeyi sil'), findsNothing);

    // AYT sekmesi
    Navigator.of(tester.element(find.text('Toplam net'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('AYT'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('AYT Sayısal Deneme 4'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('AYT Sayısal Deneme 4'), findsOneWidget);
  });

  testWidgets('deneme analizi: ders ders eğilim, ısı haritası, pencere', (
    tester,
  ) async {
    _phone(tester);
    final router = GoRouter(
      initialLocation: '/student/exams',
      routes: [
        GoRoute(path: '/student/exams', builder: (_, _) => const ExamsScreen()),
      ],
    );
    await tester.pumpWidget(
      _app(
        router: router,
        profile: _student,
        exams: InMemoryExamRepository.demo(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analiz'));
    await tester.pumpAndSettle();
    expect(find.text('Toplam net eğilimi'), findsOneWidget);
    expect(find.text('net / deneme'), findsOneWidget);
    expect(find.text('En hızlı yükselen'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Isı haritası'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.dragUntilVisible(
      find.text('Ders ders gelişim'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.dragUntilVisible(
      find.textContaining('ustalık').last,
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.textContaining('Eğilim:'), findsWidgets);

    // Pencere: tüm denemeler
    await tester.dragUntilVisible(
      find.text('Tümü'),
      find.byType(ListView).first,
      const Offset(0, 300),
    );
    await tester.tap(find.text('Tümü'));
    await tester.pumpAndSettle();
    expect(find.text('Toplam net eğilimi'), findsOneWidget);

    // Listeye geri dön
    await tester.tap(find.text('Sonuçlar'));
    await tester.pumpAndSettle();
    expect(find.text('Son net'), findsOneWidget);
  });

  testWidgets('koç listesi, eksik numara uyarısı ve numara girme', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        router: _coachRouter(),
        profile: _coach,
        exams: InMemoryExamRepository.demo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 öğrencin var'), findsOneWidget);
    expect(
      find.textContaining('1 öğrencinin okul numarası eksik'),
      findsOneWidget,
    );
    expect(find.text('No: 1042'), findsOneWidget);
    expect(find.text('Henüz deneme yok'), findsOneWidget); // Zeynep

    // Kartlar gökyüzü başlığı ve özetlerin altında: önce kaydır.
    await tester.scrollUntilVisible(
      find.text('Can Kaya'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Can Kaya'));
    await tester.pumpAndSettle();
    expect(find.text('Okul numarası girilmemiş'), findsOneWidget);

    // Başka öğrencinin numarası reddedilir
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1042');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bu numara kurumda başka bir öğrenciye ait.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).last, '2001');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Okul no: 2001'), findsOneWidget);
  });

  testWidgets('koç davet kodu oluşturur', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        router: _coachRouter(),
        profile: _coach,
        exams: InMemoryExamRepository.demo(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Öğrenci davet et').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 kişi'));
    await tester.tap(find.text('Kod oluştur'));
    await tester.pumpAndSettle();

    expect(find.text('DEMO1000'), findsWidgets);
    expect(find.text('5 öğrenci kullanabilir'), findsOneWidget);
  });
}
