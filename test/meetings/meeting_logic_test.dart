import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/features/meetings/data/meeting_repository.dart';
import 'package:mentoria/features/notifications/data/notification_repository.dart';

MeetingSchedule _weekly({DateTime? until, bool weekly = true}) =>
    MeetingSchedule(
      id: 's1',
      coachId: 'c',
      studentId: 'st',
      // 20 Ekim 2026 salı
      firstDate: DateTime(2026, 10, 20),
      hour: 11,
      minute: 0,
      repeatWeekly: weekly,
      untilDate: until,
    );

void main() {
  group('görüşme günleri', () {
    test('haftalık rutin ilk günden itibaren her hafta aynı gün', () {
      final s = _weekly();
      expect(s.occursOn(DateTime(2026, 10, 20)), isTrue);
      expect(s.occursOn(DateTime(2026, 10, 27, 15)), isTrue);
      expect(s.occursOn(DateTime(2026, 10, 21)), isFalse);
      expect(
        s.occursOn(DateTime(2026, 10, 13)),
        isFalse,
        reason: 'başlamadan önce',
      );
    });

    test('bitiş tarihinden sonra görüşme yok', () {
      final s = _weekly(until: DateTime(2026, 10, 27));
      expect(s.occursOn(DateTime(2026, 10, 27)), isTrue);
      expect(s.occursOn(DateTime(2026, 11, 3)), isFalse);
      expect(s.isActiveOn(DateTime(2026, 10, 28)), isFalse);
    });

    test('tek seferlik görüşme tekrarlanmaz', () {
      final s = _weekly(weekly: false);
      expect(s.occursOn(DateTime(2026, 10, 20)), isTrue);
      expect(s.occursOn(DateTime(2026, 10, 27)), isFalse);
    });

    test('aralıktaki günler', () {
      final s = _weekly();
      expect(s.daysBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 5)), [
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 27),
        DateTime(2026, 11, 3),
      ]);
    });
  });

  group('sıradaki görüşme', () {
    final s = _weekly();
    test('saati geçmediyse bugün', () {
      expect(
        s.nextAfter(DateTime(2026, 10, 20, 10)),
        DateTime(2026, 10, 20, 11),
      );
    });
    test('saati geçtiyse gelecek hafta', () {
      expect(
        s.nextAfter(DateTime(2026, 10, 20, 12)),
        DateTime(2026, 10, 27, 11),
      );
    });
    test('rutin başlamadıysa ilk görüşme', () {
      expect(s.nextAfter(DateTime(2026, 10, 1)), DateTime(2026, 10, 20, 11));
    });
    test('geçmiş tek seferlik görüşmenin sıradakisi yok', () {
      expect(_weekly(weekly: false).nextAfter(DateTime(2026, 10, 21)), isNull);
    });
    test('biten rutinin sıradakisi yok', () {
      expect(
        _weekly(
          until: DateTime(2026, 10, 27),
        ).nextAfter(DateTime(2026, 10, 28)),
        isNull,
      );
    });
  });

  test('hafta pazartesi başlar', () {
    expect(weekStartOf(DateTime(2026, 10, 18, 22)), DateTime(2026, 10, 12));
    expect(weekStartOf(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
    expect(weekStartOf(DateTime(2026, 10, 14)), DateTime(2026, 10, 12));
  });

  test('haftanın görüşmeleri saat sırasıyla ve durumlarıyla', () {
    final a = _weekly();
    final b = MeetingSchedule(
      id: 's2',
      coachId: 'c',
      studentId: 'st2',
      firstDate: DateTime(2026, 10, 19),
      hour: 9,
      minute: 30,
    );
    final list = expandMeetings(
      [a, b],
      {('s1', DateTime(2026, 10, 20)): MeetingStatus.held},
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 25),
    );
    expect(list.map((m) => m.schedule.id), ['s2', 's1']);
    expect(list.last.status, MeetingStatus.held);
    expect(list.first.status, isNull);
    expect(list.last.start, DateTime(2026, 10, 20, 11));
  });

  test('hatırlatma bildirimi metni: yarın, saat ve koç', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final n = AppNotification(
      id: 'n',
      kind: NotificationKind.meeting,
      createdAt: DateTime.now(),
      data: {
        'coach': 'Ayşe Koç',
        'at': DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          11,
        ).toUtc().toIso8601String(),
      },
    );
    expect(n.title, 'Görüşme hatırlatması');
    expect(n.body, 'Yarın 11:00 · Ayşe Koç ile görüşmen var');
    expect(n.route, '/student');
    expect(NotificationKind.tryDb('meeting'), NotificationKind.meeting);
  });
}
