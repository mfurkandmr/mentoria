import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/branding_providers.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../tenants/data/tenant_repository.dart';
import '../../tenants/presentation/tenant_code_chip.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/effects.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/settings_controls.dart';
import '../data/auth_repository.dart';
import 'auth_error.dart';
import 'reset_password_screen.dart';
import '../../../core/i18n/i18n.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _bizz = BizzController();
  bool _passwordVisible = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_react);
    _passwordFocus.addListener(_react);
    _email.addListener(_react);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _bizz.dispose();
    super.dispose();
  }

  /// Bızz, e-posta yazılırken yazıyı gözleriyle takip eder; şifrede gözlerini
  /// kapatır, şifre gösterilirse tek gözle gizlice bakar.
  void _react() {
    if (_passwordFocus.hasFocus) {
      _bizz
        ..look = null
        ..mood = _passwordVisible ? BizzMood.peek : BizzMood.eyesClosed;
    } else if (_emailFocus.hasFocus) {
      final x = (_email.text.length / 28).clamp(0.0, 1.0) * 2 - 1;
      _bizz
        ..mood = BizzMood.idle
        ..look = Offset(x, 0.8);
    } else {
      _bizz
        ..mood = BizzMood.idle
        ..look = null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _bizz.shake();
      return;
    }
    setState(() => _loading = true);
    // Oturum açılınca router bu ekranı kapatabilir; gerekenleri önceden al.
    final auth = ref.read(authRepositoryProvider);
    final tenants = ref.read(tenantRepositoryProvider);
    final chosenSlug = ref.read(savedTenantSlugProvider);
    final savedSlug = ref.read(savedTenantSlugProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.signIn(email: _email.text.trim(), password: _password.text);
      _bizz
        ..mood = BizzMood.happy
        ..celebrate();
      await _checkTenant(auth, tenants, chosenSlug, savedSlug, messenger);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _bizz
        ..mood = BizzMood.sad
        ..shake();
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted && _bizz.mood == BizzMood.sad) _react();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Dershane koduyla girildiyse hesap o dershaneye ait olmalı; değilse
  /// oturum kapatılır. Uygunsa kullanıcının dershanesi hatırlanır.
  Future<void> _checkTenant(
    AuthRepository auth,
    TenantRepository tenants,
    String? chosenSlug,
    SavedTenantSlug savedSlug,
    ScaffoldMessengerState messenger,
  ) async {
    final mine = await tenants.fetchMyTenant();
    if (chosenSlug != null && mine?.slug != chosenSlug) {
      await auth.signOut();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Bu hesap seçtiğin dershaneye ait değil. Dershane kodunu kontrol et.',
            ),
          ),
        ),
      );
      return;
    }
    if (mine?.slug != null) savedSlug.set(mine!.slug);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Widget step(int i, Widget child) =>
        FadeSlideIn(delay: FadeSlideIn.stagger(i, 70), child: child);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: HoneycombPainter(
                color: isDark
                    ? context.brand.primary
                    : context.brand.primaryDeep,
                opacity: isDark ? 0.06 : 0.09,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          step(
                            0,
                            Center(child: Bizz(size: 150, controller: _bizz)),
                          ),
                          const SizedBox(height: 8),
                          step(1, const Center(child: BrandLogo())),
                          const SizedBox(height: 8),
                          step(1, const Center(child: TenantCodeChip())),
                          const SizedBox(height: 4),
                          step(
                            2,
                            Text(
                              tr('Hedefine giden yolda her gün biraz daha.'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 32),
                          step(
                            3,
                            TextFormField(
                              controller: _email,
                              focusNode: _emailFocus,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: tr('E-posta'),
                                prefixIcon: const Icon(Icons.mail_outline),
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? tr('Geçerli bir e-posta gir')
                                  : null,
                              onFieldSubmitted: (_) =>
                                  _passwordFocus.requestFocus(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          step(
                            4,
                            PasswordField(
                              controller: _password,
                              focusNode: _passwordFocus,
                              label: tr('Şifre'),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? tr('Şifreni gir')
                                  : null,
                              onSubmitted: (_) => _submit(),
                              onVisibilityChanged: (v) {
                                _passwordVisible = v;
                                _react();
                              },
                            ),
                          ),
                          step(
                            5,
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => showForgotPasswordDialog(
                                  context,
                                  ref,
                                  initialEmail: _email.text.trim(),
                                ),
                                child: Text(tr('Şifremi unuttum')),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          step(
                            6,
                            PressScale(
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: _loading
                                      ? const SizedBox.square(
                                          key: ValueKey('loading'),
                                          dimension: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Text(
                                          tr('Giriş yap'),
                                          key: const ValueKey('label'),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          step(
                            7,
                            TextButton(
                              onPressed: () => context.go('/signup'),
                              child: Text(tr('Davet kodum var, hesap oluştur')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: QuickSettingsBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
