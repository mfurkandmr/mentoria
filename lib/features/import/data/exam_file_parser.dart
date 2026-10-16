import '../../../core/constants/exam_subjects.dart';
import '../../exams/data/exam.dart';
import '../../../core/i18n/i18n.dart';
import 'spreadsheet_reader.dart';

export 'spreadsheet_reader.dart'
    show SheetRows, SpreadsheetException, SpreadsheetProblem, readSpreadsheet;

/// Türkçe karakterleri sadeleştirip harf/rakam dışını atar.
String normalize(String s) {
  const map = {
    'İ': 'i',
    'I': 'i',
    'ı': 'i',
    'Ş': 's',
    'ş': 's',
    'Ğ': 'g',
    'ğ': 'g',
    'Ü': 'u',
    'ü': 'u',
    'Ö': 'o',
    'ö': 'o',
    'Ç': 'c',
    'ç': 'c',
  };
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(map[ch] ?? ch.toLowerCase());
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
}

List<String> _words(String s) =>
    normalize(s).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Okul numarası karşılaştırması: büyük harf, boşluksuz, baştaki sıfırlar atılır.
String normalizeNumber(String s) {
  final t = s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  final stripped = t.replaceFirst(RegExp(r'^0+(?=.)'), '');
  return stripped;
}

enum CountKind { correct, wrong, blank }

/// Ders adı → kod eşleştirmesi için takma adlar (normalize edilmiş, boşluksuz).
const _aliases = <String, List<String>>{
  // Optik okuyucu çıktılarındaki kısaltmalar da ("TRK D", "FİZ Y").
  'TYT_TUR': ['turkce', 'tur', 'trk', 'turk'],
  'TYT_TAR': ['tarih', 'tar'],
  'TYT_COG': ['cografya', 'cog'],
  'TYT_FEL': ['felsefe', 'fel'],
  'TYT_DIN': [
    'din',
    'dinkulturu',
    'dinkulturuveahlakbilgisi',
    'dkab',
    'dinkulturuahlakbilgisi',
  ],
  'TYT_MAT': ['matematik', 'temelmatematik', 'mat', 'tmat'],
  'TYT_FIZ': ['fizik', 'fiz'],
  'TYT_KIM': ['kimya', 'kim'],
  'TYT_BIY': ['biyoloji', 'biyo', 'biy'],
  'AYT_MAT': ['matematik', 'mat', 'aytmatematik'],
  'AYT_FIZ': ['fizik', 'fiz'],
  'AYT_KIM': ['kimya', 'kim'],
  'AYT_BIY': ['biyoloji', 'biyo', 'biy'],
  'AYT_EDB': [
    'edebiyat',
    'turkdiliveedebiyati',
    'tde',
    'tdedebiyat',
    'edb',
    'ede',
  ],
  'AYT_TAR1': ['tarih1', 'tarihi'],
  'AYT_COG1': ['cografya1', 'cografyai'],
  'AYT_TAR2': ['tarih2', 'tarihii'],
  'AYT_COG2': ['cografya2', 'cografyaii'],
  'AYT_FELG': ['felsefegrubu', 'felsefe', 'fg'],
  'AYT_DIN': ['din', 'dinkulturu', 'dkab'],
  'YDT_YD': [
    'yabancidil',
    'ingilizce',
    'ydt',
    'dil',
    'almanca',
    'arapca',
    'fransizca',
    'rusca',
  ],
};

const _kindTokens = <String, CountKind>{
  'd': CountKind.correct,
  'dogru': CountKind.correct,
  'dog': CountKind.correct,
  'y': CountKind.wrong,
  'yanlis': CountKind.wrong,
  'yan': CountKind.wrong,
  'b': CountKind.blank,
  'bos': CountKind.blank,
};

