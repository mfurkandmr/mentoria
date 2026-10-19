import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import 'legal_text_screen.dart';

/// Öğrenci davetinde kurum beyanı: "18 yaşından küçüklerin veli onayını
/// kurumumuz aldı." İşaretlenirse bu davetle katılan öğrencilerin veli onayı
/// kurum beyanı olarak kaydedilir (bkz. Veli Onay Metni, Metin B).
class GuardianStatementTile extends StatelessWidget {
  const GuardianStatementTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(
            tr(
              '18 yaşından küçük öğrencilerin velilerinden onayı kurumumuz aldı ve saklıyor.',
            ),
            style: text.bodySmall,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => openLegal(context, LegalDoc.guardianConsent),
            child: Text(tr('Veli onay metnini oku')),
          ),
        ),
        Text(
          value
              ? tr('Bu kodla katılan öğrencilerden ayrıca veli onayı istenmez.')
              : tr(
                  'İşaretlemezsen 18 yaşından küçük öğrenciler velilerini uygulamadan davet edip onay alır.',
                ),
          style: text.bodySmall,
        ),
      ],
    );
  }
}
