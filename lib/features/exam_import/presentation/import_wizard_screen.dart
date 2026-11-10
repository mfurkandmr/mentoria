import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/panel.dart';
import '../../import/data/spreadsheet_reader.dart';
import '../data/exam_admin_repository.dart';
import '../domain/exam_definition.dart';
import '../domain/exam_package.dart';
import '../domain/import_plan.dart';
import '../domain/optic_result_parser.dart';
import '../../../core/design/motion.dart';
import '../../../shared/widgets/skeleton.dart';

String warningText(RowWarning w) {
  final col = w.column == null ? '' : '${w.column}: ';
  return switch (w.kind) {
    RowWarningKind.tooShort => tr(
      '{c}cevap metni kısa ({d}); eksikler boş sayıldı',
      {'c': col, 'd': w.detail ?? ''},
    ),
    RowWarningKind.tooLong => tr('{c}cevap metni uzun ({d}); fazlası kesildi', {
      'c': col,
      'd': w.detail ?? '',
    }),
    RowWarningKind.invalidChar => tr('{c}geçersiz işaret ({d}) boş sayıldı', {
      'c': col,
      'd': w.detail ?? '',
    }),
    RowWarningKind.bookletEmpty => tr('kitapçık boş; A sayıldı'),
    RowWarningKind.bookletInvalid => tr(
      'kitapçık tanınmadı ya da anahtarı yok ({d})',
      {'d': w.detail ?? '—'},
    ),
    RowWarningKind.noNumber => tr('öğrenci numarası boş'),
  };
}

/// Optik okuyucu Excel'i: dosya → sütun eşleştirme (ya da kayıtlı şablon) →
/// doğrulama raporu → içe aktarma → özet.
class ImportWizardScreen extends ConsumerStatefulWidget {
  const ImportWizardScreen({
    super.key,
    required this.examId,
    this.rows,
    this.template,
    this.fileName,
    this.notes = const [],
  });

  final String examId;

  /// Önceden okunmuş sayfa (dosya seçmeden; testler ve sabit sütunlu optik).
  final List<List<String>>? rows;

  /// Verilirse sütun eşleştirme atlanır, doğrudan doğrulama raporu açılır.
  final ImportTemplate? template;
  final String? fileName;

  /// Raporun başında gösterilen açıklamalar (ör. tahmin edilen kitapçık).
  final List<String> notes;

  @override
  ConsumerState<ImportWizardScreen> createState() => _ImportWizardState();
}

enum _Step { file, mapping, report, done }

class _ImportWizardState extends ConsumerState<ImportWizardScreen> {
  _Step _step = _Step.file;
  ExamDefinition? _exam;
  List<RosterStudent> _roster = const [];
  List<List<String>> _rows = const [];
  List<String> _headers = const [];
  String _fileName = 'optik.xlsx';
  ImportTemplate? _template;
  final _templateName = TextEditingController(text: 'Optik okuyucu');
  bool _saveTemplate = true;
  ImportPlan? _plan;

