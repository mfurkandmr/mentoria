import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../import/data/spreadsheet_reader.dart';
import '../../student_management/data/student_management_repository.dart';
import '../data/registration_repository.dart';
import '../domain/roster_import.dart';

final _inline = FilledButton.styleFrom(minimumSize: const Size(0, 44));

/// Müdür: öğrenci kayıt modu ve kurum listesi.
class RegistrationSettingsScreen extends ConsumerWidget {
  const RegistrationSettingsScreen({super.key});

  Future<void> _setMode(
    BuildContext context,
    WidgetRef ref,
    RegistrationMode current,
    RegistrationMode next,
    int listSize,
  ) async {
    if (next == current) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          next == RegistrationMode.list
              ? tr('Liste ile eşleşmeli kayda geçilsin mi?')
              : tr('Serbest kayda geçilsin mi?'),
        ),
        content: Text(
          next == RegistrationMode.list
              ? [
                  tr(
                    'Yeni öğrenciler yalnızca kurum listesindeki numarayla kayıt olabilir. Kayıtlı öğrenciler listeyle karşılaştırılır; numarası listede olmayanlar "Şüpheli numaralar"a düşer.',
                  ),
                  if (listSize == 0)
                    tr(
                      'Dikkat: liste boş; liste yüklenene kadar hiçbir öğrenci kayıt olamaz.',
                    ),
                ].join('\n\n')
              : tr(
                  'Öğrenciler numaralarını serbestçe girer. Hatalı ya da kullanımdaki numaralar "Şüpheli numaralar"da görünür.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            key: const ValueKey('mode-confirm'),
            style: _inline,
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Geç')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(registrationRepositoryProvider).setMode(next);
      ref.invalidate(registrationModeProvider);
      ref.invalidate(managedStudentsProvider);
      ref.invalidate(expectedStudentsProvider);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(registrationModeProvider);
    final expected = ref.watch(expectedStudentsProvider).value ?? const [];
    final matched = expected.where((e) => e.matched).length;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Öğrenci kayıt ayarları'))),
      body: AsyncView(
        value: mode,
        onRetry: () => ref.invalidate(registrationModeProvider),
        builder: (m) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('Kayıt modu'), style: text.titleMedium),
            const SizedBox(height: 6),
            RadioGroup<RegistrationMode>(
              groupValue: m,
              onChanged: (v) {
                if (v != null) _setMode(context, ref, m, v, expected.length);
              },
              child: Column(
                children: [
                  Card(
                    child: RadioListTile<RegistrationMode>(
                      key: const ValueKey('mode-list'),
                      value: RegistrationMode.list,
                      title: Text(tr('Liste ile eşleşmeli kayıt (önerilen)')),
                      subtitle: Text(
                        tr(
                          'Kurumun öğrenci listesini (Excel / CSV) yüklersin. Öğrenci kayıtta numarasını girer; numara listede yoksa kayıt olamaz, varsa adı ve sınıfı listeden gelir.',
                        ),
                      ),
                    ),
                  ),
                  Card(
                    child: RadioListTile<RegistrationMode>(
                      key: const ValueKey('mode-free'),
                      value: RegistrationMode.free,
                      title: Text(tr('Serbest kayıt')),
                      subtitle: Text(
                        tr(
                          'Listen yoksa: öğrenci numarasını kendisi yazar. Hatalı biçimli, kullanımdaki ya da benzer adlı kayıtlar "Şüpheli numaralar" listesinde görünür.',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(tr('Kurum listesi'), style: text.titleMedium),
            const SizedBox(height: 6),
            Card(
              child: ListTile(
                leading: const Icon(Icons.list_alt_rounded),
                title: Text(tr('{n} öğrenci listede', {'n': expected.length})),
                subtitle: Text(
                  tr('{m} kayıt oldu · {p} bekliyor', {
                    'm': matched,
                    'p': expected.length - matched,
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('open-import'),
              onPressed: () => context.push('/admin/registration/import'),
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(tr('Excel / CSV ile liste yükle')),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Liste hesap açmaz ve numara üretmez; yalnızca kayıt olacak öğrencilerin numara, ad soyad, (varsa) sınıf ve veli telefonu listesidir.',
              ),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste içe aktarma: dosya → sayfa ve sütun eşleştirme → doğrulama raporu
/// (hatalı satırları düzelt ya da atla) → içe aktar.
class RosterImportScreen extends ConsumerStatefulWidget {
  const RosterImportScreen({super.key, this.initialFile});

  /// Testler için: dosya seçmeden bu satırlarla başla.
  final Map<String, SheetRows>? initialFile;

  @override
  ConsumerState<RosterImportScreen> createState() => _RosterImportScreenState();
}

class _RosterImportScreenState extends ConsumerState<RosterImportScreen> {
  Map<String, SheetRows>? _sheets;
  String? _fileName;
  String? _sheet;
  int _headerRow = 0;
  Map<RosterColumn, int> _columns = {};
  RosterReport? _report;
  bool _replace = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFile;
    if (f != null) _load('liste.xlsx', f);
  }

  SheetRows get _rows => _sheets?[_sheet] ?? const [];

  void _load(String name, Map<String, SheetRows> sheets) {
    final first = sheets.keys.first;
    setState(() {
      _fileName = name;
      _sheets = sheets;
      _sheet = first;
      _headerRow = 0;
      _columns = sheets[first]!.isEmpty
          ? {}
          : guessColumns(sheets[first]!.first);
      _report = null;
    });
  }

  Future<void> _pick() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final bytes = Uint8List.fromList(await files.first.readAsBytes());
      _load(files.first.name, readSpreadsheet(bytes));
    } on SpreadsheetException catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.problem == SpreadsheetProblem.encrypted
              ? tr(
                  'Dosya şifreli. Excel\'de açıp şifresini kaldırdıktan sonra yeniden yükle.',
                )
              : tr('Dosya okunamadı. Excel (.xlsx, .xls) ya da CSV seç.'),
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          tr('Dosya okunamadı. Excel (.xlsx, .xls) ya da CSV seç.'),
        );
      }
    }
  }

  Future<void> _check() async {
    if (!_columns.containsKey(RosterColumn.number) ||
        !_columns.containsKey(RosterColumn.name)) {
      showMessage(context, tr('Öğrenci no ve ad soyad sütunlarını seç.'));
      return;
    }
    setState(() => _busy = true);
    final rows = _rows;
    // Büyük dosya arayüzü dondurmasın.
    final report = rows.length > 2000
        ? await compute(parseRosterArgs, (
            rows,
            {for (final e in _columns.entries) e.key.name: e.value},
            _headerRow,
          ))
        : parseRoster(rows, _columns, headerRow: _headerRow);
    if (mounted) {
      setState(() {
        _report = report;
        _busy = false;
      });
    }
  }

  Future<void> _fixRow(RosterRow row) async {
    final fixed = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _FixRowDialog(row: row),
    );
    if (fixed == null || !mounted) return;
    final rows = [
      for (final r in _report!.rows)
        r.line == row.line ? r.copyWith(number: fixed.$1, name: fixed.$2) : r,
    ];
    setState(() => _report = validateRoster(rows));
  }

  Future<void> _import() async {
    final valid = _report!.valid;
    setState(() => _busy = true);
    try {
      final r = await ref.read(registrationRepositoryProvider).importExpected([
        for (final x in valid)
          ExpectedStudent(
            number: x.number,
            fullName: x.name,
            className: x.className,
            guardianPhone: x.phone,
          ),
      ], replace: _replace);
      ref.invalidate(expectedStudentsProvider);
      ref.invalidate(managedStudentsProvider);
      if (!mounted) return;
      showMessage(
        context,
        tr('{i} yeni, {u} güncellendi, {d} silindi.', {
          'i': r.inserted,
          'u': r.updated,
          'd': r.removed,
        }),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  String _problem(RowProblem p) => switch (p) {
    RowProblem.missingNumber => tr('Numara yok'),
    RowProblem.badNumber => tr('Numara yalnızca rakam olmalı'),
    RowProblem.missingName => tr('Ad soyad yok'),
    RowProblem.duplicateInFile => tr('Numara dosyada tekrar ediyor'),
    RowProblem.badPhone => tr('Veli telefonu geçersiz (atlanır)'),
  };

  String _columnLabel(RosterColumn c) => switch (c) {
    RosterColumn.number => tr('Öğrenci no'),
    RosterColumn.name => tr('Ad soyad (ya da ad)'),
    RosterColumn.surname => tr('Soyad (ayrıysa)'),
    RosterColumn.className => tr('Sınıf adı'),
    RosterColumn.phone => tr('Veli telefonu'),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final report = _report;
    final header = _rows.length > _headerRow
        ? _rows[_headerRow]
        : const <String>[];
    return Scaffold(
      appBar: AppBar(title: Text(tr('Öğrenci listesi yükle'))),
      bottomNavigationBar: report == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const ValueKey('import-go'),
                  onPressed: _busy || report.valid.isEmpty ? null : _import,
                  icon: const Icon(Icons.download_done_rounded),
                  label: Text(
                    tr('İçe aktar ({n} satır)', {'n': report.valid.length}),
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(_fileName ?? tr('Dosya seç (Excel / CSV)')),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'Sütunlar: öğrenci no, ad soyad; isteğe bağlı sınıf adı ve veli telefonu.',
            ),
            style: text.bodySmall,
          ),
          if (_sheets != null) ...[
            const SizedBox(height: 16),
            if (_sheets!.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _sheet,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Sayfa')),
                items: [
                  for (final s in _sheets!.keys)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() {
                  _sheet = v;
                  _columns = _rows.isEmpty ? {} : guessColumns(_rows.first);
                  _headerRow = 0;
                  _report = null;
                }),
              ),
            DropdownButtonFormField<int>(
              initialValue: _headerRow,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Başlık satırı')),
              items: [
                for (var i = 0; i < _rows.length && i < 10; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      '${i + 1}: ${_rows[i].where((c) => c.isNotEmpty).take(4).join(' | ')}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                _headerRow = v ?? 0;
                _columns = guessColumns(_rows[_headerRow]);
                _report = null;
              }),
            ),
            const SizedBox(height: 12),
            Text(tr('Sütun eşleştirme'), style: text.titleSmall),
            for (final c in RosterColumn.values)
              DropdownButtonFormField<int?>(
                key: ValueKey('col-${c.name}'),
                initialValue: _columns[c],
                isExpanded: true,
                decoration: InputDecoration(labelText: _columnLabel(c)),
                items: [
                  DropdownMenuItem(value: null, child: Text(tr('Yok'))),
                  for (var i = 0; i < header.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        header[i].isEmpty
                            ? tr('Sütun {n}', {'n': i + 1})
                            : header[i],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() {
                  v == null ? _columns.remove(c) : _columns[c] = v;
                  _report = null;
                }),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('roster-check'),
              style: _inline,
              onPressed: _busy ? null : _check,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(tr('Önizle ve doğrula')),
            ),
          ],
          if (report != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Doğrulama raporu'), style: text.titleSmall),
                    const SizedBox(height: 6),
                    Text(tr('{n} satır okundu', {'n': report.total})),
                    Text(
                      tr('{n} satır içe aktarılacak', {
                        'n': report.valid.length,
                      }),
                    ),
                    if (report.count(RowProblem.duplicateInFile) > 0)
                      Text(
                        tr('{n} mükerrer numara', {
                          'n': report.count(RowProblem.duplicateInFile),
                        }),
                      ),
                    if (report.count(RowProblem.badNumber) +
                            report.count(RowProblem.missingNumber) >
                        0)
                      Text(
                        tr('{n} hatalı ya da eksik numara', {
                          'n':
                              report.count(RowProblem.badNumber) +
                              report.count(RowProblem.missingNumber),
                        }),
                      ),
                    if (report.count(RowProblem.missingName) > 0)
                      Text(
                        tr('{n} adı eksik satır', {
                          'n': report.count(RowProblem.missingName),
                        }),
                      ),
                    if (report.count(RowProblem.badPhone) > 0)
                      Text(
                        tr('{n} geçersiz veli telefonu (numarasız aktarılır)', {
                          'n': report.count(RowProblem.badPhone),
                        }),
                      ),
                  ],
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _replace,
              onChanged: (v) => setState(() => _replace = v ?? false),
              title: Text(tr('Listeyi yenile')),
              subtitle: Text(
                tr(
                  'Bu dosyada olmayan ve henüz kayıt olmamış öğrenciler listeden silinir.',
                ),
              ),
            ),
            if (report.invalid.isNotEmpty) ...[
              Text(
                tr('Hatalı satırlar (atlanır; dokunup düzeltebilirsin)'),
                style: text.titleSmall,
              ),
              for (final r in report.invalid)
                Card(
                  color: scheme.errorContainer,
                  child: ListTile(
                    key: ValueKey('bad-row-${r.line}'),
                    title: Text(
                      tr('Satır {n}: {name}', {
                        'n': r.line,
                        'name': r.name.isEmpty ? '—' : r.name,
                      }),
                    ),
                    subtitle: Text(
                      [
                        if (r.number.isNotEmpty) r.number,
                        for (final p in r.problems) _problem(p),
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _fixRow(r),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(tr('İlk satırlar'), style: text.titleSmall),
            for (final r in report.valid.take(8))
              ListTile(
                dense: true,
                title: Text(r.name),
                subtitle: Text(
                  [
                    r.number,
                    if (r.className != null) r.className!,
                    if (r.phone != null) r.phone!,
                  ].join(' · '),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Hatalı satırı düzelt: (numara, ad) döner. Metin kutularını kendisi tutar
/// (pencere kapanırken silinmesinler).
class _FixRowDialog extends StatefulWidget {
  const _FixRowDialog({required this.row});

  final RosterRow row;

  @override
  State<_FixRowDialog> createState() => _FixRowDialogState();
}

class _FixRowDialogState extends State<_FixRowDialog> {
  late final _number = TextEditingController(text: widget.row.number);
  late final _name = TextEditingController(text: widget.row.name);

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Satır {n}', {'n': widget.row.line})),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('fix-number'),
          controller: _number,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr('Öğrenci no')),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: tr('Ad soyad')),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Vazgeç')),
      ),
      FilledButton(
        key: const ValueKey('fix-save'),
        style: _inline,
        onPressed: () => Navigator.pop(context, (
          cleanNumber(_number.text),
          _name.text.trim(),
        )),
        child: Text(tr('Düzelt')),
      ),
    ],
  );
}
