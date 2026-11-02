import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Otomatik konu reçetesi: son 3 denemenin eksik konularından haftalık ödev
/// taslağı (sunucuda `topic_prescription`). Taslak yazılmaz; öğretmen
/// maddeleri seçip soru sayısını değiştirir ve mevcut ödev akışıyla
/// (`sendAssignment`) gönderir. Son 14 günde ödevi verilmiş konu gelmez.
class PrescriptionItem {
  const PrescriptionItem({
    required this.subjectCode,
    required this.topicId,
    required this.topicName,
    required this.wrong,
    required this.examCount,
    required this.suggested,
    this.outcomes = const [],
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> j) => PrescriptionItem(
    subjectCode: j['subject_code'] as String,
    topicId: j['topic_id'] as int,
    topicName: j['topic_name'] as String,
    wrong: j['wrong'] as int,
    examCount: j['exam_count'] as int,
    outcomes: [for (final o in (j['outcomes'] as List? ?? const [])) '$o'],
    suggested: j['suggested'] as int,
  );

  final String subjectCode;
  final int topicId;
  final String topicName;

  /// Son denemelerde bu konudaki toplam yanlış (optikte boş da sayılır).
  final int wrong;

  /// Kaç denemede yanlış yapıldı.
  final int examCount;

  /// Optikten okunan denemelerde yanlış yapılan kazanımlar (en çok 2).
  final List<String> outcomes;

  /// Önerilen soru sayısı: 1 yanlış → 15, 2-3 → 25, 4+ → 40.
  final int suggested;
}

abstract interface class PrescriptionRepository {
  Future<List<PrescriptionItem>> fetch(String studentId);
}

class SupabasePrescriptionRepository implements PrescriptionRepository {
  SupabasePrescriptionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PrescriptionItem>> fetch(String studentId) async {
    final rows =
        await _client.rpc(
              'topic_prescription',
              params: {'p_student': studentId},
            )
            as List;
    return [
      for (final r in rows)
        PrescriptionItem.fromJson(Map<String, dynamic>.from(r)),
    ];
  }
}

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>(
  (ref) => SupabasePrescriptionRepository(ref.watch(supabaseClientProvider)),
);

final prescriptionProvider =
    FutureProvider.family<List<PrescriptionItem>, String>(
      (ref, studentId) =>
          ref.watch(prescriptionRepositoryProvider).fetch(studentId),
    );
