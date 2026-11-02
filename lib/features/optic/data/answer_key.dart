import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../import/data/exam_file_parser.dart';
import '../../tracking/data/tracking_models.dart';

/// Cevap anahtarında bir soru: doğru cevap ve kazanım.
class KeyItem {
  const KeyItem({
    required this.subject,
    required this.number,
    this.numberB,
    this.correct,
    this.outcome,
    this.topicId,
  });

  /// Ders kodu (`TYT_MAT`).
  final String subject;

  /// Dersin içindeki soru numarası (1'den), A kitapçığında.
  final int number;

  /// Aynı sorunun B kitapçığındaki numarası (anahtarın B'si yoksa `null`).
  final int? numberB;

  /// [booklet] kitapçığında bu sorunun numarası.
  int? numberIn(String booklet) => booklet == 'B' ? numberB : number;

  /// A–E; `null` iptal edilen soru (değerlendirilmez).
  final String? correct;
  final String? outcome;

  /// Kazanımın bağlandığı müfredat konusu (konu takibine yazılır).
  final int? topicId;

  KeyItem withTopic(int? id) => KeyItem(
    subject: subject,
    number: number,
    numberB: numberB,
    correct: correct,
    outcome: outcome,
    topicId: id,
  );

  Map<String, Object?> toJson() => {
    'subject': subject,
    'no': number,
    'no_b': numberB,
    'correct': correct,
    'outcome': outcome,
    'topic_id': topicId,
  };
}

/// Kayıtlı cevap anahtarı (deneme).
class AnswerKey {
  const AnswerKey({
    required this.id,
    required this.name,
    required this.examType,
    required this.takenOn,
    required this.templateId,
    required this.createdAt,
    this.publisher,
    this.createdBy,
    this.items = const [],
    this.readCount = 0,
  });

  final String id;
  final String name;
  final ExamType examType;
  final String? publisher;
  final DateTime takenOn;
  final String templateId;
  final DateTime createdAt;
  final String? createdBy;
  final List<KeyItem> items;

  /// Okunmuş optik (öğrenci) sayısı.
  final int readCount;

  /// B kitapçığı okunabilir mi (değerlendirilen her sorunun B numarası var).
  bool get hasBookletB =>
      items.isNotEmpty &&
      items.where((i) => i.correct != null).every((i) => i.numberB != null);
}

/// Bir optiğin değerlendirmesi (sunucudaki `submit_optic` ile aynı kural).
class OpticScore {
  const OpticScore({
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.bySubject,
    required this.mistakes,
  });

  final int correct;
  final int wrong;
  final int blank;
  final Map<String, ({int correct, int wrong, int blank})> bySubject;

  /// Yanlış ya da boş bırakılan sorular (iptaller hariç).
  final List<({KeyItem item, String? marked})> mistakes;

  double get net => calculateNet(correct, wrong);
}

/// [answers]'ı anahtara göre değerlendirir. [answers] öğrencinin
/// [booklet] kitapçığındaki sırayla işaretlerdir. İptal sorular sayılmaz;
/// AYT ve YDT'de hiç işaret konmayan testler (alan dışı) de sayılmaz.
OpticScore scoreOptic(
  List<KeyItem> items,
  Map<String, List<String?>> answers,
  ExamType type, {
  String booklet = 'A',
}) {
  bool touched(String code) =>
      answers[code]?.any((m) => m != null && 'ABCDE'.contains(m)) ?? false;
  final bySubject = <String, ({int correct, int wrong, int blank})>{};
  final mistakes = <({KeyItem item, String? marked})>[];
  var c = 0, w = 0, b = 0;
  for (final item in items) {
    if (item.correct == null) continue;
    if (type != ExamType.tyt && !touched(item.subject)) continue;
    final no = item.numberIn(booklet);
    final raw = no == null
        ? null
        : answers[item.subject]?.elementAtOrNull(no - 1);
    final marked = raw != null && 'ABCDE'.contains(raw) ? raw : null;
    final s = bySubject[item.subject] ?? (correct: 0, wrong: 0, blank: 0);
    if (marked == item.correct) {
      c++;
      bySubject[item.subject] = (
        correct: s.correct + 1,
        wrong: s.wrong,
        blank: s.blank,
      );
    } else {
      if (marked == null) {
        b++;
        bySubject[item.subject] = (
          correct: s.correct,
          wrong: s.wrong,
          blank: s.blank + 1,
        );
      } else {
        w++;
        bySubject[item.subject] = (
          correct: s.correct,
          wrong: s.wrong + 1,
          blank: s.blank,
        );
      }
      mistakes.add((item: item, marked: marked));
    }
  }
  return OpticScore(
    correct: c,
    wrong: w,
    blank: b,
    bySubject: bySubject,
    mistakes: mistakes,
  );
}

/// Cevap anahtarı dosyasının okunma sonucu.
class ParsedKey {
  const ParsedKey(this.items, this.skipped);

