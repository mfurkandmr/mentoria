import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xl;
import 'package:xml/xml.dart';

/// Bir sayfanın hücreleri (metin olarak).
typedef SheetRows = List<List<String>>;

/// Dosyanın neden okunamadığı (ekranda ayrı ayrı açıklanır).
enum SpreadsheetProblem {
  /// Şifreli Excel dosyası.
  encrypted,

  /// Okunacak hücre yok.
  empty,

  /// Tablo dosyası değil (resim, PDF, Word…).
  notSpreadsheet,

  /// Tablo dosyası ama bozuk / beklenmedik yapıda.
  corrupt,
}

class SpreadsheetException implements Exception {
  const SpreadsheetException(this.problem, [this.cause]);

  final SpreadsheetProblem problem;
  final Object? cause;

  @override
  String toString() => 'SpreadsheetException($problem, $cause)';
}

/// Yayınevlerinin ve optik okuyucuların verdiği sonuç dosyalarını okur;
/// biçimi uzantıdan değil içerikten anlar:
///  * .xlsx (Excel 2007+): XML'i doğrudan okunur (stil / sayı biçimi ne
///    olursa olsun yalnızca değerler alınır).
///  * .xls (Excel 97-2003, BIFF8; Excel 95 BIFF5 de).
///  * "XML Elektronik Tablo 2003" ve uzantısı .xls olan HTML tablolar.
///  * CSV / TXT: noktalı virgül, sekme, virgül ya da dikey çizgiyle ayrılmış;
///    UTF-8, UTF-16 ya da Windows-1254 (Türkçe) kodlamalı.
///
/// Sayfa adı → satırlar döner. Okunamazsa [SpreadsheetException].
Map<String, SheetRows> readSpreadsheet(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const SpreadsheetException(SpreadsheetProblem.empty);
  }
  final Map<String, SheetRows> sheets;
  if (_startsWith(bytes, const [0x50, 0x4B, 0x03, 0x04])) {
    sheets = _readXlsx(bytes);
  } else if (_startsWith(bytes, const [
    0xD0,
    0xCF,
    0x11,
    0xE0,
    0xA1,
    0xB1,
    0x1A,
    0xE1,
  ])) {
    sheets = _XlsReader(bytes).read();
  } else if (_looksBinary(bytes)) {
    throw const SpreadsheetException(SpreadsheetProblem.notSpreadsheet);
  } else {
    final text = decodeText(bytes);
    final head = text.length > 4000 ? text.substring(0, 4000) : text;
    if (head.contains('urn:schemas-microsoft-com:office:spreadsheet')) {
      sheets = _readXml2003(text);
    } else if (RegExp(
      r'<(table|html)\b',
      caseSensitive: false,
    ).hasMatch(head)) {
      sheets = {'Tablo': _readHtml(text)};
    } else {
      sheets = {'Tablo': _readDelimited(text)};
    }
  }
  return _withoutEmpty(sheets);
}

// --- Ortak yardımcılar --------------------------------------------------

bool _startsWith(Uint8List b, List<int> sig) {
  if (b.length < sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (b[i] != sig[i]) return false;
  }
  return true;
}

/// İlk 4 KB'ta NUL bayt varsa (UTF-16 BOM'u yoksa) ikili dosyadır.
bool _looksBinary(Uint8List b) {
  if (_startsWith(b, const [0xFF, 0xFE]) ||
      _startsWith(b, const [0xFE, 0xFF])) {
    return false;
  }
  final n = b.length < 4096 ? b.length : 4096;
  for (var i = 0; i < n; i++) {
    if (b[i] == 0) return true;
  }
  return false;
}

