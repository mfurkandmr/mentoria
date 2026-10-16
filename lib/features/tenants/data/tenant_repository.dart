import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/branding/branding.dart';
import '../../auth/data/auth_repository.dart';

/// Süper adminin yeni dershane formu.
class TenantDraft {
  const TenantDraft({
    required this.name,
    required this.slug,
    required this.primaryHex,
    required this.secondaryHex,
    this.seatLimit = 50,
  });

  final String name;
  final String slug;
  final String primaryHex;
  final String secondaryHex;
  final int seatLimit;
}

/// Yeni dershane açılınca dönen bilgiler.
class TenantCreated {
  const TenantCreated({required this.tenantId, required this.adminCode});

  final String tenantId;

  /// Dershanenin ilk kurum müdürü bu kodla kayıt olur.
  final String adminCode;
}

abstract interface class TenantRepository {
  /// Giriş yapmış kullanıcının dershanesi (yoksa null).
  Future<Branding?> fetchMyTenant();

  /// Giriş ekranı için: aktif dershanenin herkese açık markası (yoksa null).
  Future<Branding?> fetchBySlug(String slug);

  Future<bool> isSuperAdmin();

  // --- Süper admin ---
  Future<List<Branding>> listTenants();
  Future<TenantCreated> createTenant(TenantDraft draft);
  Future<void> updateTenant(Branding tenant);

  /// Logoyu Storage'a yükler ve herkese açık adresini döndürür.
  Future<String> uploadLogo(String tenantId, Uint8List bytes, String extension);
  Future<String> createAdminInvite(String tenantId);

  // --- Kurum müdürü (kendi dershanesi) ---
  /// Ad, renk, logo ve yazı tipini günceller; slug ve aktiflik değişmez.
  /// Tek kurumlu dershanede kurum adı da aynı olur.
  Future<void> updateMyBranding(Branding branding);
}

class SupabaseTenantRepository implements TenantRepository {
  SupabaseTenantRepository(this._client);

  final SupabaseClient _client;
  static const logoBucket = 'tenant-logos';

  @override
  Future<Branding?> fetchMyTenant() async {
    if (_client.auth.currentUser == null) return null;
    final id = await _client.rpc<String?>('my_tenant');
    if (id == null) return null;
    final row = await _client
        .from('tenants')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Branding.fromJson(row);
  }

  @override
  Future<Branding?> fetchBySlug(String slug) async {
    final res = await _client.rpc<Map<String, dynamic>?>(
      'tenant_branding',
      params: {'p_slug': slug},
    );
    return res == null ? null : Branding.fromJson(res);
  }

  @override
  Future<bool> isSuperAdmin() async {
    if (_client.auth.currentUser == null) return false;
    return await _client.rpc<bool>('is_super_admin');
  }

  @override
  Future<List<Branding>> listTenants() async {
    final rows = await _client.from('tenants').select().order('name');
    return [for (final r in rows) Branding.fromJson(r)];
  }

  @override
  Future<TenantCreated> createTenant(TenantDraft d) async {
    final res = await _client.rpc<Map<String, dynamic>>(
      'create_tenant',
      params: {
        'p_name': d.name,
        'p_slug': d.slug,
        'p_primary_color': d.primaryHex,
        'p_secondary_color': d.secondaryHex,
        'p_seat_limit': d.seatLimit,
      },
    );
    return TenantCreated(
      tenantId: res['tenant_id'] as String,
      adminCode: res['admin_code'] as String,
    );
  }

  @override
  Future<void> updateTenant(Branding t) => _client
      .from('tenants')
      .update({
        'name': t.name,
        'slug': t.slug,
        'logo_url': t.logoUrl,
        'primary_color': Branding.toHex(t.primary),
        'secondary_color': Branding.toHex(t.secondary),
        'font_family': t.font.key,
        'is_active': t.isActive,
      })
      .eq('id', t.tenantId!);

  @override
  Future<String> uploadLogo(
    String tenantId,
    Uint8List bytes,
    String extension,
  ) async {
    final ext = extension.toLowerCase().replaceFirst('jpg', 'jpeg');
    // Her yüklemede yeni ad: önbellekteki eski logo hemen değişsin.
    final path = '$tenantId/logo-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from(logoBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
    return _client.storage.from(logoBucket).getPublicUrl(path);
  }

  @override
  Future<void> updateMyBranding(Branding b) => _client.rpc(
    'update_my_branding',
    params: {
      'p_name': b.name,
      'p_primary_color': Branding.toHex(b.primary),
      'p_secondary_color': Branding.toHex(b.secondary),
      'p_logo_url': b.logoUrl,
      'p_font_family': b.font.key,
    },
  );

  @override
  Future<String> createAdminInvite(String tenantId) async =>
      await _client.rpc<String>(
        'create_tenant_admin_invite',
        params: {'p_tenant': tenantId},
      );
}

final tenantRepositoryProvider = Provider<TenantRepository>(
  (ref) => SupabaseTenantRepository(ref.watch(supabaseClientProvider)),
);

/// Süper admin paneli listesi.
final tenantsProvider = FutureProvider<List<Branding>>(
  (ref) => ref.watch(tenantRepositoryProvider).listTenants(),
);
