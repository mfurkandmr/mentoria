import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/constants/exam_subjects.dart';
import 'package:mentoria/core/i18n/i18n.dart';
import 'package:mentoria/core/i18n/strings_en.dart';

/// Dart tek tırnaklı literal içeriğini çalışma zamanındaki metne çevirir.
String _unescape(String s) => s
    .replaceAll(r"\'", "'")
    .replaceAll(r'\"', '"')
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\$', r'$')
    .replaceAll(r'\\', r'\');

void main() {
  tearDown(() => currentLanguage = AppLanguage.tr);

  test('koddaki her tr() metninin İngilizcesi var', () {
    final pattern = RegExp(r"\btr\(\s*'((?:[^'\\]|\\.)*)'");
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('i18n')) continue;
      for (final m in pattern.allMatches(f.readAsStringSync())) {
        final key = _unescape(m.group(1)!);
        if (!enStrings.containsKey(key)) missing.add('${f.path}: $key');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('ders, rol ve durum adları çevrilir', () {
    for (final s in examSubjects) {
      expect(enStrings.containsKey(s.trName), isTrue, reason: s.trName);
      if (s.trGroup != null) {
        expect(enStrings.containsKey(s.trGroup), isTrue, reason: s.trGroup);
      }
    }
    for (final f in FieldType.values) {
      expect(enStrings.containsKey(f.trLabel), isTrue, reason: f.trLabel);
    }
  });

  test('dil değişince metin ve yer tutucular değişir', () {
    expect(tr('Kaydet'), 'Kaydet');
    expect(tr('Merhaba {firstName}!', {'firstName': 'Elif'}), 'Merhaba Elif!');
    currentLanguage = AppLanguage.en;
    expect(tr('Kaydet'), 'Save');
    expect(tr('Merhaba {firstName}!', {'firstName': 'Elif'}), 'Hi Elif!');
    expect(subjectByCode('TYT_MAT').name, 'Mathematics');
    expect(localeTag, 'en_US');
    // Çevirisi olmayan metin olduğu gibi kalır.
    expect(tr('Bilinmeyen metin'), 'Bilinmeyen metin');
  });
}
