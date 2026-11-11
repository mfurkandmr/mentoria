// Demo / test: veliye WhatsApp (ödev PDF'i, koç mesajı) bellekte. Kurallar
// sunucudakiyle aynı (20261111140000_homework_whatsapp).
import 'dart:typed_data';

import '../features/whatsapp/data/guardian_messaging_repository.dart';

class InMemoryGuardianMessagingRepository
    implements GuardianMessagingRepository {
  InMemoryGuardianMessagingRepository({
    this.phoneOf = const {},
    this.senderName = 'Ayşe Koç',
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Öğrenci → veli telefonu (yoksa mesaj gitmez).
  final Map<String, String?> phoneOf;
  final String senderName;
  final DateTime Function() _now;

  /// Yüklenen PDF'ler: yol → bayt.
  final uploads = <String, Uint8List>{};
  final _byStudent = <String, List<GuardianMessage>>{};
  var _seq = 0;

  @override
  Future<HomeworkDelivery> sendHomeworkPdf({
    required String assignmentId,
    required String studentId,
    required Future<Uint8List> Function() buildPdf,
  }) async {
    final student = studentId;
    final path = 'demo-org/$assignmentId.pdf';
    if (uploads.containsKey(path)) return HomeworkDelivery.already;
    if (phoneOf[student] == null) return HomeworkDelivery.noPhone;
    uploads[path] = await buildPdf();
    _add(student, GuardianMessageKind.homework, tr: 'Ödev gönderildi');
    return HomeworkDelivery.queued;
  }

  @override
  Future<void> sendMessage({
    required String studentId,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty || text.length > 900) throw StateError('BAD_BODY');
    final since = _now().subtract(const Duration(hours: 24));
    final recent = (_byStudent[studentId] ?? const <GuardianMessage>[])
        .where(
          (m) =>
              m.kind == GuardianMessageKind.coach && m.createdAt.isAfter(since),
        )
        .length;
    if (recent >= 5) throw StateError('GUARDIAN_MSG_LIMIT');
    if (phoneOf[studentId] == null) throw StateError('NO_PHONE');
    _add(studentId, GuardianMessageKind.coach, tr: text);
  }

  void _add(String student, GuardianMessageKind kind, {required String tr}) {
    (_byStudent[student] ??= []).insert(
      0,
      GuardianMessage(
        id: 'gm${_seq++}',
        kind: kind,
        body: tr,
        status: 'queued',
        createdAt: _now(),
        sender: senderName,
      ),
    );
  }

  /// Demo verisi: önceden gitmiş, okunmuş bir koç mesajı.
  void seedRead(String student, String body) {
    (_byStudent[student] ??= []).add(
      GuardianMessage(
        id: 'gm${_seq++}',
        kind: GuardianMessageKind.coach,
        body: body,
        status: 'sent',
        createdAt: _now().subtract(const Duration(days: 2)),
        sender: senderName,
        deliveredAt: _now().subtract(const Duration(days: 2)),
        readAt: _now().subtract(const Duration(days: 2)),
      ),
    );
  }

  @override
  Future<List<GuardianMessage>> history(String studentId) async => [
    ...?_byStudent[studentId],
  ];
}
