// Görüşmeye (ödevlendirmeye) gelmeyen öğrenci (NOTLAR §93): koç "öğrenci
// gelmedi" işaretleyince veliye WhatsApp mesajı gider; koça sonucu söylenir.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mentoria/dev/demo_repositories.dart';
import 'package:mentoria/features/meetings/data/meeting_repository.dart';
import 'package:mentoria/features/meetings/presentation/meeting_widgets.dart';
import 'package:mentoria/features/tracking/data/tracking_models.dart';
import 'package:mentoria/shared/motion.dart';

void main() {
  setUpAll(() async {
    Motion.enabled = false;
    await initializeDateFormatting('tr_TR');
  });

  final yesterday = dateOnly(DateTime.now().subtract(const Duration(days: 1)));

  (InMemoryMeetingRepository, String) seeded() {
    final repo = InMemoryMeetingRepository(
      myId: 'coach',
      canView: (_) => true,
      names: const {'coach': 'Ayşe Koç', 's1': 'Elif Yılmaz'},
    );
    final id = repo.add(
      MeetingDraft(
        studentId: 's1',
        firstDate: yesterday,
        hour: 11,
        minute: 0,
        repeatWeekly: false,
      ),
      coachId: 'coach',
    );
    return (repo, id);
  }

  test('gelmedi: veliye bir kez mesaj; telefon yoksa no_phone', () async {
    final (repo, id) = seeded();
    expect(await repo.setStatus(id, yesterday, MeetingStatus.held), isNull);
    expect(
      await repo.setStatus(id, yesterday, MeetingStatus.missed),
      'notified',
    );
    expect(await repo.setStatus(id, yesterday, null), isNull);
    expect(await repo.setStatus(id, yesterday, MeetingStatus.missed), isNull);
    expect(repo.guardianNotified, hasLength(1));

    final (other, id2) = seeded();
    other.noGuardianPhone.add('s1');
    expect(
      await other.setStatus(id2, yesterday, MeetingStatus.missed),
      'no_phone',
    );
    expect(other.guardianNotified, isEmpty);
  });

  testWidgets('koç "öğrenci gelmedi" seçince sonucu görür', (t) async {
    final (repo, id) = seeded();
    final schedule = (await repo.fetchSchedules()).single;
    final meeting = Meeting(schedule: schedule, day: yesterday);
    await t.pumpWidget(
      ProviderScope(
        overrides: [meetingRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showMeetingStatusSheet(context, ref, meeting),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('aç'));
    await t.pumpAndSettle();
    expect(
      find.text("Veliye WhatsApp'tan bilgi mesajı gider."),
      findsOneWidget,
    );
    await t.tap(find.text('Öğrenci gelmedi'));
    await t.pumpAndSettle();
    expect(
      find.text("Veliye WhatsApp'tan bilgi mesajı gönderiliyor."),
      findsOneWidget,
    );
    expect(repo.guardianNotified, {(id, yesterday)});
  });
}
