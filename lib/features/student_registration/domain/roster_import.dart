// Kurumun öğrenci listesi (Excel / CSV) içe aktarma: sütun eşleştirme,
// doğrulama ve önizleme. Saf Dart; büyük dosyada isolate'te çalışır.

/// Listedeki sütunlar.
enum RosterColumn { number, name, surname, className, phone }

/// Satır sorunu. [blocking] olanlar satırı içe aktarmaz.
enum RowProblem {
  missingNumber(true),
  badNumber(true),
  missingName(true),
  duplicateInFile(true),
  badPhone(false);

  const RowProblem(this.blocking);

  final bool blocking;
}

class RosterRow {
  const RosterRow({
    required this.line,
    required this.number,
    required this.name,
    this.className,
    this.phone,
    this.rawPhone,
    this.problems = const [],
  });

  /// Dosyadaki satır numarası (1'den).
  final int line;
  final String number;
  final String name;
  final String? className;

  /// "+905XXXXXXXXX" (geçersizse null, [rawPhone] yazılanı tutar).
  final String? phone;
  final String? rawPhone;
  final List<RowProblem> problems;

  bool get ok => !problems.any((p) => p.blocking);

  RosterRow copyWith({String? number, String? name}) => RosterRow(
    line: line,
    number: number ?? this.number,
    name: name ?? this.name,
    className: className,
    phone: phone,
    rawPhone: rawPhone,
  );
}

class RosterReport {
  const RosterReport(this.rows);

  final List<RosterRow> rows;

  int get total => rows.length;
  List<RosterRow> get valid => [
    for (final r in rows)
      if (r.ok) r,
  ];
  List<RosterRow> get invalid => [
    for (final r in rows)
      if (!r.ok) r,
  ];
  int count(RowProblem p) => rows.where((r) => r.problems.contains(p)).length;
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('İ', 'i')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ş', 's')
    .replaceAll('ç', 'c')
    .replaceAll('ğ', 'g')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Başlık satırından sütunları tahmin eder ("Öğrenci No", "Ad Soyad",
/// "Sınıf", "Veli Tel" …). Bulunamayan sütun eşlemede yer almaz.
Map<RosterColumn, int> guessColumns(List<String> header) {
  final out = <RosterColumn, int>{};
  for (var i = 0; i < header.length; i++) {
    final h = _norm(header[i]);
    if (h.isEmpty) continue;
    RosterColumn? c;
    if (h.contains('veli') ||
        h.contains('tel') ||
        h.contains('gsm') ||
        h.contains('cep')) {
      c = RosterColumn.phone;
    } else if (h.contains('no') ||
        h.contains('numara') ||
        h == 'okulno' ||
        h.contains('number')) {
      c = RosterColumn.number;
    } else if (h.contains('sinif') ||
        h.contains('sube') ||
        h.contains('class') ||
        h.contains('grup')) {
      c = RosterColumn.className;
    } else if (h.contains('adsoyad') ||
        h.contains('adisoyad') ||
        h.contains('fullname')) {
      c = RosterColumn.name;
    } else if (h.contains('soyad') || h.contains('surname')) {
      c = RosterColumn.surname;
    } else if (h.contains('ad') || h.contains('isim') || h.contains('name')) {
      c = RosterColumn.name;
    }
    if (c != null) out.putIfAbsent(c, () => i);
  }
  return out;
}

/// Türkiye cep telefonu → "+905XXXXXXXXX"; geçersizse null.
String? normalizeRosterPhone(String text) {
  var d = text.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('90') && d.length == 12) d = d.substring(2);
  if (d.startsWith('0') && d.length == 11) d = d.substring(1);
  return RegExp(r'^5\d{9}$').hasMatch(d) ? '+90$d' : null;
}

/// Hücredeki numara: boşluk ve Excel'in ".0" eki temizlenir.
String cleanNumber(String s) {
  var t = s.trim().replaceAll(RegExp(r'\s'), '');
  if (RegExp(r'^\d+\.0+$').hasMatch(t)) t = t.split('.').first;
  return t;
}

/// [rows]: dosyanın satırları; [headerRow] başlık satırı (atlanır).
RosterReport parseRoster(
  List<List<String>> rows,
  Map<RosterColumn, int> columns, {
  int headerRow = 0,
}) {
  String cell(List<String> r, RosterColumn c) {
    final i = columns[c];
    return i == null || i >= r.length ? '' : r[i].trim();
  }

  final parsed = <RosterRow>[];
  for (var i = headerRow + 1; i < rows.length; i++) {
    final r = rows[i];
    if (r.every((c) => c.trim().isEmpty)) continue;
    final number = cleanNumber(cell(r, RosterColumn.number));
    final name = [
      cell(r, RosterColumn.name),
      cell(r, RosterColumn.surname),
    ].where((s) => s.isNotEmpty).join(' ').replaceAll(RegExp(r'\s+'), ' ');
    final klass = cell(r, RosterColumn.className);
    final rawPhone = cell(r, RosterColumn.phone);
    final phone = rawPhone.isEmpty ? null : normalizeRosterPhone(rawPhone);
    parsed.add(
      RosterRow(
        line: i + 1,
        number: number,
        name: name,
        className: klass.isEmpty ? null : klass,
        phone: phone,
        rawPhone: rawPhone.isEmpty ? null : rawPhone,
      ),
    );
  }
  return validateRoster(parsed);
}

/// Sorunları yeniden hesaplar (satır düzeltildikten sonra da çağrılır).
RosterReport validateRoster(List<RosterRow> rows) {
  final seen = <String, int>{};
  for (final r in rows) {
    if (r.number.isNotEmpty) seen[r.number] = (seen[r.number] ?? 0) + 1;
  }
  return RosterReport([
    for (final r in rows)
      RosterRow(
        line: r.line,
        number: r.number,
        name: r.name,
        className: r.className,
        phone: r.phone,
        rawPhone: r.rawPhone,
        problems: [
          if (r.number.isEmpty) RowProblem.missingNumber,
          if (r.number.isNotEmpty && !RegExp(r'^\d{1,20}$').hasMatch(r.number))
            RowProblem.badNumber,
          if (r.name.trim().length < 2) RowProblem.missingName,
          if ((seen[r.number] ?? 0) > 1) RowProblem.duplicateInFile,
          if (r.rawPhone != null && r.phone == null) RowProblem.badPhone,
        ],
      ),
  ]);
}

/// `compute()` için: ([rows], [columns adı→sütun], başlık) → rapor.
RosterReport parseRosterArgs(
  (List<List<String>>, Map<String, int>, int) args,
) => parseRoster(args.$1, {
  for (final e in args.$2.entries) RosterColumn.values.byName(e.key): e.value,
}, headerRow: args.$3);
