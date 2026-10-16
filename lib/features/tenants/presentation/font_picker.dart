import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/brand_theme.dart';

/// Kurum görünümünde yazı tipi seçimi: her kutu kendi yazı tipiyle çizilir
/// ("Aa Ğş" ve adı), seçili olanın çerçevesi ana renkte ve işaretli.
class FontPicker extends StatelessWidget {
  const FontPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AppFont selected;
  final ValueChanged<AppFont> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Yazı tipi'),
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            'Kurumdaki herkes (koçlar, öğrenciler, veliler) uygulamayı bu yazı tipiyle görür.',
          ),
          style: text.bodySmall,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 520 ? 3 : 2;
            const gap = 10.0;
            final w = (c.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final f in AppFont.values)
                  SizedBox(
                    width: w,
                    child: _FontTile(
                      font: f,
                      selected: f == selected,
                      onTap: () => onChanged(f),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FontTile extends StatelessWidget {
  const _FontTile({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final AppFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final onSurface = theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: '${font.family}, ${font.kind}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? brand.primary.withValues(alpha: 0.14)
            : theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? brand.primaryDeep
                    : onSurface.withValues(alpha: 0.12),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aa Ğş',
                        maxLines: 1,
                        style: font.style(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        font.family,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: font.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        font.kind,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected
                      ? brand.primaryDeep
                      : onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
