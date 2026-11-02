import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';

/// Rehberlik görüşme kaydı: öğretmen 2 dakikada not bırakır, öğrencinin
/// görüşme geçmişi zaman çizelgesi olarak durur. Kayıt kuruma aittir:
/// öğrencinin şimdiki koçu ve kurum müdürü görür, koç değişince yeni koç tüm
/// geçmişi görür. Öğrenci ve veli görmez. Değiştirilemez; yazan 24 saat
/// içinde, müdür her zaman silebilir.
enum GuidanceKind {
  inPerson('in_person'),
  phone('phone'),
  online('online'),
  parent('parent');

  const GuidanceKind(this.db);
  final String db;

  static GuidanceKind fromDb(String v) =>
      values.firstWhere((k) => k.db == v, orElse: () => inPerson);

  String get label => switch (this) {
    inPerson => tr('Yüz yüze'),
    phone => tr('Telefon'),
    online => tr('Online'),
    parent => tr('Veli görüşmesi'),
  };
}

/// Sabit konu etiketleri (sağlık gibi özel nitelikli veri için etiket yok).
enum GuidanceTopic {
  academic('academic'),
  motivation('motivation'),
  goals('goals'),
  university('university'),
  examAnxiety('exam_anxiety'),
  time('time'),
  family('family'),
  other('other');

  const GuidanceTopic(this.db);
  final String db;

  static GuidanceTopic? fromDb(String v) =>
      values.where((t) => t.db == v).firstOrNull;

  String get label => switch (this) {
    academic => tr('Ders başarısı'),
    motivation => tr('Motivasyon'),
    goals => tr('Hedef'),
    university => tr('Tercih / bölüm'),
    examAnxiety => tr('Sınav kaygısı'),
    time => tr('Zaman yönetimi'),
    family => tr('Aile'),
    other => tr('Diğer'),
  };
}

class GuidanceLog {
  const GuidanceLog({
    required this.id,
    required this.studentId,
    required this.authorName,
    required this.metOn,
    required this.kind,
    required this.topics,
    required this.note,
    required this.createdAt,
    this.authorId,
    this.nextStep,
    this.followUpOn,
  });

  factory GuidanceLog.fromJson(Map<String, dynamic> j) => GuidanceLog(
    id: j['id'] as String,
    studentId: j['student_id'] as String,
    authorId: j['author_id'] as String?,
    authorName: j['author_name'] as String? ?? '',
    metOn: DateTime.parse(j['met_on'] as String),
    kind: GuidanceKind.fromDb(j['kind'] as String),
    topics: [
      for (final t in (j['topics'] as List? ?? const []))
        ?GuidanceTopic.fromDb('$t'),
    ],
    note: j['note'] as String,
    nextStep: j['next_step'] as String?,
    followUpOn: j['follow_up_on'] == null
        ? null
        : DateTime.parse(j['follow_up_on'] as String),
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
  );

  final String id;
  final String studentId;

  /// Yazan kişi; hesabı silindiyse null (adı [authorName]'de kalır).
  final String? authorId;
  final String authorName;
  final DateTime metOn;
  final GuidanceKind kind;
  final List<GuidanceTopic> topics;
  final String note;
  final String? nextStep;
  final DateTime? followUpOn;
  final DateTime createdAt;

  /// Yazan kişi 24 saat içinde silebilir (sunucu da aynı kuralı uygular).
  bool deletableBy(String userId, {required bool isAdmin, DateTime? now}) =>
      isAdmin ||
      (authorId == userId &&
          (now ?? DateTime.now()).difference(createdAt) <
              const Duration(hours: 24));
}

class GuidanceDraft {
  const GuidanceDraft({
    required this.metOn,
    required this.kind,
    required this.topics,
    required this.note,
    this.nextStep,
    this.followUpOn,
  });

  final DateTime metOn;
  final GuidanceKind kind;
  final List<GuidanceTopic> topics;
  final String note;
  final String? nextStep;
  final DateTime? followUpOn;
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

abstract interface class GuidanceRepository {
  /// Öğrencinin tüm görüşme kayıtları, en yeni önce.
  Future<List<GuidanceLog>> fetch(String studentId);
  Future<void> add(String studentId, GuidanceDraft draft);
  Future<void> delete(String id);
}

class SupabaseGuidanceRepository implements GuidanceRepository {
  SupabaseGuidanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GuidanceLog>> fetch(String studentId) async {
    final rows = await _client
        .from('guidance_logs')
        .select(
          'id, student_id, author_id, author_name, met_on, kind, topics, note, next_step, follow_up_on, created_at',
        )
        .eq('student_id', studentId)
        .order('met_on', ascending: false)
        .order('created_at', ascending: false);
    return [for (final r in rows) GuidanceLog.fromJson(r)];
  }

  @override
  Future<void> add(String studentId, GuidanceDraft d) =>
      _client.from('guidance_logs').insert({
        'student_id': studentId,
        'met_on': _ymd(d.metOn),
        'kind': d.kind.db,
        'topics': [for (final t in d.topics) t.db],
        'note': d.note,
        'next_step': d.nextStep,
        'follow_up_on': d.followUpOn == null ? null : _ymd(d.followUpOn!),
        // Sunucu kendi yazar; NOT NULL için yer tutucu.
        'author_name': '',
      });

  @override
  Future<void> delete(String id) =>
      _client.from('guidance_logs').delete().eq('id', id);
}

final guidanceRepositoryProvider = Provider<GuidanceRepository>(
  (ref) => SupabaseGuidanceRepository(ref.watch(supabaseClientProvider)),
);

final guidanceLogsProvider = FutureProvider.family<List<GuidanceLog>, String>(
  (ref, studentId) => ref.watch(guidanceRepositoryProvider).fetch(studentId),
);
