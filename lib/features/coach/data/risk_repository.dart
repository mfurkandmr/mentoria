import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/format.dart';
import '../../auth/data/auth_repository.dart';

/// Risk erken uyarısı: son 7 günün devamı, net düşüşü ve ödev tamamlama
/// tek skorda (0-100, yüksek = riskli). Sunucuda `my_risk_list`; her
/// pazartesi koça "bu öğrencilerle konuş" bildirimi de aynı skordan gelir.
///
/// Skor: çalışmadığı her gün 5 + kaçırılan görüşme 7,5 (en çok 2) + son
/// 30 gündeki denemede bir öncekine göre her net düşüş 3 (en çok 10 net) +
/// bu haftanın ödevinde yapılmayan oran × 20. Listeye 30 ve üstü girer.
class RiskEntry {
  const RiskEntry({
    required this.studentId,
    required this.name,
    required this.score,
    required this.days,
    required this.meetingsMissed,
    required this.netDrop,
    required this.homeworkTotal,
    required this.homeworkDone,
    this.examType,
  });

  factory RiskEntry.fromJson(Map<String, dynamic> j) => RiskEntry(
    studentId: j['student_id'] as String,
    name: j['full_name'] as String? ?? '',
    score: j['score'] as int? ?? 0,
    days: j['days'] as int? ?? 0,
    meetingsMissed: j['meetings_missed'] as int? ?? 0,
    netDrop: (j['net_drop'] as num?)?.toDouble() ?? 0,
    examType: j['exam_type'] as String?,
    homeworkTotal: j['homework_total'] as int? ?? 0,
    homeworkDone: j['homework_done'] as int? ?? 0,
  );

  final String studentId;
  final String name;
  final int score;

  /// Son 7 günün kaçında çalıştı.
  final int days;
  final int meetingsMissed;

  /// Son denemede bir öncekine göre net kaybı (düşüş yoksa 0).
  final double netDrop;
  final String? examType;
  final int homeworkTotal;
  final int homeworkDone;

  /// Skoru yükselten nedenler, kısa: "4 gün çalışmadı · 8 net düştü".
  List<String> get reasons => [
    if (days < 7) tr('{n} gün çalışmadı', {'n': 7 - days}),
    if (meetingsMissed > 0) tr('{n} görüşme kaçırdı', {'n': meetingsMissed}),
    if (netDrop > 0)
      tr('{type} {n} net düştü', {
        'type': examType ?? '',
        'n': formatNet(netDrop),
      }),
    if (homeworkTotal > 0 && homeworkDone < homeworkTotal)
      tr('ödev %{p}', {'p': (homeworkDone * 100 / homeworkTotal).round()}),
  ];
}

abstract interface class RiskRepository {
  /// En riskli [limit] öğrenci (koç: kendi öğrencileri, müdür: kurum).
  Future<List<RiskEntry>> fetch({int limit = 7});
}

class SupabaseRiskRepository implements RiskRepository {
  SupabaseRiskRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RiskEntry>> fetch({int limit = 7}) async {
    final rows =
        await _client.rpc('my_risk_list', params: {'p_limit': limit}) as List;
    return [
      for (final r in rows) RiskEntry.fromJson(Map<String, dynamic>.from(r)),
    ];
  }
}

final riskRepositoryProvider = Provider<RiskRepository>(
  (ref) => SupabaseRiskRepository(ref.watch(supabaseClientProvider)),
);

final riskListProvider = FutureProvider<List<RiskEntry>>(
  (ref) => ref.watch(riskRepositoryProvider).fetch(),
);
