import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Velinin "bu hafta nasıldı?" sorusunun tek kartlık cevabı: son 7 gün.
/// Sunucuda `weekly_summary`; pazar akşamı veli bildirimi de aynı veriyi
/// taşır. Uygulamada sınıf yoklaması olmadığı için "devamsızlık" çalışmadığı
/// gün ve kaçırılan koç görüşmesidir.
class WeeklySummary {
  const WeeklySummary({
    required this.days,
    required this.questions,
    required this.minutes,
    required this.meetingsHeld,
    required this.meetingsMissed,
    required this.homeworkTotal,
    required this.homeworkDone,
    this.examType,
    this.examName,
    this.lastNet,
    this.prevNet,
  });

  factory WeeklySummary.fromJson(Map<String, dynamic> j) {
    double? num_(Object? v) => v == null ? null : (v as num).toDouble();
    return WeeklySummary(
      days: j['days'] as int? ?? 0,
      questions: j['questions'] as int? ?? 0,
      minutes: j['minutes'] as int? ?? 0,
      meetingsHeld: j['meetings_held'] as int? ?? 0,
      meetingsMissed: j['meetings_missed'] as int? ?? 0,
      homeworkTotal: j['homework_total'] as int? ?? 0,
      homeworkDone: j['homework_done'] as int? ?? 0,
      examType: j['exam_type'] as String?,
      examName: j['exam_name'] as String?,
      lastNet: num_(j['last_net']),
      prevNet: num_(j['prev_net']),
    );
  }

  /// Son 7 günün kaçında çalıştı (soru ya da odak oturumu).
  final int days;
  final int questions;
  final int minutes;
  final int meetingsHeld;
  final int meetingsMissed;

  /// Bu hafta teslim günü olan ödev maddeleri.
  final int homeworkTotal;
  final int homeworkDone;

  /// Son denemenin türü (TYT / AYT / YDT); hiç deneme yoksa null.
  final String? examType;
  final String? examName;
  final double? lastNet;

  /// Aynı türdeki bir önceki deneme.
  final double? prevNet;

  int get daysOff => 7 - days;

  double? get netChange =>
      lastNet == null || prevNet == null ? null : lastNet! - prevNet!;

  /// Ödev yüzdesi; bu hafta ödev yoksa null.
  int? get homeworkPercent =>
      homeworkTotal == 0 ? null : (homeworkDone * 100 / homeworkTotal).round();
}

abstract interface class WeeklySummaryRepository {
  Future<WeeklySummary> fetch(String studentId);
}

class SupabaseWeeklySummaryRepository implements WeeklySummaryRepository {
  SupabaseWeeklySummaryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WeeklySummary> fetch(String studentId) async {
    final r = await _client.rpc(
      'weekly_summary',
      params: {'p_student': studentId},
    );
    return WeeklySummary.fromJson(Map<String, dynamic>.from(r as Map));
  }
}

final weeklySummaryRepositoryProvider = Provider<WeeklySummaryRepository>(
  (ref) => SupabaseWeeklySummaryRepository(ref.watch(supabaseClientProvider)),
);

final weeklySummaryProvider = FutureProvider.family<WeeklySummary, String>(
  (ref, studentId) =>
      ref.watch(weeklySummaryRepositoryProvider).fetch(studentId),
);
