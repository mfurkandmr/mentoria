import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/account/presentation/profile_screen.dart';
import 'package:mentoria/features/admin/presentation/admin_home_screen.dart';
import 'package:mentoria/features/coach/presentation/manager_widgets.dart';
import 'package:mentoria/features/assignments/presentation/assign_homework_screen.dart';
import 'package:mentoria/features/assignments/presentation/student_homework_screen.dart';
import 'package:mentoria/features/notifications/presentation/notification_widgets.dart';
import 'package:mentoria/features/coach/presentation/student_detail_screen.dart';
import 'package:mentoria/features/import/presentation/import_screen.dart';
import 'package:mentoria/features/parent/presentation/parent_child_screen.dart';
import 'package:mentoria/features/parent/presentation/parent_home_screen.dart';
import 'package:mentoria/features/student/presentation/student_home_screen.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';
import 'package:mentoria/features/tracking/presentation/questions_view.dart';
import 'package:mentoria/features/tracking/presentation/study_view.dart';
import 'package:mentoria/features/tracking/presentation/topics_view.dart';

Future<Widget> _app(String role, Widget screen) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      // Ekranların push ettiği rotalar için boş hedefler.
      GoRoute(path: '/:a', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/:a/:b/:c', builder: (_, _) => const Scaffold()),
    ],
  );
  return ProviderScope(
    overrides: await buildDemoOverrides(role),
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ),
  );
}

