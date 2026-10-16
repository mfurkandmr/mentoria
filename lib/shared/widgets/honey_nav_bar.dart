import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/brand_theme.dart';
import '../motion.dart';
import 'effects.dart';

class HoneyNavItem {
  const HoneyNavItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.tooltip,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final String? tooltip;
}

/// Uygulamanın alt menüsü: yüzen, yuvarlak köşeli bir bar. Seçili sekmenin
/// simgesi bal rengi bir petek gözünün içinde yaylanarak belirir; zeminde
/// silik petek dokusu var. Öğrenci, koç ve müdür panelleri kullanır.
class HoneyNavBar extends StatelessWidget {
  const HoneyNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<HoneyNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final dark = theme.brightness == Brightness.dark;
    final bg = theme.cardTheme.color ?? theme.colorScheme.surface;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: brand.primary.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: brand.primary.withValues(alpha: dark ? 0.12 : 0.10),
              blurRadius: 18,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: CustomPaint(
            painter: _CombPainter(
              brand.primary.withValues(alpha: dark ? 0.06 : 0.08),
            ),
            child: Row(
              children: [
                for (final (i, item) in items.indexed)
                  Expanded(
                    child: _NavButton(
                      item: item,
                      selected: i == selectedIndex,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelected(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final HoneyNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.62);
    final onHoney =
        ThemeData.estimateBrightnessForColor(brand.primary) == Brightness.dark
        ? Colors.white
        : brand.ink;

    Widget icon = selected
        ? SizedBox.square(
            dimension: 40,
            child: CustomPaint(
              painter: _HexBadgePainter(brand.primary, brand.primaryDeep),
              child: Icon(
                item.selectedIcon ?? item.icon,
                size: 22,
                color: onHoney,
              ),
            ),
          )
        : SizedBox.square(
            dimension: 40,
            child: Icon(item.icon, size: 24, color: muted),
          );
    if (selected && Motion.of(context)) {
      icon = TweenAnimationBuilder<double>(
        key: ValueKey(item.label),
        tween: Tween(begin: 0.55, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.elasticOut,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: icon,
      );
    }

    Widget button = Semantics(
      button: true,
      selected: selected,
      label: item.label,
      // Alt düğümler dışlandığı için dokunma eylemi burada verilir; yoksa
      // ekran okuyucu sekmeyi açamaz.
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        highlightShape: BoxShape.circle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? theme.colorScheme.onSurface : muted,
              ),
            ),
          ],
        ),
      ),
    );
    if (item.tooltip != null) {
      button = Tooltip(message: item.tooltip, child: button);
    }
    return button;
  }
}

/// Seçili sekmenin bal rengi petek gözü (hafif parlayan).
class _HexBadgePainter extends CustomPainter {
  _HexBadgePainter(this.light, this.deep);

  final Color light;
  final Color deep;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final hex = hexPath(c, r);
    canvas.drawPath(
      hexPath(c, r + 3),
      Paint()
        ..color = light.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(light, Colors.white, 0.25)!, deep],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      hexPath(c, r - 3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_HexBadgePainter old) =>
      old.light != light || old.deep != deep;
}

/// Barın zeminindeki silik petek dokusu.
class _CombPainter extends CustomPainter {
  _CombPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    const r = 13.0;
    const w = 1.7320508 * r;
    for (var row = 0; row * 1.5 * r < size.height + r; row++) {
      for (var col = -1; col * w < size.width + w; col++) {
        canvas.drawPath(
          hexPath(
            Offset(col * w + (row.isOdd ? w / 2 : 0), row * 1.5 * r),
            r - 2,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CombPainter old) => old.color != color;
}
