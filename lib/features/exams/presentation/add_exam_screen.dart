import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../shared/format.dart';
import '../../coach/data/coach_repository.dart';
import '../data/exam.dart';
import '../data/exam_repository.dart';
import '../../../core/i18n/i18n.dart';

/// Koçun bir öğrenci için elle deneme girmesi.
class AddExamScreen extends ConsumerStatefulWidget {
  const AddExamScreen({
    super.key,
    required this.studentId,
    this.initialType = ExamType.tyt,
  });

  final String studentId;
  final ExamType initialType;

  @override
  ConsumerState<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends ConsumerState<AddExamScreen> {
  late ExamType _type = widget.initialType;
  FieldType _aytField = FieldType.say;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final _name = TextEditingController();
  final _publisher = TextEditingController();

  /// Ders kodu → [doğru, yanlış, boş] alanları. Tür değişse de korunur.
  final _inputs = <String, List<TextEditingController>>{};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _publisher.dispose();
    for (final row in _inputs.values) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  FieldType? get _field => switch (_type) {
    ExamType.tyt => null,
    ExamType.ayt => _aytField,
    ExamType.ydt => FieldType.dil,
  };

  List<ExamSubject> get _subjects => subjectsFor(_type, _field);

  List<TextEditingController> _row(String code) => _inputs.putIfAbsent(
    code,
    () => List.generate(3, (_) => TextEditingController()),
  );

  int _value(TextEditingController c) => int.tryParse(c.text) ?? 0;

  /// Herhangi bir alanı doldurulmuş dersler. Boş girilmezse kalan sorular
  /// boş sayılır.
  List<SubjectResult> get _results => [
    for (final s in _subjects)
      if (_row(s.code).any((c) => c.text.isNotEmpty))
        () {
          final [correct, wrong, blank] = _row(s.code);
          final c = _value(correct), w = _value(wrong);
          return SubjectResult(
            code: s.code,
            correct: c,
            wrong: w,
            blank: blank.text.isEmpty
                ? (s.questionCount - c - w).clamp(0, s.questionCount)
                : _value(blank),
          );
        }(),
  ];

  bool _isOver(ExamSubject s) =>
      _row(s.code).fold<int>(0, (sum, c) => sum + _value(c)) > s.questionCount;

  double get _totalNet => _results.fold(0, (sum, r) => sum + r.net);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _showError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _showError(tr('Denemeye bir ad ver (ör. "3D Türkiye Geneli 4").'));
      return;
    }
    final over = _subjects.where(_isOver).toList();
    if (over.isNotEmpty) {
      _showError(
        tr('{p0}: doğru + yanlış + boş, {p1} soruyu geçemez.', {
          'p0': over.first.name,
          'p1': over.first.questionCount,
        }),
      );
      return;
    }
    final results = _results;
    if (results.isEmpty) {
      _showError(tr('En az bir dersin sonucunu gir.'));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(examRepositoryProvider)
          .createExam(
            studentId: widget.studentId,
            draft: ExamDraft(
              examType: _type,
              field: _field,
              name: _name.text.trim(),
              publisher: _publisher.text.trim().isEmpty
                  ? null
                  : _publisher.text.trim(),
              takenOn: _date,
              results: results,
            ),
          );
      ref.invalidate(examsForStudentProvider(widget.studentId));
      ref.invalidate(studentSummariesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Deneme kaydedildi: {p0} net 🐝', {'p0': formatNet(_totalNet)}),
          ),
        ),
      );
      context.pop();
    } catch (_) {
      if (mounted) _showError(tr('Deneme kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subjects = _subjects;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Deneme ekle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          SegmentedButton<ExamType>(
            showSelectedIcon: false,
            segments: [
              for (final t in ExamType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          if (_type == ExamType.ayt) ...[
            const SizedBox(height: 10),
            SegmentedButton<FieldType>(
              showSelectedIcon: false,
              segments: [
                for (final f in aytFields)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {_aytField},
              onSelectionChanged: (s) => setState(() => _aytField = s.first),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr('Deneme adı'),
              hintText: tr('ör. Türkiye Geneli 4'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _publisher,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: tr('Yayın (isteğe bağlı)'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: tr('Tarih'),
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                    ),
                    child: Text(formatShortDate(_date)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('Sonuçlar'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final h in [tr('Doğru'), tr('Yanlış'), tr('Boş')])
                SizedBox(
                  width: 58,
                  child: Text(
                    h,
                    textAlign: TextAlign.center,
                    style: text.labelSmall,
                  ),
                ),
              SizedBox(
                width: 52,
                child: Text(
                  tr('Net'),
                  textAlign: TextAlign.end,
                  style: text.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < subjects.length; i++) ...[
            if (subjects[i].group != null &&
                (i == 0 || subjects[i - 1].group != subjects[i].group) &&
                subjects[i].group != subjects[i].name)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 2),
                child: Text(
                  subjects[i].group!,
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            _SubjectRow(
              key: ValueKey('subject-${subjects[i].code}'),
              subject: subjects[i],
              controllers: _row(subjects[i].code),
              isOver: _isOver(subjects[i]),
              onChanged: () => setState(() {}),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Toplam net'), style: text.bodySmall),
                  Text(
                    formatNet(_totalNet),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Text(tr('Kaydet')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    super.key,
    required this.subject,
    required this.controllers,
    required this.isOver,
    required this.onChanged,
  });

  final ExamSubject subject;
  final List<TextEditingController> controllers;
  final bool isOver;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final filled = controllers.any((c) => c.text.isNotEmpty);
    final correct = int.tryParse(controllers[0].text) ?? 0;
    final wrong = int.tryParse(controllers[1].text) ?? 0;
    final net = calculateNet(correct, wrong);
    // Boş girilmezse kalan sorular boş sayılır; ipucu olarak göster.
    final remaining = (subject.questionCount - correct - wrong).clamp(
      0,
      subject.questionCount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.name, style: text.bodyMedium),
                Text(
                  isOver
                      ? tr('{p0} soruyu geçti', {'p0': subject.questionCount})
                      : '${subject.questionCount} soru',
                  style: text.labelSmall?.copyWith(
                    color: isOver ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < 3; i++)
            SizedBox(
              width: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TextField(
                  controller: controllers[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: i == 2 && filled ? '$remaining' : '0',
                    enabledBorder: isOver
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.error,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 52,
            child: Text(
              filled ? formatNet(net) : '–',
              textAlign: TextAlign.end,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
