import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Günün Sorusu: oturumdaki öğrencinin bugünkü sorusu, cevabı ve doğru
/// serisi. Soruyu sunucu seçer (`daily_question_id`); günlük çalışma hakkını
/// harcamaz.
class DailyQuestionState {
  const DailyQuestionState({
    required this.questionId,
    required this.answered,
    required this.streak,
    this.correct,
  });

  factory DailyQuestionState.fromJson(Map<String, dynamic> j) =>
      DailyQuestionState(
        questionId: j['question_id'] as String,
        answered: j['answered'] as bool? ?? false,
        correct: j['correct'] as bool?,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
      );

  final String questionId;
  final bool answered;
  final bool? correct;

  /// Art arda doğru cevaplanan gün sayısı.
  final int streak;

  String get subject => questionId.split('-').first;
}

abstract interface class DailyQuestionRepository {
  /// Öğrenci değilse null.
  Future<DailyQuestionState?> fetchToday();
  Future<void> answer(
    String studentId, {
    required String questionId,
    required bool correct,
  });
}

class SupabaseDailyQuestionRepository implements DailyQuestionRepository {
  SupabaseDailyQuestionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DailyQuestionState?> fetchToday() async {
    final r = await _client.rpc('my_daily_question');
    return r == null
        ? null
        : DailyQuestionState.fromJson((r as Map).cast<String, dynamic>());
  }

  @override
  Future<void> answer(
    String studentId, {
    required String questionId,
    required bool correct,
  }) => _client.from('daily_answers').insert({
    'student_id': studentId,
    'question_id': questionId,
    'correct': correct,
  });
}

final dailyQuestionRepositoryProvider = Provider<DailyQuestionRepository>(
  (ref) => SupabaseDailyQuestionRepository(ref.watch(supabaseClientProvider)),
);

final dailyQuestionProvider = FutureProvider<DailyQuestionState?>(
  (ref) => ref.watch(dailyQuestionRepositoryProvider).fetchToday(),
);