/// Boş sayfaları atar, satır sonlarındaki boş hücreleri kırpar.
Map<String, SheetRows> _withoutEmpty(Map<String, SheetRows> sheets) {
  final out = <String, SheetRows>{};
  for (final e in sheets.entries) {
    final rows = [
      for (final r in e.value) [for (final c in r) c.trim()],
    ];
    for (final r in rows) {
      while (r.isNotEmpty && r.last.isEmpty) {
        r.removeLast();
      }
    }
    while (rows.isNotEmpty && rows.last.isEmpty) {
      rows.removeLast();
    }
    if (rows.any((r) => r.isNotEmpty)) out[e.key] = rows;
  }
  if (out.isEmpty) {
    throw const SpreadsheetException(SpreadsheetProblem.empty);
  }
  return out;
}

/// Sayı hücresi → metin: 34.0 → "34", 22.5 → "22.5" (üstel gösterim yok).
String formatNumber(double v) {
  if (v.isNaN || v.isInfinite) return '';
  if (v == v.roundToDouble() && v.abs() < 1e15) return '${v.toInt()}';
  var s = v.toStringAsFixed(10);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

/// Metin dosyasının kodlamasını çözer: BOM'a bakar, UTF-8 değilse
/// Windows-1254 (Türkçe Windows / eski Excel) kabul eder.
String decodeText(Uint8List b) {
  if (_startsWith(b, const [0xEF, 0xBB, 0xBF])) {
    return utf8.decode(b.sublist(3), allowMalformed: true);
  }
  if (_startsWith(b, const [0xFF, 0xFE])) return _utf16(b.sublist(2), true);
  if (_startsWith(b, const [0xFE, 0xFF])) return _utf16(b.sublist(2), false);
  try {
    return utf8.decode(b);
  } on FormatException {
    return cp1254(b);
  }
}

String _utf16(Uint8List b, bool little) {
  final sb = StringBuffer();
  for (var i = 0; i + 1 < b.length; i += 2) {
    sb.writeCharCode(little ? b[i] | b[i + 1] << 8 : b[i] << 8 | b[i + 1]);
  }
  return sb.toString();
}

/// Windows-1254 → Unicode. 0x80–0x9F ve Türkçe harfler dışında Latin-1.
String cp1254(List<int> bytes) {
  const high = <int, int>{
    0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026,
    0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160,
    0x8B: 0x2039, 0x8C: 0x0152, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
    0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02DC,
    0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153, 0x9F: 0x0178,
    0xD0: 0x011E, 0xDD: 0x0130, 0xDE: 0x015E, //
    0xF0: 0x011F, 0xFD: 0x0131, 0xFE: 0x015F,
  };
  final sb = StringBuffer();
  for (final c in bytes) {
    sb.writeCharCode(high[c] ?? c);
  }
  return sb.toString();
}

// --- CSV / TXT ----------------------------------------------------------

SheetRows _readDelimited(String text) {
  final sample = text
      .split(RegExp(r'\r\n|\n|\r'))
      .where((l) => l.trim().isNotEmpty)
      .take(10)
      .toList();
  var delimiter = ';';
  var best = -1;
  for (final d in const [';', '\t', ',', '|']) {
    // Her satırda görünen en az sayı: tutarlı ayıracı seç.
    final counts = [for (final l in sample) d.allMatches(l).length];
    final score = counts.isEmpty ? 0 : counts.reduce((a, b) => a < b ? a : b);
    if (score > best) {
      best = score;
      delimiter = d;
    }
  }
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"' && cell.isEmpty) {
      quoted = true;
    } else if (ch == delimiter) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = [];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

// --- HTML tablo (uzantısı .xls olan dışa aktarımlar) ----------------------

SheetRows _readHtml(String html) {
  final rowRe = RegExp(
    r'<tr\b[^>]*>(.*?)</tr\s*>',
    caseSensitive: false,
    dotAll: true,
  );
  final cellRe = RegExp(
    r'<t([dh])\b([^>]*)>(.*?)</t\1\s*>',
    caseSensitive: false,
    dotAll: true,
  );
  final spanRe = RegExp(r'colspan\s*=\s*"?(\d+)', caseSensitive: false);
  return [
    for (final r in rowRe.allMatches(html))
      [
        for (final c in cellRe.allMatches(r.group(1)!)) ...[
          _htmlText(c.group(3)!),
          for (
            var k = 1;
            k <
                (int.tryParse(spanRe.firstMatch(c.group(2)!)?.group(1) ?? '') ??
                    1);
            k++
          )
            '',
        ],
      ],
  ];
}

String _htmlText(String s) {
  var t = s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  t = t
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
      )
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m[1]!)),
      )
      .replaceAll('&amp;', '&');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

