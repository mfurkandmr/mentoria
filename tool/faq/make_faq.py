"""SSS içeriğinden Dart dosyasını ve İngilizce çevirileri üretir.

    python tool/faq/make_faq.py

İçerik: tool/faq/faq_content.py. Çıktı: lib/features/help/data/faq.dart ve
lib/core/i18n/strings_en.dart içindeki "SSS" bloğu.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import faq_content as F  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
OUT = os.path.join(ROOT, 'lib', 'features', 'help', 'data', 'faq.dart')
EN = os.path.join(ROOT, 'lib', 'core', 'i18n', 'strings_en.dart')
BEGIN = '  // SSS (üretildi: python tool/faq/make_faq.py; elle düzenleme)\n'
END = '  // SSS sonu\n'
ANCHOR = '  // Bildirim kanalı'


def q(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def sections_dart(name, sections):
    out = [f'List<FaqSection> _{name}() => [']
    for (title_tr, _), icon, items in sections:
        out.append(f'  FaqSection(tr({q(title_tr)}), Icons.{icon}, [')
        for q_tr, _, a_tr, _ in items:
            out.append(f'    FaqItem(\n      tr({q(q_tr)}),\n      tr({q(a_tr)}),\n    ),')
        out.append('  ]),')
    out.append('];')
    return '\n'.join(out)


GROUPS = [('student', F.STUDENT), ('coach', F.COACH), ('admin', F.ADMIN), ('parent', F.PARENT),
          ('common', F.COMMON), ('platform', F.PLATFORM)]


def main():
    dart = [
        '// ÜRETİLDİ: python tool/faq/make_faq.py. Elle düzenleme; metinleri',
        '// tool/faq/faq_content.py içinde değiştirip komutu yeniden çalıştır.',
        "import 'package:flutter/material.dart';",
        '',
        "import '../../../core/i18n/i18n.dart';",
        "import '../../auth/data/profile.dart';",
        '',
        '/// Bir soru ve cevabı.',
        'class FaqItem {',
        '  const FaqItem(this.question, this.answer);',
        '  final String question;',
        '  final String answer;',
        '}',
        '',
        '/// Başlıklı bir soru grubu.',
        'class FaqSection {',
        '  const FaqSection(this.title, this.icon, this.items);',
        '  final String title;',
        '  final IconData icon;',
        '  final List<FaqItem> items;',
        '}',
        '',
        '/// Rolün sıkça sorulan soruları; ortak sorular sonda. Metinler o anki',
        '/// dilde üretilir.',
        'List<FaqSection> faqFor(UserRole role, {bool superAdmin = false}) => [',
        '  ...switch (role) {',
        '    UserRole.student => _student(),',
        '    UserRole.coach => _coach(),',
        '    UserRole.admin => _admin(),',
        '    UserRole.parent => _parent(),',
        '  },',
        '  if (superAdmin) ..._platform(),',
        '  ..._common(),',
        '];',
        '',
    ]
    for name, sections in GROUPS:
        dart.append(sections_dart(name, sections))
        dart.append('')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(dart))

    with open(EN, encoding='utf-8') as f:
        en = f.read()
    if BEGIN in en:
        a = en.index(BEGIN)
        b = en.index(END) + len(END)
        en = en[:a] + en[b:]
    pairs = {}
    for _, sections in GROUPS:
        for (t_tr, t_en), _, items in sections:
            pairs[t_tr] = t_en
            for q_tr, q_en, a_tr, a_en in items:
                pairs[q_tr] = q_en
                pairs[a_tr] = a_en
    lines = []
    for k, v in pairs.items():
        if f'{q(k)}:' in en or f'{q(k)}\n' in en:
            continue  # zaten çevrilmiş (ör. "Hesap")
        lines.append(f'  {q(k)}:\n      {q(v)},')
    block = BEGIN + '\n'.join(lines) + '\n' + END
    i = en.index(ANCHOR)
    en = en[:i] + block + '\n' + en[i:]
    with open(EN, 'w', encoding='utf-8', newline='\n') as f:
        f.write(en)
    print(f'{sum(len(i) for _, s in GROUPS for _, _, i in s)} soru, {len(lines)} yeni çeviri')


if __name__ == '__main__':
    main()
