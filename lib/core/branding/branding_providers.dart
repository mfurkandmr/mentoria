import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/tenants/data/tenant_repository.dart';
import '../settings/app_settings.dart';
import 'branding.dart';

/// Giriş ekranında seçilen dershane kodu (slug); cihazda kalıcı.
/// Bir sonraki açılışta giriş ekranı doğrudan o dershanenin markasıyla gelir.
class SavedTenantSlug extends Notifier<String?> {
  static const _key = 'tenant_slug';

  @override
  String? build() => ref.watch(sharedPreferencesProvider)?.getString(_key);

  void set(String? slug) {
    state = slug;
    final prefs = ref.read(sharedPreferencesProvider);
    slug == null ? prefs?.remove(_key) : prefs?.setString(_key, slug);
  }
}

final savedTenantSlugProvider = NotifierProvider<SavedTenantSlug, String?>(
  SavedTenantSlug.new,
);

/// Davet linki/koduyla gelen kullanıcının dershanesi (kayıt ekranında).
class InviteBranding extends Notifier<Branding?> {
  @override
  Branding? build() => null;

  void set(Branding? b) {
    // Kayıt ekranı kapanırken çağrılır; o sırada kapsam da kapanmışsa
    // (ör. uygulama / test kapanışı) yapılacak bir şey yok.
    if (ref.mounted) state = b;
  }
}

final inviteBrandingProvider = NotifierProvider<InviteBranding, Branding?>(
  InviteBranding.new,
);

/// Sunucudaki dershane markası:
///  * giriş yapılmışsa kullanıcının dershanesi,
///  * değilse kayıtlı dershane kodunun markası,
///  * ikisi de yoksa null (Mentoria).
final tenantBrandingProvider = FutureProvider<Branding?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final repo = ref.watch(tenantRepositoryProvider);
  if (profile != null) return repo.fetchMyTenant();
  final slug = ref.watch(savedTenantSlugProvider);
  if (slug == null) return null;
  return repo.fetchBySlug(slug);
});

/// Ekranda kullanılan marka. Yüklenirken ya da hata olursa Mentoria.
final activeBrandingProvider = Provider<Branding>((ref) {
  final invite = ref.watch(inviteBrandingProvider);
  if (invite != null) return invite;
  final tenant = ref.watch(tenantBrandingProvider);
  // İlk yüklemede değer yoktur → Mentoria. Yenilenirken önceki marka kalır
  // (ekran her oturum olayında Mentoria'ya dönüp gelmesin).
  if (tenant.hasError) return Branding.mentoria;
  return tenant.value ?? Branding.mentoria;
});

/// Giriş yapan kullanıcı süper admin mi (dershane yönetim paneli).
final isSuperAdminProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return false;
  try {
    return await ref.watch(tenantRepositoryProvider).isSuperAdmin();
  } catch (_) {
    return false;
  }
});
