import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/yks_dates.dart';
import 'package:mentoria/features/student/data/daily_quotes.dart';
import 'package:mentoria/features/student/presentation/home_cards.dart';
import 'package:mentoria/features/student/presentation/home_sky.dart';

void main() {
  test('sıradaki YKS: hedef yıl geçmişse bir sonrakine geçer', () {
    final now = DateTime(2026, 10, 16);
    expect(nextYks(now: now)!.year, 2027);
    expect(nextYks(examYear: 2028, now: now)!.year, 2028);
    expect(nextYks(examYear: 2026, now: now)!.year, 2027);
    expect(nextYks(now: now)!.date.official, isFalse);
  });

  test('günün sözü her gün değişir, aynı gün aynı kalır', () {
    final a = quoteOfTheDay(DateTime(2026, 10, 16, 8));
    final b = quoteOfTheDay(DateTime(2026, 10, 16, 23));
    final c = quoteOfTheDay(DateTime(2026, 10, 17, 8));
    expect(identical(a, b), isTrue);
    expect(identical(a, c), isFalse);
  });

  test('en uzun seri hesaplanır', () {
    expect(bestStreak([]), 0);
    expect(
      bestStreak([
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 5),
        // Saat değişimi (DST) olan gün de ardışık sayılır.
        DateTime(2026, 10, 6),
      ]),
      3,
    );
  });

  test('günün saatine göre gökyüzü', () {
    expect(DayPhase.of(DateTime(2026, 1, 1, 7)), DayPhase.morning);
    expect(DayPhase.of(DateTime(2026, 1, 1, 13)), DayPhase.day);
    expect(DayPhase.of(DateTime(2026, 1, 1, 19)), DayPhase.evening);
    expect(DayPhase.of(DateTime(2026, 1, 1, 2)), DayPhase.night);
  });
}
