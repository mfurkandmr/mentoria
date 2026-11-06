import 'exam_definition.dart';
import 'exam_scorer.dart';
import 'optic_result_parser.dart';

/// Kurumun öğrencisi (numara eşleştirmesi için).
class RosterStudent {
  const RosterStudent({
    required this.id,
    required this.name,
    this.number,
    this.className,
  });

  final String id;
  final String name;
  final String? number;
  final String? className;
}

enum MatchStatus {
  /// Numara ve ad tutuyor.
  matched,

  /// Numara tuttu, ad tutmuyor: kullanıcı onaylamalı.
  nameMismatch,

  /// Numara kurumda yok: elle eşleştir ya da atla.
  unmatched,

  /// Satır değerlendirilemiyor (numara boş, kitapçık tanınmadı, numara
  /// dosyada ikinci kez geçiyor).
  error,
}

class ImportRowPlan {
  const ImportRowPlan({
    required this.parsed,
    required this.status,
    this.student,
    this.score,
    this.duplicate = false,
  });

  final ParsedStudentResult parsed;
  final MatchStatus status;
  final RosterStudent? student;

  /// Önizleme puanı (sunucu yayında yeniden hesaplar).
  final ScoredResult? score;

  /// Aynı numara dosyada daha önce geçti.
  final bool duplicate;

  ImportRowPlan withStudent(RosterStudent s) => ImportRowPlan(
    parsed: parsed,
    status: MatchStatus.matched,
    student: s,
    score: score,
  );
}

/// İçe aktarma girdisi (isolate'e gönderilir).
class ImportInput {
  const ImportInput({
    required this.rows,
    required this.template,
    required this.exam,
    required this.roster,
  });

  /// Sayfa satırları; ilk dolu satır başlık.
  final List<List<String>> rows;
  final ImportTemplate template;
  final ExamDefinition exam;
  final List<RosterStudent> roster;
}

class ImportPlan {
  const ImportPlan({required this.headers, required this.rows});

  final List<String> headers;
  final List<ImportRowPlan> rows;

  int count(MatchStatus s) => rows.where((r) => r.status == s).length;
  int get matched => count(MatchStatus.matched);
  int get unmatched => count(MatchStatus.unmatched);
  int get failed => count(MatchStatus.error);
  int get mismatched => count(MatchStatus.nameMismatch);

  /// Uzunluk / karakter uyarısı olan satırlar.
  List<ImportRowPlan> get warned => [
    for (final r in rows)
      if (r.parsed.warnings.any((w) => !w.isError)) r,
  ];
}

/// Başlık satırı: en az iki dolu hücresi olan ilk satır.
int headerRowOf(List<List<String>> rows) {
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].where((c) => c.trim().isNotEmpty).length >= 2) return i;
  }
  return 0;
}

/// Başlıklar (boş başlık "Sütun 3" olur, tekrar eden "AD (2)").
List<String> headersOf(List<List<String>> rows) {
  if (rows.isEmpty) return const [];
  final raw = rows[headerRowOf(rows)];
  final seen = <String, int>{};
  return [
    for (var i = 0; i < raw.length; i++)
      () {
        final h = raw[i].trim().isEmpty ? 'Sütun ${i + 1}' : raw[i].trim();
        final n = (seen[h] ?? 0) + 1;
        seen[h] = n;
        return n == 1 ? h : '$h ($n)';
      }(),
  ];
}

/// Numara karşılaştırması: boşluksuz, büyük harf, baştaki sıfırlar atılır.
String normalizeStudentNo(String s) => s
    .trim()
    .toUpperCase()
    .replaceAll(RegExp(r'\s+'), '')
    .replaceFirst(RegExp(r'\.0+$'), '')
    .replaceFirst(RegExp(r'^0+(?=.)'), '');

/// Ad soyad tutuyor mu: ortak kelime sayısı, kısa olanın kelime sayısına
/// (en çok 2) yetiyor mu. Türkçe harf ve büyük/küçük harf farkı gözetilmez.
bool namesMatch(String a, String b) {
  Set<String> words(String s) => foldTr(s)
      .replaceAll(RegExp(r'[^a-z ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length >= 2)
      .toSet();
  final x = words(a);
  final y = words(b);
  if (x.isEmpty || y.isEmpty) return true;
  final need = [x.length, y.length, 2].reduce((m, v) => v < m ? v : m);
  return x.intersection(y).length >= need;
}

/// Dosyayı okur, öğrencileri eşleştirir, önizleme puanını hesaplar.
/// Saf Dart; büyük dosyada `compute` ile isolate'te çalışır.
ImportPlan prepareImport(ImportInput input) {
  final rows = input.rows;
  if (rows.isEmpty) return const ImportPlan(headers: [], rows: []);
  final headerIndex = headerRowOf(rows);
  final headers = headersOf(rows);
  final counts = {for (final s in input.exam.subjects) s.code: s.questionCount};
  final byNumber = <String, RosterStudent>{
    for (final s in input.roster)
      if (s.number != null && s.number!.trim().isNotEmpty)
        normalizeStudentNo(s.number!): s,
  };
  final seen = <String>{};
  final plans = <ImportRowPlan>[];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final cells = rows[i];
    if (cells.every((c) => c.trim().isEmpty)) continue;
    final row = <String, String?>{
      for (var c = 0; c < headers.length; c++)
        headers[c]: c < cells.length ? cells[c] : null,
    };
    final parsed = OpticResultParser.parse(
      row,
      input.template,
      counts,
      rowNumber: i + 1,
      booklets: input.exam.bookletList,
    );
    final key = normalizeStudentNo(parsed.studentNo);
    final duplicate = key.isNotEmpty && !seen.add(key);
    if (parsed.hasError || duplicate) {
      plans.add(
        ImportRowPlan(
          parsed: parsed,
          status: MatchStatus.error,
          duplicate: duplicate,
        ),
      );
      continue;
    }
    ScoredResult? score;
    try {
      score = ExamScorer.score(parsed.answers, parsed.booklet!, input.exam);
    } on NoBookletKeyException {
      score = null;
    }
    final student = byNumber[key];
    final status = student == null
        ? MatchStatus.unmatched
        : (parsed.studentName == null ||
              namesMatch(parsed.studentName!, student.name))
        ? MatchStatus.matched
        : MatchStatus.nameMismatch;
    plans.add(
      ImportRowPlan(
        parsed: parsed,
        status: status,
        student: student,
        score: score,
      ),
    );
  }
  return ImportPlan(headers: headers, rows: plans);
}
