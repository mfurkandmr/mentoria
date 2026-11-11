import '../../../core/constants/exam_subjects.dart';
import 'exam_definition.dart';

/// Bir cevap sütunu: içindeki dersler sırayla (ör. "FEN" = Fizik + Kimya +
/// Biyoloji; her dersin soru sayısı kadar karakter).
class AnswerColumn {
  const AnswerColumn({required this.column, required this.subjects});

  /// Excel başlığı.
  final String column;
  final List<String> subjects;

  Map<String, Object?> toJson() => {'column': column, 'subjects': subjects};

  factory AnswerColumn.fromJson(Map<String, dynamic> j) => AnswerColumn(
    column: j['column'] as String,
    subjects: [for (final s in j['subjects'] as List) s as String],
  );
}

/// Optik okuyucu Excel'inin sütun eşleştirmesi. Kurum bunu adıyla saklar;
/// optik okuyucunun biçimi değişmediğinden sonraki sınavda yeniden kullanır.
class ImportTemplate {
  const ImportTemplate({
    this.id,
    this.name = '',
    required this.studentNo,
    this.studentName,
    this.className,
    this.booklet,
    this.columns = const [],
  });

  final String? id;
  final String name;
  final String studentNo;
  final String? studentName;
  final String? className;
  final String? booklet;
  final List<AnswerColumn> columns;

  /// Eşleştirilmiş dersler.
  Set<String> get subjects => {for (final c in columns) ...c.subjects};

  ImportTemplate copyWith({
    String? id,
    String? name,
    String? studentNo,
    String? studentName,
    bool clearName = false,
    String? className,
    bool clearClass = false,
    String? booklet,
    bool clearBooklet = false,
    List<AnswerColumn>? columns,
  }) => ImportTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    studentNo: studentNo ?? this.studentNo,
    studentName: clearName ? null : (studentName ?? this.studentName),
    className: clearClass ? null : (className ?? this.className),
    booklet: clearBooklet ? null : (booklet ?? this.booklet),
    columns: columns ?? this.columns,
  );

  Map<String, Object?> toJson() => {
    'student_no': studentNo,
    'name': studentName,
    'class': className,
    'booklet': booklet,
    'columns': [for (final c in columns) c.toJson()],
  };

  factory ImportTemplate.fromJson(
    Map<String, dynamic> j, {
    String? id,
    String name = '',
  }) => ImportTemplate(
    id: id,
    name: name,
    studentNo: j['student_no'] as String,
    studentName: j['name'] as String?,
    className: j['class'] as String?,
    booklet: j['booklet'] as String?,
    columns: [
      for (final c in (j['columns'] as List? ?? const []))
        AnswerColumn.fromJson(Map<String, dynamic>.from(c as Map)),
    ],
  );

  /// Şablondaki sütunların hepsi bu başlıklarda var mı.
  bool fits(List<String> headers) {
    final h = headers.toSet();
    return h.contains(studentNo) &&
        (studentName == null || h.contains(studentName)) &&
        (className == null || h.contains(className)) &&
        (booklet == null || h.contains(booklet)) &&
        columns.every((c) => h.contains(c.column));
  }
}

enum RowWarningKind {
  /// Cevap metni soru sayısından kısa; eksikler boş sayıldı.
  tooShort,

  /// Cevap metni soru sayısından uzun; fazlası kesildi.
  tooLong,

  /// A-E dışında karakter; boş sayıldı.
  invalidChar,

  /// Kitapçık boş; A (tek kitapçık) kullanıldı.
  bookletEmpty,

  /// Kitapçık tanınmadı ya da anahtarı yok; satır değerlendirilemez.
  bookletInvalid,

  /// Öğrenci numarası boş.
  noNumber,
}

class RowWarning {
  const RowWarning(this.kind, {this.column, this.detail});

  final RowWarningKind kind;
  final String? column;
  final String? detail;

  /// Satırı değerlendirmeye engel mi.
  bool get isError =>
      kind == RowWarningKind.bookletInvalid || kind == RowWarningKind.noNumber;
}

