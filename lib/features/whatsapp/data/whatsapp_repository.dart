// Kurumun WhatsApp Business bağlantısı (NOTLAR §88). Velilere giden bütün
// mesajlar (yoklama, taksit, toplu mesaj, deneme sonucu) kurumun numarasından
// Meta Cloud API ile gider; erişim anahtarı sunucuda kalır, uygulamaya dönmez.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../auth/data/auth_repository.dart';

/// Bağlantı durumu ve son 30 günün mesaj sayıları (yalnızca müdür).
class WhatsAppStatus {
  const WhatsAppStatus({
    required this.connected,
    this.displayPhone,
    this.phoneNumberId,
    this.wabaId,
    this.templateName = defaultWhatsAppTemplate,
    this.connectedAt,
    this.queued = 0,
    this.sent = 0,
    this.delivered = 0,
    this.read = 0,
    this.failed = 0,
  });

  factory WhatsAppStatus.fromJson(Map<String, dynamic> j) => WhatsAppStatus(
    connected: j['connected'] as bool? ?? false,
    displayPhone: j['display_phone'] as String?,
    phoneNumberId: j['phone_number_id'] as String?,
    wabaId: j['waba_id'] as String?,
    templateName: j['template_name'] as String? ?? defaultWhatsAppTemplate,
    connectedAt: j['connected_at'] == null
        ? null
        : DateTime.parse(j['connected_at'] as String).toLocal(),
    queued: j['queued'] as int? ?? 0,
    sent: j['sent'] as int? ?? 0,
    delivered: j['delivered'] as int? ?? 0,
    read: j['read'] as int? ?? 0,
    failed: j['failed'] as int? ?? 0,
  );

  final bool connected;
  final String? displayPhone;
  final String? phoneNumberId;
  final String? wabaId;
  final String templateName;
  final DateTime? connectedAt;

  /// Sırada (WhatsApp bağlı değilse burada bekler).
  final int queued;
  final int sent;
  final int delivered;
  final int read;
  final int failed;
}

/// Genel bilgilendirme şablonunun Meta'daki adı.
const defaultWhatsAppTemplate = 'kurum_bilgilendirme';

/// Meta'ya onaylatılacak genel şablon metni ({{1}} mesaj, {{2}} kurum).
const whatsAppTemplateText =
    'Kurumunuzdan bilgilendirme:\n\n{{1}}\n\nBu mesaj {{2}} tarafından '
    'gönderilmiştir.';

abstract interface class WhatsAppRepository {
  Future<WhatsAppStatus> status();

  /// [token] boşsa kayıtlı anahtar korunur (ilk bağlantıda zorunlu).
  Future<void> connect({
    required String phoneNumberId,
    required String wabaId,
    String? displayPhone,
    String? token,
    String? template,
  });

  Future<void> disconnect();
}

class SupabaseWhatsAppRepository implements WhatsAppRepository {
  SupabaseWhatsAppRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WhatsAppStatus> status() async {
    final rows = await _client.rpc('org_whatsapp_status') as List;
    return rows.isEmpty
        ? const WhatsAppStatus(connected: false)
        : WhatsAppStatus.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  @override
  Future<void> connect({
    required String phoneNumberId,
    required String wabaId,
    String? displayPhone,
    String? token,
    String? template,
  }) => _client.rpc<void>(
    'set_org_whatsapp',
    params: {
      'p_phone_number_id': phoneNumberId.trim(),
      'p_waba_id': wabaId.trim(),
      'p_display_phone': displayPhone?.trim(),
      'p_token': token?.trim(),
      'p_template': template?.trim(),
    },
  );

  @override
  Future<void> disconnect() => _client.rpc<void>('disconnect_org_whatsapp');
}

/// Sunucu hata kodlarını müdürün anlayacağı metne çevirir.
String whatsAppErrorMessage(Object e) {
  final s = '$e';
  if (s.contains('WA_TOKEN_REQUIRED')) {
    return tr('İlk bağlantıda erişim anahtarı gerekli.');
  }
  if (s.contains('WA_BAD_TOKEN')) return tr('Erişim anahtarı geçersiz.');
  if (s.contains('WA_BAD_ID')) {
    return tr('Numara kimliği ve hesap kimliği yalnızca rakamdan oluşur.');
  }
  if (s.contains('WA_BAD_TEMPLATE')) {
    return tr('Şablon adı küçük harf, rakam ve _ içerebilir.');
  }
  if (s.contains('NOT_ALLOWED')) return tr('Bu işlem için yetkin yok.');
  return tr('Kaydedilemedi. Tekrar dene.');
}

final whatsAppRepositoryProvider = Provider<WhatsAppRepository>(
  (ref) => SupabaseWhatsAppRepository(sessionClient(ref)),
);

final whatsAppStatusProvider = FutureProvider<WhatsAppStatus>(
  (ref) => ref.watch(whatsAppRepositoryProvider).status(),
);