// --- XML yardımcıları (önekli / öneksiz ad alanlarına dayanıklı) ---------

Iterable<XmlElement> _all(XmlNode n, String local) =>
    n.descendants.whereType<XmlElement>().where((e) => e.name.local == local);

Iterable<XmlElement> _kids(XmlNode n, String local) =>
    n.children.whereType<XmlElement>().where((e) => e.name.local == local);

String? _attr(XmlElement e, String local) =>
    e.attributes.where((a) => a.name.local == local).firstOrNull?.value;

// --- XML Elektronik Tablo 2003 ------------------------------------------

Map<String, SheetRows> _readXml2003(String text) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(text);
  } catch (e) {
    throw SpreadsheetException(SpreadsheetProblem.corrupt, e);
  }
  final out = <String, SheetRows>{};
  for (final (i, ws) in _all(doc, 'Worksheet').indexed) {
    final rows = <List<String>>[];
    for (final row in _all(ws, 'Row')) {
      final r = <String>[];
      for (final c in _kids(row, 'Cell')) {
        final idx = int.tryParse(_attr(c, 'Index') ?? '');
        while (idx != null && r.length < idx - 1) {
          r.add('');
        }
        final data = _kids(c, 'Data').firstOrNull;
        var v = data?.innerText ?? '';
        if (_attr(data ?? c, 'Type') == 'Number') {
          final d = double.tryParse(v);
          if (d != null) v = formatNumber(d);
        }
        r.add(v);
      }
      rows.add(r);
    }
    out[_attr(ws, 'Name') ?? 'Sayfa ${i + 1}'] = rows;
  }
  return out;
}

// --- XLSX ---------------------------------------------------------------

Map<String, SheetRows> _readXlsx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw SpreadsheetException(SpreadsheetProblem.corrupt, e);
  }
  String? file(String path) {
    final f =
        zip.findFile(path) ??
        zip.files
            .where((f) => f.name.toLowerCase() == path.toLowerCase())
            .firstOrNull;
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final workbook = file('xl/workbook.xml');
  if (workbook == null) {
    // Word / OpenDocument gibi başka bir zip.
    throw const SpreadsheetException(SpreadsheetProblem.notSpreadsheet);
  }
  try {
    return _parseXlsx(workbook, file);
  } on SpreadsheetException {
    rethrow;
  } catch (e) {
    // Beklenmedik yapı: yine de kütüphaneyle bir kez dene.
    try {
      final book = xl.Excel.decodeBytes(bytes);
      return {
        for (final t in book.tables.entries)
          t.key: [
            for (final row in t.value.rows)
              [for (final c in row) c?.value?.toString() ?? ''],
          ],
      };
    } catch (_) {
      throw SpreadsheetException(SpreadsheetProblem.corrupt, e);
    }
  }
}

Map<String, SheetRows> _parseXlsx(
  String workbook,
  String? Function(String path) file,
) {
  final rels = <String, String>{};
  final relsXml = file('xl/_rels/workbook.xml.rels');
  if (relsXml != null) {
    for (final r in _all(XmlDocument.parse(relsXml), 'Relationship')) {
      final id = _attr(r, 'Id'), target = _attr(r, 'Target');
      if (id != null && target != null) rels[id] = target;
    }
  }

  final shared = <String>[];
  final ssXml = file('xl/sharedStrings.xml');
  if (ssXml != null) {
    for (final si in _all(XmlDocument.parse(ssXml), 'si')) {
      shared.add(_richText(si));
    }
  }

  final out = <String, SheetRows>{};
  final sheets = _all(XmlDocument.parse(workbook), 'sheet').toList();
  for (final (i, s) in sheets.indexed) {
    final name = _attr(s, 'name') ?? 'Sayfa ${i + 1}';
    final target = rels[_attr(s, 'id') ?? ''];
    final path = target == null
        ? 'xl/worksheets/sheet${i + 1}.xml'
        : target.startsWith('/')
        ? target.substring(1)
        : 'xl/${target.replaceFirst(RegExp(r'^\./'), '')}';
    final xml = file(path);
    if (xml == null) continue;
    out[name] = _parseXlsxSheet(XmlDocument.parse(xml), shared);
  }
  return out;
}

