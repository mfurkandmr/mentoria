import '../../../core/constants/exam_subjects.dart';
import 'exam_definition.dart';
import 'exam_scorer.dart';
import 'optic_result_parser.dart';

/// Sınav paketi: optik makinesinin sabit sütunlu çıktısı, cevap anahtarı metni
/// ve soru-kazanım tablosu. Saf Dart; arayüzden ve Supabase'den bağımsız.

/// Paket okunamadı; [problems] kullanıcıya gösterilir (soru numaralarıyla).
class ExamPackageException implements Exception {
  const ExamPackageException(this.problems);

  final List<ExamPackageProblem> problems;

  @override
  String toString() => 'ExamPackageException($problems)';
}

enum ExamPackageProblemKind {
  /// Sınav türü anlaşılmadı ya da desteklenmiyor (şimdilik TYT).
  unsupportedType,

  /// Anahtarda bölüm listesi ders sınırlarıyla uyuşmuyor.
  sections,

  /// Anahtar uzunluğu soru sayısını tutmuyor.
  keyLength,

  /// Kazanım tablosundaki A cevabı anahtarla çelişiyor.
  answerConflict,

  /// B kitapçığı var ama soru yerleri eksik ya da tekrarlı.
  bookletMap,

  /// B anahtarı, eşlenen sorunun cevabıyla çelişiyor.
  bookletConflict,

  /// Optik satırının biçimi ötekilerden farklı.
  opticLine,
}

class ExamPackageProblem {
  const ExamPackageProblem(this.kind, [this.detail = '']);

  final ExamPackageProblemKind kind;
  final String detail;

  @override
  String toString() => '${kind.name}: $detail';
}

/// Cevap anahtarı dosyası.
class ParsedAnswerKey {
  const ParsedAnswerKey({
    required this.name,
    required this.takenOn,
    required this.sections,
    required this.booklets,
  });

  final String name;
  final DateTime? takenOn;

  /// (bölüm adı, ilk soru, son soru).
  final List<(String, int, int)> sections;

  /// Kitapçık → soru sırasıyla cevaplar.
  final Map<String, String> booklets;
}

/// Anahtar dosyası mı (içeriğe bakılır, dosya adına değil).
bool looksLikeAnswerKey(String text) =>
    RegExp(r'^\s*[A-D]\s+KITAP', multiLine: true).hasMatch(_ascii(text));

/// Kazanım tablosunun başlık satırı mı.
bool looksLikeOutcomeTable(List<List<String>> rows) =>
    rows.isNotEmpty &&
    rows.first.any((c) => c.trim().toLowerCase() == 'soru_no');

/// Türkçe harfleri sadeleştirir; KİTAPÇIĞI ve KITAPCIGI aynı okunur.
String _ascii(String s) => s
    .replaceAll('İ', 'I')
    .replaceAll('ı', 'i')
    .replaceAll('Ç', 'C')
    .replaceAll('ç', 'c')
    .replaceAll('Ğ', 'G')
    .replaceAll('ğ', 'g')
    .replaceAll('Ş', 'S')
    .replaceAll('ş', 's')
    .replaceAll('Ö', 'O')
    .replaceAll('ö', 'o')
    .replaceAll('Ü', 'U')
    .replaceAll('ü', 'u');

