import 'package:flutter/material.dart';

import '../../../../core/i18n/i18n.dart';
import 'cockpit_motion.dart';
import 'cockpit_theme.dart';

/// Geçen haftaya göre değişim. [value] mutlak (öğrenci) ya da yüzde (soru).
class MetricDelta {
  const MetricDelta(this.value, {this.percent = false});

  /// [now] ve [prev] arasındaki fark; [percent] ise yüzde değişim
  /// (geçen hafta 0 ise null: kıyas yapılamaz).
  static MetricDelta? between(int now, int prev, {bool percent = false}) {
    if (!percent) return MetricDelta((now - prev).toDouble());
    if (prev == 0) return null;
    return MetricDelta((now - prev) * 100 / prev, percent: true);
  }

  final double value;
  final bool percent;

  int get rounded => value.round();
}

/// Özet şeridindeki tek kart: küçük gri etiket, büyük kalın sayı, altında
/// tek satır ayrıntı ve değişim oku. Kartın tamamı dokunulabilir.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.unit,
    this.detail,
    this.delta,
    this.tone,
    this.semanticsHint,
    this.count,
    this.format,
  });

  final String label;
  final String value;

  /// Doluysa sayı sayarak gelir ([format] ile; son hali [value] ile aynı).
  final int? count;
  final String Function(int)? format;

  /// Sayının yanındaki küçük birim ("/ 410", "gün sonra").
  final String? unit;
  final String? detail;
  final MetricDelta? delta;

  /// Yalnızca bir eşik aşıldığında (ör. aktiflik %40'ın altı).
  final Tone? tone;
  final String? semanticsHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final numberStyle = cockpitNumber(
      context,
    )?.copyWith(color: tone?.of(context));
    return Pressable(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            hint: semanticsHint,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(label, style: cockpitLabel(context)),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.cockpit.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 4,
                    children: [
                      if (count != null && format != null)
                        AnimatedCount(
                          value: count!,
                          format: format!,
                          style: numberStyle,
                        )
                      else
                        Text(value, style: numberStyle),
                      if (unit != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            unit!,
                            style: text.bodySmall?.copyWith(
                              color: context.cockpit.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (detail != null || delta != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (delta != null) DeltaBadge(delta: delta!),
                        if (detail != null)
                          Text(
                            detail!,
                            style: text.bodySmall?.copyWith(
                              color: context.cockpit.muted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ▲ +12 (yeşil), ▼ −5 (kırmızı), — (gri). Ekran okuyucuya "geçen haftaya
/// göre 12 arttı" diye okunur; renk tek başına anlam taşımaz (ok + işaret).
/// [onDark]: koyu zeminde (bu hafta kartı) açık renkli rozet.
class DeltaBadge extends StatelessWidget {
  const DeltaBadge({super.key, required this.delta, this.onDark = false});

  final MetricDelta delta;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final n = delta.rounded;
    final tone = n > 0
        ? Tone.good
        : n < 0
        ? Tone.risk
        : Tone.neutral;
    final icon = n > 0
        ? Icons.arrow_upward_rounded
        : n < 0
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;
    final abs = n.abs();
    final shown = delta.percent ? '%$abs' : '$abs';
    final sign = n > 0
        ? '+'
        : n < 0
        ? '−'
        : '';
    final spoken = n == 0
        ? tr('Geçen haftayla aynı')
        : n > 0
        ? tr('Geçen haftaya göre {v} arttı', {'v': shown})
        : tr('Geçen haftaya göre {v} azaldı', {'v': shown});
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Tooltip(
        message: tr('Geçen haftaya göre'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: onDark
                ? Colors.white.withValues(alpha: 0.16)
                : tone.tintOf(context),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: onDark ? Colors.white : tone.of(context),
              ),
              const SizedBox(width: 2),
              Text(
                n == 0 ? tr('aynı') : '$sign$shown',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: onDark ? Colors.white : tone.of(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
