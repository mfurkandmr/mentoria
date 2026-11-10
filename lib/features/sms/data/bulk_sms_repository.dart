import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';

/// Toplu SMS'in kime gideceği.
enum SmsAudience {
  all('all'),
  classes('classes'),
  students('students');

  const SmsAudience(this.db);

  final String db;

  static SmsAudience fromDb(String? v) =>
      values.firstWhere((a) => a.db == v, orElse: () => SmsAudience.all);
}

/// Önizleme / gönderim sonucu.
class SmsReach {
  const SmsReach({
    required this.students,
    required this.recipients,
    required this.noPhone,
  });

  factory SmsReach.fromJson(Map<String, dynamic> j) => SmsReach(
    students: j['students'] as int? ?? 0,
    recipients: j['recipients'] as int? ?? 0,
    noPhone: j['no_phone'] as int? ?? 0,
  );

  final int students;

  /// Farklı veli numarası (kardeşler bir kez).
  final int recipients;

  /// Velisinin telefonu olmayan öğrenci.
  final int noPhone;
}

class SmsBroadcast {
  const SmsBroadcast({
    required this.id,
    required this.body,
    required this.audience,
    required this.recipients,
    required this.createdAt,
    this.sender,
    this.queued = 0,
    this.sent = 0,
    this.failed = 0,
  });

  factory SmsBroadcast.fromJson(Map<String, dynamic> j) => SmsBroadcast(
    id: j['id'] as String,
    body: j['body'] as String,
    audience: SmsAudience.fromDb(j['audience'] as String?),
    recipients: j['recipients'] as int? ?? 0,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    sender: j['sender'] as String?,
    queued: j['queued'] as int? ?? 0,
    sent: j['sent'] as int? ?? 0,
    failed: j['failed'] as int? ?? 0,
  );

  final String id;
  final String body;
  final SmsAudience audience;
  final int recipients;
  final DateTime createdAt;
  final String? sender;
  final int queued;
  final int sent;
  final int failed;
}

/// Metnin yaklaşık SMS sayısı (Türkçe karakterli tek SMS 155, Türkçe dışı
/// özel karakter ya da emoji varsa 67 karakter).
int smsSegments(String text) {
  if (text.isEmpty) return 0;
  final unicode = RegExp(
    r"[^A-Za-z0-9 \n\r.,;:!?'\x22()\-+*/=%&@#$_<>çÇğĞıİöÖşŞüÜâÂîÎûÛ€£]",
  ).hasMatch(text);
  final per = unicode ? 67 : 155;
  return (text.length + per - 1) ~/ per;
}

abstract interface class BulkSmsRepository {
  /// [dryRun]: yalnızca kaç numaraya gideceğini sayar.
  Future<SmsReach> send({
    required String body,
    required SmsAudience audience,
    List<String> classroomIds = const [],
    List<String> studentIds = const [],
    bool dryRun = false,
  });

  Future<List<SmsBroadcast>> history();

  /// Kurum sınavı yayınlanınca (ve yeni optik gelince) sonuç velilere SMS
  /// ile gitsin mi (varsayılan açık; yalnızca müdür).
  Future<bool> examResultSmsEnabled();

  Future<void> setExamResultSms(bool enabled);
}

class SupabaseBulkSmsRepository implements BulkSmsRepository {
  SupabaseBulkSmsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SmsReach> send({
    required String body,
    required SmsAudience audience,
    List<String> classroomIds = const [],
    List<String> studentIds = const [],
    bool dryRun = false,
  }) async => SmsReach.fromJson(
    Map<String, dynamic>.from(
      await _client.rpc(
            'send_bulk_sms',
            params: {
              'p_body': body,
              'p_audience': audience.db,
              'p_classrooms': classroomIds,
              'p_students': studentIds,
              'p_dry_run': dryRun,
            },
          )
          as Map,
    ),
  );

  @override
  Future<List<SmsBroadcast>> history() async => [
    for (final r in await _client.rpc('my_sms_broadcasts') as List)
      SmsBroadcast.fromJson(Map<String, dynamic>.from(r as Map)),
  ];

  @override
  Future<bool> examResultSmsEnabled() async =>
      await _client.rpc<bool>('exam_result_sms_enabled');

  @override
  Future<void> setExamResultSms(bool enabled) =>
      _client.rpc<void>('set_exam_result_sms', params: {'p_enabled': enabled});
}

final bulkSmsRepositoryProvider = Provider<BulkSmsRepository>(
  (ref) => SupabaseBulkSmsRepository(sessionClient(ref)),
);

final examResultSmsProvider = FutureProvider<bool>(
  (ref) => ref.watch(bulkSmsRepositoryProvider).examResultSmsEnabled(),
);

final smsHistoryProvider = FutureProvider<List<SmsBroadcast>>(
  (ref) => ref.watch(bulkSmsRepositoryProvider).history(),
);
