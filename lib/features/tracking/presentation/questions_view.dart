import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/daily_bar_chart.dart';
import '../../../shared/widgets/panel.dart';
import '../../auth/data/auth_repository.dart';
import '../../coach/data/coach_repository.dart';
import '../../student/presentation/home_sky.dart';
import '../data/tracking_models.dart';
import '../data/tracking_repository.dart';
import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/effects.dart';

/// Öğrencinin soru takibi sekmesi.
class QuestionsScreen extends ConsumerWidget {
  const QuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: SkyAppBar(title: Text(tr('Soru takibi'))),
      floatingActionButton: profile == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddQuestionSheet(context, profile.id),
              icon: const Icon(Icons.add),
              label: Text(tr('Soru ekle')),
            ),
      body: profile == null
          ? const BizzLoader()
          : QuestionsView(studentId: profile.id, canEdit: true),
    );
  }
}

Future<void> showAddQuestionSheet(BuildContext context, String studentId) =>
    showModalBottomSheet<void>(
      context: context,
      // Alt menünün üstünde açılsın (sekme içi gezgin değil).
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddQuestionSheet(studentId: studentId),
    );

/// Soru istatistikleri ve kayıtlar. [canEdit] yalnızca öğrencinin kendisi.
class QuestionsView extends ConsumerWidget {
  const QuestionsView({
    super.key,
    required this.studentId,
    this.canEdit = false,
    this.bottomPadding = 96,
  });

  final String studentId;
  final bool canEdit;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(questionLogsProvider(studentId));
    final goals = ref.watch(goalsProvider(studentId)).value;

    return AsyncView(
      value: logs,
      onRetry: () => ref.invalidate(questionLogsProvider(studentId)),
      builder: (list) {
        if (list.isEmpty) {
          return ListView(
            children: [
              EmptyState(
                title: tr('Henüz soru kaydı yok'),
                message: canEdit
                    ? tr(
                        'Çözdüğün soruları ders ders gir; günlük hedefini ve gelişimini burada takip et.',
                      )
                    : tr(
                        'Öğrenci soru girdikçe istatistikler burada görünecek.',
                      ),
                action: canEdit
                    ? FilledButton.icon(
                        onPressed: () =>
                            showAddQuestionSheet(context, studentId),
                        icon: const Icon(Icons.add),
                        label: Text(tr('İlk kaydını ekle')),
                      )
                    : null,
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(questionLogsProvider(studentId).future),
          child: _QuestionsContent(
            logs: list,
            dailyGoal: goals?.dailyQuestions,
            canEdit: canEdit,
            studentId: studentId,
            bottomPadding: bottomPadding,
          ),
        );
      },
    );
  }
}

class _QuestionsContent extends ConsumerWidget {
  const _QuestionsContent({
    required this.logs,
    required this.dailyGoal,
    required this.canEdit,
    required this.studentId,
    required this.bottomPadding,
  });

  final List<QuestionLog> logs;
  final int? dailyGoal;
  final bool canEdit;
  final String studentId;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final days = lastDays(7);
    final week = logs.where((l) => !l.loggedOn.isBefore(days.first)).toList();
    final todayTotal = logs
        .where((l) => l.loggedOn == today)
        .fold<int>(0, (s, l) => s + l.total);
    final weekTotal = week.fold<int>(0, (s, l) => s + l.total);
    final weekCorrect = week.fold<int>(0, (s, l) => s + l.correct);
    final accuracy = weekTotal == 0
        ? 0
        : (weekCorrect * 100 / weekTotal).round();
    final perDay = [
      for (final d in days)
        logs.where((l) => l.loggedOn == d).fold<int>(0, (s, l) => s + l.total),
    ];

    // Ders dağılımı (30 gün)
    final bySubject = <String, (int, int)>{}; // kod → (toplam, doğru)
    for (final l in logs) {
      final cur = bySubject[l.subjectCode] ?? (0, 0);
      bySubject[l.subjectCode] = (cur.$1 + l.total, cur.$2 + l.correct);
    }
    final subjects = bySubject.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    final maxSubject = subjects.isEmpty ? 1 : subjects.first.value.$1;

    // Tarihe göre gruplu kayıtlar
    final byDay = <DateTime, List<QuestionLog>>{};
    for (final l in logs) {
      byDay.putIfAbsent(l.loggedOn, () => []).add(l);
    }
    final text = Theme.of(context).textTheme;
    final brand = context.brand;
    final dayFormat = DateFormat('d MMMM EEEE', localeTag);

    final top = <Widget>[
      StatRow(
        children: [
          GlowStat(
            icon: Icons.today_rounded,
            label: tr('Bugün'),
            value: todayTotal.toDouble(),
            caption: dailyGoal == null
                ? tr('soru')
                : tr('/ {n} hedef', {'n': dailyGoal}),
            color: brand.primary,
          ),
          GlowStat(
            icon: Icons.date_range_rounded,
            label: tr('Son 7 gün'),
            value: weekTotal.toDouble(),
            caption: tr('soru'),
            color: brand.secondary,
          ),
          GlowStat(
            icon: Icons.verified_rounded,
            label: tr('Doğruluk'),
            value: accuracy.toDouble(),
            format: (v) => '%${v.round()}',
            caption: tr('son 7 gün'),
            color: brand.success,
          ),
        ],
      ),
      SectionCard(
        title: tr('Son 7 gün'),
        subtitle: tr('Günlük çözülen soru'),
        child: DailyBarChart(
          days: days,
          values: perDay,
          unit: tr('soru'),
          goal: dailyGoal,
        ),
      ),
      SectionCard(
        title: tr('Ders dağılımı'),
        subtitle: tr('Son 30 gün · soru sayısı ve doğruluk'),
        child: Column(
          children: [
            for (final e in subjects)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SubjectRow(
                  subject: subjectByCode(e.key),
                  total: e.value.$1,
                  correct: e.value.$2,
                  max: maxSubject,
                ),
              ),
          ],
        ),
      ),
      PanelSectionTitle(
        title: tr('Kayıtlar'),
        subtitle: tr('{n} kayıt', {'n': logs.length}),
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
      children: [
        for (final (i, c) in top.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          staggered(i, c),
        ],
        for (final day in byDay.keys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              day == today ? tr('Bugün') : dayFormat.format(day),
              style: text.labelLarge,
            ),
          ),
          for (final l in byDay[day]!)
            _LogTile(log: l, canEdit: canEdit, studentId: studentId),
        ],
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.total,
    required this.correct,
    required this.max,
  });

