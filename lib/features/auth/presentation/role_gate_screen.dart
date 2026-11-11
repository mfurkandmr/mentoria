import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/branding_providers.dart';
import '../../credits/data/org_credits_repository.dart';
import '../../privacy/data/consent_repository.dart';
import '../../privacy/presentation/legal_update_screen.dart';
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
    UserRole.teacher => '/teacher',
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
            // Kurumun lisansı bittiyse öğrenci, koç ve veli giremez (veriler
            // RLS ile zaten kapalı); müdür girer ve panelinde görür.
            final license = ref.watch(licenseActiveProvider);
            if (license.isLoading && !license.hasValue) {
              return const CircularProgressIndicator();
            }
            if (license.value == false) {
              return _Problem(
                message: tr(
                  'Kurumunun lisans süresi doldu. Kurum yöneticinle iletişime geç.',
                ),
                onRetry: () => ref.invalidate(licenseActiveProvider),
              );
            }
            // KVKK: yayımlanan metin sürümü onaylanmadıysa önce onay. Durum
            // okunamazsa (bağlantı) kişi içeride kilitli kalmasın, geçer.
            final consent = ref.watch(myConsentStatusProvider);
            if (consent.isLoading && !consent.hasValue) {
              return const CircularProgressIndicator();
            }
            if (consent.value?.needsLegalAccept ?? false) {
              return const LegalUpdatePrompt();
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
