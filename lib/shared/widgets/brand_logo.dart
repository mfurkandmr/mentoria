import 'package:flutter/material.dart';

import '../../core/theme/brand_theme.dart';
import 'bizz.dart';

/// Uygulamanın her yerindeki logo. Varsayılan markada "mentoria" yazı
/// logosu; dershanede kendi logosu ve adı (logo yüklenemezse baş harfi).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.fontSize = 32, this.showName = true});

  final double fontSize;

  /// Logonun yanında dershane adı yazsın mı.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    if (b.isDefaultBrand) return MentoriaWordmark(fontSize: fontSize);

    final size = fontSize * 1.35;
    final mark = b.logoUrl == null
        ? BrandInitial(size: size)
        : ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.network(
              b.logoUrl!,
              height: size,
              fit: BoxFit.contain,
              semanticLabel: b.appName,
              errorBuilder: (_, _, _) => BrandInitial(size: size),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : SizedBox(width: size, height: size),
            ),
          );
    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: fontSize * 0.35),
        Flexible(
          child: Text(
            b.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: fontSize * 0.78,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Logosu olmayan dershane için ana renkte baş harf rozeti.
class BrandInitial extends StatelessWidget {
  const BrandInitial({super.key, required this.size, this.name, this.color});

  final double size;

  /// Verilmezse geçerli markanın adı/rengi.
  final String? name;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final bg = color ?? b.primary;
    final text = (name ?? b.appName).trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Text(
        text.isEmpty ? '?' : text.characters.first.toUpperCase(),
        style: TextStyle(
          color: BrandTheme.readableOn(bg, dark: b.ink),
          fontWeight: FontWeight.w900,
          fontSize: size * 0.55,
        ),
      ),
    );
  }
}
