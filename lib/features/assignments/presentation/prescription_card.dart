import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/exam_subjects.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../learn/data/practice_repository.dart';
import '../data/assignment_repository.dart';
import '../data/prescription_repository.dart';

String _subjectLabel(String code) => code.startsWith('TYT_')
    ? 'TYT ${subjectByCode(code).name}'
    : code.startsWith('AYT_')
    ? practiceSubjectLabel(code)
    : subjectByCode(code).name;

/// Konu reçetesi: son 3 denemenin eksik konularından haftalık ödev taslağı.
/// Öğretmen maddeleri seçer, soru sayısını değiştirir ve tek tuşla gönderir
/// (öğrenciye mevcut ödev bildirimi gider). Teslim günü bir hafta sonra.
class PrescriptionCard extends ConsumerStatefulWidget {
  const PrescriptionCard({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends ConsumerState<PrescriptionCard> {
  /// Kullanıcının değiştirdiği soru sayıları ve çıkardığı konular
  /// (dokunulmayan madde önerilen sayıyla seçili gelir).
  final _counts = <int, int>{};
  final _off = <int>{};
  bool _sending = false;

  int _count(PrescriptionItem i) => _counts[i.topicId] ?? i.suggested;

  Future<void> _send(List<PrescriptionItem> items) async {
    final chosen = items.where((i) => !_off.contains(i.topicId)).toList();
    if (chosen.isEmpty) return;
    setState(() => _sending = true);
    final now = DateTime.now();
    try {
      await ref
          .read(assignmentRepositoryProvider)
          .sendAssignment(
            studentId: widget.studentId,
            title: tr('Konu reçetesi · {date}', {
              'date': DateFormat('d MMMM', localeTag).format(now),
            }),
            dueOn: DateTime(now.year, now.month, now.day + 7),
            note: tr('Son denemelerdeki eksik konulardan hazırlandı.'),
            items: [
              for (final i in chosen)
                AssignmentItemDraft(
                  subjectCode: i.subjectCode,
                  topicId: i.topicId,
                  topicName: i.topicName,
                  questionCount: _count(i),
                  note: i.outcomes.isEmpty
                      ? null
                      : _clip(i.outcomes.join(' · '), 300),
                ),
            ],
          );
      if (!mounted) return;
      showMessage(context, tr('Reçete ödev olarak gönderildi.'));
      _counts.clear();
      _off.clear();
      ref.invalidate(assignmentsProvider(widget.studentId));
      ref.invalidate(prescriptionProvider(widget.studentId));
    } catch (_) {
      if (mounted) showMessage(context, tr('Gönderilemedi. Tekrar dene.'));
    }
    if (mounted) setState(() => _sending = false);
  }

  static String _clip(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n - 1)}…';

  @override
  Widget build(BuildContext context) {
    final rx = ref.watch(prescriptionProvider(widget.studentId));
    final brand = context.brand;
    return SectionCard(
      title: tr('Konu reçetesi'),
      subtitle: tr('Son 3 denemenin eksik konularından haftalık ödev taslağı'),
      child: rx.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => TextButton(
          onPressed: () =>
              ref.invalidate(prescriptionProvider(widget.studentId)),
          child: Text(tr('Tekrar dene')),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Text(
              tr(
                'Önerilecek konu yok: son denemelerde konu bazlı yanlış kaydı yok ya da hepsine yakın zamanda ödev verildi.',
              ),
            );
          }
          final chosen = items.where((i) => !_off.contains(i.topicId));
          final total = chosen.fold<int>(0, (s, i) => s + _count(i));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in items)
                _PrescriptionTile(
                  item: i,
                  selected: !_off.contains(i.topicId),
                  count: _count(i),
                  onSelected: (on) => setState(
                    () => on ? _off.remove(i.topicId) : _off.add(i.topicId),
                  ),
                  onCount: (c) => setState(() => _counts[i.topicId] = c),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _sending || chosen.isEmpty
                    ? null
                    : () => _send(items),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  tr('Onayla ve gönder · {n} konu, {q} soru', {
                    'n': chosen.length,
                    'q': total,
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr('Teslim: 1 hafta sonra. Öğrenciye ödev bildirimi gider.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: brand.primaryDeep),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.item,
    required this.selected,
    required this.count,
    required this.onSelected,
    required this.onCount,
  });

  final PrescriptionItem item;
  final bool selected;
  final int count;
  final ValueChanged<bool> onSelected;
  final ValueChanged<int> onCount;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.65);
    final why = item.examCount > 1
        ? tr('{e} denemede {n} yanlış', {'e': item.examCount, 'n': item.wrong})
        : tr('{n} yanlış', {'n': item.wrong});
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onSelected(v ?? false);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_subjectLabel(item.subjectCode)} · ${item.topicName}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? null : muted,
                  ),
                ),
                Text(why, style: TextStyle(color: muted)),
                for (final o in item.outcomes)
                  Text('• $o', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          // Soru sayısı: 5'er artar / azalır (5-200).
          IconButton(
            tooltip: tr('Azalt'),
            visualDensity: VisualDensity.compact,
            onPressed: selected && count > 5 ? () => onCount(count - 5) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              semanticsLabel: tr('{n} soru', {'n': count}),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected ? null : muted,
              ),
            ),
          ),
          IconButton(
            tooltip: tr('Artır'),
            visualDensity: VisualDensity.compact,
            onPressed: selected && count < 200
                ? () => onCount(count + 5)
                : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
