import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/branding.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../data/tenant_repository.dart';

/// Süper admin: tüm dershaneler (white label müşterileri).
class PlatformScreen extends ConsumerWidget {
  const PlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(tenantsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Dershaneler'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/platform/new'),
        icon: const Icon(Icons.add_business_rounded),
        label: Text(tr('Yeni dershane')),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(tenantsProvider.future),
        child: AsyncView(
          value: tenants,
          onRetry: () => ref.invalidate(tenantsProvider),
          builder: (list) => list.isEmpty
              ? ListView(
                  children: [
                    EmptyState(
                      title: tr('Henüz dershane yok'),
                      message: tr('İlk dershaneyi "Yeni dershane" ile ekle.'),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => FadeSlideIn(
                    delay: FadeSlideIn.stagger(i.clamp(0, 10), 40),
                    child: _TenantTile(tenant: list[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TenantTile extends StatelessWidget {
  const _TenantTile({required this.tenant});

  final Branding tenant;

  @override
  Widget build(BuildContext context) {
    final t = tenant;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/platform/${t.tenantId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              TenantMark(tenant: t, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(t.slug ?? '', style: text.bodySmall),
                  ],
                ),
              ),
              if (!t.isActive) ...[
                Chip(
                  label: Text(tr('Pasif')),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: context.brand.danger),
                ),
                const SizedBox(width: 6),
              ],
              _Swatch(color: t.primary),
              const SizedBox(width: 4),
              _Swatch(color: t.secondary),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir dershanenin logosu ya da (yoksa) kendi renginde baş harfi.
class TenantMark extends StatelessWidget {
  const TenantMark({super.key, required this.tenant, this.size = 40});

  final Branding tenant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = BrandInitial(
      size: size,
      name: tenant.name,
      color: tenant.primary,
    );
    if (!tenant.hasLogo) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.network(
        tenant.logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: tenant.name,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}
