import '../../../core/i18n/i18n.dart';
import '../../student/presentation/home_cards.dart' show buildAchievements;
import '../data/avatar_models.dart';

/// Kilit koşulunun öğrenciye gösterilen metni. Koşulun kendisi sunucudaki
/// `avatar_items.unlock_rule` verisinden gelir; burada yalnızca okunur hale
/// getirilir (rozet adları uygulamadaki rozetlerden).
extension AvatarRuleText on AvatarRule {
  /// Öğrenciye gösterilecek koşul metni (kural verisinden üretilir).
  String describe() {
    switch (type) {
      case 'free':
        return tr('Herkese açık');
      case 'streak':
        return tr('{n} gün üst üste çalış', {'n': data['days'] ?? 1});
      case 'net':
        return tr('{exam} denemesinde {n} net yap', {
          'exam': data['exam_type'] ?? 'TYT',
          'n': data['value'] ?? 0,
        });
      case 'badge':
        final key = data['badge'] as String?;
        final badge = buildAchievements(
          totalQuestions: 0,
          bestStreak: 0,
          exams: 0,
          studyMinutes: 0,
          topicsDone: 0,
        ).where((a) => a.key == key).firstOrNull;
        return tr('"{badge}" rozetini aç', {
          'badge': badge?.title ?? key ?? '?',
        });
      case 'questions':
        return tr('Toplam {n} soru çöz', {'n': data['count'] ?? 1});
      case 'study_minutes':
        return tr('Toplam {n} saat odaklan', {
          'n': (((data['minutes'] as num?) ?? 60) / 60).round(),
        });
      case 'topics':
        return tr('{n} konuyu bitir', {'n': data['count'] ?? 1});
      case 'exams':
        return tr('{n} denemeye gir', {'n': data['count'] ?? 1});
      case 'duel_wins':
        return tr('{n} düello kazan', {'n': data['count'] ?? 1});
      default:
        return tr('Yakında');
    }
  }
}
