import '../features/sms/data/bulk_sms_repository.dart';

/// Bellekte toplu SMS (demo ve testler). Sunucudaki gibi: aynı numara bir
/// kez, metnin başına kurum adı, 10 dakikada bir gönderim.
class InMemoryBulkSmsRepository implements BulkSmsRepository {
  InMemoryBulkSmsRepository({
    required this.phoneOf,
    required this.classOf,
    this.orgName = 'Demo Kurs',
  });

  /// Öğrenci → veli telefonu (yoksa null).
  final Map<String, String?> phoneOf;

  /// Öğrenci → sınıf kimliği (yoksa null).
  final String? Function(String studentId) classOf;
  final String orgName;

  final _history = <SmsBroadcast>[];

  /// Sıraya alınan SMS'ler (telefon, metin) — testler için.
  final outbox = <(String, String)>[];
  int _id = 0;

  /// Demo: daha önce gönderilmiş SMS'ler (en yeni önce).
  void seedHistory(List<SmsBroadcast> list) => _history.addAll(list);

  @override
  Future<SmsReach> send({
    required String body,
    required SmsAudience audience,
    List<String> classroomIds = const [],
    List<String> studentIds = const [],
    bool dryRun = false,
  }) async {
    final students = [
      for (final s in phoneOf.keys)
        if (switch (audience) {
          SmsAudience.all => true,
          SmsAudience.classes => classroomIds.contains(classOf(s)),
          SmsAudience.students => studentIds.contains(s),
        })
          s,
    ];
    final phones = {
      for (final s in students)
        if (phoneOf[s] != null) phoneOf[s]!,
    };
    final reach = SmsReach(
      students: students.length,
      recipients: phones.length,
      noPhone: students.where((s) => phoneOf[s] == null).length,
    );
    if (dryRun) return reach;
    final text = body.trim();
    if (text.isEmpty || text.length > 600) throw StateError('BAD_BODY');
    if (phones.isEmpty) throw StateError('NO_RECIPIENTS');
    if (_history.isNotEmpty &&
        DateTime.now().difference(_history.first.createdAt).inMinutes < 10) {
      throw StateError('SMS_TOO_SOON');
    }
    for (final p in phones) {
      outbox.add((p, '$orgName: $text'));
    }
    _history.insert(
      0,
      SmsBroadcast(
        id: 'b${_id++}',
        body: text,
        audience: audience,
        recipients: phones.length,
        createdAt: DateTime.now(),
        sender: 'Mehmet Demir',
        queued: phones.length,
      ),
    );
    return reach;
  }

  @override
  Future<List<SmsBroadcast>> history() async => [..._history];

  /// Deneme sonucu SMS'i açık mı (sunucuda organizations.exam_result_sms).
  bool examResultSms = true;

  @override
  Future<bool> examResultSmsEnabled() async => examResultSms;

  @override
  Future<void> setExamResultSms(bool enabled) async => examResultSms = enabled;
}
