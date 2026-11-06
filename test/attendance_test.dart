import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_attendance.dart';
import 'package:mentoria/dev/demo_mode.dart';
import 'package:mentoria/features/attendance/data/attendance_repository.dart';
import 'package:mentoria/features/attendance/presentation/attendance_screen.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('depo', () {
    test('işaretler, kaldırır; tarih ve yetki denetlenir', () async {
      final repo = InMemoryAttendanceRepository(students: const {'a': 'Ali'});
      await repo.save(today, {'a': AttendanceStatus.late});
      expect((await repo.fetchDay(today)).single.status, AttendanceStatus.late);
      await repo.save(today, {'a': null});
      expect((await repo.fetchDay(today)).single.status, isNull);
      expect(
        () => repo.save(today.add(const Duration(days: 1)), {
          'a': AttendanceStatus.present,
        }),
        throwsStateError,
      );
      expect(
        () => repo.save(today, {'x': AttendanceStatus.present}),
        throwsStateError,
      );
    });

    test('SMS yalnızca gelmeyene, telefonu olana ve günde bir kez', () async {
      final repo = InMemoryAttendanceRepository(
        students: const {'a': 'Ali', 'b': 'Banu', 'c': 'Cem'},
        phones: const {'a': ('Ayşe', '+905321234567')},
      );
      await repo.save(today, {
        'a': AttendanceStatus.absent,
        'b': AttendanceStatus.absent,
        'c': AttendanceStatus.present,
      });
      var r = await repo.sendAbsenceSms(today, ['a', 'b', 'c']);
      expect((r.queued, r.noPhone, r.skipped), (1, 1, 1));
      r = await repo.sendAbsenceSms(today, ['a']);
      expect((r.queued, r.skipped), (0, 1));
      expect(repo.sentSms.single.$1, '+905321234567');
    });

    test('gün özeti', () {
      const c = AttendanceCounts([
        AttendanceRow(
          studentId: 'a',
          fullName: 'A',
          status: AttendanceStatus.present,
        ),
        AttendanceRow(
          studentId: 'b',
          fullName: 'B',
          status: AttendanceStatus.absent,
        ),
        AttendanceRow(studentId: 'c', fullName: 'C'),
      ]);
      expect(c.total, 3);
      expect(c.marked, 2);
      expect(c.count(AttendanceStatus.absent), 1);
    });
  });

  group('ekran', () {
    late InMemoryAttendanceRepository repo;

    Future<void> pump(WidgetTester t) async {
      t.view.physicalSize = const Size(1080, 4200);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      repo = InMemoryAttendanceRepository(
        students: const {
          's1': 'Elif Yılmaz',
          's2': 'Can Kaya',
          's3': 'Deniz Ak',
        },
        phones: const {'s1': ('Selin Yılmaz', '+905321234567')},
        fallbackPhones: const {'s3'},
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: await buildDemoOverrides(
            'coach',
            true,
            null,
            null,
            null,
            repo,
          ),
          child: const MaterialApp(
            locale: Locale('tr', 'TR'),
            supportedLocales: [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: AttendanceScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('yoklama kaydedilir, gelmeyenin velisine SMS sorulur', (
      t,
    ) async {
      await pump(t);
      expect(find.textContaining('Bugün ·'), findsOneWidget);
      expect(find.text('İşaretsiz 3'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('att-s1-absent')));
      await t.tap(find.byKey(const ValueKey('att-s2-absent')));
      await t.pumpAndSettle();
      await t.tap(find.text('İşaretsizlerin hepsi geldi'));
      await t.pumpAndSettle();
      expect(find.text('Yoklamayı kaydet (3)'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('attendance-save')));
      await t.pumpAndSettle();
      final day = await repo.fetchDay(today);
      expect(
        {for (final r in day) r.studentId: r.status},
        {
          's1': AttendanceStatus.absent,
          's2': AttendanceStatus.absent,
          's3': AttendanceStatus.present,
        },
      );

      expect(
        find.text('Gelmeyenlerin velisine SMS gönderilsin mi?'),
        findsOneWidget,
      );
      expect(find.text('Veli telefonu yok'), findsOneWidget);
      await t.tap(find.text('Gönder (1)'));
      await t.pumpAndSettle();
      expect(repo.sentSms.single.$1, '+905321234567');
      expect(find.text('1 veliye SMS sırasına alındı.'), findsOneWidget);
      expect(find.textContaining('Veliye SMS gönderildi'), findsOneWidget);
    });

    testWidgets('veli telefonu eklenince SMS gönderilebilir', (t) async {
      await pump(t);
      await t.tap(find.byKey(const ValueKey('att-s2-absent')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('attendance-save')));
      await t.pumpAndSettle();
      await t.tap(find.text('Gönderme'));
      await t.pumpAndSettle();
      expect(repo.sentSms, isEmpty);

      await t.tap(find.byTooltip('Veli telefonu ekle'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('guardian-phone')),
        '0533 765 43 21',
      );
      await t.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await t.pumpAndSettle();
      expect(
        (await repo.fetchDay(
          today,
        )).firstWhere((r) => r.studentId == 's2').guardianPhone,
        '+905337654321',
      );

      await t.tap(find.byTooltip('Gelmeyenlerin velisine SMS'));
      await t.pumpAndSettle();
      await t.tap(find.text('Gönder (1)'));
      await t.pumpAndSettle();
      expect(repo.sentSms.single.$1, '+905337654321');
    });

    testWidgets('kaydedilmemiş işaretle gün değişirken sorulur', (t) async {
      await pump(t);
      await t.tap(find.byKey(const ValueKey('att-s1-late')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Önceki gün'));
      await t.pumpAndSettle();
      expect(find.text('Kaydedilmemiş yoklama'), findsOneWidget);
      await t.tap(find.text('Sil'));
      await t.pumpAndSettle();
      expect(find.textContaining('Bugün ·'), findsNothing);
      expect(find.text('İşaretsiz 3'), findsOneWidget);
    });
  });
}