/// Paylaşılan / satır içi metin: tüm `t` parçaları (fonetik `rPh` hariç).
String _richText(XmlElement e) => _all(e, 't')
    .where(
      (t) => !t.ancestors.any((a) => a is XmlElement && a.name.local == 'rPh'),
    )
    .map((t) => t.innerText)
    .join();

int _colIndex(String ref) {
  var col = 0;
  for (final c in ref.codeUnits) {
    if (c >= 65 && c <= 90) {
      col = col * 26 + (c - 64);
    } else if (c >= 97 && c <= 122) {
      col = col * 26 + (c - 96);
    } else {
      break;
    }
  }
  return col - 1;
}

SheetRows _parseXlsxSheet(XmlDocument doc, List<String> shared) {
  final cells = <int, Map<int, String>>{};
  var nextRow = 0;
  var maxRow = -1;
  for (final row in _all(doc, 'row')) {
    final r = (int.tryParse(_attr(row, 'r') ?? '') ?? nextRow + 1) - 1;
    nextRow = r + 1;
    if (r > maxRow) maxRow = r;
    var nextCol = 0;
    for (final c in _kids(row, 'c')) {
      final ref = _attr(c, 'r');
      final col = ref == null ? nextCol : _colIndex(ref);
      nextCol = col + 1;
      final v = _kids(c, 'v').firstOrNull?.innerText;
      final text = switch (_attr(c, 't')) {
        's' => shared.elementAtOrNull(int.tryParse(v ?? '') ?? -1) ?? '',
        'inlineStr' => _richText(_kids(c, 'is').firstOrNull ?? c),
        'str' => v ?? '',
        'b' => v ?? '',
        'e' => '',
        _ =>
          v == null
              ? ''
              : (double.tryParse(v) == null
                    ? v
                    : formatNumber(double.parse(v))),
      };
      if (text.isNotEmpty) (cells[r] ??= {})[col] = text;
    }
  }
  return _gridFrom(cells, maxRow);
}

SheetRows _gridFrom(Map<int, Map<int, String>> cells, int maxRow) => [
  for (var r = 0; r <= maxRow; r++)
    () {
      final row = cells[r];
      if (row == null || row.isEmpty) return <String>[];
      final maxCol = row.keys.reduce((a, b) => a > b ? a : b);
      return [for (var c = 0; c <= maxCol; c++) row[c] ?? ''];
    }(),
];

// --- XLS (Excel 97-2003 BIFF8, Excel 95 BIFF5) ---------------------------

class _XlsReader {
  _XlsReader(this.bytes) : data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData data;

  static const _end = 0xFFFFFFFE;
  static const _free = 0xFFFFFFFF;

  int _u16(ByteData d, int o) => d.getUint16(o, Endian.little);
  int _u32(ByteData d, int o) => d.getUint32(o, Endian.little);

  Map<String, SheetRows> read() {
    try {
      final stream = _workbookStream();
      return _parseBiff(stream);
    } on SpreadsheetException {
      rethrow;
    } catch (e) {
      throw SpreadsheetException(SpreadsheetProblem.corrupt, e);
    }
  }