  final List<KeyItem> items;

  /// Okunamayan satırlar ("Satır 14: ders tanınmadı").
  final List<String> skipped;
}

class AnswerKeyFormatException implements Exception {
  const AnswerKeyFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Testin adı → içindeki dersler (optik ve kazanım tablolarında sorular
/// test içinde baştan sona numaralanır: Sosyal 1–20 = Tarih 1–5, Coğrafya
/// 6–10…).
const _sections = <ExamType, Map<String, List<String>>>{
  ExamType.tyt: {
    'turkce': ['TYT_TUR'],
    'sosyal': ['TYT_TAR', 'TYT_COG', 'TYT_FEL', 'TYT_DIN'],
    'sosyalbilimler': ['TYT_TAR', 'TYT_COG', 'TYT_FEL', 'TYT_DIN'],
    'temelmatematik': ['TYT_MAT'],
    'matematik': ['TYT_MAT'],
    'fen': ['TYT_FIZ', 'TYT_KIM', 'TYT_BIY'],
    'fenbilimleri': ['TYT_FIZ', 'TYT_KIM', 'TYT_BIY'],
  },
  ExamType.ayt: {
    'turkdiliveedebiyatisosyalbilimler1': ['AYT_EDB', 'AYT_TAR1', 'AYT_COG1'],
    'edebiyatsosyalbilimler1': ['AYT_EDB', 'AYT_TAR1', 'AYT_COG1'],
    'sosyalbilimler1': ['AYT_EDB', 'AYT_TAR1', 'AYT_COG1'],
    'sosyal1': ['AYT_EDB', 'AYT_TAR1', 'AYT_COG1'],
    'sosyalbilimler2': ['AYT_TAR2', 'AYT_COG2', 'AYT_FELG', 'AYT_DIN'],
    'sosyal2': ['AYT_TAR2', 'AYT_COG2', 'AYT_FELG', 'AYT_DIN'],
    'matematik': ['AYT_MAT'],
    'fen': ['AYT_FIZ', 'AYT_KIM', 'AYT_BIY'],
    'fenbilimleri': ['AYT_FIZ', 'AYT_KIM', 'AYT_BIY'],
  },
  ExamType.ydt: {
    'yabancidil': ['YDT_YD'],
  },
};

/// Bir testin [no]. sorusu → (ders, ders içi no).
({String subject, int number})? _inSection(List<String> codes, int no) {
  var n = no;
  for (final code in codes) {
    final count = subjectByCode(code).questionCount;
    if (n <= count) return (subject: code, number: n);
    n -= count;
  }
  return null;
}

/// Ders adı tek bir derse ya da bir teste karşılık gelir; soru no ders içi
/// ya da test içi olabilir ("Coğrafya 6" = Sosyal testinin 6. sorusu =
/// Coğrafya 1).
({String subject, int number})? _resolve(String label, int no, ExamType type) {
  final key = normalize(
    label,
  ).replaceAll(' ', '').replaceFirst(RegExp(r'^(tyt|ayt|ydt)'), '');
  final code = matchSubject(label, type);
  if (code != null) {
    final count = subjectByCode(code).questionCount;
    if (no >= 1 && no <= count) return (subject: code, number: no);
    // Test içi numara: dersin testteki yerine göre kaydır.
    for (final codes in _sections[type]!.values) {
      final i = codes.indexOf(code);
      if (i < 0) continue;
      final offset = codes
          .take(i)
          .fold(0, (n, c) => n + subjectByCode(c).questionCount);
      final local = no - offset;
      if (local >= 1 && local <= count) return (subject: code, number: local);
    }
    return null;
  }
  final codes =
      _sections[type]![key] ?? _sections[type]![key.replaceAll('testi', '')];
  if (codes == null || no < 1) return null;
  return _inSection(codes, no);
}

String? _letter(String v) {
  final t = normalize(v).replaceAll(' ', '').toUpperCase();
  return t.length == 1 && 'ABCDE'.contains(t) ? t : null;
}

/// Kazanım / cevap anahtarı tablosunu okur. Beklenen sütunlar (sıra ve
/// yazım serbest): Ders (ya da Test), Soru No, Cevap, Kazanım (ya da Konu)
/// ve isteğe bağlı "B Soru No" (sorunun B kitapçığındaki yeri; numaralama
/// A'daki gibi ders içi ya da test içi). Ders hücresi boşsa üstteki
/// satırın dersi geçerlidir (birleştirilmiş hücre).
ParsedKey parseAnswerKey(SheetRows rows, ExamType type) {
  int? subjectCol, numberCol, answerCol, outcomeCol, bCol;
  var headerRow = -1;
  for (var r = 0; r < rows.length && r < 15; r++) {
    int? s, n, a, o, b;
    for (var c = 0; c < rows[r].length; c++) {
      final h = normalize(rows[r][c]);
      if (h.isEmpty) continue;
      final w = h.split(' ');
      if (a == null &&
          (w.contains('cevap') ||
              w.contains('anahtar') ||
              w.contains('yanit') ||
              h == 'dogru cevap')) {
        a = c;
      } else if (o == null &&
          (w.contains('kazanim') ||
              w.contains('kazanimlar') ||
              w.contains('konu') ||
              w.contains('konusu'))) {
        o = c;
      } else if (b == null &&
          w.contains('b') &&
          (w.contains('soru') ||
              w.contains('no') ||
              w.contains('kitapcik') ||
              w.contains('kitapcigi'))) {
        b = c;
      } else if (n == null &&
          (w.contains('soru') || w.contains('no') || w.contains('sira'))) {
        n = c;
      } else if (s == null &&
          (w.contains('ders') ||
              w.contains('test') ||
              w.contains('bolum') ||
              w.contains('alan'))) {
        s = c;
      }
    }
    if (n != null && a != null && s != null) {
      (subjectCol, numberCol, answerCol, outcomeCol, bCol) = (s, n, a, o, b);
      headerRow = r;
      break;
    }
  }
  if (headerRow < 0) {
    throw AnswerKeyFormatException(
      tr(
        'Başlık satırı bulunamadı. Tabloda "Ders", "Soru No" ve "Cevap" sütunları olmalı.',
      ),
    );
  }

  String cell(List<String> row, int? c) =>
      c == null || c >= row.length ? '' : row[c].trim();

  final items = <String, KeyItem>{};
  final skipped = <String>[];
  var lastSubject = '';
  for (var r = headerRow + 1; r < rows.length; r++) {
    final row = rows[r];
    final label = cell(row, subjectCol);
    if (label.isNotEmpty) lastSubject = label;
    final noText = cell(row, numberCol);
    if (noText.isEmpty && cell(row, answerCol).isEmpty) continue;
    final no = int.tryParse(noText.replaceAll(RegExp(r'[^0-9]'), ''));
    final at = no == null ? null : _resolve(lastSubject, no, type);
    if (at == null) {
      skipped.add(
        tr('Satır {n}: {label} {no}', {
          'n': r + 1,
          'label': lastSubject,
          'no': noText,
        }),
      );
      continue;
    }
    final outcome = cell(row, outcomeCol);
    // B numarası aynı derse düşmeli; düşmüyorsa satır B'siz kalır.
    final noB = int.tryParse(cell(row, bCol).replaceAll(RegExp(r'[^0-9]'), ''));
    final atB = noB == null ? null : _resolve(lastSubject, noB, type);
    items['${at.subject}#${at.number}'] = KeyItem(
      subject: at.subject,
      number: at.number,
      numberB: atB?.subject == at.subject ? atB!.number : null,
      correct: _letter(cell(row, answerCol)),
      outcome: outcome.isEmpty ? null : outcome,
    );
  }
  if (items.isEmpty) {
    throw AnswerKeyFormatException(
      tr('Tabloda {type} sorusu bulunamadı. Sınav türünü kontrol et.', {
        'type': type.label,
      }),
    );
  }
  // Aynı derste iki soruya verilmiş B numarası: ikisinin de B'si yok sayılır.
  final seenB = <String, int>{};
  for (final i in items.values) {
    if (i.numberB != null) {
      final k = '${i.subject}#${i.numberB}';
      seenB[k] = (seenB[k] ?? 0) + 1;
    }
  }
  for (final e in items.entries.toList()) {
    final i = e.value;
    if (i.numberB != null && seenB['${i.subject}#${i.numberB}']! > 1) {
      skipped.add(
        tr('{subject} {n}: B numarası tekrar ediyor', {
          'subject': subjectByCode(i.subject).name,
          'n': i.number,
        }),
      );
      items[e.key] = KeyItem(
        subject: i.subject,
        number: i.number,
        correct: i.correct,
        outcome: i.outcome,
      );
    }
  }
  final list = items.values.toList()
    ..sort((a, b) {
      final s =
          examSubjects.indexWhere((x) => x.code == a.subject) -
          examSubjects.indexWhere((x) => x.code == b.subject);
      return s != 0 ? s : a.number - b.number;
    });
  return ParsedKey(list, skipped);
}

/// Kazanım metnini aynı dersin müfredat konularından birine bağlar:
/// konu adı kazanımın içinde geçiyorsa (ya da tersi) en uzun eşleşen konu.
int? matchTopic(String? outcome, String subject, List<Topic> topics) {
  if (outcome == null) return null;
  final o = normalize(outcome);
  if (o.isEmpty) return null;
  Topic? best;
  for (final t in topics.where((t) => t.subjectCode == subject)) {
    final n = normalize(t.name);
    if (n.length < 3) continue;
    if (o.contains(n) || n.contains(o)) {
      if (best == null || n.length > normalize(best.name).length) best = t;
    }
  }
  return best?.id;
}
