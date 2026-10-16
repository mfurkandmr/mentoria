import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/format.dart';
import '../data/exam.dart';
import '../../coach/data/coach_repository.dart';
import '../data/exam_repository.dart';
import '../../../core/i18n/i18n.dart';

/// Deneme detayı: ders bazlı doğru / yanlış / boş / net ve silme.
class ExamDetailSheet extends ConsumerWidget {
  const ExamDetailSheet({
    super.key,
    required this.exam,
    required this.studentId,
    this.canDelete = false,
  });

  final Exam exam;
  final String studentId;

  /// Yalnızca koç / müdür silebilir.
  final bool canDelete;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Deneme silinsin mi?')),
        content: Text(
          tr('"{p0}" ve tüm ders sonuçları silinecek.', {'p0': exam.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Vazgeç')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Sil')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(examRepositoryProvider).deleteExam(exam.id);
      ref.invalidate(examsForStudentProvider(studentId));
      ref.invalidate(studentSummariesProvider);
      if (context.mounted) Navigator.pop(context);
    } on ExamLockedException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Bu deneme 7 günden eski; artık silinemez.')),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Deneme silinemedi. Tekrar dene.'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    final header = text.labelMedium?.copyWith(color: muted);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exam.name,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              [
                exam.examType.label,
                if (exam.field != null) exam.field!.label,
                formatLongDate(exam.takenOn),
                if (exam.publisher?.isNotEmpty ?? false) exam.publisher!,
              ].join(' · '),
              style: text.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
                3: FlexColumnWidth(),
                4: FlexColumnWidth(1.4),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    Text(tr('Ders'), style: header),
                    for (final h in ['D', 'Y', 'B'])
                      Text(h, style: header, textAlign: TextAlign.center),
                    Text(tr('Net'), style: header, textAlign: TextAlign.end),
                  ],
                ),
                for (final r in exam.results)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(r.subject.name, style: text.bodyMedium),
                      ),
                      Text('${r.correct}', textAlign: TextAlign.center),
                      Text('${r.wrong}', textAlign: TextAlign.center),
                      Text('${r.blank}', textAlign: TextAlign.center),
                      Text(
                        formatNet(r.net),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text(tr('Toplam net'), style: text.titleMedium),
                const Spacer(),
                Text(
                  formatNet(exam.totalNet),
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            if (canDelete && !exam.editable) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr(
                        'Bu deneme 7 günden eski; silinemez ve değiştirilemez.',
                      ),
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ],
            if (canDelete && exam.editable) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(tr('Denemeyi sil')),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