  // OLE2 bileşik dosyası: FAT zincirleri ve dizin.
  Uint8List _workbookStream() {
    final sectorSize = 1 << _u16(data, 0x1E);
    final miniSize = 1 << _u16(data, 0x20);
    final dirStart = _u32(data, 0x30);
    final cutoff = _u32(data, 0x38);
    final miniFatStart = _u32(data, 0x3C);
    var difatNext = _u32(data, 0x44);
    final numFat = _u32(data, 0x2C);

    int sectorOffset(int s) => (s + 1) * sectorSize;

    final fatSectors = <int>[
      for (var i = 0; i < 109; i++)
        if (_u32(data, 0x4C + 4 * i) != _free) _u32(data, 0x4C + 4 * i),
    ];
    var guard = 0;
    while (difatNext != _end && difatNext != _free && guard++ < 10000) {
      final o = sectorOffset(difatNext);
      final per = sectorSize ~/ 4 - 1;
      for (var i = 0; i < per; i++) {
        final s = _u32(data, o + 4 * i);
        if (s != _free) fatSectors.add(s);
      }
      difatNext = _u32(data, o + 4 * per);
    }
    final fat = <int>[
      for (final s in fatSectors.take(numFat == 0 ? fatSectors.length : numFat))
        for (var i = 0; i < sectorSize ~/ 4; i++)
          _u32(data, sectorOffset(s) + 4 * i),
    ];

    Uint8List chain(int start, [int? size]) {
      final out = BytesBuilder(copy: false);
      var s = start;
      var n = 0;
      while (s != _end && s != _free && s < fat.length && n++ <= fat.length) {
        final o = sectorOffset(s);
        if (o + sectorSize > bytes.length) {
          out.add(bytes.sublist(o.clamp(0, bytes.length)));
          break;
        }
        out.add(Uint8List.sublistView(bytes, o, o + sectorSize));
        s = fat[s];
      }
      final all = out.toBytes();
      return size == null || size > all.length ? all : all.sublist(0, size);
    }

    // Dizin girdileri (128 bayt).
    final dir = chain(dirStart);
    final dd = ByteData.sublistView(dir);
    final entries = <({String name, int type, int start, int size})>[];
    for (var o = 0; o + 128 <= dir.length; o += 128) {
      final nameLen = _u16(dd, o + 64);
      final sb = StringBuffer();
      for (var i = 0; i + 1 < nameLen - 1 && i < 64; i += 2) {
        sb.writeCharCode(_u16(dd, o + i));
      }
      entries.add((
        name: sb.toString(),
        type: dir[o + 66],
        start: _u32(dd, o + 116),
        size: _u32(dd, o + 120),
      ));
    }
    if (entries.any((e) => e.name == 'EncryptedPackage')) {
      throw const SpreadsheetException(SpreadsheetProblem.encrypted);
    }
    final wb = entries
        .where(
          (e) =>
              e.type == 2 &&
              (e.name.toLowerCase() == 'workbook' ||
                  e.name.toLowerCase() == 'book'),
        )
        .firstOrNull;
    if (wb == null) {
      // Word belgesi vb. başka bir OLE2 dosyası.
      throw const SpreadsheetException(SpreadsheetProblem.notSpreadsheet);
    }
    if (wb.size >= cutoff) return chain(wb.start, wb.size);

    // Küçük akış: mini akıştan okunur.
    final root = entries.firstWhere((e) => e.type == 5);
    final mini = chain(root.start);
    final miniFatBytes = chain(miniFatStart);
    final mfd = ByteData.sublistView(miniFatBytes);
    final miniFat = [
      for (var i = 0; i + 4 <= miniFatBytes.length; i += 4) _u32(mfd, i),
    ];
    final out = BytesBuilder(copy: false);
    var s = wb.start;
    var n = 0;
    while (s != _end && s < miniFat.length && n++ <= miniFat.length) {
      final o = s * miniSize;
      out.add(
        Uint8List.sublistView(mini, o, (o + miniSize).clamp(0, mini.length)),
      );
      s = miniFat[s];
    }
    final all = out.toBytes();
    return all.length > wb.size ? all.sublist(0, wb.size) : all;
  }

