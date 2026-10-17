import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../auth/data/auth_repository.dart';

/// Bir öğrencinin son 5 denemesindeki değişim (ilk → son toplam net).
class ExamTrend {
  const ExamTrend({
    required this.studentId,
    required this.name,
    required this.examCount,
    required this.firstNet,
    required this.lastNet,
  });

  factory ExamTrend.fromJson(Map<String, dynamic> j) => ExamTrend(
    studentId: j['student_id'] as String,
    name: j['full_name'] as String,
    examCount: j['exam_count'] as int,
    firstNet: (j['first_net'] as num).toDouble(),
    lastNet: (j['last_net'] as num).toDouble(),
  );

  final String studentId;
  final String name;

  /// Hesaba katılan deneme sayısı (2-5).
  final int examCount;
  final double firstNet;
  final double lastNet;

  double get delta => lastNet - firstNet;
}

/// En çok yükselen ve en çok düşen [n] öğrenci.
({List<ExamTrend> rising, List<ExamTrend> falling}) topMovers(
  List<ExamTrend> all, {
  int n = 5,
}) {
  final rising = all.where((t) => t.delta > 0).toList()
    ..sort((a, b) => b.delta.compareTo(a.delta));
  final falling = all.where((t) => t.delta < 0).toList()
    ..sort((a, b) => a.delta.compareTo(b.delta));
  return (rising: rising.take(n).toList(), falling: falling.take(n).toList());
}

abstract interface class ExamTrendRepository {
  /// Yönetilen öğrencilerin (en az 2 denemesi olan) eğilimi.
  Future<List<ExamTrend>> fetch(ExamType type);
}

class SupabaseExamTrendRepository implements ExamTrendRepository {
  SupabaseExamTrendRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ExamTrend>> fetch(ExamType type) async {
    final rows =
        await _client.rpc('exam_trends', params: {'p_exam_type': type.label})
            as List;
    return [for (final r in rows) ExamTrend.fromJson(r)];
  }
}

final examTrendRepositoryProvider = Provider<ExamTrendRepository>(
  (ref) => SupabaseExamTrendRepository(ref.watch(supabaseClientProvider)),
);

final examTrendsProvider = FutureProvider.family<List<ExamTrend>, ExamType>(
  (ref, type) => ref.watch(examTrendRepositoryProvider).fetch(type),
);
