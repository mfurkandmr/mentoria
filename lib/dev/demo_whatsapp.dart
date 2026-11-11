// Demo / test: kurum WhatsApp bağlantısı bellekte. Kurallar sunucudakiyle
// aynı (20261111130000_whatsapp).
import '../features/whatsapp/data/whatsapp_repository.dart';

class InMemoryWhatsAppRepository implements WhatsAppRepository {
  InMemoryWhatsAppRepository({this.isAdmin = true, bool connected = false})
    : _status = connected
          ? WhatsAppStatus(
              connected: true,
              displayPhone: '+90 212 555 00 00',
              phoneNumberId: '109876543210',
              wabaId: '201234567890',
              connectedAt: DateTime(2026, 11, 1),
              sent: 42,
              delivered: 40,
              read: 31,
              failed: 2,
            )
          : const WhatsAppStatus(connected: false, queued: 3);

  final bool isAdmin;
  WhatsAppStatus _status;
  String? _token;

  /// Testler için: kaydedilen anahtar.
  String? get token => _token;

  static final _digits = RegExp(r'^[0-9]{5,30}$');
  static final _tpl = RegExp(r'^[a-z0-9_]{1,100}$');

  @override
  Future<WhatsAppStatus> status() async {
    if (!isAdmin) throw StateError('NOT_ALLOWED');
    return _status;
  }

  @override
  Future<void> connect({
    required String phoneNumberId,
    required String wabaId,
    String? displayPhone,
    String? token,
    String? template,
  }) async {
    if (!isAdmin) throw StateError('NOT_ALLOWED');
    final t = token?.trim() ?? '';
    final tpl = (template?.trim().isEmpty ?? true)
        ? defaultWhatsAppTemplate
        : template!.trim();
    if (!_digits.hasMatch(phoneNumberId.trim()) ||
        !_digits.hasMatch(wabaId.trim())) {
      throw StateError('WA_BAD_ID');
    }
    if (!_tpl.hasMatch(tpl)) throw StateError('WA_BAD_TEMPLATE');
    if (t.isNotEmpty && (t.length < 20 || t.length > 1000)) {
      throw StateError('WA_BAD_TOKEN');
    }
    if (t.isEmpty && !_status.connected) {
      throw StateError('WA_TOKEN_REQUIRED');
    }
    if (t.isNotEmpty) _token = t;
    final phone = displayPhone?.trim() ?? '';
    _status = WhatsAppStatus(
      connected: true,
      displayPhone: phone.isEmpty ? null : phone,
      phoneNumberId: phoneNumberId.trim(),
      wabaId: wabaId.trim(),
      templateName: tpl,
      connectedAt: t.isEmpty ? _status.connectedAt : DateTime.now(),
      // Bağlanınca sıradakiler gönderilir.
      sent: _status.sent + _status.queued,
      delivered: _status.delivered,
      read: _status.read,
      failed: _status.failed,
    );
  }

  @override
  Future<void> disconnect() async {
    if (!isAdmin) throw StateError('NOT_ALLOWED');
    _token = null;
    _status = WhatsAppStatus(
      connected: false,
      sent: _status.sent,
      delivered: _status.delivered,
      read: _status.read,
      failed: _status.failed,
    );
  }
}