  // BIFF kayıtları.
  Map<String, SheetRows> _parseBiff(Uint8List s) {
    final d = ByteData.sublistView(s);
    var biff8 = true;
    var codepage = 1254;
    final sheets = <({String name, int pos})>[];
    var sst = <String>[];

    String bytesText(Uint8List b) =>
        codepage == 1252 ? String.fromCharCodes(b) : cp1254(b);

    // Kitap genelindeki kayıtlar: ilk EOF'a kadar.
    var pos = 0;
    while (pos + 4 <= s.length) {
      final type = _u16(d, pos), len = _u16(d, pos + 2);
      final body = Uint8List.sublistView(
        s,
        pos + 4,
        (pos + 4 + len).clamp(0, s.length),
      );
      final bd = ByteData.sublistView(body);
      switch (type) {
        case 0x0809: // BOF
          biff8 = len >= 2 && _u16(bd, 0) == 0x0600;
        case 0x002F: // FILEPASS
          throw const SpreadsheetException(SpreadsheetProblem.encrypted);
        case 0x0042: // CODEPAGE
          codepage = _u16(bd, 0);
        case 0x0085: // BOUNDSHEET
          final sheetPos = _u32(bd, 0);
          final kind = body[5];
          final cch = body[6];
          final String name;
          if (biff8) {
            final high = body[7] & 1 == 1;
            name = high
                ? String.fromCharCodes([
                    for (var i = 0; i < cch; i++) _u16(bd, 8 + 2 * i),
                  ])
                : String.fromCharCodes(body.sublist(8, 8 + cch));
          } else {
            name = bytesText(body.sublist(7, 7 + cch));
          }
          if (kind == 0) sheets.add((name: name, pos: sheetPos));
        case 0x00FC: // SST (+ CONTINUE)
          final chunks = <Uint8List>[body];
          var p = pos + 4 + len;
          while (p + 4 <= s.length && _u16(d, p) == 0x003C) {
            final l = _u16(d, p + 2);
            chunks.add(Uint8List.sublistView(s, p + 4, p + 4 + l));
            p += 4 + l;
          }
          sst = _readSst(chunks);
        case 0x000A: // EOF
          pos = s.length; // kitap kayıtları bitti
          continue;
      }
      pos += 4 + len;
    }

    final out = <String, SheetRows>{};
    for (final sh in sheets) {
      final cells = <int, Map<int, String>>{};
      var maxRow = -1;
      void put(int r, int c, String v) {
        if (v.isEmpty) return;
        (cells[r] ??= {})[c] = v;
        if (r > maxRow) maxRow = r;
      }

      (int, int)? pendingString;
      var p = sh.pos;
      while (p + 4 <= s.length) {
        final type = _u16(d, p), len = _u16(d, p + 2);
        final body = Uint8List.sublistView(
          s,
          p + 4,
          (p + 4 + len).clamp(0, s.length),
        );
        final bd = ByteData.sublistView(body);
        if (type == 0x000A && p != sh.pos) break; // EOF
        switch (type) {
          case 0x00FD: // LABELSST
            put(
              _u16(bd, 0),
              _u16(bd, 2),
              sst.elementAtOrNull(_u32(bd, 6)) ?? '',
            );
          case 0x0204 || 0x00D6: // LABEL / RSTRING
            final cch = _u16(bd, 6);
            put(
              _u16(bd, 0),
              _u16(bd, 2),
              biff8
                  ? _chars(body, bd, 9, cch, body[8] & 1 == 1)
                  : bytesText(body.sublist(8, (8 + cch).clamp(0, body.length))),
            );
          case 0x0203: // NUMBER
            put(
              _u16(bd, 0),
              _u16(bd, 2),
              formatNumber(bd.getFloat64(6, Endian.little)),
            );
          case 0x027E: // RK
            put(_u16(bd, 0), _u16(bd, 2), formatNumber(_rk(_u32(bd, 6))));
          case 0x00BD: // MULRK
            final row = _u16(bd, 0), first = _u16(bd, 2);
            final n = (len - 6) ~/ 6;
            for (var i = 0; i < n; i++) {
              put(row, first + i, formatNumber(_rk(_u32(bd, 4 + 6 * i + 2))));
            }
          case 0x0006: // FORMULA: önbellekteki sonuç
            final row = _u16(bd, 0), col = _u16(bd, 2);
            if (body[12] == 0xFF && body[13] == 0xFF) {
              switch (body[6]) {
                case 0:
                  pendingString = (row, col); // metin sonraki STRING kaydında
                case 1:
                  put(row, col, body[8] == 1 ? '1' : '0');
              }
            } else {
              put(row, col, formatNumber(bd.getFloat64(6, Endian.little)));
            }
          case 0x0207: // STRING (formül sonucu)
            if (pendingString != null) {
              final cch = _u16(bd, 0);
              put(
                pendingString.$1,
                pendingString.$2,
                biff8
                    ? _chars(body, bd, 3, cch, body[2] & 1 == 1)
                    : bytesText(
                        body.sublist(2, (2 + cch).clamp(0, body.length)),
                      ),
              );
              pendingString = null;
            }
          case 0x0205: // BOOLERR
            if (body[7] == 0) put(_u16(bd, 0), _u16(bd, 2), '${body[6]}');
        }
        p += 4 + len;
      }
      out[sh.name] = _gridFrom(cells, maxRow);
    }
    return out;
  }

