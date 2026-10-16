import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/i18n/i18n.dart';

/// Supabase hatalarını kullanıcıya gösterilecek Türkçe mesaja çevirir.
String authErrorMessage(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return tr('E-posta veya şifre hatalı.');
    }
    if (msg.contains('email not confirmed')) {
      return tr('E-posta adresini henüz doğrulamadın.');
    }
    if (msg.contains('signups not allowed') ||
        msg.contains('signup is disabled')) {
      return tr('Yeni kayıtlar şu an kapalı. Kurum yöneticine haber ver.');
    }
    if (msg.contains('rate limit')) {
      return tr(
        'Kısa sürede çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.',
      );
    }
    if (msg.contains('expired or is invalid') || msg.contains('otp')) {
      return tr('Kod hatalı ya da süresi dolmuş. Yeni kod isteyebilirsin.');
    }
    if (msg.contains('email address') && msg.contains('invalid')) {
      return tr('Bu e-posta adresi geçerli değil.');
    }
    if (msg.contains('already registered')) {
      return tr('Bu e-posta ile zaten bir hesap var.');
    }
    if (msg.contains('same password') ||
        msg.contains('different from the old')) {
      return tr('Yeni şifre eskisiyle aynı olamaz.');
    }
    if (msg.contains('password')) {
      return tr('Şifre en az 8 karakter olmalı.');
    }
    if (msg.contains('database error')) {
      // handle_new_user tetikleyicisi daveti reddetti.
      return tr(
        'Davet kodu geçersiz, süresi dolmuş veya kurumun lisans kotası dolu.',
      );
    }
    return error.message;
  }
  return tr('Bir şeyler ters gitti. Lütfen tekrar dene.');
}