/// Excel'den okunmuş bir öğrenci satırı.
class ParsedStudentResult {
  const ParsedStudentResult({
    required this.row,
    required this.studentNo,
    required this.answers,
    required this.booklet,
    this.studentName,
    this.className,
    this.warnings = const [],
  });

  /// Excel'deki satır numarası (1'den, başlık dahil).
  final int row;
  final String studentNo;
  final String? studentName;
  final String? className;

  /// A / B / C / D; tanınmazsa `null` (satır hatalı).
  final String? booklet;

  /// Ders kodu → soru soru işaret (öğrencinin kitapçık sırasıyla, `null` boş).
  final Map<String, List<String?>> answers;
  final List<RowWarning> warnings;

  bool get hasError => warnings.any((w) => w.isError);
}

/// Optik okuyucu satırını ayrıştırır. Saf Dart; arayüzden ve Supabase'den
/// bağımsız.
class OpticResultParser {
  const OpticResultParser._();

  /// Boş sayılan işaretler (boş hücre ve `null` da boştur).
  static const blankMarks = {' ', '-', '*', '.', '_'};

  /// Tek karakteri normalleştirir: küçük harf → büyük, Türkçe ve tam genişlik
  /// harfler sadeleşir. A-E dışı `null` döner; boş işaret için `''`.
  static String? normalizeMark(String ch) {
    if (blankMarks.contains(ch) || ch.trim().isEmpty) return '';
    const map = {'ı': 'I', 'i': 'I', 'İ': 'I'};
    var c = map[ch] ?? ch.toUpperCase();
    // Tam genişlik Latin harfler (Ａ-Ｅ).
    final code = c.codeUnitAt(0);
    if (code >= 0xFF21 && code <= 0xFF25) {
      c = String.fromCharCode(code - 0xFF21 + 0x41);
    }
    return 'ABCDE'.contains(c) && c.length == 1 ? c : null;
  }

  /// Bir cevap metnini [expected] soruya böler. Kısaysa eksikler boş, uzunsa
  /// fazlası kesilir; geçersiz karakter boş sayılır. Uyarılar döner.
  static (List<String?>, List<RowWarning>) parseAnswers(
    String? raw,
    int expected, {
    String? column,
  }) {
    final text = raw ?? '';
    final chars = text.split('');
    final warnings = <RowWarning>[];
    if (chars.length < expected && text.isNotEmpty) {
      warnings.add(
        RowWarning(
          RowWarningKind.tooShort,
          column: column,
          detail: '${chars.length}/$expected',
        ),
      );
    } else if (chars.length > expected) {
      // Sondaki boşluklar (Excel dolgusu) uyarı sayılmaz.
      final extra = chars.sublist(expected).join();
      if (extra.trim().isNotEmpty) {
        warnings.add(
          RowWarning(
            RowWarningKind.tooLong,
            column: column,
            detail: '${chars.length}/$expected',
          ),
        );
      }
    }
    final out = <String?>[];
    final invalid = <String>{};
    for (var i = 0; i < expected; i++) {
      if (i >= chars.length) {
        out.add(null);
        continue;
      }
      final m = normalizeMark(chars[i]);
      if (m == null) {
        invalid.add(chars[i]);
        out.add(null);
      } else {
        out.add(m.isEmpty ? null : m);
      }
    }
    if (invalid.isNotEmpty) {
      warnings.add(
        RowWarning(
          RowWarningKind.invalidChar,
          column: column,
          detail: invalid.join(' '),
        ),
      );
    }
    return (out, warnings);
  }

