import '../../admin/presentation/cockpit/cockpit_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../data/risk_repository.dart';
import '../../../core/design/motion.dart';
import '../../../shared/widgets/skeleton.dart';

/// Koç ve müdür ana sayfası: "bu hafta konuşulacaklar". Devam, net düşüşü
/// ve ödeve göre en riskli 7 öğrenci; dokununca öğrenci detayı açılır.
/// Pazartesi sabahı koça aynı liste bildirim olarak da gelir.
class RiskCard extends ConsumerWidget {
  const RiskCard({super.key, required this.basePath});

  /// `/coach` ya da `/admin`.
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risks = ref.watch(riskListProvider);
    return SectionCard(
      title: tr('Bu hafta konuşulacaklar'),
      subtitle: tr('Devam, net düşüşü ve ödeve göre son 7 gün'),
      trailing: IconButton(
        tooltip: tr('Skor nasıl hesaplanır?'),
        icon: const Icon(Icons.info_outline_rounded),
        onPressed: () => showDialog<void>(
          context: context,
          animationStyle: AppMotion.overlayStyle(context),
          builder: (context) => AlertDialog(
            title: Text(tr('Risk skoru')),
            content: Text(
              tr(
                'Çalışmadığı her gün 5 puan, kaçırılan her koç görüşmesi 7,5 puan (en çok 2). Son 30 gündeki denemesi bir öncekinden düşükse her net 3 puan (en çok 10 net). Bu haftanın ödevinde yapılmayan oran × 20. Toplam 100 üzerinden; 30 ve üstü listeye girer.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('Tamam')),
              ),
            ],
          ),
        ),
      ),
      child: risks.when(
        loading: () => const SkeletonList(rows: 2),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(riskListProvider),
          child: Text(tr('Tekrar dene')),
        ),
        data: (list) => list.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr('Bu hafta risk işareti veren öğrenci yok.')),
              )
            : Column(
                children: [
                  for (final r in list)
                    _RiskTile(
                      entry: r,
                      onTap: () =>
                          context.push('$basePath/students/${r.studentId}'),
                    ),
                ],
              ),
      ),
    );
  }
}

class _RiskTile extends StatelessWidget {
  const _RiskTile({required this.entry, required this.onTap});

  final RiskEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final high = entry.score >= 60;
    // Kokpitte renk anlam taşır: yüksek risk kırmızı, orta risk sarı.
    final quiet = inCockpit(context);
    final color = high
        ? (quiet ? context.cockpit.risk : brand.danger)
        : (quiet ? context.cockpit.warn : brand.secondary);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Semantics(
        label: tr('Risk skoru {n}', {'n': entry.score}),
        child: ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: Text(
              '${entry.score}',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
      title: Text(
        entry.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(entry.reasons.join(' · ')),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
