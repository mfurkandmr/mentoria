import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/brand_theme.dart';
import '../data/avatar_models.dart';
import '../data/avatar_repository.dart';

/// Öğrenci avatarı: parçalar uygulamadaki asset'lerden üst üste çizilir
/// (ödül kanatları → ten → kıyafet → saç → aksesuar → ödül tacı). Profil, ana
/// sayfa, sıralamalar ve editör hep bu widget'ı kullanır. Görsel üretilmez, ağdan resim indirilmez;
/// yalnızca küçük katalog bir kez çekilir.
class StudentAvatar extends ConsumerWidget {
  const StudentAvatar({
    super.key,
    required this.config,
    this.size = 48,
    this.background = true,
    this.semanticLabel,
    this.reward,
  });

  final AvatarConfig config;

  /// Başarı sıralaması ödülü (TYT ilk 5); avatar JSON'unda tutulmaz.
  final AvatarReward? reward;
  final double size;

  /// Arkada markanın renginde yuvarlak zemin.
  final bool background;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(avatarCatalogProvider).value;
    final brand = context.brand;
    final front = reward?.frontAsset;
    final layers = <Widget>[
      if (catalog != null) ...[
        if (reward != null)
          AvatarLayer(
            key: ValueKey('reward-back-${reward!.name}'),
            assetPath: reward!.backAsset,
          ),
        for (final c in AvatarCategory.values)
          if (config[c] != null && catalog[config[c]] != null)
            // Kral tacı varken başka bir taç aksesuarı çizilmez.
            if (!(front != null &&
                c == AvatarCategory.accessory &&
                catalog[config[c]]!.assetName.contains('crown')))
              AvatarLayer(
                key: ValueKey('${c.name}-${config[c]}'),
                assetPath: catalog[config[c]]!.assetPath,
              ),
        if (front != null)
          AvatarLayer(key: const ValueKey('reward-front'), assetPath: front),
      ],
    ];

    Widget avatar = SizedBox.square(
      dimension: size,
      child: layers.isEmpty
          // Katalog yüklenemezse boş daire yerine sade bir yüz simgesi.
          ? Icon(
              Icons.face_rounded,
              size: size * 0.6,
              color: brand.ink.withValues(alpha: 0.55),
            )
          : Stack(fit: StackFit.expand, children: layers),
    );
    if (background) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              brand.primary.withValues(alpha: 0.45),
              brand.primary.withValues(alpha: 0.18),
            ],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        // Baş biraz yukarıda dursun, gövde alttan taşıp kırpılsın.
        child: Transform.translate(
          offset: Offset(0, size * 0.06),
          child: avatar,
        ),
      );
    }
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: avatar,
    );
  }
}

/// Tek parça katmanı. Asset eksikse (ör. yeni parça henüz uygulamaya
/// eklenmemişse) sessizce boş kalır.
class AvatarLayer extends StatelessWidget {
  const AvatarLayer({super.key, required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    assetPath,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