/// Kaydırılabilir sekme çubuğunda sekmeyi görünür yapıp açar.
Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

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

  group('yardımcılar', () {
    test('dakika biçimi', () {
      expect(formatMinutes(40), '40 dk');
      expect(formatMinutes(60), '1 sa');
      expect(formatMinutes(135), '2 sa 15 dk');
    });

    test('çalışma serisi', () {
      final today = DateTime(2026, 10, 15);
      final days = [
        today,
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 2)),
        today.subtract(const Duration(days: 4)),
      ];
      expect(studyStreak(days, today), 3);
      // Bugün çalışılmadıysa dünden geriye sayılır.
      expect(studyStreak(days.skip(1), today), 2);
      expect(studyStreak([], today), 0);
    });
  });

  testWidgets('öğrenci soru ekler', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('student', const QuestionsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Ders dağılımı'), findsOneWidget);

    await tester.tap(find.text('Soru ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Doğru'), '20');
    await tester.enterText(find.widgetWithText(TextField, 'Yanlış'), '5');
    await tester.pump();
    await tester.tap(find.text('25 soruyu kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('25 soru kaydedildi 🐝'), findsOneWidget);
  });

  testWidgets('öğrenci konu durumunu değiştirir', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('student', const TopicsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();
    // Demo verisinde "Yazım Kuralları" (5. konu) başlanmadı durumunda.
    await tester.tap(find.text('Yazım Kuralları'));
    await tester.pumpAndSettle();
    final before = find.text('Bitti').evaluate().length;
    await tester.tap(find.text('Bitti').last);
    await tester.pumpAndSettle();
    expect(find.text('Bitti').evaluate().length, greaterThan(before - 1));
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Yazım Kuralları'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('Bitti'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('öğrenci ana sayfası: görev işaretleme', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('student', const StudentHomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Elif!'), findsOneWidget);

    final task = find.text('Paragraf: 3 gün boyunca günde 40 soru');
    await tester.scrollUntilVisible(
      task,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final box = find.descendant(
      of: find.ancestor(of: task, matching: find.byType(ListTile)),
      matching: find.byType(Checkbox),
    );
    expect(tester.widget<Checkbox>(box).value, isFalse);
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(box).value, isTrue);
  });

  testWidgets('öğrenci veli davet kodu oluşturur', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('student', const ProfileScreen()));
    await tester.pumpAndSettle();
    final button = find.text('Veli davet kodu oluştur');
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('VELI1000'), findsOneWidget);
  });

  testWidgets('koç görev verir ve not yazar', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      await _app('coach', const StudentDetailScreen(studentId: 'demo-can')),
    );
    await tester.pumpAndSettle();

    await _openTab(tester, 'Görevler');
    expect(find.textContaining('Henüz görev vermedin'), findsOneWidget);
    await tester.tap(find.text('Görev ver'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Görev'),
      'Problemler 50 soru',
    );
    await tester.tap(find.text('Görevi ver'));
    await tester.pumpAndSettle();
    expect(find.text('Problemler 50 soru'), findsOneWidget);

    await _openTab(tester, 'Notlar');
    await tester.enterText(
      find.byType(TextField).last,
      'Harika gidiyorsun Can!',
    );
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pumpAndSettle();
    expect(find.text('Harika gidiyorsun Can!'), findsOneWidget);
  });

  testWidgets('kurum müdürü: özet, koç değiştirme, davet', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('admin', const AdminHomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Bal Akademi'), findsOneWidget);
    expect(find.text('Öğrenci kredisi: 120'), findsOneWidget);

    // Öğrenciler → Zeynep'in koçunu değiştir
    await tester.tap(find.text('Öğrenciler').last);
    await tester.pumpAndSettle();
    final zeynep = find.ancestor(
      of: find.text('Zeynep Arslan'),
      matching: find.byType(StudentCard),
    );
    expect(
      find.descendant(
        of: zeynep,
        matching: find.textContaining('Koç: Burak Yıldız'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: zeynep,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Koçunu değiştir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayşe Koç').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: zeynep,
        matching: find.textContaining('Koç: Ayşe Koç'),
      ),
      findsOneWidget,
    );

    // Davetler → koç daveti
    await tester.tap(find.text('Koçlar').last);
    await tester.pumpAndSettle();
    expect(find.text('Burak Yıldız'), findsOneWidget);
    await tester.tap(find.text('Koç davet et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kod oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('KOC1000'), findsOneWidget);
  });

  testWidgets('veli çocuğunun panelini salt okunur görür', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('parent', const ParentHomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Elif Yılmaz bu hafta'), findsOneWidget);
    // Koç paneliyle aynı dil: renkli özet kutuları ve hızlı geçişler.
    expect(find.byType(GlowStat), findsNWidgets(5));
    expect(find.widgetWithText(QuickActionTile, 'Sorular'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Koçunun verdiği görevler'),
      find.byType(CustomScrollView).first,
      const Offset(0, -300),
    );
    expect(find.text('Koçunun verdiği görevler'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    // Ödev maddeleri görünür ama veli işaretleyemez.
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .where((c) => c.onChanged != null),
      isEmpty,
    );
  });

  testWidgets('veli ayrıntı ekranında sekmeleri salt okunur görür', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      await _app(
        'parent',
        const ParentChildScreen(childId: 'demo-student', initialTab: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Elif Yılmaz'), findsOneWidget);
    expect(find.text('Ders dağılımı'), findsOneWidget);
    expect(find.byType(GlowStat), findsWidgets);
    expect(find.byTooltip('Sil'), findsNothing);

    await _openTab(tester, 'Konular');
    expect(find.text('Dersler'), findsOneWidget);
    await _openTab(tester, 'Süre');
    expect(find.text('Oturumlar'), findsOneWidget);
    expect(find.byTooltip('Sil'), findsNothing);
  });

  testWidgets('koç Excel sonucunu yükler ve öğrencilere dağıtır', (
    tester,
  ) async {
    _phone(tester);
    final sheets = {
      'Sonuçlar': [
        [
          'Öğrenci No',
          'Ad Soyad',
          'Türkçe D',
          'Türkçe Y',
          'Matematik D',
          'Matematik Y',
        ],
        ['01042', 'Elif Yılmaz', '34', '4', '26', '5'],
        ['1077', 'Zeynep Arslan', '28', '6', '18', '8'],
        ['9999', 'Bilinmeyen Öğrenci', '20', '10', '10', '10'],
      ],
    };
    await tester.pumpWidget(
      await _app(
        'coach',
        ImportScreen(initialSheets: sheets, initialFileName: 'TG TYT 9.xlsx'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 ders otomatik bulundu'), findsOneWidget);
    expect(find.text('3 satır · 2 eşleşti · 1 eşleşmedi'), findsOneWidget);
    expect(find.textContaining('numara ile eşleşti'), findsNWidgets(2));

    await tester.tap(find.text('2 öğrenciye kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Yükleme tamamlandı'), findsOneWidget);
    expect(find.text('2 öğrenciye deneme eklendi.'), findsOneWidget);
  });

  testWidgets('koç öğrenciyi arar, sepete konu ekler ve ödev gönderir', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(await _app('coach', const AssignHomeworkScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Kime ödev vereceksin?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1042');
    await tester.pumpAndSettle();
    expect(find.text('Can Kaya'), findsNothing);
    await tester.tap(find.text('Elif Yılmaz'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AYT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parabol'));
    await tester.tap(find.text('Polinomlar'));
    await tester.pumpAndSettle();
    expect(find.text('2 madde · 40 soru'), findsOneWidget);

    // Aynı konuya tekrar dokunmak sepetten çıkarır.
    await tester.tap(find.text('Polinomlar'));
    await tester.pumpAndSettle();
    expect(find.text('1 madde · 20 soru'), findsOneWidget);

    await tester.tap(find.text('Sepeti gör'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Artır'));
    await tester.pumpAndSettle();
    expect(find.text('25 soru'), findsOneWidget);
    await tester.tap(find.text('Öğrenciye gönder'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ödev Elif Yılmaz adlı öğrenciye gönderildi 🐝'),
      findsOneWidget,
    );
    expect(find.text('Kime ödev vereceksin?'), findsOneWidget);
  });

  testWidgets('öğrenci ödevlerini görür ve maddeyi işaretler', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      await _app('student', const StudentHomeworkScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('AYT Matematik: Parabol haftası'), findsOneWidget);
    expect(find.text('Matematik · Parabol'), findsOneWidget);
    expect(find.text('1/3 tamam', findRichText: false), findsNothing);
    final box = find.descendant(
      of: find.widgetWithText(CheckboxListTile, 'Matematik · Parabol'),
      matching: find.byType(Checkbox),
    );
    expect(tester.widget<Checkbox>(box).value, isFalse);
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(box).value, isTrue);
    expect(find.textContaining('2/3 tamam'), findsOneWidget);
    expect(find.text('Tamamlananlar (1)'), findsOneWidget);
  });

  testWidgets('öğrenci bildirimleri görür', (tester) async {
    _phone(tester);
    await tester.pumpWidget(await _app('student', const NotificationsScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text('Yeni ödev: AYT Matematik: Parabol haftası'),
      findsOneWidget,
    );
    expect(
      find.text('Ayşe Koç sana 3 maddelik ödev gönderdi'),
      findsNWidgets(2),
    );
    expect(find.text('Deneme sonucun geldi'), findsOneWidget);
    expect(find.text('Koçundan yeni not'), findsOneWidget);
  });

  testWidgets('öğrenci hesabının silinmesini ister ve talebi geri alır', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(await _app('student', const ProfileScreen()));
    await tester.pumpAndSettle();
    final request = find.text('Hesabımın silinmesini iste');
    await tester.scrollUntilVisible(
      request,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(request);
    await tester.pumpAndSettle();
    // Öğrenci hesabını kendisi silemez; yalnızca talep eder.
    expect(find.text('Hesabımı sil'), findsNothing);

    await tester.tap(request);
    await tester.pumpAndSettle();
    expect(find.text('Hesabının silinmesini istiyor musun?'), findsOneWidget);
    await tester.tap(find.text('Talep gönder'));
    await tester.pumpAndSettle();
    expect(find.text('Talebin koçuna iletildi.'), findsOneWidget);
    expect(find.text('Hesap silme talebin iletildi'), findsOneWidget);
    expect(request, findsNothing);

    // Önceki bildirim çubuğu kapansın (çubuklar sırayla gösterilir).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(find.text('Hesap silme talebin geri alındı.'), findsOneWidget);
    expect(request, findsOneWidget);
  });

  testWidgets('hesap silme diyaloğu kapanırken denetleyici hatası yok', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(await _app('coach', const ProfileScreen()));
    await tester.pumpAndSettle();
    final delete = find.text('Hesabımı sil');
    await tester.scrollUntilVisible(
      delete,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();

    final confirmButton = find.widgetWithText(TextButton, 'Hesabımı sil');
    expect(tester.widget<TextButton>(confirmButton).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'SİL');
    await tester.pump();
    expect(tester.widget<TextButton>(confirmButton).onPressed, isNotNull);

    // Kapanış animasyonu boyunca kare kare çiz: serbest bırakılmış
    // denetleyici kullanılırsa burada hata yakalanır.
    await tester.tap(find.text('Vazgeç'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Hesabın silinsin mi?'), findsNothing);
  });

  testWidgets('koç bekleyen silme talebini görür ve silme akışını açar', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      await _app('coach', const StudentDetailScreen(studentId: 'demo-can')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hesap silme talebi'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Hesabı sil'));
    await tester.pumpAndSettle();
    expect(find.text('Öğrenci hesabı silinsin mi?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'SİL');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Kalıcı olarak sil'));
    await tester.pumpAndSettle();
    expect(find.text('Öğrenci hesabı silindi.'), findsOneWidget);
  });

  testWidgets('talep yoksa koç rozet görmez', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      await _app('coach', const StudentDetailScreen(studentId: 'demo-student')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hesap silme talebi'), findsNothing);
    expect(find.text('Hesabı sil'), findsNothing);
  });

  testWidgets('koç öğrencinin hesabını onayla siler', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      await _app('coach', const StudentDetailScreen(studentId: 'demo-can')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Diğer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Öğrenci hesabını sil'));
    await tester.pumpAndSettle();
    expect(find.text('Öğrenci hesabı silinsin mi?'), findsOneWidget);

    final button = find.widgetWithText(TextButton, 'Kalıcı olarak sil');
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'sil');
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Öğrenci hesabı silindi.'), findsOneWidget);
  });
}
