import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../tracking/presentation/study_view.dart' show formatMinutes;
import '../data/weekly_summary_repository.dart';
import '../../../shared/widgets/skeleton.dart';

/// Velinin haftalık özeti, tek kart: devam (çalıştığı gün, kaçırılan
/// görüşme), net trendi ve ödev oranı. Veli ana sayfasında ve koçun öğrenci
/// özetinde görünür. [canShare]: koç / müdür kartı metin olarak veliye
/// gönderebilir (WhatsApp ya da başka bir uygulama).
class WeeklySummaryCard extends ConsumerWidget {
  const WeeklySummaryCard({
    super.key,
    required this.studentId,
    required this.name,
    this.canShare = false,
  });

  final String studentId;

  /// Öğrencinin adı soyadı.
  final String name;
  final bool canShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(weeklySummaryProvider(studentId));
    final brand = context.brand;
    final s = summary.value;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize_rounded, color: brand.primaryDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Haftalık özet'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        tr('Son 7 gün'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (canShare && s != null)
                  TextButton.icon(
                    onPressed: () => _share(context, s),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(tr('Veliye gönder')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (summary.hasError && s == null)
              TextButton(
                onPressed: () =>
                    ref.invalidate(weeklySummaryProvider(studentId)),
                child: Text(tr('Özet yüklenemedi. Tekrar dene.')),
              )
            else if (s == null)
              const SkeletonList(rows: 2)
            else ...[
              _Line(
                icon: Icons.event_available_rounded,
                label: tr('Devam'),
                value: tr('{d} / 7 gün çalıştı', {'d': s.days}),
                detail: s.meetingsMissed > 0
                    ? tr('{n} koç görüşmesini kaçırdı', {'n': s.meetingsMissed})
                    : s.meetingsHeld > 0
                    ? tr('{n} koç görüşmesine katıldı', {'n': s.meetingsHeld})
                    : null,
                warn: s.days <= 2 || s.meetingsMissed > 0,
              ),
              _Line(
                icon: Icons.insights_rounded,
                label: tr('Net trendi'),
                value: s.lastNet == null
                    ? tr('Henüz deneme yok')
                    : tr('Son {type}: {net} net', {
                        'type': s.examType,
                        'net': formatNet(s.lastNet!),
                      }),
                detail: switch (s.netChange) {
                  null => null,
                  final d => tr('öncekinden {d}', {'d': formatChange(d)}),
                },
                warn: (s.netChange ?? 0) < 0,
                good: (s.netChange ?? 0) > 0,
              ),
              _Line(
                icon: Icons.assignment_turned_in_rounded,
                label: tr('Ödev'),
                value: s.homeworkPercent == null
                    ? tr('Bu hafta teslimli ödev yok')
                    : tr('{d} / {n} tamamlandı · %{p}', {
                        'd': s.homeworkDone,
                        'n': s.homeworkTotal,
                        'p': s.homeworkPercent,
                      }),
                warn: s.homeworkPercent != null && s.homeworkPercent! < 50,
                good: s.homeworkPercent == 100,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, WeeklySummary s) async {
    // Paylaşım menüsü: WhatsApp, SMS ya da e-posta; kişi orada seçilir.
    await SharePlus.instance.share(
      ShareParams(
        text: weeklySummaryText(name, s),
        subject: tr('{name} · haftalık özet', {'name': name}),
      ),
    );
  }
}

/// Veliye gönderilen düz metin (WhatsApp'ta okunur kalsın diye kısa).
String weeklySummaryText(String name, WeeklySummary s) => [
  tr('{name} · haftalık özet (son 7 gün)', {'name': name}),
  '• ${tr('{d} / 7 gün çalıştı', {'d': s.days})}'
      '${s.meetingsMissed > 0 ? ' · ${tr('{n} koç görüşmesini kaçırdı', {'n': s.meetingsMissed})}' : ''}',
  if (s.lastNet != null)
    '• ${tr('Son {type}: {net} net', {'type': s.examType, 'net': formatNet(s.lastNet!)})}'
        '${s.netChange == null ? '' : ' (${tr('öncekinden {d}', {'d': formatChange(s.netChange!)})})'}',
  if (s.homeworkPercent != null)
    '• ${tr('Ödev')}: ${tr('{d} / {n} tamamlandı · %{p}', {'d': s.homeworkDone, 'n': s.homeworkTotal, 'p': s.homeworkPercent})}',
  '• ${tr('{q} soru · {time} çalışma', {'q': s.questions, 'time': formatMinutes(s.minutes)})}',
].join('\n');

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.warn = false,
    this.good = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final bool warn;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final tone = warn
        ? brand.danger
        : good
        ? brand.success
        : brand.primaryDeep;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.65);
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: TextStyle(
                      color: warn || good ? tone : muted,
                      fontWeight: FontWeight.w700,
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
