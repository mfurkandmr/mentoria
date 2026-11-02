import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../coach/presentation/manager_widgets.dart';
import '../../import/data/spreadsheet_reader.dart';
import '../../tracking/data/tracking_repository.dart';
import '../data/answer_key.dart';
import '../data/omr/optic_form_print.dart';
import '../data/omr/optic_template.dart';
import '../data/optic_repository.dart';

/// Boş cevap kâğıdını A4 PDF olarak paylaşır (yazdırıp çoğaltmak için).
/// [template] verilmezse koç listeden seçer. Yazı tipi uygulamanınki
/// (Türkçe karakterler).
Future<void> shareBlankForm(
  BuildContext context, [
  OpticTemplate? template,
]) async {
  final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;
  final messenger = ScaffoldMessenger.of(context);
  final t = template ?? await _pickTemplate(context);
  if (t == null) return;
  try {
    final pdf = await renderOpticFormPdf(t, fontFamily: font);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            pdf,
            mimeType: 'application/pdf',
            name: '${t.id.replaceAll('_', '-')}-cevap-kagidi.pdf',
          ),
        ],
        text: tr(t.trName),
      ),
    );
  } catch (e) {
    debugPrint('Optik form hazırlanamadı: $e');
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Form hazırlanamadı. Tekrar dene.'))),
    );
  }
}

