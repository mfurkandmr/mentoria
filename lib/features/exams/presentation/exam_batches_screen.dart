import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../coach/data/coach_repository.dart';
import '../../coach/presentation/manager_widgets.dart';
import '../data/exam.dart';
import '../data/exam_repository.dart';

/// Koçun / müdürün yüklediği denemeler. Bir Excel yüklemesi tek satırdır ve
/// içindeki tüm öğrencilerden birlikte silinir. Yalnızca son 7 günde
/// yüklenenler silinebilir; daha eskiler kilitlidir (kural sunucuda).
class ExamBatchesScreen extends ConsumerWidget {
  const ExamBatchesScreen({super.key, this.basePath = '/coach'});

  /// '/coach' ya da '/admin' (deneme yükleme ekranına geçiş için).
  final String basePath;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ExamBatch batch, {
    bool latest = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: latest
          ? tr('Son yüklenen deneme herkesten silinsin mi?')
          : tr('Deneme silinsin mi?'),
      message: batch.studentCount > 1
          ? tr(
              '"{name}" {n} öğrencinin hepsinden silinecek; sonuçları ve bildirimleri de gider. Bu işlem geri alınamaz.',
              {'name': batch.name, 'n': batch.studentCount},
            )
          : tr(
              '"{name}" ve tüm ders sonuçları silinecek. Bu işlem geri alınamaz.',
              {'name': batch.name},
            ),
      action: batch.studentCount > 1 ? tr('Herkesten sil') : tr('Sil'),
    );
    if (!ok) return;
    try {
      final n = await ref.read(examRepositoryProvider).deleteBatch(batch.id);
      ref.invalidate(myExamBatchesProvider);
      ref.invalidate(studentSummariesProvider);
      ref.invalidate(examsForStudentProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('"{name}" {n} öğrenciden silindi.', {
              'name': batch.name,
              'n': n,
            }),
          ),
        ),
      );
    } on ExamLockedException {
      ref.invalidate(myExamBatchesProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('Bu deneme 7 günden eski; artık silinemez.')),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Deneme silinemedi. Tekrar dene.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(myExamBatchesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('Denemeler'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: tr('Deneme sonuçlarını yükle'),
            icon: const Icon(Icons.upload_file),
            onPressed: () => context.push('$basePath/import'),
          ),
        ],
      ),
      body: AsyncView(
        value: batches,
        onRetry: () => ref.invalidate(myExamBatchesProvider),
        builder: (list) {
          final latest = list.firstOrNull;
          final children = <Widget>[
            PanelNotice(
              icon: Icons.lock_clock_outlined,
              message: tr(
                'Yüklediğin denemeleri 7 gün içinde silebilirsin. Daha eskiler kilitlenir ve öğrencilerin kayıtlarında kalır.',
              ),
            ),
            if (list.isEmpty)
              EmptyState(
                title: tr('Henüz deneme yüklemedin'),
                message: tr(
                  'Excel\'den yüklediğin ya da elle girdiğin denemeler burada listelenir.',
                ),
                action: FilledButton.icon(
                  onPressed: () => context.push('$basePath/import'),
                  icon: const Icon(Icons.upload_file),
                  label: Text(tr('Deneme yükle')),
                ),
              ),
            if (latest != null && latest.editable)
              _LatestCard(
                batch: latest,
                onDelete: () => _delete(context, ref, latest, latest: true),
              ),
            if (list.isNotEmpty)
              PanelSectionTitle(
                title: tr('Tüm yüklemeler'),
                subtitle: tr('{n} yükleme · son yüklenen en üstte', {
                  'n': list.length,
                }),
              ),
            for (final b in list)
              _BatchCard(
                key: ValueKey(b.id),
                batch: b,
                onDelete: () => _delete(context, ref, b),
              ),
          ];
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myExamBatchesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => staggered(i, children[i]),
            ),
          );
        },
      ),
    );
  }
}

String _when(ExamBatch b) =>
    tr('{date} yüklendi', {'date': formatShortDate(b.uploadedAt)});

/// Kalan düzeltme süresi: "3 gün daha silinebilir" / "Bugün kilitleniyor".
String _remaining(ExamBatch b) {
  final left = b.editableUntil.difference(DateTime.now());
  // Yukarı yuvarla: 2 gün önce yüklenen "5 gün daha" (4 gün 23 saat).
  final days = (left.inMinutes / Duration.minutesPerDay).ceil();
  if (days > 1) {
    return tr('{n} gün daha silinebilir', {'n': days});
  }
  return tr('Bugün kilitleniyor');
}

/// En son yüklenen deneme: tek dokunuşla herkesten silinir.
class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.batch, required this.onDelete});

  final ExamBatch batch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: brand.danger.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Son yüklenen deneme'),
              style: text.labelLarge?.copyWith(
                color: brand.danger,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              batch.name,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Yanlış dosya ya da hatalı sonuç mu yükledin? Bu denemeyi {n} öğrencinin hepsinden tek seferde kaldırabilirsin.',
                {'n': batch.studentCount},
              ),
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: brand.danger,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(tr('Son denemeyi herkesten sil')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({super.key, required this.batch, required this.onDelete});

  final ExamBatch batch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    final brand = context.brand;
    final text = Theme.of(context).textTheme;
    final color = b.imported ? brand.info : brand.secondary;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                b.imported ? Icons.table_view_rounded : Icons.edit_note_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${b.examType.label}'
                    '${b.field == null ? '' : ' ${b.field!.label}'}'
                    ' · ${formatShortDate(b.takenOn)} · ${_when(b)}',
                    style: text.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      InfoPill(
                        icon: Icons.groups_outlined,
                        text: tr('{n} öğrenci', {'n': b.studentCount}),
                        color: color,
                      ),
                      InfoPill(
                        icon: Icons.trending_up_rounded,
                        text: tr('ort. {net} net', {
                          'net': formatNet(b.avgNet),
                        }),
                      ),
                      if (b.editable)
                        InfoPill(
                          icon: Icons.timer_outlined,
                          text: _remaining(b),
                          color: brand.primaryDeep,
                        )
                      else
                        InfoPill(icon: Icons.lock_outline, text: tr('Kilitli')),
                    ],
                  ),
                ],
              ),
            ),
            b.editable
                ? IconButton(
                    tooltip: b.studentCount > 1
                        ? tr('Herkesten sil')
                        : tr('Sil'),
                    color: brand.danger,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Tooltip(
                      message: tr('7 günden eski; silinemez'),
                      child: Icon(Icons.lock_outline, color: muted),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
