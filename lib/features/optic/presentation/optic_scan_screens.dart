import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../coach/data/coach_repository.dart';
import '../../coach/presentation/manager_widgets.dart';
import '../../exams/data/exam_repository.dart';
import '../../import/data/exam_file_parser.dart' show normalizeNumber;
import '../data/answer_key.dart';
import '../data/omr/omr_reader.dart';
import '../data/omr/optic_template.dart';
import '../data/optic_excel.dart';
import '../data/optic_repository.dart';
import 'answer_key_screens.dart' show shareBlankForm;
import 'exam_answers_view.dart';

/// Ağır iş: ayrı isolate'te çalışır (`compute` üst düzey fonksiyon ister).
OmrResult _read((Uint8List, String, String) a) =>
    readOptic(a.$1, templateById(a.$2)!, ExamType.fromDb(a.$3));

/// Bir deneme: optik okut, okunanları gör, Excel'i indir.
class OpticKeyScreen extends ConsumerStatefulWidget {
  const OpticKeyScreen({
    super.key,
    required this.keyId,
    this.basePath = '/coach',
  });

  final String keyId;
  final String basePath;

  @override
  ConsumerState<OpticKeyScreen> createState() => _OpticKeyScreenState();
}

class _OpticKeyScreenState extends ConsumerState<OpticKeyScreen> {
  var _reading = false;