/// "Türkçe D", "TÜRKÇE DOĞRU" gibi bir başlığı (ders, tür) olarak çözer.
(String, CountKind)? parseHeader(String label, ExamType type) {
  final words = _words(label);
  // "Türkçe Doğru Sayısı" → "Türkçe Doğru"
  while (words.length > 2 &&
      const {'sayisi', 'sayi', 'adet'}.contains(words.last)) {
    words.removeLast();
  }
  if (words.length < 2) return null;
  final kind = _kindTokens[words.last];
  if (kind == null) return null;
  final subject = words.sublist(0, words.length - 1).join();
  // Başlıktaki "tyt"/"ayt" ön ekini yok say.
  final cleaned = subject.replaceFirst(RegExp(r'^(tyt|ayt|ydt)'), '');
  for (final s in examSubjects.where((s) => s.examType == type)) {
    if (_aliases[s.code]!.contains(cleaned)) return (s.code, kind);
  }
  return null;
}

bool _isNumberHeader(String label) {
  final w = _words(label);
  final joined = w.join();
  return w.contains('no') ||
      w.contains('numara') ||
      w.contains('numarasi') ||
      joined.contains('ogrencino') ||
      joined.contains('okulno') ||
      joined.contains('ogrno');
}

bool _isNameHeader(String label) {
  final joined = _words(label).join();
  return joined == 'ad' ||
      joined.contains('adsoyad') ||
      joined.contains('adisoyadi') ||
      joined.contains('adisoyad') ||
      joined == 'isim' ||
      joined.contains('ogrenciadi') ||
      joined == 'ogrenci';
}

/// Sütun eşleştirmesi (koç önizlemede değiştirebilir).
class ColumnMapping {
  ColumnMapping({
    this.numberCol,
    this.nameCol,
    Map<String, Map<CountKind, int>>? subjects,
  }) : subjects = subjects ?? {};

  int? numberCol;
  int? nameCol;

  /// ders kodu → (tür → sütun)
  final Map<String, Map<CountKind, int>> subjects;

  int get mappedSubjectCount =>
      subjects.values.where((m) => m.containsKey(CountKind.correct)).length;
}

/// Başlık satırı bulunmuş bir sayfa.
class ParsedSheet {
  ParsedSheet({
    required this.headers,
    required this.dataRows,
    required this.mapping,
    required this.headerRow,
  });

  /// Her sütunun görünen adı (iki satırlı başlıkta birleştirilmiş).
  final List<String> headers;
  final SheetRows dataRows;
  final ColumnMapping mapping;
  final int headerRow;
}

/// İki satırlı başlıklarda üst satırdaki birleştirilmiş ders adlarını sağa taşır.
List<String> _carryForward(List<String> row, int width) {
  final out = <String>[];
  var last = '';
  for (var c = 0; c < width; c++) {
    final v = c < row.length ? row[c] : '';
    if (v.isNotEmpty) last = v;
    out.add(last);
  }
  return out;
}

