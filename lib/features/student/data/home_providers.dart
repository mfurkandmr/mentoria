import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assignments/data/assignment_repository.dart';
import '../../exams/data/exam_repository.dart';
import '../../garden/data/garden.dart';
import '../../garden/presentation/garden_screen.dart';
import '../../mistakes/data/mistake_repository.dart';
import '../../tracking/data/tracking_repository.dart';

/// Öğrenci ana sayfası açılınca bir kez (yenilemede yeniden) okunur: ana
/// sayfanın verisini tek istekte çekmeye başlar (bkz. HomeSeed). Cihazdaki
/// paketle çizilen ekran, taze paket gelince buradan yenilenir. Demoda
/// (bellek içi repository) bir şey yapmaz.
final studentHomePrimeProvider = Provider.family<void, String>((
  ref,
  studentId,
) {
  final repo = ref.watch(trackingRepositoryProvider);
  if (repo is! SupabaseTrackingRepository) return;
  repo.primeHome(
    studentId,
    onFresh: () {
      ref.invalidate(questionLogsProvider(studentId));
      ref.invalidate(studySessionsProvider(studentId));
      ref.invalidate(goalsProvider(studentId));
      ref.invalidate(topicProgressProvider(studentId));
      ref.invalidate(examsForStudentProvider(studentId));
      ref.invalidate(assignmentsProvider(studentId));
      ref.invalidate(shortcutCountsProvider(studentId));
    },
  );
});

/// Ana sayfa kısayollarındaki sayılar.
class ShortcutCounts {
  const ShortcutCounts({
    required this.flowers,
    required this.mistakesDue,
    required this.mistakesTotal,
  });

  factory ShortcutCounts.fromJson(Map<String, dynamic> j) => ShortcutCounts(
    flowers: j['flowers'] as int? ?? 0,
    mistakesDue: j['mistakes_due'] as int? ?? 0,
    mistakesTotal: j['mistakes_total'] as int? ?? 0,
  );

  /// Odak Bahçesi'ndeki solmamış çiçekler.
  final int flowers;

  /// Hata Defteri'nde bugün tekrarı gelen sorular.
  final int mistakesDue;
  final int mistakesTotal;
}

/// Kısayol sayıları. Sunucuda yalnızca sayılar hesaplanır (öğrencinin tüm
/// oturumları ve hata kartları indirilmez). Pomodoro bitince ya da hata
/// defteri değişince bu da yenilenmeli. Demoda bellek içi listelerden sayılır.
final shortcutCountsProvider = FutureProvider.family<ShortcutCounts, String>((
  ref,
  studentId,
) async {
  final repo = ref.watch(trackingRepositoryProvider);
  if (repo is SupabaseTrackingRepository) {
    return ShortcutCounts.fromJson(await repo.fetchShortcutCounts(studentId));
  }
  final sessions = await ref.watch(allSessionsProvider(studentId).future);
  final cards = await ref.watch(mistakeCardsProvider(studentId).future);
  final now = DateTime.now();
  return ShortcutCounts(
    flowers: sessions
        .where((s) => FlowerSize.of(s) != FlowerSize.wilted)
        .length,
    mistakesDue: cards.where((c) => c.isDue(now)).length,
    mistakesTotal: cards.length,
  );
});