ParsedAnswerKey parseAnswerKey(String text) {
  final lines = text.split(RegExp(r'\r\n|\n|\r'));
  var name = '';
  DateTime? date;
  final sections = <(String, int, int)>[];
  final booklets = <String, String>{};
  final section = RegExp(r'^\s*(.+?)\s+(\d+)\s*-\s*(\d+)\s*(\(|$)');
  final bookletHead = RegExp(r'^\s*([A-D])\s+KITAP', caseSensitive: false);
  final dateCell = RegExp(r'(\d{1,2})[./](\d{1,2})[./](\d{4})');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final plain = _ascii(line).trim();
    final field = RegExp(r'^([A-Za-z]+)\s*:\s*(.*)$').firstMatch(plain);
    if (field != null) {
      final key = field.group(1)!.toUpperCase();
      final value = line.substring(line.indexOf(':') + 1).trim();
      if (key == 'SINAV') name = value;
      if (key == 'TARIH') {
        final m = dateCell.firstMatch(value);
        if (m != null) {
          date = DateTime(
            int.parse(m.group(3)!),
            int.parse(m.group(2)!),
            int.parse(m.group(1)!),
          );
        }
      }
      continue;
    }
    final head = bookletHead.firstMatch(plain);
    if (head != null) {
      var j = i + 1;
      while (j < lines.length && lines[j].trim().isEmpty) {
        j++;
      }
      if (j < lines.length) {
        booklets[head.group(1)!.toUpperCase()] = lines[j].trimRight();
      }
      i = j;
      continue;
    }
    final s = section.firstMatch(line);
    if (s != null) {
      sections.add((
        s.group(1)!.trim(),
        int.parse(s.group(2)!),
        int.parse(s.group(3)!),
      ));
    }
  }
  return ParsedAnswerKey(
    name: name,
    takenOn: date,
    sections: sections,
    booklets: booklets,
  );
}

/// Soru-kazanım tablosunun bir satırı (numaralar sınav geneli, 1'den).
class OutcomeTableRow {
  const OutcomeTableRow({
    required this.number,
    this.outcome,
    this.difficulty,
    this.answer,
    this.bookletBNumber,
  });

  final int number;
  final String? outcome;
  final Difficulty? difficulty;
  final String? answer;

  /// Bu sorunun B kitapçığındaki yeri.
  final int? bookletBNumber;
}

List<OutcomeTableRow> parseOutcomeTable(List<List<String>> rows) {
  if (rows.isEmpty) return const [];
  final header = [for (final c in rows.first) c.trim().toLowerCase()];
  int col(String name) => header.indexOf(name);
  String? cell(List<String> r, int i) {
    if (i < 0 || i >= r.length) return null;
    final v = r[i].trim();
    return v.isEmpty ? null : v;
  }

  final no = col('soru_no');
  final outcome = col('kazanim');
  final level = col('zorluk');
  final answer = col('a_cevap');
  final b = col('b_sorusunun_yeri');
  return [
    for (final r in rows.skip(1))
      if (int.tryParse(cell(r, no) ?? '') case final n?)
        OutcomeTableRow(
          number: n,
          outcome: cell(r, outcome),
          difficulty: switch (_ascii(cell(r, level) ?? '').toLowerCase()) {
            'kolay' => Difficulty.easy,
            'orta' => Difficulty.medium,
            'zor' => Difficulty.hard,
            _ => null,
          },
          answer: cell(r, answer)?.toUpperCase(),
          bookletBNumber: int.tryParse(cell(r, b) ?? ''),
        ),
  ];
}

/// Pakete göre kurulan sınav ve kitapçıkların fiziksel sırası.
class ExamPackage {
  const ExamPackage({required this.exam, required this.bookletOrders});

  final ExamDefinition exam;

  /// Kitapçık → cevap dizisinin yeniden dizilişi: i. eleman, ders sırasına
  /// göre i. işaretin kitapçıktaki yeri (1'den). A kitapçığında yoktur.
  ///
  /// Makine bir bölümün sorularını dersler arasında karıştırabilir (Sosyal'de
  /// Tarih sorusu Coğrafya sırasına düşer). Sistem kitapçığı ders içinde tuttuğu
  /// için her dersin soruları, kitapçıktaki sırasıyla bir araya getirilir.
  final Map<String, List<int>> bookletOrders;
}

/// (ders, ders içi numara) ↔ sınav geneli numara.
class _Layout {
  _Layout(this.subjects) {
    var start = 1;
    for (final s in subjects) {
      first[s.code] = start;
      start += s.questionCount;
    }
    total = start - 1;
  }

  final List<ExamSubject> subjects;
  final first = <String, int>{};
  late final int total;
}

