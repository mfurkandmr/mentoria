import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/exam_subjects.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/widgets/common.dart';
import '../../data/cockpit_repository.dart';
import 'cockpit_theme.dart';
import 'section_states.dart';
import '../../../../core/design/haptics.dart';
import '../../../../core/design/motion.dart';

/// Deneme takvimi: kurumun planladığı denemeler. En yakını özet
/// şeridinde "Yaklaşan deneme" olarak görünür.
class ExamPlansScreen extends ConsumerWidget {
  const ExamPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(cockpitProvider);
    final df = DateFormat('d MMMM yyyy, EEEE', localeTag);
    return CockpitThemed(
      child: Scaffold(
        appBar: AppBar(title: Text(tr('Deneme takvimi'))),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('exam-plan-add'),
          onPressed: () => addExamPlanFlow(context, ref),
          icon: const Icon(Icons.add),
          label: Text(tr('Deneme planla')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            CockpitSection(
              title: tr('Planlı denemeler'),
              subtitle: tr('Bugünden itibaren, en yakını önce'),
              child: CockpitAsync(
                value: value,
                onRetry: () => ref.invalidate(cockpitProvider),
                builder: (d) => d.examPlans.isEmpty
                    ? SectionEmpty(
                        icon: Icons.event_note_outlined,
                        message: tr('Planlı deneme yok.'),
                        actionLabel: tr('Deneme planla'),
                        actionIcon: Icons.add,
                        onAction: () => addExamPlanFlow(context, ref),
                      )
                    : Column(
                        children: [
                          for (final (i, p) in d.examPlans.indexed) ...[
                            if (i > 0) const Divider(),
                            ListTile(
                              key: ValueKey('exam-plan-${p.id}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${p.examType.label} · ${df.format(p.plannedOn)} · ${_when(p)}',
                              ),
                              trailing: IconButton(
                                tooltip: tr('Planı sil'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final ok = await confirm(
                                    context,
                                    title: tr('Plan silinsin mi?'),
                                    message: p.name,
                                  );
                                  if (!ok) return;
                                  try {
                                    await ref
                                        .read(cockpitRepositoryProvider)
                                        .deleteExamPlan(p.id);
                                    ref.invalidate(cockpitProvider);
                                  } catch (_) {
                                    if (context.mounted) {
                                      showMessage(
                                        context,
                                        tr('Silinemedi. Tekrar dene.'),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _when(ExamPlan p) {
    final d = p.daysFrom(DateTime.now());
    return d <= 0
        ? tr('bugün')
        : d == 1
        ? tr('yarın')
        : tr('{n} gün sonra', {'n': d});
  }
}

/// Yeni deneme planı: ad, tür, tarih.
Future<void> addExamPlanFlow(BuildContext context, WidgetRef ref) async {
  var type = ExamType.tyt;
  final now = DateTime.now();
  var date = DateTime(now.year, now.month, now.day + 7);
  final df = DateFormat('d MMMM yyyy', localeTag);
  final title = await showDialog<String>(
    context: context,
    animationStyle: AppMotion.overlayStyle(context),
    builder: (context) => ControllerScope(
      builder: (context, name) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('Deneme planla')),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('exam-plan-name'),
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: tr('Deneme adı'),
                    hintText: tr('ör. TYT Genel Deneme 5'),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ExamType>(
                  showSelectedIcon: false,
                  segments: [
                    for (final t in ExamType.values)
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setLocal(() => type = s.first),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('exam-plan-date'),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(df.format(date)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: DateTime(now.year + 1, now.month, now.day),
                    );
                    if (picked != null) setLocal(() => date = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Vazgeç')),
            ),
            FilledButton(
              key: const ValueKey('exam-plan-save'),
              onPressed: () {
                if (name.text.trim().length < 2) {
                  showMessage(context, tr('Deneme adını yaz.'));
                  return;
                }
                Navigator.pop(context, name.text.trim());
              },
              child: Text(tr('Kaydet')),
            ),
          ],
        ),
      ),
    ),
  );
  if (title == null) return;
  try {
    await ref.read(cockpitRepositoryProvider).addExamPlan(title, type, date);
    ref.invalidate(cockpitProvider);
    AppHaptics.confirm();
    if (context.mounted) showMessage(context, tr('Deneme takvime eklendi.'));
  } catch (_) {
    if (context.mounted) {
      showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }
}
