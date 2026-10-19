import '../../privacy/data/consent_repository.dart';
import '../../student/data/home_seed.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile.dart';

/// Mobilde e-posta bağlantılarının döneceği derin bağlantı.
/// Supabase → Authentication → URL Configuration → Redirect URLs listesine
/// eklenmeli.
const mobileAuthRedirect = 'mentoria://reset-password';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// Davet kodunu doğrular. Geçersiz / süresi dolmuş kodlarda `null` döner.
  Future<InviteInfo?> checkInvite(String code) async {
    final result = await _client.rpc(
      'check_invite',
      params: {'p_code': code.trim().toUpperCase()},
    );
    if (result == null) return null;
    return InviteInfo.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Kayıt yalnızca davet koduyla yapılır. Kodun asıl doğrulaması ve
  /// profil/ilişki kayıtları veritabanındaki `handle_new_user` tetikleyicisinde
  /// (e-posta doğrulanınca; davet ondan önce harcanmaz).
  /// Dönüş: e-postaya doğrulama kodu gittiyse `true`, oturum hemen açıldıysa
  /// (Supabase'de "Confirm email" kapalı) `false`.
  Future<bool> signUpWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
    int? birthYear,
    bool rankingConsent = false,
    bool guardianApproval = false,
    bool childRanking = false,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      // Profil, rızalar ve veli onayı e-posta doğrulanınca sunucuda yazılır
      // (apply_signup_invite).
      data: {
        'full_name': fullName.trim(),
        'invite_code': inviteCode.trim().toUpperCase(),
        // Aydınlatma metni teyidi (rıza değil) ve metin sürümü.
        'kvkk_consent': true,
        'privacy_version': legalVersion,
        'birth_year': ?birthYear,
        'consents': {'ranking': rankingConsent},
        if (guardianApproval) 'guardian_approval': true,
        if (childRanking) 'child_ranking': true,
      },
    );
    // Adres zaten doğrulanmış bir hesaba aitse Supabase, hesapları tahmin
    // ettirmemek için hata yerine kimliksiz bir kullanıcı döndürür.
    final identities = res.user?.identities;
    if (res.session == null && identities != null && identities.isEmpty) {
      throw const AuthException('User already registered');
    }
    return res.session == null;
  }

  /// Kayıt e-postasındaki kodu doğrular; başarılıysa oturum açılır.
  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) => _client.auth.verifyOTP(
    type: OtpType.signup,
    email: email.trim(),
    token: code.trim(),
  );

  /// Doğrulama kodunu yeniden gönderir.
  Future<void> resendSignupCode(String email) =>
      _client.auth.resend(type: OtpType.signup, email: email.trim());

  /// Çıkıştan hemen önce çalışır (ör. bu cihazın bildirim adresini silmek).
  /// Hata verse bile çıkış yapılır.
  static Future<void> Function()? beforeSignOut;

  Future<void> signOut() async {
    try {
      await beforeSignOut?.call();
    } catch (_) {}
    // Cihazda bu hesabın ana sayfası kalmasın.
    await HomeSeed.clearDisk();
    await _client.auth.signOut();
  }

  /// Şifre sıfırlama e-postası gönderir. Bağlantı web'de uygulamanın kendi
  /// adresine, mobilde `mentoria://reset-password` derin bağlantısına döner.
  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? Uri.base.origin : mobileAuthRedirect,
      );

  /// Oturumdaki kullanıcının şifresini değiştirir.
  Future<void> updatePassword(String password) =>
      _client.auth.updateUser(UserAttributes(password: password));

  /// Hesabı ve tüm verilerini kalıcı olarak siler (`delete_my_account`).
  Future<void> deleteMyAccount() async {
    await _client.rpc('delete_my_account');
    await _client.auth.signOut();
  }

  Future<Profile?> fetchCurrentProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }
}

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).fetchCurrentProfile();
});