/// Sayfadaki başlık satırını bulur ve sütunları otomatik eşleştirir.
ParsedSheet? parseSheet(SheetRows rows, ExamType type) {
  if (rows.isEmpty) return null;
  final width = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
  ParsedSheet? best;
  var bestScore = 0;

  for (var r = 0; r < rows.length && r < 25; r++) {
    final row = rows[r];
    final above = r > 0
        ? _carryForward(rows[r - 1], width)
        : List.filled(width, '');
    final headers = <String>[];
    final mapping = ColumnMapping();
    var score = 0;

    for (var c = 0; c < width; c++) {
      final cell = c < row.length ? row[c] : '';
      // Önce hücrenin kendisi ("Türkçe D"), olmazsa üst satırla birlikte.
      var label = cell;
      var parsed = parseHeader(cell, type);
      if (parsed == null && above[c].isNotEmpty && cell.isNotEmpty) {
        final combined = '${above[c]} $cell';
        final p2 = parseHeader(combined, type);
        if (p2 != null) {
          parsed = p2;
          label = combined;
        }
      }
      headers.add(label.isEmpty ? 'Sütun ${c + 1}' : label);
      if (parsed != null) {
        final m = mapping.subjects.putIfAbsent(parsed.$1, () => {});
        if (!m.containsKey(parsed.$2)) {
          m[parsed.$2] = c;
          score++;
        }
      } else {
        // Numara / ad başlığı bu satırda ya da (iki satırlı başlıkta) üstünde.
        final raw = cell.isNotEmpty
            ? cell
            : (r > 0 && c < rows[r - 1].length ? rows[r - 1][c] : '');
        if (raw.isNotEmpty) {
          if (cell.isEmpty) headers[c] = raw;
          if (mapping.numberCol == null && _isNumberHeader(raw)) {
            mapping.numberCol = c;
          } else if (mapping.nameCol == null && _isNameHeader(raw)) {
            mapping.nameCol = c;
          }
        }
      }
    }

    if (score > bestScore) {
      bestScore = score;
      best = ParsedSheet(
        headers: headers,
        dataRows: _dataRows(rows.sublist(r + 1), mapping),
        mapping: mapping,
        headerRow: r,
      );
    }
  }
  return bestScore >= 2 ? best : null;
}

/// Başlıktan sonraki dolu satırlar (art arda 3 boş satırda durur).
SheetRows _dataRows(SheetRows rows, ColumnMapping m) {
  final out = <List<String>>[];
  var empty = 0;
  for (final r in rows) {
    final key = m.numberCol ?? m.nameCol;
    final v = key != null && key < r.length ? r[key] : r.join();
    if (v.trim().isEmpty) {
      if (++empty >= 3) break;
      continue;
    }
    empty = 0;
    out.add(r);
  }
  return out;
}

int _intAt(List<String> row, int? col) {
  if (col == null || col >= row.length) return 0;
  final v = row[col].replaceAll(',', '.');
  return double.tryParse(v)?.round() ?? 0;
}

/// Dosyadaki bir öğrenci satırı.
class ImportRow {
  const ImportRow({
    required this.number,
    required this.name,
    required this.results,
  });

  final String number;
  final String name;
  final List<SubjectResult> results;

  double get totalNet => results.fold(0, (s, r) => s + r.net);

  /// Soru sayısını aşan ders varsa hata metni.
  String? get problem {
    for (final r in results) {
      if (r.correct + r.wrong > r.subject.questionCount) {
        return tr('{subject}: D+Y soru sayısını aşıyor', {
          'subject': r.subject.name,
        });
      }
    }
    return null;
  }
}

/// Eşleştirmeye göre satırları öğrenci sonuçlarına çevirir.
List<ImportRow> buildRows(ParsedSheet sheet, ColumnMapping m) {
  return [
    for (final row in sheet.dataRows)
      () {
        final results = <SubjectResult>[];
        for (final e in m.subjects.entries) {
          final cCol = e.value[CountKind.correct];
          final wCol = e.value[CountKind.wrong];
          if (cCol == null) continue;
          final subject = subjectByCode(e.key);
          final correct = _intAt(row, cCol);
          final wrong = _intAt(row, wCol);
          final hasCell = cCol < row.length && row[cCol].isNotEmpty;
          if (!hasCell) continue;
          final bCol = e.value[CountKind.blank];
          final blank = bCol != null
              ? _intAt(row, bCol)
              : (subject.questionCount - correct - wrong).clamp(
                  0,
                  subject.questionCount,
                );
          results.add(
            SubjectResult(
              code: e.key,
              correct: correct,
              wrong: wrong,
              blank: blank,
            ),
          );
        }
        return ImportRow(
          number: m.numberCol == null || m.numberCol! >= row.length
              ? ''
              : row[m.numberCol!],
          name: m.nameCol == null || m.nameCol! >= row.length
              ? ''
              : row[m.nameCol!],
          results: results,
        );
      }(),
  ];
}
