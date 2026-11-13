// Veliye WhatsApp (NOTLAR §89): ödev PDF'i ve koçun mesajı kurumun
// numarasından gider. PDF uygulamada üretilir, 'homework' kovasına
// '<kurum>/<ödev>.pdf' olarak yüklenir; mesajı sunucu sıraya alır.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';

/// Ödevin veliye gidişi.
enum HomeworkDelivery {
  /// Sıraya alındı (WhatsApp bağlıysa hemen gider).
  queued,

  /// Bu ödev daha önce gönderilmiş.
  already,

  /// Öğrencinin veli telefonu kayıtlı değil.
  noPhone;

  static HomeworkDelivery fromDb(String? v) => switch (v) {
    'already' => already,
    'no_phone' => noPhone,
    _ => queued,
  };
}

enum GuardianMessageKind {
  homework,
  coach,
  other;

  static GuardianMessageKind fromDb(String? v) => switch (v) {
    'homework' => homework,
    'coach' => coach,
    _ => other,
  };
}

/// Velinin WhatsApp'ına giden bir mesaj ve durumu.
class GuardianMessage {
  const GuardianMessage({
    required this.id,
    required this.kind,
    required this.body,
    required this.status,
    required this.createdAt,
    this.sender,
    this.deliveredAt,
    this.readAt,
    this.error,
  });

  factory GuardianMessage.fromJson(Map<String, dynamic> j) {
    DateTime? at(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String).toLocal();
    return GuardianMessage(
      id: j['id'] as String,
      kind: GuardianMessageKind.fromDb(j['kind'] as String?),
      body: j['body'] as String? ?? '',
      status: j['status'] as String? ?? 'queued',
      createdAt: at('created_at')!,
      sender: j['sender'] as String?,
      deliveredAt: at('delivered_at'),
      readAt: at('read_at'),
      error: j['error'] as String?,
    );
  }

  final String id;
  final GuardianMessageKind kind;
  final String body;

  /// 'queued' | 'sending' | 'sent' | 'failed'.
  final String status;
  final DateTime createdAt;
  final String? sender;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? error;

  String get statusLabel => switch (status) {
    'failed' => tr('Gitmedi'),
    'sent' when readAt != null => tr('Okundu'),
    'sent' when deliveredAt != null => tr('Teslim edildi'),
    'sent' => tr('Gönderildi'),
    _ => tr('Sırada'),
  };
}

abstract interface class GuardianMessagingRepository {
  /// PDF'i yükler ve veliye gönderilmek üzere sıraya alır. [buildPdf]
  /// yalnızca gerçekten gönderilecekse çağrılır.
  Future<HomeworkDelivery> sendHomeworkPdf({
    required String assignmentId,
    required String studentId,
    required Future<Uint8List> Function() buildPdf,
  });

  Future<void> sendMessage({required String studentId, required String body});

  Future<List<GuardianMessage>> history(String studentId);
}

class SupabaseGuardianMessagingRepository
    implements GuardianMessagingRepository {
  SupabaseGuardianMessagingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<HomeworkDelivery> sendHomeworkPdf({
    required String assignmentId,
    required String studentId,
    required Future<Uint8List> Function() buildPdf,
  }) async {
    Future<String> queue() => _client.rpc<String>(
      'queue_homework_whatsapp',
      params: {'p_assignment': assignmentId},
    );
    // Önce sıraya almayı dene: telefon yoksa ya da zaten gittiyse PDF
    // hiç yüklenmez (depoda sahipsiz dosya kalmasın).
    try {
      return HomeworkDelivery.fromDb(await queue());
    } catch (e) {
      if (!'$e'.contains('HW_NO_PDF')) rethrow;
    }
    // Yol sunucudakiyle aynı: '<kurum>/<ödev>.pdf'.
    final me = await _client
        .from('profiles')
        .select('org_id')
        .eq('id', _client.auth.currentUser!.id)
        .single();
    await _client.storage
        .from('homework')
        .uploadBinary(
          '${me['org_id']}/$assignmentId.pdf',
          await buildPdf(),
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );
    return HomeworkDelivery.fromDb(await queue());
  }

  @override
  Future<void> sendMessage({required String studentId, required String body}) =>
      _client.rpc<void>(
        'send_guardian_message',
        params: {'p_student': studentId, 'p_body': body.trim()},
      );

  @override
  Future<List<GuardianMessage>> history(String studentId) async => [
    for (final r
        in await _client.rpc(
              'guardian_messages',
              params: {'p_student': studentId},
            )
            as List)
      GuardianMessage.fromJson(Map<String, dynamic>.from(r as Map)),
  ];
}

String guardianMessageError(Object e) {
  final s = '$e';
  if (s.contains('NO_PHONE')) {
    return tr('Öğrencinin veli telefonu kayıtlı değil.');
  }
  if (s.contains('GUARDIAN_MSG_LIMIT')) {
    return tr('Bu veliye 24 saatte en çok 5 mesaj gönderilebilir.');
  }
  if (s.contains('BAD_BODY')) return tr('Mesaj 1-900 karakter olmalı.');
  if (s.contains('NOT_ALLOWED')) return tr('Bu işlem için yetkin yok.');
  return tr('Gönderilemedi. Tekrar dene.');
}

final guardianMessagingRepositoryProvider =
    Provider<GuardianMessagingRepository>(
      (ref) => SupabaseGuardianMessagingRepository(sessionClient(ref)),
    );

final guardianMessagesProvider =
    FutureProvider.family<List<GuardianMessage>, String>(
      (ref, studentId) =>
          ref.watch(guardianMessagingRepositoryProvider).history(studentId),
    );
