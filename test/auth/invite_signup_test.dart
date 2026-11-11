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
  _FakeAuth({
    this.numberMode = 'free',
    this.numbers = const {},
    this.role = UserRole.student,
  });

  /// Kurumun kayıt modu ve numara → 'ok' | 'not_found' | 'taken'.
  final String numberMode;
  final Map<String, String> numbers;

  /// Davetin rolü.
  final UserRole role;

  final calls = <String>[];
  String? signedUpEmail;
  String? studentNumber;
  List<String>? teacherBranches;
  int? birthYear;
  int? gradeLevel;
  bool? ranking;

  @override
  Future<InviteInfo?> checkInvite(String code) async =>
      InviteInfo(role: role, orgName: 'Bal Kurs', numberMode: numberMode);

  @override
  Future<String> matchStudentNumber(String code, String number) async {
    calls.add('match:$number');
    return numbers[number] ?? (numberMode == 'list' ? 'not_found' : 'ok');
  }

  @override
  Future<bool> signUpWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
    int? birthYear,
    int? gradeLevel,
    String? studentNumber,
    List<String>? teacherBranches,
    bool rankingConsent = false,
    bool guardianApproval = false,
    bool childRanking = false,
  }) async {
    calls.add('signUp');
    signedUpEmail = email;
    this.teacherBranches = teacherBranches;
    this.studentNumber = studentNumber;
    this.birthYear = birthYear;
    this.gradeLevel = gradeLevel;
    ranking = rankingConsent;
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
      tester.view.physicalSize = const Size(1080, 4500);
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
      await tester.enterText(fields.at(2), '1042');
      await tester.enterText(fields.at(3), 'elif@gmial.com');
      await tester.enterText(fields.at(4), 'balarisi1');
      await tester.enterText(fields.at(5), 'balarisi2');
      // KVKK: doğum yılı, aydınlatma teyidi ve isteğe bağlı sıralama rızası.
      final year = DateTime.now().year - 17;
      await tester.tap(find.text('Doğum yılı'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$year').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sınıf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('11. sınıf').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          "Kullanım Koşulları'nı kabul ediyorum; Aydınlatma Metni'ni okudum.",
        ),
      );
      await tester.tap(
        find.textContaining('başarı sıralamasında adımın kısaltması'),
      );
      expect(
        find.textContaining('18 yaşından küçüksen velinin onayı gerekir'),
        findsOneWidget,
      );
      final submit = find.text('Devam et: e-postamı doğrula');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Şifreler birbiriyle eşleşmiyor'), findsOneWidget);
      expect(auth.calls, isEmpty);

      await tester.enterText(fields.at(5), 'balarisi1');
      await tester.ensureVisible(submit);
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
      expect(auth.studentNumber, '1042');
      expect(auth.calls.first, 'match:1042');
      expect(auth.birthYear, DateTime.now().year - 17);
      expect(auth.gradeLevel, 11);
      expect(auth.ranking, isTrue);

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

  testWidgets('öğretmen daveti: branş seçmeden kayıt olmaz, branşlar gider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4500);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = _FakeAuth(role: UserRole.teacher);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(
          home: InviteSignupScreen(initialCode: 'OGRETMN1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Öğrenci numaran'), findsNothing);
    expect(find.text('Doğum yılı'), findsNothing);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Selin Kaya');
    await tester.enterText(fields.at(2), 'selin@gmail.com');
    await tester.enterText(fields.at(3), 'balarisi1');
    await tester.enterText(fields.at(4), 'balarisi1');
    await tester.tap(
      find.text(
        "Kullanım Koşulları'nı kabul ediyorum; Aydınlatma Metni'ni okudum.",
      ),
    );
    final submit = find.text('Devam et: e-postamı doğrula');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('En az bir branş seç.'), findsOneWidget);
    expect(auth.calls, isEmpty);
    // Hata mesajı düğmenin üstünü kapatmasın.
    ScaffoldMessenger.of(tester.element(submit)).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('signup-branch-Kimya')),
    );
    await tester.tap(find.byKey(const ValueKey('signup-branch-Kimya')));
    await tester.tap(find.byKey(const ValueKey('signup-branch-Biyoloji')));
    await tester.pump();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(auth.calls, ['signUp']);
    expect(auth.teacherBranches, ['Kimya', 'Biyoloji']);
    expect(auth.studentNumber, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('liste modu: listede olmayan numarayla kayıt yapılmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4500);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = _FakeAuth(numberMode: 'list', numbers: {'2001': 'taken'});
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
    expect(
      find.textContaining('Kurumunun listesindeki numaran'),
      findsOneWidget,
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Elif Yılmaz');
    await tester.enterText(fields.at(2), '9999');
    await tester.enterText(fields.at(3), 'elif@gmail.com');
    await tester.enterText(fields.at(4), 'balarisi1');
    await tester.enterText(fields.at(5), 'balarisi1');
    final year = DateTime.now().year - 17;
    await tester.tap(find.text('Doğum yılı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$year').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sınıf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12. sınıf / mezun').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(
        "Kullanım Koşulları'nı kabul ediyorum; Aydınlatma Metni'ni okudum.",
      ),
    );
    final submit = find.text('Devam et: e-postamı doğrula');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bu numara kurum listesinde bulunamadı'),
      findsOneWidget,
    );
    expect(auth.calls, ['match:9999']);

    await tester.enterText(fields.at(2), '2001');
    // Hata bildirimi düğmenin üstünü kapatmasın.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(auth.calls, ['match:9999', 'match:2001']);
    expect(find.textContaining('Bu numara zaten kullanımda'), findsOneWidget);
    expect(auth.calls.contains('signUp'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