  /// Satır → elle seçilen öğrenci (eşleşmeyenler) / ad uyuşmazlığı onayı.
  final _manual = <int, RosterStudent>{};
  final _approved = <int>{};
  bool _busy = false;
  double _progress = 0;
  ImportOutcome? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _templateName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(examAdminRepositoryProvider);
    final exam = await repo.fetchExam(widget.examId);
    final roster = await repo.fetchRoster();
    if (!mounted) return;
    setState(() {
      _exam = exam;
      _roster = roster;
    });
    if (widget.rows == null) return;
    await _useRows(widget.rows!, widget.fileName ?? 'optik.xlsx');
    if (widget.template != null && mounted) {
      setState(() {
        _template = widget.template;
        _saveTemplate = false;
      });
      await _validate();
    }
  }

  Future<void> _pick() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final bytes = Uint8List.fromList(await files.first.readAsBytes());
      final text = decodeText(bytes);
      if (looksLikeFixedWidthOptic(text)) {
        if (mounted) await _useFixedWidth(text, files.first.name);
        return;
      }
      final sheets = await readSpreadsheetInBackground(bytes);
      if (!mounted) return;
      await _useRows(sheets.values.first, files.first.name);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('Dosya okunamadı. Excel (.xlsx, .xls) ya da CSV seç.'),
          ),
        ),
      );
    }
  }

  /// Optik makinesinin sabit sütunlu .txt çıktısı. B kitapçığının fiziksel
  /// sırası kayıtlı sınavda tutulmadığı için çok kitapçıklı sınavda kazanım
  /// tablosu da gerekir: o zaman "Dosyalardan sınav kur" kullanılır.
  Future<void> _useFixedWidth(String text, String name) async {
    final exam = _exam!;
    if (exam.bookletList.length > 1) {
      showMessage(
        context,
        tr(
          'Bu sınavda birden çok kitapçık var. Optik .txt çıktısını Kurum sınavları > Dosyalardan sınav kur ile anahtar ve kazanım tablosuyla birlikte yükle.',
        ),
      );
      return;
    }
    final total = exam.subjects.fold<int>(0, (s, x) => s + x.questionCount);
    final List<OpticLine> lines;
    try {
      lines = parseFixedWidthOptic(text, total);
    } on ExamPackageException {
      showMessage(context, tr('Optik çıktısının satırları okunamadı.'));
      return;
    }
    final r = opticRowsFor(lines, exam, const {});
    await _useRows(r.rows, name);
    if (!mounted) return;
    setState(() {
      _template = r.template;
      _saveTemplate = false;
    });
    await _validate();
  }

  Future<void> _useRows(List<List<String>> rows, String name) async {
    final headers = headersOf(rows);
    if (headers.length < 2) {
      showMessage(context, tr('Dosyada başlık satırı bulunamadı.'));
      return;
    }
    final saved = await ref.read(importTemplatesProvider.future);
    final fit = saved.where((t) => t.fits(headers)).firstOrNull;
    final guess = OpticResultParser.guess(headers, [
      for (final s in _exam!.subjects) s.code,
    ]);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _headers = headers;
      _fileName = name;
      _template = fit ?? guess;
      if (fit != null) _templateName.text = fit.name;
      _step = _Step.mapping;
    });
  }

  Future<void> _validate() async {
    final t = _template!;
    if (t.columns.isEmpty) {
      showMessage(context, tr('En az bir cevap sütununu bir derse eşleştir.'));
      return;
    }
    setState(() => _busy = true);
    final input = ImportInput(
      rows: _rows,
      template: t,
      exam: _exam!,
      roster: _roster,
    );
    // Büyük dosya isolate'te ayrıştırılır (arayüz donmaz).
    final plan = _rows.length > 60
        ? await compute(prepareImport, input)
        : prepareImport(input);
    if (_saveTemplate && _templateName.text.trim().isNotEmpty) {
      try {
        final savedT = await ref
            .read(examAdminRepositoryProvider)
            .saveTemplate(t.copyWith(name: _templateName.text.trim()));
        ref.invalidate(importTemplatesProvider);
        _template = savedT;
      } catch (_) {
        // Şablon kaydedilemese de içe aktarma sürer.
      }
    }
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _manual.clear();
      _approved.clear();
      _busy = false;
      _step = _Step.report;
    });
  }

  /// Gönderilecek optikler: eşleşenler, onaylanan ad uyuşmazlıkları, elle
  /// eşleştirilenler. Aynı öğrenci iki satırda seçildiyse sonuncusu.
  List<SheetUpload> get _uploads {
    final out = <String, SheetUpload>{};
    for (final (i, r) in _plan!.rows.indexed) {
      final student = switch (r.status) {
        MatchStatus.matched => r.student,
        MatchStatus.nameMismatch => _approved.contains(i) ? r.student : null,
        MatchStatus.unmatched => _manual[i],
        MatchStatus.error => null,
      };
      if (student == null || r.parsed.booklet == null) continue;
      out[student.id] = SheetUpload(
        studentId: student.id,
        booklet: r.parsed.booklet!,
        answers: r.parsed.answers,
      );
    }
    return out.values.toList();
  }

  Future<void> _import() async {
    final uploads = _uploads;
    if (uploads.isEmpty) {
      showMessage(context, tr('Aktarılacak öğrenci yok.'));
      return;
    }
    final repo = ref.read(examAdminRepositoryProvider);
    final existing = await repo.sheetCount(widget.examId);
    if (!mounted) return;
    if (existing > 0) {
      final ok = await confirm(
        context,
        title: tr('Üzerine yazılsın mı?'),
        message: tr(
          'Bu sınavda zaten {n} sonuç var. Dosyadaki öğrencilerin sonuçları güncellenir; kopya kayıt oluşmaz.',
          {'n': existing},
        ),
        action: tr('Üzerine yaz'),
      );
      if (!ok || !mounted) return;
    }
    final plan = _plan!;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final r = await repo.importSheets(
        examId: widget.examId,
        fileName: _fileName,
        stats: {
          'rows': plan.rows.length,
          'matched': uploads.length,
          'unmatched': plan.unmatched - _manual.length,
          'failed': plan.failed,
          'log': {
            'unmatched': [
              for (final (i, r) in plan.rows.indexed)
                if (r.status == MatchStatus.unmatched &&
                    !_manual.containsKey(i))
                  r.parsed.studentNo,
            ],
            'errors': [
              for (final r in plan.rows)
                if (r.status == MatchStatus.error) r.parsed.row,
            ],
          },
        },
        sheets: uploads,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      ref.invalidate(orgExamsProvider);
      ref.invalidate(orgExamProvider(widget.examId));
      if (!mounted) return;
      setState(() {
        _result = r;
        _step = _Step.done;
      });
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          tr(
            'Aktarım yarıda kaldı. Tekrar yüklersen kopya oluşmaz, kalan öğrenciler eklenir.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.file => tr('Optik sonuçlarını yükle'),
      _Step.mapping => tr('Sütunları eşleştir'),
      _Step.report => tr('Doğrulama raporu'),
      _Step.done => tr('Aktarım tamamlandı'),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _exam == null
          ? const SkeletonList()
          : switch (_step) {
              _Step.file => _fileStep(),
              _Step.mapping => _mappingStep(),
              _Step.report => _reportStep(),
              _Step.done => _doneStep(),
            },
    );
  }

  Widget _fileStep() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      EmptyState(
        title: _exam!.name,
        message: tr(
          'Optik okuyucunun verdiği dosyayı seç: Excel, CSV ya da makinenin sabit sütunlu .txt çıktısı. Her satır bir öğrenci.',
        ),
        action: FilledButton.icon(
          key: const ValueKey('pick-optic-file'),
          onPressed: _pick,
          icon: const Icon(Icons.folder_open_rounded),
          label: Text(tr('Dosya seç')),
        ),
      ),
    ],
  );

  Widget _mappingStep() {
    final t = _template!;
    final e = _exam!;
    final first = _rows.length > headerRowOf(_rows) + 1
        ? _rows[headerRowOf(_rows) + 1]
        : const <String>[];
    String sample(String header) {
      final i = _headers.indexOf(header);
      return i >= 0 && i < first.length ? first[i] : '';
    }

    final idCols = {t.studentNo, t.studentName, t.className, t.booklet};
    final counts = {for (final s in e.subjects) s.code: s.questionCount};
    final templates = ref.watch(importTemplatesProvider).value ?? const [];
    final fitting = [
      for (final x in templates)
        if (x.fits(_headers)) x,
    ];

    Widget pick(
      String label,
      String? value,
      ValueChanged<String?> onChanged, {
      bool optional = true,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (optional) DropdownMenuItem(value: null, child: Text(tr('Yok'))),
          for (final h in _headers)
            DropdownMenuItem(
              value: h,
              child: Text(
                sample(h).isEmpty ? h : '$h  ·  ${sample(h)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('{f}: {n} satır okundu', {
            'f': _fileName,
            'n': _rows.length - headerRowOf(_rows) - 1,
          }),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (fitting.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final x in fitting)
                ActionChip(
                  avatar: const Icon(Icons.bookmark_rounded, size: 18),
                  label: Text(tr('Şablonu kullan: {n}', {'n': x.name})),
                  onPressed: () => setState(() {
                    _template = x;
                    _templateName.text = x.name;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        pick(
          tr('Öğrenci numarası'),
          t.studentNo,
          (v) => setState(() => _template = t.copyWith(studentNo: v)),
          optional: false,
        ),
        pick(
          tr('Ad soyad (kontrol için)'),
          t.studentName,
          (v) => setState(
            () => _template = t.copyWith(studentName: v, clearName: v == null),
          ),
        ),
        pick(
          tr('Sınıf'),
          t.className,
          (v) => setState(
            () => _template = t.copyWith(className: v, clearClass: v == null),
          ),
        ),
        pick(
          tr('Kitapçık'),
          t.booklet,
          (v) => setState(
            () => _template = t.copyWith(booklet: v, clearBooklet: v == null),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('Cevap sütunları'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          tr(
            'Her sütunda hangi derslerin cevapları var? Bir sütunda birden çok ders varsa (ör. Fen) sırayla seç; karakterler soru sayılarına göre bölünür.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final h in _headers)
          if (!idCols.contains(h))
            _AnswerColumnTile(
              key: ValueKey('col-$h'),
              header: h,
              sample: sample(h),
              subjects: [for (final s in e.subjects) s.code],
              selected: [
                for (final c in t.columns)
                  if (c.column == h) ...c.subjects,
              ],
              taken: {
                for (final c in t.columns)
                  if (c.column != h) ...c.subjects,
              },
              counts: counts,
              onChanged: (list) => setState(() {
                _template = t.copyWith(
                  columns: [
                    for (final c in t.columns)
                      if (c.column != h) c,
                    if (list.isNotEmpty)
                      AnswerColumn(column: h, subjects: list),
                  ],
                );
              }),
            ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _saveTemplate,
          onChanged: (v) => setState(() => _saveTemplate = v!),
          title: Text(tr('Eşleştirmeyi şablon olarak kaydet')),
          subtitle: Text(tr('Sonraki sınavda "Şablonu kullan" ile seçilir.')),
        ),
        if (_saveTemplate)
          TextField(
            controller: _templateName,
            decoration: InputDecoration(labelText: tr('Şablon adı')),
          ),
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('validate-import'),
          onPressed: _busy ? null : _validate,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr('Kontrol et')),
        ),
      ],
    );
  }

  Widget _reportStep() {
    final p = _plan!;
    final b = context.brand;
    final text = Theme.of(context).textTheme;
    final uploads = _uploads.length;
    Widget stat(String label, int n, Color c) => Expanded(
      child: Column(
        children: [
          Text(
            '$n',
            style: text.headlineSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
    final rows = p.rows.indexed.toList();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final n in widget.notes)
                PanelNotice(icon: Icons.info_outline_rounded, message: n),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      stat(tr('satır'), p.rows.length, b.ink),
                      stat(tr('eşleşti'), p.matched, b.success),
                      stat(tr('eşleşmedi'), p.unmatched, b.secondary),
                      stat(tr('ad tutmuyor'), p.mismatched, b.info),
                      stat(tr('hatalı'), p.failed, b.danger),
                    ],
                  ),
                ),
              ),
              if (p.unmatched > 0)
                SectionCard(
                  title: tr('Eşleşmeyen numaralar'),
                  subtitle: tr(
                    'Kurumda bu numarayla öğrenci yok. Elle eşleştir ya da atla; atlananlar aktarılmaz.',
                  ),
                  child: Column(
                    children: [
                      for (final (i, r) in rows)
                        if (r.status == MatchStatus.unmatched)
                          _ManualMatch(
                            key: ValueKey('unmatched-${r.parsed.row}'),
                            row: r,
                            roster: _roster,
                            value: _manual[i],
                            onChanged: (s) => setState(
                              () => s == null
                                  ? _manual.remove(i)
                                  : _manual[i] = s,
                            ),
                          ),
                    ],
                  ),
                ),
              if (p.mismatched > 0)
                SectionCard(
                  title: tr('Numara tuttu, ad tutmuyor'),
                  subtitle: tr('Onayladıkların aktarılır.'),
                  child: Column(
                    children: [
                      for (final (i, r) in rows)
                        if (r.status == MatchStatus.nameMismatch)
                          CheckboxListTile(
                            key: ValueKey('mismatch-${r.parsed.row}'),
                            contentPadding: EdgeInsets.zero,
                            value: _approved.contains(i),
                            onChanged: (v) => setState(
                              () => v! ? _approved.add(i) : _approved.remove(i),
                            ),
                            title: Text(
                              '${r.parsed.studentNo}: ${r.parsed.studentName}',
                            ),
                            subtitle: Text(
                              tr('Kurumdaki kayıt: {n}', {
                                'n': r.student!.name,
                              }),
                            ),
                          ),
                    ],
                  ),
                ),
              if (p.failed > 0)
                SectionCard(
                  title: tr('Hatalı satırlar'),
                  subtitle: tr(
                    'Bu satırlar aktarılmaz; dosyayı düzeltip yeniden yükleyebilirsin.',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in p.rows)
                        if (r.status == MatchStatus.error)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${tr('Satır {n}', {'n': r.parsed.row})}: ${r.duplicate ? tr('numara dosyada ikinci kez geçiyor ({no})', {'no': r.parsed.studentNo}) : r.parsed.warnings.where((w) => w.isError).map(warningText).join(', ')}',
                            ),
                          ),
                    ],
                  ),
                ),
              if (p.warned.isNotEmpty)
                SectionCard(
                  title: tr('Uyarılar ({n})', {'n': p.warned.length}),
                  subtitle: tr('Aktarılır; sorunlu işaretler boş sayılır.'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in p.warned.take(50))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${tr('Satır {n}', {'n': r.parsed.row})} (${r.parsed.studentNo}): ${r.parsed.warnings.where((w) => !w.isError).map(warningText).join('; ')}',
                          ),
                        ),
                    ],
                  ),
                ),
              SectionCard(
                title: tr('Önizleme'),
                subtitle: tr('Netler yaklaşık; kesin sonucu sunucu hesaplar.'),
                child: Column(
                  children: [
                    for (final r
                        in p.rows.where((r) => r.score != null).take(15))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${r.parsed.studentNo}  ${r.student?.name ?? r.parsed.studentName ?? ''}',
                        ),
                        subtitle: Text(
                          [
                            for (final s in r.score!.subjects.values)
                              '${subjectByCode(s.subject).name} ${formatNet(s.net)}',
                          ].join(' · '),
                        ),
                        trailing: Text(
                          formatNet(r.score!.totalNet),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy) ...[
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Text(tr('%{p} aktarıldı', {'p': (_progress * 100).round()})),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _step = _Step.mapping),
                      child: Text(tr('Geri')),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      key: const ValueKey('run-import'),
                      onPressed: _busy || uploads == 0 ? null : _import,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(tr('{n} öğrenciyi aktar', {'n': uploads})),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _doneStep() {
    final r = _result!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        EmptyState(
          title: tr('{n} öğrencinin optiği kaydedildi', {'n': r.saved}),
          message: [
            if (r.skipped.isNotEmpty)
              tr('{n} öğrenci kurumda bulunamadığı için atlandı.', {
                'n': r.skipped.length,
              }),
            tr('Sınavda toplam {n} optik var.', {'n': r.sheets}),
            r.published
                ? tr('Sınav yayında: sonuçlar ve sıralamalar güncellendi.')
                : tr(
                    'Sınav taslakta: kontrol edip "Sonuçları yayınla" deyince öğrenciler görür.',
                  ),
          ].join('\n'),
          action: FilledButton(
            key: const ValueKey('import-done'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('Bitti')),
          ),
        ),
      ],
    );
  }
}

