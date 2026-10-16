import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../../core/branding/branding_providers.dart';
import '../data/tenant_repository.dart';

/// `/t/slug` linki: dershaneyi doğrular, kodu kaydeder ve giriş ekranına
/// o dershanenin markasıyla geçer.
class TenantLinkScreen extends ConsumerStatefulWidget {
  const TenantLinkScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<TenantLinkScreen> createState() => _TenantLinkScreenState();
}

class _TenantLinkScreenState extends ConsumerState<TenantLinkScreen> {
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final slug = widget.slug.trim().toLowerCase();
    final repo = ref.read(tenantRepositoryProvider);
    final saved = ref.read(savedTenantSlugProvider.notifier);
    try {
      final tenant = await repo.fetchBySlug(slug);
      if (!mounted) return;
      if (tenant == null) {
        setState(() => _notFound = true);
        return;
      }
      saved.set(slug);
      context.go('/login');
    } catch (_) {
      if (mounted) setState(() => _notFound = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _notFound
            ? EmptyState(
                title: tr('Dershane bulunamadı'),
                message: tr(
                  'Link eski ya da dershane şu an aktif değil. Kurumundan yeni link iste.',
                ),
                action: FilledButton(
                  onPressed: () => context.go('/login'),
                  child: Text(tr('Girişe dön')),
                ),
              )
            : const BizzLoader(),
      ),
    );
  }
}