/// Anahtar ve kazanım tablosundan sınav kurar; çelişki varsa hepsini birden
/// [ExamPackageException] ile bildirir.
ExamPackage buildExamPackage(
  ParsedAnswerKey key,
  List<OutcomeTableRow> table, {
  DateTime? fallbackDate,
}) {
  final type = RegExp(r'\b(TYT|AYT|YDT)\b').firstMatch(key.name)?.group(1);
  if (type != 'TYT') {
    throw ExamPackageException([
      ExamPackageProblem(ExamPackageProblemKind.unsupportedType, key.name),
    ]);
  }
  final layout = _Layout(subjectsFor(ExamType.tyt));
  final problems = <ExamPackageProblem>[];

  // Her ders tek bir bölümün içinde kalmalı.
  if (key.sections.isNotEmpty) {
    for (final s in layout.subjects) {
      final from = layout.first[s.code]!;
      final to = from + s.questionCount - 1;
      if (!key.sections.any((x) => x.$2 <= from && to <= x.$3)) {
        problems.add(
          ExamPackageProblem(
            ExamPackageProblemKind.sections,
            '${s.name} $from-$to',
          ),
        );
      }
    }
  }
  final keyA = key.booklets['A'] ?? '';
  for (final e in key.booklets.entries) {
    if (e.value.length != layout.total) {
      problems.add(
        ExamPackageProblem(
          ExamPackageProblemKind.keyLength,
          '${e.key}: ${e.value.length}/${layout.total}',
        ),
      );
    }
  }
  if (keyA.isEmpty) {
    problems.add(
      const ExamPackageProblem(ExamPackageProblemKind.keyLength, 'A: 0'),
    );
  }
  if (problems.isNotEmpty) throw ExamPackageException(problems);

  final byNumber = {for (final r in table) r.number: r};
  final conflicts = [
    for (final r in table)
      if (r.answer != null &&
          r.number >= 1 &&
          r.number <= layout.total &&
          r.answer != keyA[r.number - 1])
        r.number,
  ];
  if (conflicts.isNotEmpty) {
    problems.add(
      ExamPackageProblem(
        ExamPackageProblemKind.answerConflict,
        conflicts.join(', '),
      ),
    );
  }

  final questions = <KeyQuestion>[];
  for (final s in layout.subjects) {
    final from = layout.first[s.code]!;
    for (var n = 1; n <= s.questionCount; n++) {
      final g = from + n - 1;
      final mark = keyA[g - 1];
      final valid = 'ABCDE'.contains(mark);
      final row = byNumber[g];
      questions.add(
        KeyQuestion(
          subject: s.code,
          number: n,
          correct: valid ? mark : null,
          // Anahtarda boş bırakılan soru iptaldir.
          cancelled: !valid,
          outcome: row?.outcome,
          difficulty: row?.difficulty,
        ),
      );
    }
  }

  // B kitapçığı: yerler 1..toplam arası, tekrarsız; anahtar tutmalı.
  final booklets = <String, List<BookletQuestion>>{};
  final orders = <String, List<int>>{};
  final keyB = key.booklets['B'];
  if (keyB != null) {
    final positions = [
      for (var g = 1; g <= layout.total; g++) byNumber[g]?.bookletBNumber,
    ];
    final known = positions.whereType<int>().toSet();
    if (positions.any((p) => p == null) ||
        known.length != layout.total ||
        known.any((p) => p < 1 || p > layout.total)) {
      problems.add(const ExamPackageProblem(ExamPackageProblemKind.bookletMap));
    } else {
      final bad = [
        for (var g = 1; g <= layout.total; g++)
          if (keyB[positions[g - 1]! - 1] != keyA[g - 1]) g,
      ];
      if (bad.isNotEmpty) {
        problems.add(
          ExamPackageProblem(
            ExamPackageProblemKind.bookletConflict,
            bad.join(', '),
          ),
        );
      } else {
        final (list, order) = _bookletB(layout, positions.cast<int>());
        booklets['B'] = list;
        orders['B'] = order;
      }
    }
  }
  if (problems.isNotEmpty) throw ExamPackageException(problems);

  return ExamPackage(
    exam: ExamDefinition(
      name: key.name,
      examType: ExamType.tyt,
      takenOn: key.takenOn ?? fallbackDate ?? DateTime.now(),
      subjects: [
        for (final s in layout.subjects)
          ExamSubjectDef(code: s.code, questionCount: s.questionCount),
      ],
      questions: questions,
      booklets: booklets,
    ),
    bookletOrders: orders,
  );
}

