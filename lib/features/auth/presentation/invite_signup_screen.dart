import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/branding_providers.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/settings_controls.dart';
import '../data/auth_repository.dart';
import '../data/email_check.dart';
import '../data/profile.dart';
import 'auth_error.dart';
import '../../../core/i18n/i18n.dart';

/// Üç adımlı kayıt: davet kodu doğrulanır, hesap bilgileri alınır, sonra
/// e-postaya giden doğrulama koduyla adresin gerçekten kullanıcıya ait olduğu
/// kanıtlanır (hesap ancak o zaman açılır).
class InviteSignupScreen extends ConsumerStatefulWidget {
  const InviteSignupScreen({super.key, this.initialCode});

  /// Davet linkiyle gelindiyse kod; ekran açılınca otomatik doğrulanır.
  final String? initialCode;

  @override
  ConsumerState<InviteSignupScreen> createState() => _InviteSignupScreenState();
}

class _InviteSignupScreenState extends ConsumerState<InviteSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _otp = TextEditingController();

  InviteInfo? _invite;
  bool _kvkk = false;
  bool _loading = false;

  /// Doğrulama kodunun gönderildiği adres; doluysa kod adımındayız.
  String? _codeSentTo;

  /// Yeniden gönderme için kalan saniye.
  int _resendIn = 0;
  Timer? _resendTimer;

  // initState'te alınır: dispose'da ref kullanılamaz (tembel alan orada ilk
  // kez okunursa hata verirdi).
  late final InviteBranding _inviteBranding;

  @override
  void initState() {
    super.initState();
    _inviteBranding = ref.read(inviteBrandingProvider.notifier);
    final code = widget.initialCode?.trim();
    if (code != null && code.isNotEmpty) {
      _code.text = code.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _verifyCode();
      });
    }
  }

  @override
  void dispose() {
    // Kayıt ekranından çıkınca davetin markası bırakılır; giriş yapıldıysa
    // tema kullanıcının kendi dershanesinden gelir.
    final branding = _inviteBranding;
    Future.microtask(() => branding.set(null));
    _code.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    _otp.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _verifyCode() async {
    if (_code.text.trim().length < 6) {
      _showError(tr('Davet kodu en az 6 karakter olmalı.'));
      return;
    }
    setState(() => _loading = true);
    try {
      final invite = await ref
          .read(authRepositoryProvider)
          .checkInvite(_code.text);
      if (!mounted) return;
      if (invite == null) {
        _showError(tr('Bu davet kodu geçersiz veya süresi dolmuş.'));
      } else {
        setState(() => _invite = invite);
        // Davetin dershanesinin markası anında uygulanır ve hatırlanır.
        final tenant = invite.tenant;
        if (tenant != null) {
          _inviteBranding.set(tenant);
          if (tenant.slug != null) {
            ref.read(savedTenantSlugProvider.notifier).set(tenant.slug);
          }
        }
      }
    } catch (e) {
      if (mounted) _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    final suggestion = suggestEmail(_email.text);
    if (suggestion != null) {
      final fix = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('E-posta adresini kontrol et')),
          content: Text(
            tr('Bunu mu demek istedin: {email}?', {'email': suggestion}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Hayır, böyle kalsın')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('Evet, düzelt')),
            ),
          ],
        ),
      );
      if (!mounted || fix == null) return;
      if (fix) _email.text = suggestion;
    }
    if (!_kvkk) {
      _showError(tr('Devam etmek için aydınlatma metnini onaylamalısın.'));
      return;
    }
    setState(() => _loading = true);
    try {
      final codeSent = await ref
          .read(authRepositoryProvider)
          .signUpWithInvite(
            email: _email.text.trim(),
            password: _password.text,
            fullName: _name.text,
            inviteCode: _code.text,
          );
      if (!mounted) return;
      if (codeSent) {
        _otp.clear();
        setState(() => _codeSentTo = _email.text.trim());
        _startResendCountdown();
      }
      // Oturum açıldıysa router otomatik olarak ana sayfaya yönlendirir.
    } catch (e) {
      if (mounted) _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _verifyOtp() async {
    final email = _codeSentTo;
    final code = _otp.text.trim();
    if (email == null) return;
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      _showError(tr('E-postana gelen kodu eksiksiz gir.'));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .verifySignupCode(email: email, code: code);
      // Oturum açıldı; router ana sayfaya yönlendirir.
    } catch (e) {
      if (mounted) _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    final email = _codeSentTo;
    if (email == null || _resendIn > 0) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resendSignupCode(email);
      if (!mounted) return;
      _showError(tr('Yeni kod gönderildi.'));
      _startResendCountdown();
    } catch (e) {
      if (mounted) _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Yanlış adres yazıldıysa forma dön. Doğrulanmamış kayıt daveti
  /// harcamadığı için yeni adresle yeniden denenebilir.
  void _changeEmail() {
    _resendTimer?.cancel();
    setState(() {
      _codeSentTo = null;
      _resendIn = 0;
    });
  }

  List<Widget> _codeStep(String email, TextTheme text) => [
    Icon(
      Icons.mark_email_unread_outlined,
      size: 44,
      color: context.brand.primaryDeep,
    ),
    const SizedBox(height: 12),
    Text(
      tr('{email} adresine bir doğrulama kodu gönderdik.', {'email': email}),
      textAlign: TextAlign.center,
      style: text.titleSmall,
    ),
    const SizedBox(height: 6),
    Text(
      tr(
        'Kodu aşağıya yaz; hesabın o zaman açılır. Gelmediyse istenmeyen (spam) klasörüne de bak.',
      ),
      textAlign: TextAlign.center,
      style: text.bodySmall,
    ),
    const SizedBox(height: 20),
    TextField(
      controller: _otp,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 10,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: text.headlineSmall?.copyWith(letterSpacing: 8),
      decoration: InputDecoration(
        labelText: tr('Doğrulama kodu'),
        counterText: '',
      ),
      onSubmitted: (_) => _verifyOtp(),
    ),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: _loading ? null : _verifyOtp,
      child: _loading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : Text(tr('Doğrula ve hesabımı aç')),
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: _loading || _resendIn > 0 ? null : _resendCode,
      child: Text(
        _resendIn > 0
            ? tr('Kodu yeniden gönder ({n} sn)', {'n': _resendIn})
            : tr('Kodu yeniden gönder'),
      ),
    ),
    TextButton(
      onPressed: _loading ? null : _changeEmail,
      child: Text(tr('E-posta adresini değiştir')),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    final text = Theme.of(context).textTheme;
    final codeSentTo = _codeSentTo;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
        title: Text(tr('Hesap oluştur')),
        actions: const [QuickSettingsBar()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: invite?.tenant == null
                          ? const Bizz(size: 110)
                          : const BrandLogo(fontSize: 30),
                    ),
                    const SizedBox(height: 16),
                    _Steps(
                      current: invite == null
                          ? 0
                          : codeSentTo == null
                          ? 1
                          : 2,
                    ),
                    const SizedBox(height: 16),
                    if (codeSentTo != null)
                      ..._codeStep(codeSentTo, text)
                    else ...[
                      Text(
                        invite == null
                            ? tr(
                                '{app} hesabı yalnızca davetle açılır. Kurumundan, koçundan ya da çocuğundan aldığın davet kodunu gir.',
                                {'app': context.brand.appName},
                              )
                            : tr('Harika! Şimdi hesap bilgilerini gir.'),
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _code,
                        enabled: invite == null,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: tr('Davet kodu'),
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                        ),
                        onFieldSubmitted: (_) => _verifyCode(),
                      ),
                      if (invite != null) ...[
                        const SizedBox(height: 12),
                        _InviteBadge(invite: invite),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: tr('Ad Soyad'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().length < 3)
                              ? tr('Adını ve soyadını gir')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: tr('E-posta'),
                            prefixIcon: const Icon(Icons.mail_outline),
                          ),
                          autofillHints: const [AutofillHints.email],
                          validator: (v) => (v == null || !isValidEmail(v))
                              ? tr('Geçerli bir e-posta gir (ör. ad@gmail.com)')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        PasswordField(
                          controller: _password,
                          label: tr('Şifre (en az 8 karakter)'),
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (v) => (v == null || v.length < 8)
                              ? tr('Şifre en az 8 karakter olmalı')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        PasswordField(
                          controller: _password2,
                          label: tr('Şifre (tekrar)'),
                          autofillHints: const [AutofillHints.newPassword],
                          validator: (v) => v != _password.text
                              ? tr('Şifreler birbiriyle eşleşmiyor')
                              : null,
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _kvkk,
                          onChanged: (v) => setState(() => _kvkk = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            tr(
                              'KVKK aydınlatma metnini okudum, kişisel verilerimin işlenmesine onay veriyorum.',
                            ),
                            style: text.bodySmall,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading
                            ? null
                            : (invite == null ? _verifyCode : _signUp),
                        child: _loading
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              )
                            : Text(
                                invite == null
                                    ? tr('Kodu doğrula')
                                    : tr('Devam et: e-postamı doğrula'),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kayıt adımları: davet kodu → bilgiler → doğrulama.
class _Steps extends StatelessWidget {
  const _Steps({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final labels = [tr('Davet kodu'), tr('Bilgiler'), tr('Doğrulama')];
    final deep = context.brand.primaryDeep;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= current ? deep : deep.withValues(alpha: 0.2),
              ),
            ),
          Column(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: i <= current
                    ? deep
                    : deep.withValues(alpha: 0.15),
                child: i < current
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: i <= current ? Colors.white : deep,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: text.labelSmall),
            ],
          ),
        ],
      ],
    );
  }
}

class _InviteBadge extends StatelessWidget {
  const _InviteBadge({required this.invite});

  final InviteInfo invite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.brand.primary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: context.brand.primaryDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('{p0} · {p1} olarak katılıyorsun', {
                'p0': invite.orgName,
                'p1': invite.role.label,
              }),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
