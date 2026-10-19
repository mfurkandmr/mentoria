import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';

/// Uygulamada gösterilen KVKK metinleri (assets/legal, kaynak docs/kvkk).
enum LegalDoc {
  privacyNotice('assets/legal/aydinlatma.md', 'Aydınlatma Metni'),
  explicitConsent('assets/legal/acik_riza.md', 'Açık Rıza Metni'),
  guardianConsent('assets/legal/veli_onay.md', 'Veli Onay Metni');

  const LegalDoc(this.asset, this.trTitle);
  final String asset;
  final String trTitle;

  String get title => tr(trTitle);
}

/// Metni tam ekran açar (oturum gerekmez; kayıt ekranından da açılır).
Future<void> openLegal(BuildContext context, LegalDoc doc) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => LegalTextScreen(doc: doc)));

class LegalTextScreen extends StatelessWidget {
  const LegalTextScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(doc.asset),
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              title: tr('Metin açılamadı'),
              message: tr('Biraz sonra yeniden dene.'),
            );
          }
          if (!snap.hasData) return const Center(child: BizzLoader());
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                // Metinler Türkçe yayımlanır (yasal metnin aslı).
                for (final b in parseLegalMarkdown(snap.data!))
                  _BlockView(block: b),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Metin bloğu: başlık, paragraf, madde, tablo satırı ya da ayırıcı.
sealed class LegalBlock {
  const LegalBlock();
}

class LegalHeading extends LegalBlock {
  const LegalHeading(this.level, this.text);
  final int level;
  final String text;
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text);
  final String text;
}

class LegalBullet extends LegalBlock {
  const LegalBullet(this.text, {this.indent = 0});
  final String text;
  final int indent;
}

class LegalTableRow extends LegalBlock {
  const LegalTableRow(this.cells, {this.header = false});
  final List<String> cells;
  final bool header;
}

class LegalRule extends LegalBlock {
  const LegalRule();
}

/// Metinlerde kullanılan küçük Markdown alt kümesini bloklara ayırır:
/// `#` başlıklar, `-` maddeler, `|` tablolar, `---` ayırıcı, paragraflar.
List<LegalBlock> parseLegalMarkdown(String source) {
  final blocks = <LegalBlock>[];
  final para = <String>[];
  var tableHeaderPending = false;

  void flush() {
    if (para.isNotEmpty) {
      blocks.add(LegalParagraph(para.join(' ')));
      para.clear();
    }
  }

  for (final raw in source.split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) {
      flush();
      tableHeaderPending = false;
      continue;
    }
    final heading = RegExp(r'^(#{1,4}) (.*)$').firstMatch(trimmed);
    if (heading != null) {
      flush();
      blocks.add(LegalHeading(heading.group(1)!.length, heading.group(2)!));
      continue;
    }
    if (trimmed == '---') {
      flush();
      blocks.add(const LegalRule());
      continue;
    }
    if (trimmed.startsWith('|')) {
      flush();
      final cells = trimmed
          .substring(1, trimmed.endsWith('|') ? trimmed.length - 1 : null)
          .split('|')
          .map((c) => c.trim())
          .toList();
      if (cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c))) {
        // Başlık ayırıcısı: bir önceki satır başlıktı.
        final last = blocks.removeLast() as LegalTableRow;
        blocks.add(LegalTableRow(last.cells, header: true));
        continue;
      }
      blocks.add(LegalTableRow(cells));
      tableHeaderPending = true;
      continue;
    }
    final bullet = RegExp(r'^- (.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flush();
      final indent = (line.length - trimmed.length) ~/ 2;
      blocks.add(LegalBullet(bullet.group(1)!, indent: indent));
      continue;
    }
    // Maddenin alt satırı (girintili devam).
    if (para.isEmpty &&
        blocks.isNotEmpty &&
        blocks.last is LegalBullet &&
        line.startsWith('  ')) {
      final b = blocks.removeLast() as LegalBullet;
      blocks.add(LegalBullet('${b.text} $trimmed', indent: b.indent));
      continue;
    }
    if (tableHeaderPending) tableHeaderPending = false;
    para.add(trimmed);
  }
  flush();
  return blocks;
}

/// `**kalın**` ve `*eğik*` işaretlerini yazı stillerine çevirir.
List<InlineSpan> legalSpans(String text, TextStyle? base) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
  var pos = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
    spans.add(
      m.group(1) != null
          ? TextSpan(
              text: m.group(1),
              style: const TextStyle(fontWeight: FontWeight.w800),
            )
          : TextSpan(
              text: m.group(2),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
    );
    pos = m.end;
  }
  if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
  return spans;
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget rich(String s, TextStyle? style) =>
        Text.rich(TextSpan(style: style, children: legalSpans(s, style)));

    return switch (block) {
      LegalHeading(:final level, text: final t) => Padding(
        padding: EdgeInsets.only(top: level == 1 ? 4 : 18, bottom: 6),
        child: Semantics(
          header: true,
          child: rich(
            t,
            (switch (level) {
              1 => text.headlineSmall,
              2 => text.titleLarge,
              _ => text.titleMedium,
            })?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      LegalParagraph(text: final t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: rich(t, text.bodyMedium?.copyWith(height: 1.45)),
      ),
      LegalBullet(text: final t, :final indent) => Padding(
        padding: EdgeInsets.only(left: 4 + indent * 18.0, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: text.bodyMedium),
            Expanded(child: rich(t, text.bodyMedium?.copyWith(height: 1.4))),
          ],
        ),
      ),
      LegalTableRow(:final cells, :final header) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, c) in cells.indexed)
              Expanded(
                flex: i == 0 ? 3 : 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: rich(
                    c,
                    (header ? text.labelLarge : text.bodySmall)?.copyWith(
                      fontWeight: header ? FontWeight.w800 : null,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      LegalRule() => const Divider(height: 28),
    };
  }
}