  Future<void> _scan(AnswerKey key, ImageSource source) async {
    final template = templateById(key.templateId);
    if (template == null) {
      showMessage(
        context,
        tr('Bu denemenin optik formu uygulamada yok. Uygulamayı güncelle.'),
      );
      return;
    }
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    if (file == null || !mounted) return;
    setState(() => _reading = true);
    OmrResult result;
    try {
      final bytes = await file.readAsBytes();
      result = await compute(_read, (bytes, template.id, key.examType.db));
    } on OmrException catch (e) {
      if (mounted) {
        setState(() => _reading = false);
        await _problem(key, e.problem, source);
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _reading = false);
        showMessage(context, tr('Fotoğraf okunamadı. Tekrar dene.'));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _reading = false);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OpticReviewScreen(answerKey: key, result: result),
      ),
    );
    // Kamerayla okurken sıradaki optiğe kendiliğinden geç.
    if (saved == true && source == ImageSource.camera && mounted) {
      await _scan(key, source);
    }
  }

  Future<void> _problem(
    AnswerKey key,
    OmrProblem problem,
    ImageSource source,
  ) async {
    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Optik okunamadı')),
        content: Text(switch (problem) {
          OmrProblem.notImage => tr('Seçilen dosya bir fotoğraf değil.'),
          OmrProblem.anchorsNotFound => tr(
            'Formun dört köşesindeki siyah kareler bulunamadı. Kâğıdı düz bir yere koy, dört köşesi de görünecek şekilde tepeden ve iyi ışıkta çek.',
          ),
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Vazgeç')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Yeniden çek')),
          ),
        ],
      ),
    );
    if (again == true && mounted) await _scan(key, source);
  }

  Future<void> _export(AnswerKey key, List<OpticSheet> sheets) async {
    final students = ref.read(studentSummariesProvider).value ?? const [];
    try {
      final bytes = buildOpticWorkbook(
        key: key,
        sheets: sheets,
        students: {
          for (final s in students)
            s.id: (name: s.fullName, number: s.studentNumber),
        },
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: '${_fileName(key.name)}.xlsx',
            ),
          ],
          text: key.name,
        ),
      );
    } catch (e) {
      debugPrint('Optik Excel paylaşılamadı: $e');
      if (mounted) showMessage(context, tr('Excel hazırlanamadı.'));
    }
  }

  Future<void> _delete(AnswerKey key) async {
    final ok = await confirm(
      context,
      title: tr('Cevap anahtarı silinsin mi?'),
      message: tr(
        'Okunmuş optikler öğrencilerin denemelerinde kalır; onları "Denemeler" ekranından silebilirsin.',
      ),
    );
    if (!ok || !mounted) return;
    final router = GoRouter.of(context);
    try {
      await ref.read(opticRepositoryProvider).deleteKey(key.id);
      ref.invalidate(answerKeysProvider);
      router.pop();
    } catch (_) {
      if (mounted) {
        showMessage(context, tr('Yalnızca anahtarı ekleyen kişi silebilir.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(answerKeyProvider(widget.keyId));
    final sheets = ref.watch(opticSheetsProvider(widget.keyId));
    final students = {
      for (final s in ref.watch(studentSummariesProvider).value ?? const [])
        s.id: s,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          key.value?.name ?? tr('Optik okuma'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (key.value != null && sheets.value != null)
            IconButton(
              tooltip: tr('Excel indir'),
              icon: const Icon(Icons.download_outlined),
              onPressed: sheets.value!.isEmpty
                  ? null
                  : () => _export(key.value!, sheets.value!),
            ),
          if (key.value != null)
            PopupMenuButton<String>(
              onSelected: (_) => _delete(key.value!),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(tr('Cevap anahtarını sil')),
                ),
              ],
            ),
        ],
      ),
      body: AsyncView(
        value: key,
        onRetry: () => ref.invalidate(answerKeyProvider(widget.keyId)),
        builder: (k) {
          final template = templateById(k.templateId);
          final list = sheets.value ?? const <OpticSheet>[];
          final scored = [
            for (final s in list)
              (sheet: s, score: scoreOptic(k.items, s.answers, k.examType)),
          ]..sort((a, b) => b.score.net.compareTo(a.score.net));
          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(opticSheetsProvider(widget.keyId).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  [
                    k.examType.label,
                    formatLongDate(k.takenOn),
                    if (k.publisher != null) k.publisher!,
                    if (template != null) tr(template.trName),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_reading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: () => _scan(k, ImageSource.camera),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(tr('Optik oku')),
                  ),
                  TextButton.icon(
                    onPressed: () => _scan(k, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(tr('Galeriden seç')),
                  ),
                  if (template != null)
                    TextButton.icon(
                      onPressed: () => shareBlankForm(context, template),
                      icon: const Icon(Icons.print_outlined),
                      label: Text(tr('Bu denemenin boş kâğıdını indir (PDF)')),
                    ),
                ],
                const SizedBox(height: 8),
                PanelNotice(
                  icon: Icons.tips_and_updates_outlined,
                  message: tr(
                    'İpucu: kâğıdı düz bir masaya koy, dört köşedeki siyah kareler kadraja girsin ve gölge düşmesin. Kaydedince kamera sıradaki optik için yeniden açılır.',
                  ),
                ),
                if (scored.isNotEmpty) ...[
                  _WeakOutcomes(answerKey: k, sheets: list),
                  PanelSectionTitle(
                    title: tr('Okunan optikler'),
                    subtitle: tr('{n} öğrenci · nete göre', {'n': list.length}),
                  ),
                  for (final r in scored)
                    Card(
                      child: ListTile(
                        title: Text(
                          students[r.sheet.studentId]?.fullName ?? '?',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          tr('{c} D · {w} Y · {b} B', {
                            'c': r.score.correct,
                            'w': r.score.wrong,
                            'b': r.score.blank,
                          }),
                        ),
                        trailing: Text(
                          formatNet(r.score.net),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: ExamAnswersView(
                                examId: r.sheet.examId,
                                title: students[r.sheet.studentId]?.fullName,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String _fileName(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();

/// Sınıfın en çok yanlış / boş bıraktığı kazanımlar (ilk 5).
class _WeakOutcomes extends StatelessWidget {
  const _WeakOutcomes({required this.answerKey, required this.sheets});

  final AnswerKey answerKey;
  final List<OpticSheet> sheets;

  @override
  Widget build(BuildContext context) {
    final missed = <String, int>{};
    final subjectOf = <String, String>{};
    for (final s in sheets) {
      for (final m in scoreOptic(
        answerKey.items,
        s.answers,
        answerKey.examType,
      ).mistakes) {
        final o = m.item.outcome;
        if (o == null) continue;
        missed[o] = (missed[o] ?? 0) + 1;
        subjectOf[o] = m.item.subject;
      }
    }
    if (missed.isEmpty) return const SizedBox.shrink();
    final top = missed.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return SectionCard(
      title: tr('En çok yanlış yapılan kazanımlar'),
      subtitle: tr('Yanlış + boş, tüm okunan optiklerde'),
      child: Column(
        children: [
          for (final e in top.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${subjectByCode(subjectOf[e.key]!).name} · ${e.key}',
                    ),
                  ),
                  Text(
                    '${e.value}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: context.brand.danger,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Okunan optiğin kontrolü: öğrenci (formdaki numaradan), emin olunamayan
/// sorular (koç tek dokunuşla seçer) ve net önizlemesi.
class OpticReviewScreen extends ConsumerStatefulWidget {
  const OpticReviewScreen({
    super.key,
    required this.answerKey,
    required this.result,
  });

  final AnswerKey answerKey;
  final OmrResult result;

  @override
  ConsumerState<OpticReviewScreen> createState() => _OpticReviewScreenState();
}

class _OpticReviewScreenState extends ConsumerState<OpticReviewScreen> {
  String? _studentId;
  var _matchedByNumber = false;
  var _saving = false;

  /// Kitapçık türü: formdan okunan, işaret yoksa A; koç değiştirebilir.
  late String _booklet = widget.result.booklet ?? 'A';

  /// Belirsiz sorulara koçun seçimi ('' = boş).
  final _choices = <(String, int), String>{};

  @override
  void initState() {
    super.initState();
    final number = widget.result.studentNumber;
    final students = ref.read(studentSummariesProvider).value ?? const [];
    if (number != null && number.isNotEmpty && !widget.result.numberUncertain) {
      final n = normalizeNumber(number);
      final match = students
          .where(
            (s) =>
                s.studentNumber != null &&
                normalizeNumber(s.studentNumber!) == n,
          )
          .toList();
      if (match.length == 1) {
        _studentId = match.single.id;
        _matchedByNumber = true;
      }
    }
  }

  Map<String, List<String?>> get _answers {
    final out = {
      for (final e in widget.result.answers.entries) e.key: [...e.value],
    };
    for (final MapEntry(key: (subject, no), value: v) in _choices.entries) {
      final list = out[subject];
      if (list != null && no - 1 < list.length) {
        list[no - 1] = v.isEmpty ? null : v;
      }
    }
    return out;
  }

  Future<void> _save() async {
    final student = _studentId;
    if (student == null) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name =
        (ref.read(studentSummariesProvider).value ?? const [])
            .where((s) => s.id == student)
            .firstOrNull
            ?.fullName ??
        '';
    try {
      final r = await ref
          .read(opticRepositoryProvider)
          .submit(
            keyId: widget.answerKey.id,
            studentId: student,
            answers: _answers,
            booklet: _booklet,
          );
      ref.invalidate(opticSheetsProvider(widget.answerKey.id));
      ref.invalidate(answerKeysProvider);
      ref.invalidate(studentSummariesProvider);
      ref.invalidate(examsForStudentProvider(student));
      ref.invalidate(myExamBatchesProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            r.updated
                ? tr('{name}: optik yeniden okundu, {net} net.', {
                    'name': name,
                    'net': formatNet(r.net),
                  })
                : tr('{name}: {net} net kaydedildi.', {
                    'name': name,
                    'net': formatNet(r.net),
                  }),
          ),
        ),
      );
      navigator.pop(true);
    } on OpticLockedException {
      if (mounted) {
        showMessage(
          context,
          tr('Bu öğrencinin denemesi 7 günden eski; optiği yeniden okunamaz.'),
        );
      }
    } on NoBookletBException {
      if (mounted) {
        showMessage(
          context,
          tr('Cevap anahtarında B kitapçığı numaraları yok.'),
        );
      }
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final result = widget.result;
    final students = ref.watch(studentSummariesProvider).value ?? const [];
    final already = ref
        .watch(opticSheetsProvider(widget.answerKey.id))
        .value
        ?.any((s) => s.studentId == _studentId);
    final key = widget.answerKey;
    final score = scoreOptic(
      key.items,
      _answers,
      key.examType,
      booklet: _booklet,
    );
    final noB = _booklet == 'B' && !key.hasBookletB;
    final otherSession =
        result.session != null && result.session != key.examType.db;
    final unresolved = result.uncertain
        .where((u) => !_choices.containsKey((u.subject, u.number)))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('Optiği kontrol et'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: tr('Öğrenci'),
            subtitle: result.studentNumber == null
                ? null
                : result.studentNumber!.isEmpty
                ? tr('Formda öğrenci numarası işaretlenmemiş.')
                : result.numberUncertain
                ? tr('Formdaki numara net okunamadı: {n}', {
                    'n': result.studentNumber!,
                  })
                : _matchedByNumber
                ? tr('Formdaki numaradan bulundu: {n}', {
                    'n': result.studentNumber!,
                  })
                : tr('{n} numaralı öğrencin yok; listeden seç.', {
                    'n': result.studentNumber!,
                  }),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _studentId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('Öğrenci seç')),
                  items: [
                    for (final s in students)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.studentNumber == null
                              ? s.fullName
                              : '${s.fullName} (${s.studentNumber})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _studentId = v;
                    _matchedByNumber = false;
                  }),
                ),
                if (already == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Bu öğrencinin optiği daha önce okunmuştu; kaydedersen sonucu güncellenir.',
                    ),
                    style: text.bodySmall?.copyWith(
                      color: context.brand.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (otherSession) ...[
            PanelNotice(
              icon: Icons.warning_amber_rounded,
              color: context.brand.danger,
              message: tr(
                'Formda {form} işaretli ama bu deneme {key}. Doğru denemeyi okuttuğundan emin ol.',
                {'form': result.session!, 'key': key.examType.label},
              ),
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: tr('Kitapçık'),
            subtitle: result.bookletUncertain
                ? tr('Formdaki kitapçık işareti net değil; kâğıda bakıp seç.')
                : result.booklet == null
                ? tr('Formda kitapçık işaretlenmemiş; A sayıldı.')
                : tr('Formdan okundu: {b}', {'b': result.booklet!}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'A', label: Text('A')),
                    ButtonSegment(value: 'B', label: Text('B')),
                  ],
                  selected: {_booklet},
                  onSelectionChanged: (s) =>
                      setState(() => _booklet = s.single),
                ),
                if (noB) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Bu denemenin cevap anahtarında B kitapçığı numaraları yok. Kazanım Excel\'ine "B Soru No" sütununu ekleyip denemeyi yeniden oluştur.',
                    ),
                    style: text.bodySmall?.copyWith(
                      color: context.brand.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (result.uncertain.isNotEmpty) ...[
            SectionCard(
              title: tr('Emin olunamayan sorular ({n})', {
                'n': result.uncertain.length,
              }),
              subtitle: tr(
                'İki şık işaretli ya da işaret silik. Kâğıda bakıp doğru şıkkı seç; seçmezsen boş sayılır.',
              ),
              child: Column(
                children: [
                  for (final u in result.uncertain)
                    _UncertainRow(
                      mark: u,
                      choice: _choices[(u.subject, u.number)],
                      onChoice: (v) =>
                          setState(() => _choices[(u.subject, u.number)] = v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: tr('Sonuç'),
            subtitle: tr('{c} doğru · {w} yanlış · {b} boş', {
              'c': score.correct,
              'w': score.wrong,
              'b': score.blank,
            }),
            trailing: Text(
              formatNet(score.net),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            child: Column(
              children: [
                for (final MapEntry(key: code, value: r)
                    in score.bySubject.entries)
                  Row(
                    children: [
                      Expanded(child: Text(subjectByCode(code).name)),
                      Text('${r.correct} D  ${r.wrong} Y  ${r.blank} B'),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 48,
                        child: Text(
                          formatNet(calculateNet(r.correct, r.wrong)),
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _studentId == null || _saving || noB ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(
              unresolved > 0
                  ? tr('Kaydet ({n} soru boş sayılacak)', {'n': unresolved})
                  : tr('Kaydet'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Vazgeç')),
          ),
        ],
      ),
    );
  }
}

class _UncertainRow extends StatelessWidget {
  const _UncertainRow({
    required this.mark,
    required this.choice,
    required this.onChoice,
  });

  final UncertainMark mark;
  final String? choice;
  final ValueChanged<String> onChoice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('{subject} {n}. soru · görünen: {c}', {
              'subject': subjectByCode(mark.subject).name,
              'n': mark.number,
              'c': mark.candidates.split('').join(', '),
            }),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final o in ['A', 'B', 'C', 'D', 'E', ''])
                ChoiceChip(
                  label: Text(o.isEmpty ? tr('Boş') : o),
                  selected: choice == o,
                  onSelected: (_) => onChoice(o),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
