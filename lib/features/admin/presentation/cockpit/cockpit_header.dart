import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/theme/brand_theme.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../pending_work/presentation/pending_work_screen.dart';
import '../../data/admin_repository.dart';
import 'cockpit_theme.dart';

/// Kokpitin üst çubuğu: kurumun logosu (tam opak), kurum adı ve bugünün
/// tarihi; sağda denemeler, deneme yükleme, bekleyen işler (rozetli) ve
/// profil. Selamlama yok.
/// Koç panelinde [examActions] kapalı (o kısayollar alt çubukta).
class CockpitHeader extends ConsumerWidget {
  const CockpitHeader({
    super.key,
    this.basePath = '/admin',
    this.examActions = true,
  });

  final String basePath;
  final bool examActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final orgName = ref.watch(orgProvider).value?.name ?? brand.appName;
    final date = DateFormat(
      'd MMMM yyyy, EEEE',
      localeTag,
    ).format(DateTime.now());

    return SliverAppBar(
      pinned: true,
      // iOS büyük başlığı: açıkken kurum adı büyük, kaydırınca küçülüp
      // buzlu cam çubuğa dönüşür.
      expandedHeight: 132,
      toolbarHeight: 56,
      backgroundColor: Colors.transparent,
      shape: const Border(),
      automaticallyImplyLeading: false,
      flexibleSpace: _CollapsingTitle(orgName: orgName, date: date),
      actions: [
        if (examActions) ...[
          IconButton(
            tooltip: tr('Yüklediğin denemeler'),
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => context.push('$basePath/exams'),
          ),
          IconButton(
            tooltip: tr('Deneme sonuçlarını yükle'),
            icon: const Icon(Icons.upload_file),
            onPressed: () => context.push('$basePath/import'),
          ),
        ],
        PendingWorkButton(basePath: basePath),
        CockpitProfileButton(
          name: ref.watch(currentProfileProvider).value?.fullName ?? '',
          route: '$basePath/profile',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Büyük başlık ↔ küçük başlık geçişi ve kaydırınca beliren buzlu cam.
class _CollapsingTitle extends StatelessWidget {
  const _CollapsingTitle({required this.orgName, required this.date});

  final String orgName;
  final String date;

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final top = MediaQuery.paddingOf(context).top;
    // 1: tam açık, 0: kapalı.
    final t = settings == null || settings.maxExtent == settings.minExtent
        ? 1.0
        : ((settings.currentExtent - settings.minExtent) /
                  (settings.maxExtent - settings.minExtent))
              .clamp(0.0, 1.0);
    final collapsed = 1 - t;
    final text = Theme.of(context).textTheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Kaydırınca beliren buzlu cam ve ince alt çizgi.
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 18 * collapsed,
              sigmaY: 18 * collapsed,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.cockpit.surface.withValues(
                  alpha: 0.78 * collapsed,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: context.cockpit.border.withValues(alpha: collapsed),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Küçük başlık (çubukta, ortada).
        Positioned(
          top: top,
          left: 16,
          right: 140,
          height: 56,
          child: Opacity(
            opacity: (collapsed * 2 - 1).clamp(0.0, 1.0),
            child: Row(
              children: [
                _OrgLogo(name: orgName, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    orgName,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Büyük başlık (çubuğun altında; kayarken yukarı süzülür, solar).
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: Opacity(
            opacity: (t * 1.6 - 0.6).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 8 * collapsed),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _OrgLogo(name: orgName, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(date, style: cockpitLabel(context)),
                        Text(
                          orgName,
                          key: const ValueKey('cockpit-org-name'),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kurum logosu; yoksa ya da yüklenemezse kurum adının baş harfi.
class _OrgLogo extends StatelessWidget {
  const _OrgLogo({required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final initial = BrandInitial(size: size, name: name, color: b.ink);
    if (b.isDefaultBrand || b.logoUrl == null) return initial;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        b.logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: name,
        errorBuilder: (_, _, _) => initial,
      ),
    );
  }
}

/// Profil düğmesi: nötr renkte baş harfler (dekoratif renk yok).
class CockpitProfileButton extends StatelessWidget {
  const CockpitProfileButton({
    super.key,
    required this.name,
    this.route = '/admin/profile',
  });

  final String name;
  final String route;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .take(2)
        .map((p) => p.isEmpty ? '' : p.characters.first)
        .join()
        .toUpperCase();
    return IconButton(
      tooltip: tr('Profil'),
      onPressed: () => context.push(route),
      icon: CircleAvatar(
        radius: 17,
        backgroundColor: context.cockpit.faint,
        foregroundColor: context.cockpit.ink,
        child: Text(
          initials,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
