import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../coach/data/coach_repository.dart';
import '../../exams/data/exam.dart';
import '../../exams/data/exam_repository.dart';
import '../data/exam_file_parser.dart';
import '../../../core/i18n/i18n.dart';

/// Koç / kurum müdürü: yayınevi sonuç dosyasını (.xlsx, .xls, CSV, TXT) yükleyip
/// öğrencilere okul numarasıyla dağıtır.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, this.initialSheets, this.initialFileName});

  /// Testler için dosya seçmeden sayfa verisi.
  final Map<String, SheetRows>? initialSheets;
  final String? initialFileName;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  String? _fileName;
  Map<String, SheetRows> _sheets = {};
  String? _sheet;

  ExamType _type = ExamType.tyt;
  FieldType _aytField = FieldType.say;
  final _name = TextEditingController();
  final _publisher = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  ParsedSheet? _parsed;
  ColumnMapping? _mapping;

  /// satır indeksi → atanmış öğrenci (null = eşleşmedi)
  final _assigned = <int, String?>{};
  final _matchedBy = <int, String>{}; // 'numara' | 'isim'
  final _included = <int>{};

  bool _saving = false;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialSheets != null) {
      _load(widget.initialFileName ?? 'dosya.xlsx', widget.initialSheets!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _publisher.dispose();
    super.dispose();
  }

  FieldType? get _field => switch (_type) {
    ExamType.tyt => null,
    ExamType.ayt => _aytField,
    ExamType.ydt => FieldType.dil,
  };

  Future<void> _pick() async {
    try {
      // Biçim içerikten anlaşılır; Android'de uzantı süzgeci bazı geçerli
      // dosyaları (ör. WhatsApp'tan inenleri) seçilemez gösterdiği için
      // her dosya seçilebilir.
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final Uint8List bytes;
      try {
        bytes = Uint8List.fromList(await files.first.readAsBytes());
      } catch (_) {
        if (mounted) {
          showMessage(
            context,
            tr(
              'Dosya açılamadı. Telefona indirip yeniden seçmeyi dene (bulut klasörlerinden okuma bazen engellenir).',
            ),
          );
        }
        return;
      }
      _load(files.first.name, readSpreadsheet(bytes));
    } on SpreadsheetException catch (e) {
      if (mounted) showMessage(context, _problemText(e.problem));
    } catch (_) {
      if (mounted) {
        showMessage(context, _problemText(SpreadsheetProblem.corrupt));
      }
    }
  }

  String _problemText(SpreadsheetProblem p) => switch (p) {
    SpreadsheetProblem.encrypted => tr(
      'Dosya şifreli. Excel\'de açıp şifresini kaldırdıktan sonra yeniden yükle.',
    ),
    SpreadsheetProblem.empty => tr('Dosyada okunacak bir tablo bulunamadı.'),
    SpreadsheetProblem.notSpreadsheet => tr(
      'Bu dosya bir tablo değil. Excel (.xlsx, .xls) ya da CSV / TXT sonuç dosyası seç.',
    ),
    SpreadsheetProblem.corrupt => tr(
      'Dosya okunamadı; bozuk olabilir. Excel\'de açıp "Farklı kaydet → Excel Çalışma Kitabı (.xlsx)" ile kaydedip yeniden dene.',
    ),
  };

  void _load(String fileName, Map<String, SheetRows> sheets) {
    // Sınav türü önce dosya adından; ad bir şey söylemiyorsa ya da o türde
    // sütun bulunamazsa sütunlardan anlaşılır. Kapak / bilgi sayfası olan
    // dosyalarda ders sütunları en çok eşleşen sayfa seçilir.
    final lower = normalize(fileName);
    final named = lower.contains('ayt')
        ? ExamType.ayt
        : lower.contains('ydt')
        ? ExamType.ydt
        : lower.contains('tyt')
        ? ExamType.tyt
        : null;
    var sheet = sheets.keys.firstOrNull;
    var type = named ?? ExamType.tyt;
    var best = -1;
    // Puan: eşleşen ders sayısı; eşitlikte (ör. Fizik / Kimya hem TYT hem
    // AYT'de var) soru sayısını aşan satırı az olan tür kazanır.
    int scoreOf(SheetRows rows, ExamType t) {
      final p = parseSheet(rows, t);
      if (p == null) return 0;
      final bad = buildRows(p, p.mapping).where((r) => r.problem != null);
      return p.mapping.mappedSubjectCount * 10000 - bad.length;
    }

    for (final t in [?named, ...ExamType.values.where((t) => t != named)]) {
      for (final e in sheets.entries) {
        final score = scoreOf(e.value, t);
        if (score > best) {
          best = score;
          sheet = e.key;
          type = t;
        }
      }
      // Dosya adındaki tür tutuyorsa diğerlerine bakma.
      if (t == named && best > 0) break;
    }
    setState(() {
      _fileName = fileName;
      _sheets = sheets;
      _sheet = sheet;
      _type = type;
      if (_name.text.isEmpty) {
        _name.text = fileName.replaceAll(
          RegExp(r'\.(xlsx|xlsm|xls|csv|txt)$', caseSensitive: false),
          '',
        );
      }
    });
    _reparse();
  }

  void _reparse() {
    final rows = _sheet == null ? null : _sheets[_sheet];
    final parsed = rows == null ? null : parseSheet(rows, _type);
    setState(() {
      _parsed = parsed;
      _mapping = parsed?.mapping;
    });
    _rematch();
  }

  void _rematch() {
    final students = ref.read(studentSummariesProvider).value ?? const [];
    final byNumber = {
      for (final s in students)
        if (s.studentNumber != null) normalizeNumber(s.studentNumber!): s.id,
    };
    final byName = <String, String>{};
    for (final s in students) {
      byName[_words(s.fullName)] = s.id;
    }
    final rows = _rows;
    setState(() {
      _assigned.clear();
      _matchedBy.clear();
      _included.clear();
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final viaNumber = r.number.isEmpty
            ? null
            : byNumber[normalizeNumber(r.number)];
        final viaName = r.name.isEmpty ? null : byName[_words(r.name)];
        final id = viaNumber ?? viaName;
        _assigned[i] = id;
        if (id != null) {
          _matchedBy[i] = viaNumber != null ? 'numara' : 'isim';
          if (r.problem == null && r.results.isNotEmpty) _included.add(i);
        }
      }
    });
  }

  static String _words(String s) => normalize(s).replaceAll(' ', '');

  List<ImportRow> get _rows => _parsed == null || _mapping == null
      ? const []
      : buildRows(_parsed!, _mapping!);

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showMessage(context, tr('Denemeye bir ad ver.'));
      return;
    }
    final rows = _rows;
    final targets = [
      for (final i in _included)
        if (_assigned[i] != null) (i, _assigned[i]!),
    ];
    if (targets.isEmpty) {
      showMessage(context, tr('Kaydedilecek öğrenci seçilmedi.'));
      return;
    }
    final ok = await confirm(
      context,
      title: tr('Denemeler kaydedilsin mi?'),
      message: tr('"{p0}" denemesi {p1} öğrencinin hesabına eklenecek.', {
        'p0': _name.text.trim(),
        'p1': targets.length,
      }),
      action: tr('Kaydet'),
    );
    if (!ok) return;

    setState(() {
      _saving = true;
      _savedCount = 0;
    });
    final repo = ref.read(examRepositoryProvider);
    // Bu yüklemedeki tüm denemeler tek paket: Denemeler ekranından birlikte
    // silinebilir.
    final batchId = newBatchId();
    final failed = <String>[];
    for (final (i, studentId) in targets) {
      try {
        await repo.createExam(
          studentId: studentId,
          draft: ExamDraft(
            examType: _type,
            field: _field,
            name: _name.text.trim(),
            publisher: _publisher.text.trim().isEmpty
                ? null
                : _publisher.text.trim(),
            takenOn: _date,
            results: rows[i].results,
            imported: true,
            batchId: batchId,
          ),
        );
        if (mounted) setState(() => _savedCount++);
      } catch (_) {
        failed.add(rows[i].name.isEmpty ? rows[i].number : rows[i].name);
      }
    }
    ref.invalidate(examsForStudentProvider);
    ref.invalidate(studentSummariesProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Yükleme tamamlandı')),
        content: Text(
          tr('{_savedCount} öğrenciye deneme eklendi.{p0}', {
            '_savedCount': _savedCount,
            'p0': failed.isEmpty
                ? ''
                : '\n\nKaydedilemeyenler: ${failed.join(', ')}',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Tamam')),
          ),
        ],
      ),
    );
    if (mounted && failed.isEmpty) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentSummariesProvider);
    // Öğrenci listesi sonradan gelirse eşleştirmeyi yenile.
    ref.listen(studentSummariesProvider, (_, _) => _rematch());
    final rows = _rows;
    final selected = _included.where((i) => _assigned[i] != null).length;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Deneme sonuçlarını yükle'))),
      bottomNavigationBar: _parsed == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _saving || selected == 0 ? null : _save,
                  child: Text(
                    _saving
                        ? tr('Kaydediliyor… {_savedCount} / {selected}', {
                            '_savedCount': _savedCount,
                            'selected': selected,
                          })
                        : tr('{selected} öğrenciye kaydet', {
                            'selected': selected,
                          }),
                  ),
                ),
              ),
            ),
      body: AsyncView(
        value: students,
        builder: (studentList) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _FileCard(
              fileName: _fileName,
              sheets: _sheets.keys.toList(),
              sheet: _sheet,
              onPick: _saving ? null : _pick,
              onSheet: (s) {
                setState(() => _sheet = s);
                _reparse();
              },
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 12),
              _ExamInfoCard(
                type: _type,
                aytField: _aytField,
                name: _name,
                publisher: _publisher,
                date: _date,
                onType: (t) {
                  setState(() => _type = t);
                  _reparse();
                },
                onField: (f) => setState(() => _aytField = f),
                onDate: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: 12),
              if (_parsed == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      tr(
                        'Bu sayfada ders sütunları bulunamadı. Sınav türünün doğru seçildiğinden ve dosyada "Türkçe D / Türkçe Y" gibi başlıklar olduğundan emin ol. Dosyayı bize gönderirsen formatını tanıtabiliriz.',
                      ),
                    ),
                  ),
                )
              else ...[
                _MappingCard(
                  parsed: _parsed!,
                  mapping: _mapping!,
                  type: _type,
                  onChanged: () {
                    setState(() {});
                    _rematch();
                  },
                ),
                const SizedBox(height: 12),
                _PreviewCard(
                  rows: rows,
                  students: studentList,
                  assigned: _assigned,
                  matchedBy: _matchedBy,
                  included: _included,
                  onAssign: (i, id) => setState(() {
                    _assigned[i] = id;
                    _matchedBy[i] = 'elle';
                    if (id != null && rows[i].problem == null) {
                      _included.add(i);
                    } else {
                      _included.remove(i);
                    }
                  }),
                  onInclude: (i, v) => setState(
                    () => v ? _included.add(i) : _included.remove(i),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.fileName,
    required this.sheets,
    required this.sheet,
    required this.onPick,
    required this.onSheet,
  });

  final String? fileName;
  final List<String> sheets;
  final String? sheet;
  final VoidCallback? onPick;
  final ValueChanged<String> onSheet;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: tr('1. Sonuç dosyası'),
      subtitle: tr(
        'Yayınevinin ya da optik okuyucunun verdiği dosya: Excel (.xlsx, .xls), CSV ya da TXT',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fileName == null)
            Text(
              tr(
                'Dosyadaki her satır bir öğrenci olmalı; öğrenciler okul numarasıyla eşleştirilir. Kaydetmeden önce önizlemede kontrol edebilirsin.',
              ),
              style: text.bodySmall,
            )
          else
            Row(
              children: [
                const Icon(Icons.description_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          if (sheets.length > 1) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: sheet,
              decoration: InputDecoration(labelText: tr('Sayfa')),
              items: [
                for (final s in sheets)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => onSheet(v!),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file),
            label: Text(
              fileName == null ? tr('Dosya seç') : tr('Başka dosya seç'),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamInfoCard extends StatelessWidget {
  const _ExamInfoCard({
    required this.type,
    required this.aytField,
    required this.name,
    required this.publisher,
    required this.date,
    required this.onType,
    required this.onField,
    required this.onDate,
  });

  final ExamType type;
  final FieldType aytField;
  final TextEditingController name;
  final TextEditingController publisher;
  final DateTime date;
  final ValueChanged<ExamType> onType;
  final ValueChanged<FieldType> onField;
  final ValueChanged<DateTime> onDate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: tr('2. Deneme bilgileri'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ExamType>(
            showSelectedIcon: false,
            segments: [
              for (final t in ExamType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {type},
            onSelectionChanged: (s) => onType(s.first),
          ),
          if (type == ExamType.ayt) ...[
            const SizedBox(height: 10),
            SegmentedButton<FieldType>(
              showSelectedIcon: false,
              segments: [
                for (final f in aytFields)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {aytField},
              onSelectionChanged: (s) => onField(s.first),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: name,
            decoration: InputDecoration(labelText: tr('Deneme adı')),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: publisher,
                  decoration: InputDecoration(labelText: tr('Yayın')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(DateTime.now().year - 2),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) onDate(d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: tr('Tarih')),
                    child: Text(formatShortDate(date)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MappingCard extends StatelessWidget {
  const _MappingCard({
    required this.parsed,
    required this.mapping,
    required this.type,
    required this.onChanged,
  });

  final ParsedSheet parsed;
  final ColumnMapping mapping;
  final ExamType type;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final headers = parsed.headers;
    final subjects = examSubjects.where((s) => s.examType == type).toList();

    Widget columnPicker(String label, int? value, ValueChanged<int?> onPick) =>
        DropdownButtonFormField<int?>(
          initialValue: value,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            labelText: label,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('—')),
            for (var i = 0; i < headers.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(headers[i], overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            onPick(v);
            onChanged();
          },
        );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: mapping.numberCol == null,
          title: Text(
            tr('3. Sütun eşleştirmesi'),
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            tr('{p0} ders otomatik bulundu{p1}', {
              'p0': mapping.mappedSubjectCount,
              'p1': mapping.numberCol == null
                  ? tr(' · numara sütunu bulunamadı!')
                  : '',
            }),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: columnPicker(
                    tr('Okul no'),
                    mapping.numberCol,
                    (v) => mapping.numberCol = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: columnPicker(
                    tr('Ad soyad'),
                    mapping.nameCol,
                    (v) => mapping.nameCol = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final s in subjects) ...[
              Text(s.name, style: text.labelLarge),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final (kind, label) in [
                    (CountKind.correct, 'D'),
                    (CountKind.wrong, 'Y'),
                    (CountKind.blank, 'B'),
                  ]) ...[
                    Expanded(
                      child: columnPicker(
                        label,
                        mapping.subjects[s.code]?[kind],
                        (v) {
                          final m = mapping.subjects.putIfAbsent(
                            s.code,
                            () => {},
                          );
                          v == null ? m.remove(kind) : m[kind] = v;
                        },
                      ),
                    ),
                    if (kind != CountKind.blank) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.rows,
    required this.students,
    required this.assigned,
    required this.matchedBy,
    required this.included,
    required this.onAssign,
    required this.onInclude,
  });

  final List<ImportRow> rows;
  final List<StudentSummary> students;
  final Map<int, String?> assigned;
  final Map<int, String> matchedBy;
  final Set<int> included;
  final void Function(int, String?) onAssign;
  final void Function(int, bool) onInclude;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final matched = assigned.values.where((v) => v != null).length;
    final byId = {for (final s in students) s.id: s};

    return SectionCard(
      title: tr('4. Önizleme'),
      subtitle: tr('{p0} satır · {matched} eşleşti · {p1} eşleşmedi', {
        'p0': rows.length,
        'matched': matched,
        'p1': rows.length - matched,
      }),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _PreviewRow(
              row: rows[i],
              student: byId[assigned[i]],
              matchedBy: matchedBy[i],
              included: included.contains(i),
              students: students,
              onAssign: (id) => onAssign(i, id),
              onInclude: (v) => onInclude(i, v),
            ),
          if (rows.isEmpty)
            Text(
              tr('Dosyada öğrenci satırı bulunamadı.'),
              style: text.bodyMedium,
            ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.row,
    required this.student,
    required this.matchedBy,
    required this.included,
    required this.students,
    required this.onAssign,
    required this.onInclude,
  });

  final ImportRow row;
  final StudentSummary? student;
  final String? matchedBy;
  final bool included;
  final List<StudentSummary> students;
  final ValueChanged<String?> onAssign;
  final ValueChanged<bool> onInclude;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final problem =
        row.problem ?? (row.results.isEmpty ? tr('Sonuç yok') : null);
    final (icon, color) = problem != null
        ? (Icons.error_outline, context.brand.danger)
        : student == null
        ? (Icons.help_outline, context.brand.primaryDeep)
        : (Icons.check_circle, context.brand.success);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.12),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    if (row.number.isNotEmpty)
                      tr('No {p0}', {'p0': row.number}),
                    if (row.name.isNotEmpty) row.name,
                  ].join(' · '),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${formatNet(row.totalNet)} net',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Checkbox(
                value: included,
                onChanged: student == null || problem != null
                    ? null
                    : (v) => onInclude(v ?? false),
              ),
            ],
          ),
          if (problem != null)
            Text(
              problem,
              style: text.labelSmall?.copyWith(color: context.brand.danger),
            )
          else if (student != null && matchedBy != 'elle')
            Text(
              tr('→ {p0} ({matchedBy} ile eşleşti)', {
                'p0': student!.fullName,
                'matchedBy': tr(matchedBy!),
              }),
              style: text.labelSmall,
            )
          else
            DropdownButtonFormField<String?>(
              initialValue: student?.id,
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                labelText: tr('Öğrenci seç'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(tr('Atla'))),
                for (final s in students)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.fullName}${s.studentNumber == null ? '' : ' (${s.studentNumber})'}',
                    ),
                  ),
              ],
              onChanged: onAssign,
            ),
        ],
      ),
    );
  }
}