/// İndirilecek formu sordurur (tek form varsa doğrudan o).
Future<OpticTemplate?> _pickTemplate(BuildContext context) {
  if (opticTemplates.length == 1) return Future.value(opticTemplates.single);
  return showModalBottomSheet<OpticTemplate>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              tr('Hangi cevap kâğıdı?'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          for (final t in opticTemplates)
            ListTile(
              leading: Icon(
                t.track != null
                    ? Icons.view_week_outlined
                    : Icons.crop_free_rounded,
              ),
              title: Text(tr(t.trName)),
              subtitle: Text(
                t.track != null
                    ? tr(
                        'Kenarında zamanlama çizgisi olan, yayınevi tarzı form',
                      )
                    : tr(
                        'Köşelerinde siyah kare olan, kamera için en sağlam form',
                      ),
              ),
              onTap: () => Navigator.pop(context, t),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Optik okuma: kurumdaki denemeler (cevap anahtarları). Koç önce
/// kazanım / cevap anahtarı Excel'ini yükler, sonra optikleri okutur.
class OpticKeysScreen extends ConsumerWidget {
  const OpticKeysScreen({super.key, this.basePath = '/coach'});

  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(answerKeysProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('Optik okuma'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: tr('Boş cevap kâğıdını indir (PDF)'),
            icon: const Icon(Icons.print_outlined),
            onPressed: () => shareBlankForm(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('$basePath/optic/new'),
        icon: const Icon(Icons.add),
        label: Text(tr('Yeni deneme')),
      ),
      body: AsyncView(
        value: keys,
        onRetry: () => ref.invalidate(answerKeysProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(answerKeysProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              PanelNotice(
                icon: Icons.document_scanner_outlined,
                message: tr(
                  'Önce denemenin kazanım ve cevap anahtarı Excel\'ini yükle. Sonra optikleri telefonla tek tek çek; her öğrencinin yanlışları kazanımlarıyla birlikte kaydedilir.',
                ),
              ),
              const SizedBox(height: 8),
              PanelNotice(
                icon: Icons.print_outlined,
                message: tr(
                  'Öğrencilere cevap kâğıdını dağıt: TYT ve AYT aynı kâğıtta. PDF\'i indirip istediğin kadar çoğaltabilirsin.',
                ),
                onTap: () => shareBlankForm(context),
              ),
              if (list.isEmpty)
                EmptyState(
                  title: tr('Henüz deneme yok'),
                  message: tr(
                    'Yeni deneme ekleyip kazanım tablosunu yükleyince optik okumaya başlayabilirsin.',
                  ),
                ),
              for (final k in list)
                Card(
                  key: ValueKey(k.id),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.brand.primary.withValues(
                        alpha: 0.2,
                      ),
                      child: Text(
                        k.examType.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      k.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        formatLongDate(k.takenOn),
                        if (k.publisher != null) k.publisher!,
                        tr('{n} optik okundu', {'n': k.readCount}),
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('$basePath/optic/${k.id}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yeni deneme: ad, tür, yayınevi, tarih, optik form ve kazanım Excel'i.
class NewAnswerKeyScreen extends ConsumerStatefulWidget {
  const NewAnswerKeyScreen({super.key, this.basePath = '/coach'});

  final String basePath;

  @override
  ConsumerState<NewAnswerKeyScreen> createState() => _NewAnswerKeyScreenState();
}

class _NewAnswerKeyScreenState extends ConsumerState<NewAnswerKeyScreen> {
  final _name = TextEditingController();
  final _publisher = TextEditingController();
  var _type = ExamType.tyt;
  var _date = DateTime.now();
  String? _templateId = opticTemplates
      .where((t) => t.examTypes.contains(ExamType.tyt))
      .firstOrNull
      ?.id;
  String? _fileName;
  SheetRows? _rows;
  ParsedKey? _parsed;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _publisher.dispose();
    super.dispose();
  }

  List<OpticTemplate> get _templates =>
      opticTemplates.where((t) => t.examTypes.contains(_type)).toList();

  void _setType(ExamType t) {
    setState(() {
      _type = t;
      _templateId = _templates.firstOrNull?.id;
    });
    _reparse();
  }

  Future<void> _pick() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final Uint8List bytes = Uint8List.fromList(
        await files.first.readAsBytes(),
      );
      final book = readSpreadsheet(bytes);
      // En çok satırı olan sayfa.
      final rows = book.values.reduce((a, b) => a.length >= b.length ? a : b);
      setState(() {
        _fileName = files.first.name;
        _rows = rows;
      });
      _reparse();
    } on SpreadsheetException {
      if (mounted) {
        setState(() {
          _parsed = null;
          _error = tr(
            'Dosya okunamadı. Excel (.xlsx, .xls) ya da CSV kazanım tablosu seç.',
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _parsed = null;
          _error = tr(
            'Dosya açılamadı. Telefona indirip yeniden seçmeyi dene (bulut klasörlerinden okuma bazen engellenir).',
          );
        });
      }
    }
  }

  void _reparse() {
    final rows = _rows;
    if (rows == null) return;
    try {
      final parsed = parseAnswerKey(rows, _type);
      setState(() {
        _parsed = parsed;
        _error = null;
      });
    } on AnswerKeyFormatException catch (e) {
      setState(() {
        _parsed = null;
        _error = e.message;
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final parsed = _parsed;
    final templateId = _templateId;
    if (parsed == null || templateId == null) return;
    if (_name.text.trim().length < 2) {
      showMessage(context, tr('Denemeye bir ad ver.'));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(opticRepositoryProvider);
    final router = GoRouter.of(context);
    try {
      // Kazanımları konu takibine bağla (kazanım konunun adını içeriyorsa).
      final topics = await ref.read(topicsProvider.future);
      final items = [
        for (final i in parsed.items)
          i.withTopic(matchTopic(i.outcome, i.subject, topics)),
      ];
      final id = await repo.createKey(
        name: _name.text.trim(),
        examType: _type,
        publisher: _publisher.text.trim().isEmpty
            ? null
            : _publisher.text.trim(),
        takenOn: _date,
        templateId: templateId,
        items: items,
      );
      ref.invalidate(answerKeysProvider);
      router.pushReplacement('${widget.basePath}/optic/$id');
    } catch (_) {
      if (mounted) {
        showMessage(context, tr('Deneme kaydedilemedi. Tekrar dene.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final parsed = _parsed;
    final templates = _templates;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('Yeni deneme'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: tr('Deneme adı'),
              hintText: tr('ör. Kasım TYT-1'),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ExamType>(
            segments: [
              for (final t in const [ExamType.tyt, ExamType.ayt])
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => _setType(s.single),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _publisher,
            decoration: InputDecoration(
              labelText: tr('Yayınevi (isteğe bağlı)'),
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(tr('Deneme tarihi')),
            subtitle: Text(formatLongDate(_date)),
            onTap: _pickDate,
          ),
          if (templates.isEmpty)
            PanelNotice(
              icon: Icons.warning_amber_rounded,
              color: context.brand.danger,
              message: tr(
                'Bu sınav türü için uygulamada optik form şablonu yok. Kullandığınız formun boş ve dolu birer fotoğrafını gönderin; şablon eklenince okuyabilirsiniz.',
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _templateId,
              decoration: InputDecoration(labelText: tr('Optik form')),
              items: [
                for (final t in templates)
                  DropdownMenuItem(value: t.id, child: Text(tr(t.trName))),
              ],
              onChanged: (v) => setState(() => _templateId = v),
            ),
          const SizedBox(height: 20),
          SectionCard(
            title: tr('Kazanım ve cevap anahtarı'),
            subtitle: tr(
              'Excel\'de "Ders", "Soru No", "Cevap" ve "Kazanım" sütunları olmalı. Ders yerine test adı (ör. Sosyal Bilimler 1–20) da olur.',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_fileName ?? tr('Excel dosyası seç')),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (parsed != null) ...[
                  const SizedBox(height: 12),
                  _KeySummary(parsed: parsed, type: _type),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: parsed == null || _templateId == null || _saving
                ? null
                : _save,
            icon: const Icon(Icons.check),
            label: Text(tr('Kaydet ve optik okumaya geç')),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Kaydettikten sonra cevap anahtarı değiştirilemez; yanlışsa silip yeniden ekle.',
            ),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Okunan tablonun özeti: ders ders soru sayısı, eksik sorular, atlanan
/// satırlar.
class _KeySummary extends StatelessWidget {
  const _KeySummary({required this.parsed, required this.type});

  final ParsedKey parsed;
  final ExamType type;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = parsed.items;
    final outcomes = items.where((i) => i.outcome != null).length;
    final cancelled = items.where((i) => i.correct == null).length;
    final subjects = [
      for (final s in examSubjects.where((s) => s.examType == type))
        if (items.any((i) => i.subject == s.code)) s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('{n} soru · {k} kazanım · {c} iptal', {
            'n': items.length,
            'k': outcomes,
            'c': cancelled,
          }),
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        for (final s in subjects)
          () {
            final n = items.where((i) => i.subject == s.code).length;
            final missing = s.questionCount - n;
            return Text(
              missing > 0
                  ? tr(
                      '{subject}: {n}/{total} soru (eksik sorular değerlendirilmez)',
                      {'subject': s.name, 'n': n, 'total': s.questionCount},
                    )
                  : tr('{subject}: {n} soru', {'subject': s.name, 'n': n}),
              style: text.bodySmall?.copyWith(
                color: missing > 0 ? context.brand.danger : null,
              ),
            );
          }(),
        if (parsed.skipped.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            tr('Okunamayan {n} satır: {rows}', {
              'n': parsed.skipped.length,
              'rows': parsed.skipped.take(5).join(', '),
            }),
            style: text.bodySmall?.copyWith(color: context.brand.danger),
          ),
        ],
      ],
    );
  }
}