(List<BookletQuestion>, List<int>) _bookletB(
  _Layout layout,
  List<int> positions,
) {
  final list = <BookletQuestion>[];
  final order = <int>[];
  for (final s in layout.subjects) {
    final from = layout.first[s.code]!;
    final items = [
      for (var n = 1; n <= s.questionCount; n++) (n, positions[from + n - 2]),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (i, item) in items.indexed) {
      list.add(
        BookletQuestion(subject: s.code, number: i + 1, itemNo: item.$1),
      );
      order.add(item.$2);
    }
  }
  return (list, order);
}

/// Kayıtlı sınavın B kitapçığı için fiziksel sıra (kazanım tablosundan).
Map<String, List<int>> bookletOrdersFromTable(
  ExamDefinition exam,
  List<OutcomeTableRow> table,
) {
  final layout = _Layout([
    for (final s in exam.subjects) subjectByCode(s.code),
  ]);
  final byNumber = {for (final r in table) r.number: r.bookletBNumber};
  final positions = [for (var g = 1; g <= layout.total; g++) byNumber[g]];
  if (positions.any((p) => p == null) ||
      positions.toSet().length != layout.total) {
    throw const ExamPackageException([
      ExamPackageProblem(ExamPackageProblemKind.bookletMap),
    ]);
  }
  return {'B': _bookletB(layout, positions.cast<int>()).$2};
}

/// Havuzdaki kazanımları sorulara bağlar (ad ve ders tutuyorsa).
ExamDefinition linkOutcomes(
  ExamDefinition exam,
  Iterable<LearningOutcome> pool,
) {
  final ids = {
    for (final o in pool)
      if (o.parentId == null) (o.subject, foldTr(o.name)): o.id,
  };
  return exam.copyWith(
    questions: [
      for (final q in exam.questions)
        switch (q.outcome == null
            ? null
            : ids[(q.subject, foldTr(q.outcome!))]) {
          final id? => q.copyWith(outcomeId: id),
          null => q,
        },
    ],
  );
}

/// Optik satırı.
class OpticLine {
  const OpticLine({
    required this.number,
    required this.name,
    required this.className,
    required this.booklet,
    required this.answers,
  });

  final String number;
  final String name;
  final String? className;

  /// Boşsa makine okuyamamış demektir.
  final String booklet;

  /// Kitapçık sırasıyla; boşluklar korunur.
  final String answers;
}

const _delimiters = [';', '\t', '|'];

/// Sabit sütunlu optik çıktısı mı: bütün satırlar eşit uzunlukta, numarayla
/// başlıyor, ayraç yok. Sondaki boşluklar cevaptır; satırlar kırpılmaz.
bool looksLikeFixedWidthOptic(String text) {
  final lines = _lines(text);
  if (lines.isEmpty) return false;
  return lines.every(
    (l) =>
        l.length == lines.first.length &&
        l.length >= 40 &&
        RegExp(r'^\d').hasMatch(l) &&
        !_delimiters.any(l.contains),
  );
}

List<String> _lines(String text) => [
  for (final l in text.split(RegExp(r'\r\n|\n|\r')))
    if (l.trim().isNotEmpty) l,
];

/// Satırın sonundaki [totalQuestions] karakter cevap, öncesindeki tek karakter
/// kitapçıktır; numara baştaki rakamlar, sınıf ad sütununun son parçası.
List<OpticLine> parseFixedWidthOptic(String text, int totalQuestions) {
  final classAtEnd = RegExp(
    r'\s+(\d{1,2}\s*[-/]?\s*[A-Za-zÇĞİÖŞÜçğıöşü]{0,3})\s*$',
  );
  final out = <OpticLine>[];
  final problems = <ExamPackageProblem>[];
  for (final (i, l) in _lines(text).indexed) {
    if (l.length < totalQuestions + 9) {
      problems.add(
        ExamPackageProblem(ExamPackageProblemKind.opticLine, '${i + 1}'),
      );
      continue;
    }
    final answers = l.substring(l.length - totalQuestions);
    final booklet = l[l.length - totalQuestions - 1].trim();
    final head = l.substring(0, l.length - totalQuestions - 1);
    final number = RegExp(r'^\d+').stringMatch(head) ?? '';
    final rest = head.substring(number.length);
    final cls = classAtEnd.firstMatch(rest);
    out.add(
      OpticLine(
        number: number,
        name: (cls == null ? rest : rest.substring(0, cls.start)).trim(),
        className: cls?.group(1)?.trim(),
        booklet: booklet.toUpperCase(),
        answers: answers,
      ),
    );
  }
  if (problems.isNotEmpty) throw ExamPackageException(problems);
  return out;
}

