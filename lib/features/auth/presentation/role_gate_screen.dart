import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/branding_providers.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/bizz.dart';
import '../data/auth_repository.dart';
import '../data/profile.dart';
import '../../../core/i18n/i18n.dart';

/// Giriş sonrası profili okuyup kullanıcıyı rolünün ana ekranına yollar.
class RoleGateScreen extends ConsumerWidget {
  const RoleGateScreen({super.key});

  static String homeFor(UserRole role) => switch (role) {
    UserRole.student => '/student',
    UserRole.coach => '/coach',
    UserRole.parent => '/parent',
    UserRole.admin => '/admin',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      body: Center(
        child: profile.when(
          loading: () => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Bizz(size: 120),
              SizedBox(height: 16),
              CircularProgressIndicator(),
            ],
          ),
          error: (e, _) => _Problem(
            message: tr(
              'Profilin yüklenemedi. İnternet bağlantını kontrol et.',
            ),
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (p) {
            if (p == null) {
              return _Problem(
                message: tr('Hesabına ait profil bulunamadı.'),
                onRetry: () => ref.invalidate(currentProfileProvider),
              );
            }
            // Dershane pasifse panele girilmez (veriler RLS ile zaten kapalı).
            final tenant = ref.watch(tenantBrandingProvider);
            if (tenant.isLoading && !tenant.hasValue) {
              return const CircularProgressIndicator();
            }
            final t = tenant.value;
            if (t != null && !t.isActive) {
              return _Problem(
                message: tr(
                  '{name} için erişim şu an kapalı. Kurumunla iletişime geç.',
                  {'name': t.name},
                ),
                onRetry: () => ref.invalidate(tenantBrandingProvider),
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go(homeFor(p.role));
            });
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}

class _Problem extends ConsumerWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Bizz(size: 100),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(tr('Tekrar dene'))),
          TextButton(
            onPressed: () async {
              final ok = await confirm(
                context,
                title: tr('Çıkış yapılsın mı?'),
                message: tr('Tekrar girmek için e-posta ve şifren gerekecek.'),
                action: tr('Çıkış yap'),
              );
              if (ok) await ref.read(authRepositoryProvider).signOut();
            },
            child: Text(tr('Çıkış yap')),
          ),
        ],
      ),
    );
  }
}