class _AnswerColumnTile extends StatelessWidget {
  const _AnswerColumnTile({
    super.key,
    required this.header,
    required this.sample,
    required this.subjects,
    required this.selected,
    required this.taken,
    required this.counts,
    required this.onChanged,
  });

  final String header;
  final String sample;
  final List<String> subjects;
  final List<String> selected;
  final Set<String> taken;
  final Map<String, int> counts;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final expected = selected.fold<int>(0, (a, s) => a + (counts[s] ?? 0));
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(header, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (sample.isNotEmpty)
              Text(
                sample.length > 60 ? '${sample.substring(0, 60)}…' : sample,
                style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            if (selected.isNotEmpty)
              Text(
                tr('{n} karakter bekleniyor, ilk satırda {m}', {
                  'n': expected,
                  'm': sample.length,
                }),
                style: text.bodySmall,
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in subjects)
                  if (!taken.contains(s))
                    FilterChip(
                      label: Text(
                        selected.contains(s)
                            ? '${selected.indexOf(s) + 1}. ${subjectByCode(s).name}'
                            : subjectByCode(s).name,
                      ),
                      selected: selected.contains(s),
                      onSelected: (v) => onChanged(
                        v
                            ? [...selected, s]
                            : [
                                for (final x in selected)
                                  if (x != s) x,
                              ],
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualMatch extends StatelessWidget {
  const _ManualMatch({
    super.key,
    required this.row,
    required this.roster,
    required this.value,
    required this.onChanged,
  });

  final ImportRowPlan row;
  final List<RosterStudent> roster;
  final RosterStudent? value;
  final ValueChanged<RosterStudent?> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      '${row.parsed.studentNo}  ${row.parsed.studentName ?? ''}'.trim(),
    ),
    subtitle: Text(
      value == null
          ? tr('Atlanacak')
          : tr('{n} ile eşleştirildi', {'n': value!.name}),
    ),
    trailing: TextButton(
      onPressed: () async {
        final picked = await showModalBottomSheet<RosterStudent?>(
          context: context,
          sheetAnimationStyle: AppMotion.overlayStyle(context),
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _StudentPicker(
            roster: roster,
            hint: row.parsed.studentName ?? '',
          ),
        );
        if (picked != null) {
          onChanged(picked.id.isEmpty ? null : picked);
        }
      },
      child: Text(value == null ? tr('Eşleştir') : tr('Değiştir')),
    ),
  );
}

class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.roster, required this.hint});
  final List<RosterStudent> roster;
  final String hint;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  late final _q = TextEditingController(text: widget.hint);

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = foldTr(
      _q.text,
    ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final list = [
      for (final s in widget.roster)
        if (words.isEmpty ||
            words.any((w) => foldTr('${s.name} ${s.number ?? ''}').contains(w)))
          s,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _q,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: tr('Ad ya da numara ara'),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: Text(tr('Atla')),
              onTap: () =>
                  Navigator.pop(context, const RosterStudent(id: '', name: '')),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  Widget row(int i) {
                    final s = list[i];
                    return ListTile(
                      title: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (s.number != null) s.number!,
                          if (s.className != null) s.className!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, s),
                    );
                  }

                  return ListView.builder(
                    itemCount: list.length,
                    // Satırlar eş yükseklikte: kaydırma konumu ölçmeden hesaplanır.
                    prototypeItem: list.isEmpty ? null : row(0),
                    itemBuilder: (context, i) => row(i),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
