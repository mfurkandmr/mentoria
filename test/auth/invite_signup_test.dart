import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mentoria/core/settings/app_settings.dart';
import 'package:mentoria/features/auth/data/auth_repository.dart';
import 'package:mentoria/features/auth/data/email_check.dart';
import 'package:mentoria/features/auth/data/profile.dart';
import 'package:mentoria/features/auth/presentation/invite_signup_screen.dart';
import 'package:mentoria/shared/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// Supabase'e gitmeden kayıt akışını izleyen sahte depo.
class _FakeAuth implements AuthRepository {
  final calls = <String>[];
  String? signedUpEmail;

  @override
  Future<InviteInfo?> checkInvite(String code) async =>
      const InviteInfo(role: UserRole.student, orgName: 'Bal Kurs');

  @override
  Future<bool> signUpWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) async {
    calls.add('signUp');
    signedUpEmail = email;
    return true;
  }

  @override
  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) async {
    calls.add('verify:$email:$code');
    if (code != '123456') {
      throw const AuthException('Token has expired or is invalid');
    }
  }

  @override
  Future<void> resendSignupCode(String email) async => calls.add('resend');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => Motion.enabled = false);

  group('e-posta denetimi', () {
    test('biçim', () {
      expect(isValidEmail('ali@gmail.com'), isTrue);
      expect(isValidEmail(' Ali.Veli+yks@okul.k12.tr '), isTrue);
      for (final bad in [
        'ali',
        'ali@',
        'ali@gmail',
        'a b@x.com',
        'a..b@x.com',
      ]) {
        expect(isValidEmail(bad), isFalse, reason: bad);
      }
    });
    test('yazım hatası önerisi', () {
      expect(suggestEmail('ali@gmial.com'), 'ali@gmail.com');
      expect(suggestEmail('Ali@Hotmail.con'), 'ali@hotmail.com');
      expect(suggestEmail('ali@gmail.com'), isNull);
    });
  });

  testWidgets(
    'kayıt: şifre tekrarı eşleşmeli, adres önerisi, kodla doğrulama',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = _FakeAuth();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(
            home: InviteSignupScreen(initialCode: 'ABCD2345'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 2. adım: bilgiler.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'Elif Yılmaz');
      await tester.enterText(fields.at(2), 'elif@gmial.com');
      await tester.enterText(fields.at(3), 'balarisi1');
      await tester.enterText(fields.at(4), 'balarisi2');
      await tester.tap(find.byType(CheckboxListTile));
      final submit = find.text('Devam et: e-postamı doğrula');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Şifreler birbiriyle eşleşmiyor'), findsOneWidget);
      expect(auth.calls, isEmpty);

      await tester.enterText(fields.at(4), 'balarisi1');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      // Alan adındaki yazım hatası için öneri; kabul edilince düzeltilir.
      expect(
        find.text('Bunu mu demek istedin: elif@gmail.com?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Evet, düzelt'));
      await tester.pumpAndSettle();
      expect(auth.signedUpEmail, 'elif@gmail.com');

      // 3. adım: doğrulama kodu.
      expect(
        find.text('elif@gmail.com adresine bir doğrulama kodu gönderdik.'),
        findsOneWidget,
      );
      expect(find.text('Kodu yeniden gönder (60 sn)'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Doğrula ve hesabımı aç'));
      await tester.pump();
      expect(
        find.text('Kod hatalı ya da süresi dolmuş. Yeni kod isteyebilirsin.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Doğrula ve hesabımı aç'));
      await tester.pump();
      expect(auth.calls.last, 'verify:elif@gmail.com:123456');

      // Süre dolunca yeniden gönderilebilir.
      await tester.pump(const Duration(seconds: 61));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await tester.pump();
      expect(auth.calls.last, 'resend');

      // Yanlış adres: forma dönülür, bilgiler korunur.
      await tester.tap(find.text('E-posta adresini değiştir'));
      await tester.pumpAndSettle();
      expect(find.text('elif@gmail.com'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