  String _chars(Uint8List b, ByteData bd, int at, int cch, bool high) {
    final sb = StringBuffer();
    for (var i = 0; i < cch; i++) {
      final o = at + (high ? 2 * i : i);
      if (o + (high ? 1 : 0) >= b.length) break;
      sb.writeCharCode(high ? _u16(bd, o) : b[o]);
    }
    return sb.toString();
  }

  /// RK: 30 bitlik sıkıştırılmış sayı (tamsayı ya da double'ın üst 30 biti).
  static double _rk(int v) {
    final double r;
    if (v & 2 != 0) {
      r = (v.toSigned(32) >> 2).toDouble();
    } else {
      final b = ByteData(8)
        ..setUint32(0, 0, Endian.little)
        ..setUint32(4, v & 0xFFFFFFFC, Endian.little);
      r = b.getFloat64(0, Endian.little);
    }
    return v & 1 != 0 ? r / 100 : r;
  }

  /// Paylaşılan metin tablosu. Metinler CONTINUE kayıtlarına bölünebilir;
  /// bölünen karakter dizisinin devamı yeni bir bayrak baytıyla başlar.
  List<String> _readSst(List<Uint8List> chunks) {
    var ci = 0, off = 0;
    void norm() {
      while (ci < chunks.length && off >= chunks[ci].length) {
        ci++;
        off = 0;
      }
    }

    int u8() {
      norm();
      return chunks[ci][off++];
    }

    int u16() => u8() | u8() << 8;
    int u32() => u16() | u16() << 16;
    void skip(int n) {
      for (var i = 0; i < n; i++) {
        u8();
      }
    }

    String chars(int cch, bool high) {
      final sb = StringBuffer();
      var left = cch;
      while (left > 0) {
        if (off >= chunks[ci].length) {
          ci++;
          off = 0;
          high = chunks[ci][off++] & 1 == 1;
        }
        final c = chunks[ci];
        if (high) {
          sb.writeCharCode(c[off] | c[off + 1] << 8);
          off += 2;
        } else {
          sb.writeCharCode(c[off]);
          off++;
        }
        left--;
      }
      return sb.toString();
    }

    u32(); // toplam
    final unique = u32();
    final out = <String>[];
    for (var i = 0; i < unique; i++) {
      norm();
      if (ci >= chunks.length) break;
      final cch = u16();
      final flags = u8();
      final runs = flags & 8 != 0 ? u16() : 0;
      final ext = flags & 4 != 0 ? u32() : 0;
      out.add(chars(cch, flags & 1 == 1));
      skip(4 * runs + ext);
    }
    return out;
  }
}
