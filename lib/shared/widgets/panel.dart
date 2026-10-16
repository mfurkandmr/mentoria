import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/brand_theme.dart';
import '../motion.dart';
import 'effects.dart';

/// Panellerin ortak görsel dili: renkli özet kutuları, bölüm başlıkları,
/// uyarı şeritleri, bilgi hapları, baş harf rozetleri ve sırayla süzülen
/// kartlar. Koç, müdür, öğrenci sekmeleri ve veli ekranları birlikte kullanır.
/// Üst çubuktaki yuvarlak profil düğmesi (baş harfler).
class ProfileInitialsButton extends StatelessWidget {
  const ProfileInitialsButton({
    super.key,
    required this.name,
    required this.onPressed,
  });

  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tr('Profil'),
    onPressed: onPressed,
    icon: InitialsAvatar(name: name, size: 34),
  );
}

/// Ada göre sabit renkli, degrade zeminli baş harf rozeti. [active] verilirse
/// sağ altta yeşil (bu hafta çalıştı) ya da gri nokta çıkar.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 46,
    this.active,
  });

  final String name;
  final double size;
  final bool? active;

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p.characters.first.toUpperCase()).toList();
    if (letters.isEmpty) return '?';
    return letters.length == 1 ? letters.first : letters.first + letters.last;
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final palette = [brand.secondary, brand.primary, brand.info, brand.success];
    final base =
        palette[name.codeUnits.fold<int>(0, (a, c) => a + c) % palette.length];
    final light = Color.lerp(base, Colors.white, 0.35)!;
    final onBase = ThemeData.estimateBrightnessForColor(base) == Brightness.dark
        ? Colors.white
        : brand.ink;
    final dot = size * 0.3;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [light, base],
              ),
              boxShadow: [
                BoxShadow(
                  color: base.withValues(alpha: 0.35),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.06),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initialsOf(name),
              style: TextStyle(
                color: onBase,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.36,
              ),
            ),
          ),
          if (active != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active! ? brand.success : const Color(0xFFB8C2CC),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Renkli özet kutusu: ikon rozeti, sayarak gelen değer, etiket.
class GlowStat extends StatelessWidget {
  const GlowStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.caption,
    this.format,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final String? caption;

  /// Değerin biçimi (varsayılan: tam sayı).
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : context.brand.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: dark ? 0.30 : 0.26),
            color.withValues(alpha: dark ? 0.12 : 0.08),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: onColor),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUp(
              value: value,
              format: format ?? (v) => '${v.round()}',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                color: text.labelSmall?.color?.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

/// Büyük, basınca küçülen hızlı işlem düğmesi (Davet et, Ödev ver…).
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : context.brand.ink;
    Widget tile = PressScale(
      child: Material(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                    ),
                  ),
                  child: Icon(icon, color: onColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) tile = Tooltip(message: tooltip, child: tile);
    return tile;
  }
}

/// Bölüm başlığı: kalın başlık, isteğe bağlı alt satır ve sağda bir düğme.
class PanelSectionTitle extends StatelessWidget {
  const PanelSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(
                      color: text.bodySmall?.color?.withValues(alpha: 0.75),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Uyarı şeridi (eksik okul numarası, dolu lisans…).
class PanelNotice extends StatelessWidget {
  const PanelNotice({
    super.key,
    required this.icon,
    required this.message,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String message;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.brand.primary;
    return Material(
      color: c.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: context.brand.primaryDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Küçük bilgi hapı (ikon + metin).
class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurface.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? scheme.onSurface).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: c,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartların sırayla süzülerek gelmesi (hareket azaltılmışsa anında).
Widget staggered(int index, Widget child) => Builder(
  builder: (context) => Motion.of(context)
      ? FadeSlideIn(
          delay: FadeSlideIn.stagger(index.clamp(0, 12), 55),
          child: child,
        )
      : child,
);
