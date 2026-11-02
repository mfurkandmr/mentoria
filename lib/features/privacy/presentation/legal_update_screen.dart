import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/data/auth_repository.dart';
import '../data/consent_repository.dart';
import 'legal_text_screen.dart';

/// Kullanım Koşulları / Aydınlatma Metni güncellendi ([legalVersion]) ya da
/// hiç onaylanmamış: panele girmeden önce yeniden onay istenir. Onay
/// `set_consent('privacy_notice')` ile yeni sürümle kaydedilir.
class LegalUpdatePrompt extends ConsumerStatefulWidget {
  const LegalUpdatePrompt({super.key});

  @override
  ConsumerState<LegalUpdatePrompt> createState() => _LegalUpdatePromptState();
}

class _LegalUpdatePromptState extends ConsumerState<LegalUpdatePrompt> {
  bool _accepted = false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(consentRepositoryProvider)
          .setConsent(ConsentKind.privacyNotice, granted: true);
      if (!mounted) return;
      ref.invalidate(myConsentStatusProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Kaydedilemedi. Tekrar dene.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Bizz(size: 100)),
            const SizedBox(height: 16),
            Text(
              tr('Metinlerimiz güncellendi'),
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'Devam etmeden önce Kullanım Koşulları\'nı ve Aydınlatma Metni\'ni okuyup onaylaman gerekiyor.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => openLegal(context, LegalDoc.terms),
                  child: Text(tr('Kullanım Koşulları\'nı oku')),
                ),
                TextButton(
                  onPressed: () => openLegal(context, LegalDoc.privacyNotice),
                  child: Text(tr('Aydınlatma Metni\'ni oku')),
                ),
              ],
            ),
            CheckboxListTile(
              value: _accepted,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _accepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(
                  'Kullanım Koşulları\'nı kabul ediyorum; Aydınlatma Metni\'ni okudum.',
                ),
                style: text.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _accepted && !_saving ? _save : null,
              child: Text(tr('Onayla ve devam et')),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final ok = await confirm(
                        context,
                        title: tr('Çıkış yapılsın mı?'),
                        message: tr(
                          'Tekrar girmek için e-posta ve şifren gerekecek.',
                        ),
                        action: tr('Çıkış yap'),
                      );
                      if (ok) await ref.read(authRepositoryProvider).signOut();
                    },
              child: Text(tr('Çıkış yap')),
            ),
          ],
        ),
      ),
    );
  }
}
