// Müdür: kurumun WhatsApp Business numarasını bağlar (NOTLAR §88). Bilgiler
// Meta Business panelinden (WhatsApp → API Setup) kopyalanır; erişim anahtarı
// kaydedildikten sonra bir daha gösterilmez.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/haptics.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../admin/presentation/cockpit/cockpit_theme.dart';
import '../data/whatsapp_repository.dart';

final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

class WhatsAppConnectScreen extends ConsumerStatefulWidget {
  const WhatsAppConnectScreen({super.key});

  @override
  ConsumerState<WhatsAppConnectScreen> createState() =>
      _WhatsAppConnectScreenState();
}

class _WhatsAppConnectScreenState extends ConsumerState<WhatsAppConnectScreen> {
  final _phoneId = TextEditingController();
  final _wabaId = TextEditingController();
  final _display = TextEditingController();
  final _token = TextEditingController();
  final _template = TextEditingController();
  bool _filled = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_phoneId, _wabaId, _display, _token, _template]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(WhatsAppStatus s) {
    if (_filled) return;
    _filled = true;
    _phoneId.text = s.phoneNumberId ?? '';
    _wabaId.text = s.wabaId ?? '';
    _display.text = s.displayPhone ?? '';
    _template.text = s.templateName;
  }

  Future<void> _save(bool connected) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(whatsAppRepositoryProvider)
          .connect(
            phoneNumberId: _phoneId.text,
            wabaId: _wabaId.text,
            displayPhone: _display.text,
            token: _token.text,
            template: _template.text,
          );
      _token.clear();
      ref.invalidate(whatsAppStatusProvider);
      if (!mounted) return;
      AppHaptics.confirm();
      showMessage(
        context,
        connected ? tr('Bağlantı güncellendi') : tr('WhatsApp bağlandı'),
      );
    } catch (e) {
      if (mounted) showMessage(context, whatsAppErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final ok = await confirm(
      context,
      title: tr('WhatsApp bağlantısı kaldırılsın mı?'),
      message: tr(
        'Erişim anahtarı silinir. Velilere giden mesajlar yeniden bağlanana kadar sırada bekler.',
      ),
      action: tr('Kaldır'),
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(whatsAppRepositoryProvider).disconnect();
      _filled = false;
      ref.invalidate(whatsAppStatusProvider);
      if (mounted) showMessage(context, tr('Bağlantı kaldırıldı'));
    } catch (e) {
      if (mounted) showMessage(context, whatsAppErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(whatsAppStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('WhatsApp bağlantısı'))),
      body: AsyncView(
        value: status,
        onRetry: () => ref.invalidate(whatsAppStatusProvider),
        builder: (s) {
          _fill(s);
          return _body(context, s);
        },
      ),
    );
  }

  Widget _body(BuildContext context, WhatsAppStatus s) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        WhatsAppStatusCard(status: s, showAction: false),
        const SizedBox(height: 8),
        Text(
          tr(
            'Velilere giden bütün mesajlar (yoklama, taksit hatırlatma, toplu mesaj, deneme sonucu) kurumun WhatsApp Business numarasından gider. Veli cevap yazarsa cevap kurumun WhatsApp Business uygulamasına düşer.',
          ),
          style: text.bodyMedium,
        ),
        const SizedBox(height: 16),
        CockpitHeading(tr('Numara bilgileri')),
        Text(
          tr(
            'Meta Business panelinde WhatsApp → API Setup sayfasından kopyala. Erişim anahtarı için kalıcı bir "System User" anahtarı kullan.',
          ),
          style: text.bodySmall,
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('wa-phone-id'),
          controller: _phoneId,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: tr('Telefon numarası kimliği'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('wa-waba-id'),
          controller: _wabaId,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: tr('WhatsApp Business hesap kimliği'),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('wa-display'),
          controller: _display,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: tr('Numara (görünen)'),
            hintText: '+90 212 555 00 00',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('wa-token'),
          controller: _token,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: tr('Erişim anahtarı'),
            helperText: s.connected
                ? tr('Kayıtlı. Değiştirmek istemiyorsan boş bırak.')
                : null,
          ),
        ),
        const SizedBox(height: 16),
        CockpitHeading(tr('Mesaj şablonu')),
        Text(
          tr(
            'WhatsApp, velinin son 24 saatte yazmadığı mesajlar için Meta onaylı şablon ister. Aşağıdaki metni Meta panelinde "Utility" kategorisinde, Türkçe olarak bu adla bir kez onaylat.',
          ),
          style: text.bodySmall,
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('wa-template'),
          controller: _template,
          autocorrect: false,
          decoration: InputDecoration(labelText: tr('Şablon adı')),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    whatsAppTemplateText,
                    style: text.bodyMedium,
                  ),
                ),
                IconButton(
                  tooltip: tr('Kopyala'),
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: whatsAppTemplateText),
                    );
                    if (context.mounted) {
                      showMessage(context, tr('Şablon metni kopyalandı'));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('wa-save'),
          style: _inline,
          onPressed: _busy ? null : () => _save(s.connected),
          child: Text(s.connected ? tr('Güncelle') : tr('Bağla')),
        ),
        if (s.connected) ...[
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('wa-disconnect'),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            onPressed: _busy ? null : _disconnect,
            child: Text(tr('Bağlantıyı kaldır')),
          ),
        ],
      ],
    );
  }
}

/// Bağlantı durumu kartı: toplu mesaj ekranının başında ve bağlantı
/// ekranında. Bağlı değilse mesajların sırada beklediğini söyler.
class WhatsAppStatusCard extends StatelessWidget {
  const WhatsAppStatusCard({
    required this.status,
    this.showAction = true,
    super.key,
  });

  final WhatsAppStatus status;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final cs = Theme.of(context).colorScheme;
    final date = s.connectedAt == null
        ? ''
        : DateFormat('d MMMM y', 'tr_TR').format(s.connectedAt!);
    final subtitle = s.connected
        ? [
            if (date.isNotEmpty) tr('{d} tarihinde bağlandı', {'d': date}),
            tr('Son 30 gün: {s} gönderildi · {r} okundu · {f} gitmedi', {
              's': s.sent,
              'r': s.read,
              'f': s.failed,
            }),
            if (s.queued > 0) tr('{n} mesaj sırada', {'n': s.queued}),
          ].join('\n')
        : s.queued > 0
        ? tr('{n} mesaj sırada bekliyor; WhatsApp bağlanınca gider.', {
            'n': s.queued,
          })
        : tr('Velilere mesaj gitmesi için kurumun numarasını bağla.');
    return Card(
      key: const ValueKey('wa-status'),
      color: s.connected ? null : cs.errorContainer,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          s.connected ? Icons.check_circle_rounded : Icons.link_off_rounded,
          color: s.connected ? cs.primary : cs.onErrorContainer,
        ),
        title: Text(
          s.connected
              ? tr('WhatsApp bağlı · {p}', {
                  'p': s.displayPhone ?? s.phoneNumberId ?? '',
                })
              : tr('WhatsApp bağlı değil'),
        ),
        subtitle: Text(subtitle),
        isThreeLine: s.connected,
        trailing: showAction
            ? TextButton(
                key: const ValueKey('wa-open'),
                onPressed: () => context.push('/admin/whatsapp'),
                child: Text(s.connected ? tr('Ayarlar') : tr('Bağla')),
              )
            : null,
      ),
    );
  }
}
