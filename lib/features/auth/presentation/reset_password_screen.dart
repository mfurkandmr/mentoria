import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/password_field.dart';
import '../data/auth_repository.dart';
import 'auth_error.dart';
import '../../../core/i18n/i18n.dart';

/// E-postadaki sıfırlama bağlantısından gelen kullanıcı burada yeni şifre
/// belirler. (Bağlantı Supabase oturumu açar; router bu ekrana yönlendirir.)
final passwordRecovery = ValueNotifier<bool>(false);

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      passwordRecovery.value = false;
      if (!mounted) return;
      showMessage(context, tr('Şifren güncellendi.'));
      context.go('/');
    } catch (e) {
      if (mounted) showMessage(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    const Center(child: Bizz(size: 110)),
                    const SizedBox(height: 16),
                    Text(
                      tr('Yeni şifreni belirle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PasswordFields(password: _password, again: _again),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(tr('Şifremi kaydet')),
                    ),
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

/// Yeni şifre + tekrar alanları (doğrulamalı).
class PasswordFields extends StatelessWidget {
  const PasswordFields({
    super.key,
    required this.password,
    required this.again,
  });

  final TextEditingController password;
  final TextEditingController again;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PasswordField(
          controller: password,
          label: tr('Yeni şifre (en az 8 karakter)'),
          autofillHints: const [AutofillHints.newPassword],
          validator: (v) => (v == null || v.length < 8)
              ? tr('Şifre en az 8 karakter olmalı')
              : null,
        ),
        const SizedBox(height: 12),
        PasswordField(
          controller: again,
          label: tr('Yeni şifre (tekrar)'),
          autofillHints: const [AutofillHints.newPassword],
          validator: (v) =>
              v != password.text ? tr('Şifreler aynı değil') : null,
        ),
      ],
    );
  }
}

/// Giriş ekranındaki "Şifremi unuttum" penceresi.
Future<void> showForgotPasswordDialog(
  BuildContext context,
  WidgetRef ref, {
  String initialEmail = '',
}) async {
  final controller = TextEditingController(text: initialEmail);
  final email = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Şifremi unuttum')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(
              'Hesabının e-posta adresini yaz; şifreni yenilemen için bir bağlantı gönderelim.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: tr('E-posta')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(tr('Bağlantı gönder')),
        ),
      ],
    ),
  );
  controller.dispose();
  if (email == null || !email.contains('@') || !context.mounted) return;
  try {
    await ref.read(authRepositoryProvider).sendPasswordReset(email);
    if (context.mounted) {
      showMessage(
        context,
        tr(
          'Sıfırlama bağlantısını {email} adresine gönderdik. Gelen kutunu kontrol et.',
          {'email': email},
        ),
      );
    }
  } catch (e) {
    if (context.mounted) showMessage(context, authErrorMessage(e));
  }
}