  /// Kitapçık hücresi: boş / TEK → A; A-D (küçük harf, "A Kitapçığı" gibi
  /// yazımlar da); tanınmazsa `null`.
  static String? normalizeBooklet(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty || const {'-', '*', '.', '0'}.contains(t)) return 'A';
    final u = foldTr(t).toUpperCase();
    if (u == 'TEK') return 'A';
    final m = RegExp(r'^([A-D])\b').firstMatch(u);
    if (m != null) return m.group(1);
    if (RegExp(r'^[1-4]$').hasMatch(u)) return 'ABCD'[int.parse(u) - 1];
    return null;
  }

  /// [row]: başlık → hücre metni. [counts]: ders kodu → soru sayısı.
  /// [booklets]: sınavın kitapçıkları (anahtarı olmayan kitapçık hatalı).
  static ParsedStudentResult parse(
    Map<String, String?> row,
    ImportTemplate template,
    Map<String, int> counts, {
    int rowNumber = 0,
    List<String> booklets = const ['A'],
  }) {
    final warnings = <RowWarning>[];
    final number = (row[template.studentNo] ?? '').trim();
    if (number.isEmpty) warnings.add(const RowWarning(RowWarningKind.noNumber));

    String? booklet = 'A';
    if (template.booklet != null) {
      final raw = row[template.booklet];
      booklet = normalizeBooklet(raw);
      if (booklet == null || !booklets.contains(booklet)) {
        warnings.add(
          RowWarning(RowWarningKind.bookletInvalid, detail: raw?.trim()),
        );
        booklet = null;
      } else if ((raw ?? '').trim().isEmpty && booklets.length > 1) {
        warnings.add(const RowWarning(RowWarningKind.bookletEmpty));
      }
    }

    final answers = <String, List<String?>>{};
    for (final col in template.columns) {
      final subjects = [
        for (final s in col.subjects)
          if (counts.containsKey(s)) s,
      ];
      if (subjects.isEmpty) continue;
      final total = subjects.fold<int>(0, (a, s) => a + counts[s]!);
      final (marks, w) = parseAnswers(
        row[col.column],
        total,
        column: col.column,
      );
      warnings.addAll(w);
      var i = 0;
      for (final s in subjects) {
        answers[s] = marks.sublist(i, i + counts[s]!);
        i += counts[s]!;
      }
    }

    String? cell(String? col) {
      if (col == null) return null;
      final v = row[col]?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return ParsedStudentResult(
      row: rowNumber,
      studentNo: number,
      studentName: cell(template.studentName),
      className: cell(template.className),
      booklet: booklet,
      answers: answers,
      warnings: warnings,
    );
  }

  /// Başlıklara bakıp eşleştirme önerir. Ders sütunları, sınavın dersleri
  /// adlarından (Türkçe, Matematik, Fen, Sosyal…) tahmin edilir.
  static ImportTemplate guess(List<String> headers, List<String> subjects) {
    String? find(bool Function(String h) test) {
      for (final h in headers) {
        if (test(foldTr(h).replaceAll(RegExp(r'[^a-z0-9]'), ' '))) return h;
      }
      return null;
    }

    bool has(String h, List<String> words) => words.any(h.contains);

    final number =
        find((h) => has(h, ['ogrenci no', 'ogr no', 'numara', 'okul no'])) ??
        find((h) => RegExp(r'(^| )no( |$)').hasMatch(h)) ??
        headers.first;
    final name = find(
      (h) =>
          has(h, ['ad soyad', 'adi soyadi', 'adsoyad', 'isim', 'ogrenci adi']),
    );
    final cls = find((h) => has(h, ['sinif', 'sube']));
    final booklet = find((h) => has(h, ['kitapcik', 'kitap', 'grup']));

    // Uzun adlar kelime başında, üç harfli kısaltmalar tam kelime olarak
    // (sonunda rakam olabilir: "SOS1") aranır; "Kimlik No" Kimya sayılmaz.
    const keywords = <String, List<String>>{
      'TUR': ['turkce', 'turk', 'tur'],
      'MAT': ['matematik', 'mat'],
      'FEN': ['fen'],
      'SOS': ['sosyal', 'sos'],
      'FIZ': ['fizik', 'fiz'],
      'KIM': ['kimya', 'kim'],
      'BIY': ['biyoloji', 'biy'],
      'EDB': ['edebiyat', 'edb', 'tde'],
      'TAR': ['tarih', 'tar'],
      'COG': ['cografya', 'cog'],
      'FEL': ['felsefe', 'fel'],
      'DIN': ['din'],
      'YD': ['ingilizce', 'yabanci', 'dil', 'ydt', 'ing'],
    };
    const groups = {'FEN', 'SOS'};

    /// [digit]: başlıktaki test numarası ("Tarih-2", "Sosyal 1"); yalnızca
    /// numaralı dersi olan sınavda (AYT) ayırt eder.
    List<String> groupOf(String key, String? digit) {
      bool ends(String s, List<String> xs) => xs.any((x) => s.endsWith('_$x'));
      final all = [
        for (final s in subjects)
          if (switch (key) {
            'FEN' => ends(s, const ['FIZ', 'KIM', 'BIY']),
            'SOS' => ends(s, const [
              'TAR',
              'COG',
              'FEL',
              'DIN',
              'TAR1',
              'COG1',
              'TAR2',
              'COG2',
              'FELG',
            ]),
            _ => s.split('_').last.startsWith(key),
          })
            s,
      ];
      if (digit == null || !all.any((s) => RegExp(r'\d$').hasMatch(s))) {
        return all;
      }
      // AYT: Sosyal-1 = Tarih-1 + Coğrafya-1; Sosyal-2 = geri kalanı.
      if (key == 'SOS') {
        return [
          for (final s in all)
            if (s.endsWith('1') == (digit == '1')) s,
        ];
      }
      final narrowed = [
        for (final s in all)
          if (s.endsWith(digit)) s,
      ];
      return narrowed.isEmpty ? all : narrowed;
    }

    final used = <String>{number, ?name, ?cls, ?booklet};
    final columns = <AnswerColumn>[];
    final taken = <String>{};
    int? social1;
    for (final h in headers) {
      if (used.contains(h)) continue;
      final f = foldTr(h).replaceAll(RegExp(r'[^a-z0-9]'), ' ');
      // Başlıkta geçen dersler, geçtikleri sırayla ("Edebiyat-Sosyal 1").
      final hits = <(int, String)>[];
      for (final e in keywords.entries) {
        int? at;
        for (final w in e.value) {
          final m = RegExp(
            w.length <= 3 ? '(^| )$w[0-9]*( |\$)' : '(^| )$w',
          ).firstMatch(f);
          if (m != null && (at == null || m.start < at)) at = m.start;
        }
        if (at != null) hits.add((at, e.key));
      }
      hits.sort((a, b) => a.$1 - b.$1);
      final group = <String>[];
      for (final (i, hit) in hits.indexed) {
        final end = i + 1 < hits.length ? hits[i + 1].$1 : f.length;
        final digit = RegExp(
          r'(?<![0-9])[12](?![0-9])',
        ).firstMatch(f.substring(hit.$1, end))?.group(0);
        final found = [
          for (final s in groupOf(hit.$2, digit))
            if (!taken.contains(s) && !group.contains(s)) s,
        ];
        // Tek ders başlığı tek derse gider ("Tarih" → önce Tarih-1).
        group.addAll(groups.contains(hit.$2) ? found : found.take(1));
        if (hit.$2 == 'SOS' && digit == '1' && found.isNotEmpty) {
          social1 = columns.length;
        }
      }
      if (group.isEmpty) continue;
      columns.add(AnswerColumn(column: h, subjects: group));
      taken.addAll(group);
    }
    // AYT'nin ilk testi Türk Dili ve Edebiyatı-Sosyal Bilimler-1'dir: yalnızca
    // "Sosyal 1" yazan sütunun başında Edebiyat vardır.
    final literature = [
      for (final s in subjects)
        if (s.endsWith('_EDB') && !taken.contains(s)) s,
    ];
    if (social1 != null && literature.isNotEmpty) {
      final c = columns[social1];
      columns[social1] = AnswerColumn(
        column: c.column,
        subjects: [...literature, ...c.subjects],
      );
    }
    return ImportTemplate(
      studentNo: number,
      studentName: name,
      className: cls,
      booklet: booklet,
      columns: columns,
    );
  }
}

/// Bir sınav türünün dersleri (ExamSubject sırasıyla).
List<String> subjectCodesOf(ExamType type) => [
  for (final s in examSubjects)
    if (s.examType == type) s.code,
];