  final ExamSubject subject;
  final int total;
  final int correct;
  final int max;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final track = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);
    final accuracy = total == 0 ? 0 : (correct * 100 / total).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${subject.examType.label} ${subject.name}',
                style: text.bodyMedium,
              ),
            ),
            Text(
              '$total soru',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text('  · %$accuracy', style: text.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AnimatedLinearProgress(
            value: total / max,
            minHeight: 8,
            backgroundColor: track,
            color: context.brand.primaryDeep,
          ),
        ),
      ],
    );
  }
}

class _LogTile extends ConsumerWidget {
  const _LogTile({
    required this.log,
    required this.canEdit,
    required this.studentId,
  });

  final QuestionLog log;
  final bool canEdit;
  final String studentId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: tr('Kayıt silinsin mi?'),
      message: tr('{p0} · {p1} soru kaydı silinecek.', {
        'p0': log.subject.name,
        'p1': log.total,
      }),
    );
    if (!ok) return;
    await ref.read(trackingRepositoryProvider).deleteQuestionLog(log.id);
    ref.invalidate(questionLogsProvider(studentId));
    ref.invalidate(studentSummariesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final detail = [
      'D ${log.correct}',
      'Y ${log.wrong}',
      'B ${log.blank}',
      tr('Net {p0}', {'p0': formatNet(log.net)}),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        title: Text(
          '${log.subject.examType.label} ${log.subject.name}'
          '${log.topicName == null ? '' : ' · ${log.topicName}'}',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [detail, if (log.source?.isNotEmpty ?? false) log.source!].join('\n'),
        ),
        isThreeLine: log.source?.isNotEmpty ?? false,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${log.total}',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (canEdit)
              IconButton(
                tooltip: tr('Sil'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddQuestionSheet extends ConsumerStatefulWidget {
  const _AddQuestionSheet({required this.studentId});

  final String studentId;

  @override
  ConsumerState<_AddQuestionSheet> createState() => _AddQuestionSheetState();
}

class _AddQuestionSheetState extends ConsumerState<_AddQuestionSheet> {
  String _subject = 'TYT_MAT';
  int? _topicId;
  DateTime _date = dateOnly(DateTime.now());
  final _correct = TextEditingController();
  final _wrong = TextEditingController();
  final _blank = TextEditingController();
  final _source = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_correct, _wrong, _blank, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  int _v(TextEditingController c) => int.tryParse(c.text) ?? 0;

  Future<void> _save() async {
    final c = _v(_correct), w = _v(_wrong), b = _v(_blank);
    if (c + w + b == 0) {
      setState(() => _error = tr('En az bir değer gir.'));
      return;
    }
    if (c + w + b > 500) {
      setState(() => _error = tr('Tek kayıtta en fazla 500 soru girilebilir.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(trackingRepositoryProvider)
          .addQuestionLog(
            widget.studentId,
            QuestionLogDraft(
              subjectCode: _subject,
              topicId: _topicId,
              correct: c,
              wrong: w,
              blank: b,
              loggedOn: _date,
              source: _source.text.trim().isEmpty ? null : _source.text.trim(),
            ),
          );
      final today = dateOnly(DateTime.now());
      final before =
          (ref.read(questionLogsProvider(widget.studentId)).value ?? const [])
              .where((l) => l.loggedOn == today)
              .fold<int>(0, (s, l) => s + l.total);
      final goal = ref
          .read(goalsProvider(widget.studentId))
          .value
          ?.dailyQuestions;
      final reached =
          goal != null &&
          dateOnly(_date) == today &&
          before < goal &&
          before + c + w + b >= goal;
      ref.invalidate(questionLogsProvider(widget.studentId));
      if (!mounted) return;
      if (reached) celebrate(context);
      Navigator.pop(context);
      showMessage(
        context,
        reached
            ? tr('Günlük soru hedefini tamamladın! 🎉')
            : tr('{p0} soru kaydedildi 🐝', {'p0': c + w + b}),
      );
    } catch (_) {
      setState(() => _error = tr('Kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topics = (ref.watch(topicsProvider).value ?? const [])
        .where((t) => t.subjectCode == _subject)
        .toList();
    final total = _v(_correct) + _v(_wrong) + _v(_blank);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Soru ekle'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SubjectDropdown(
              value: _subject,
              onChanged: (v) => setState(() {
                _subject = v;
                _topicId = null;
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              initialValue: _topicId,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Konu (isteğe bağlı)')),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(tr('Karışık / belirtme')),
                ),
                for (final t in topics)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => _topicId = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (i, (label, c)) in [
                  (tr('Doğru'), _correct),
                  (tr('Yanlış'), _wrong),
                  (tr('Boş'), _blank),
                ].indexed) ...[
                  Expanded(
                    child: TextField(
                      controller: c,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: InputDecoration(labelText: label),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(tr('Hızlı doğru:'), style: text.labelMedium),
                      for (final n in const [5, 10, 20])
                        ActionChip(
                          label: Text('+$n'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _correct.text =
                                '${(_v(_correct) + n).clamp(0, 500)}';
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: Text(
                    tr('Net {p0}', {
                      'p0': formatNet(calculateNet(_v(_correct), _v(_wrong))),
                    }),
                    key: ValueKey('${_v(_correct)}-${_v(_wrong)}'),
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: context.brand.primaryDeep,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _source,
                    decoration: InputDecoration(
                      labelText: tr('Kaynak (isteğe bağlı)'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: tr('Tarih')),
                      child: Text(formatShortDate(_date)),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                total == 0
                    ? tr('Kaydet')
                    : tr('{total} soruyu kaydet', {'total': total}),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sınav türüne göre gruplanmış ders seçici.
class SubjectDropdown extends StatelessWidget {
  const SubjectDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.allowNone = false,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String? label;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label ?? tr('Ders')),
      items: [
        if (allowNone)
          DropdownMenuItem(value: null, child: Text(tr('Belirtme'))),
        for (final s in examSubjects)
          DropdownMenuItem(
            value: s.code,
            child: Text('${s.examType.label} · ${s.name}'),
          ),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}