/// [answers] kitapçık sırasında; ders sırasına getirir.
String _ordered(String answers, List<int>? order) =>
    order == null ? answers : [for (final p in order) answers[p - 1]].join();

Map<String, List<String?>> _bySubject(String ordered, ExamDefinition exam) {
  final out = <String, List<String?>>{};
  var i = 0;
  for (final s in exam.subjects) {
    out[s.code] = [
      for (var k = 0; k < s.questionCount; k++)
        'ABCDE'.contains(ordered[i + k]) && ordered[i + k] != ' '
            ? ordered[i + k]
            : null,
    ];
    i += s.questionCount;
  }
  return out;
}

/// Kitapçığı boş satır için kararın en az bu kadar doğru farkıyla verilmesi
/// gerekir; yoksa satır uyarıyla A kalır, müdür dosyadan bakar.
const bookletGuessMargin = 10;

/// Sihirbaza gidecek tablo ve şablon.
class OpticImportRows {
  const OpticImportRows({
    required this.rows,
    required this.template,
    required this.guessedBooklets,
  });

  final List<List<String>> rows;
  final ImportTemplate template;

  /// Kitapçığı boş olup cevaplarından çıkarılanlar: (numara, ad, kitapçık,
  /// seçilen kitapçığın doğru sayısı, öbürünün doğru sayısı).
  final List<(String, String, String, int, int)> guessedBooklets;
}

/// Optik satırlarını sihirbazın beklediği tabloya çevirir.
OpticImportRows opticRowsFor(
  List<OpticLine> lines,
  ExamDefinition exam,
  Map<String, List<int>> orders,
) {
  const no = 'Öğrenci numarası';
  const name = 'Ad soyad';
  const cls = 'Sınıf';
  const booklet = 'Kitapçık';
  const answers = 'Cevaplar';
  final guessed = <(String, String, String, int, int)>[];

  int correctWith(OpticLine l, String b) {
    final marks = _bySubject(_ordered(l.answers, orders[b]), exam);
    try {
      return ExamScorer.score(
        marks,
        b,
        exam,
      ).responses.where((r) => r.result == ResponseResult.correct).length;
    } on NoBookletKeyException {
      return -1;
    }
  }

  final rows = <List<String>>[
    [no, name, cls, booklet, answers],
  ];
  for (final l in lines) {
    var b = l.booklet;
    if (b.isEmpty &&
        exam.bookletList.length > 1 &&
        l.answers.trim().isNotEmpty) {
      final scores = {for (final x in exam.bookletList) x: correctWith(l, x)};
      final ranked = scores.entries.toList()
        ..sort((x, y) => y.value.compareTo(x.value));
      if (ranked[0].value - ranked[1].value >= bookletGuessMargin) {
        b = ranked[0].key;
        guessed.add((l.number, l.name, b, ranked[0].value, ranked[1].value));
      }
    }
    rows.add([
      l.number,
      l.name,
      l.className ?? '',
      b,
      _ordered(l.answers, orders[b]),
    ]);
  }
  return OpticImportRows(
    rows: rows,
    template: ImportTemplate(
      studentNo: no,
      studentName: name,
      className: cls,
      booklet: booklet,
      columns: [
        AnswerColumn(
          column: answers,
          subjects: [for (final s in exam.subjects) s.code],
        ),
      ],
    ),
    guessedBooklets: guessed,
  );
}
