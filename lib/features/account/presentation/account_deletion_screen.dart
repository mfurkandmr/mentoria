import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';
import '../../auth/presentation/auth_error.dart';
import '../../privacy/presentation/privacy_screen.dart';
import '../data/account_repository.dart';
import '../../../shared/widgets/skeleton.dart';

/// Uygulamayı kurmadan hesap silme (`/hesap-sil`; Google Play zorunluluğu).
///
/// E-postaya gelen tek kullanımlık kodla oturum açılır, sonra uygulamadaki
/// kurallar aynen uygulanır: öğrenci silme talebi açar (koçu siler, 29 günde
/// sonuçlanmazsa sistem siler), diğer roller hesabını hemen siler.
class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

enum _Step { email, code, done }

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  var _step = _Step.email;
  var _busy = false;
  String? _doneMessage;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      showMessage(context, tr('Geçerli bir e-posta gir'));
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendLoginCode(email);
    } on AuthException catch (e) {
      // Kayıtlı olmayan adres: hesapların tahmin edilmemesi için kod
      // gönderilmiş gibi devam edilir.
      if (!e.message.toLowerCase().contains('signups not allowed')) {
        if (mounted) showMessage(context, authErrorMessage(e));
        return;
      }
    }
    if (mounted) setState(() => _step = _Step.code);
  });

  Future<void> _verify() => _run(() async {
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyLoginCode(email: _email.text, code: _code.text);
    } catch (e) {
      if (mounted) showMessage(context, authErrorMessage(e));
    }
  });

  Future<void> _requestAsStudent() => _run(() async {
    final auth = ref.read(authRepositoryProvider);
    try {
      await ref.read(accountRepositoryProvider).requestAccountDeletion();
      await auth.signOut();
      _finish(
        tr(
          'Talebin alındı. Hesabını ve tüm verilerini koçun siler; 29 gün içinde silinmezse sistem otomatik olarak siler.',
        ),
      );
    } catch (_) {
      if (mounted) showMessage(context, tr('İşlem yapılamadı. Tekrar dene.'));
    }
  });

  Future<void> _deleteNow() async {
    final ok = await confirm(
      context,
      title: tr('Hesabın kalıcı olarak silinsin mi?'),
      message: tr(
        'Hesabın ve tüm verilerin hemen silinir. Bu işlem geri alınamaz.',
      ),
      action: tr('Kalıcı olarak sil'),
    );
    if (!ok || !mounted) return;
    await _run(() async {
      try {
        await ref.read(authRepositoryProvider).deleteMyAccount();
        _finish(tr('Hesabın ve tüm verilerin silindi.'));
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString();
        showMessage(
          context,
          msg.contains('LAST_ADMIN')
              ? tr('Kurumun tek müdürüsün. Önce başka bir müdür eklenmeli.')
              : msg.contains('COACH_HAS_STUDENTS')
              ? tr(
                  'Bağlı öğrencilerin var. Önce kurum müdürünün öğrencilerini başka bir koça devretmesi gerekiyor.',
                )
              : tr('Hesap silinemedi. Tekrar dene.'),
        );
      }
    });
  }

  void _finish(String message) {
    if (!mounted) return;
    setState(() {
      _step = _Step.done;
      _doneMessage = message;
      _code.clear();
    });
  }

  Future<void> _signOut() => _run(() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) setState(() => _step = _Step.email);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loggedIn =
        Supabase.instance.client.auth.currentSession != null &&
        _step != _Step.done;
    // Oturum değişince (kod doğrulandı / çıkış) yeniden çizilsin.
    ref.watch(authStateProvider);

    final Widget body;
    if (_step == _Step.done) {
      body = _Done(message: _doneMessage ?? '');
    } else if (loggedIn) {
      body = ref
          .watch(currentProfileProvider)
          .when(
            loading: () => const SkeletonList(),
            error: (_, _) =>
                Text(tr('Bir şeyler ters gitti. Lütfen tekrar dene.')),
            data: (profile) => _Confirm(
              profile: profile,
              busy: _busy,
              onStudentRequest: _requestAsStudent,
              onDelete: _deleteNow,
              onCancel: _signOut,
            ),
          );
    } else if (_step == _Step.code) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              '{email} adresi kayıtlıysa 6 haneli bir kod gönderdik. Kodu aşağıya yaz.',
              {'email': _email.text.trim()},
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(
              labelText: tr('Doğrulama kodu'),
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
            onSubmitted: (_) => _busy ? null : _verify(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: Text(tr('Doğrula')),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _step = _Step.email),
            child: Text(tr('E-postayı değiştir')),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              'Hesabının e-posta adresini yaz. Hesabın sana ait olduğunu doğrulamak için bu adrese bir kod göndereceğiz.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: tr('E-posta'),
              prefixIcon: const Icon(Icons.mail_outline),
            ),
            onSubmitted: (_) => _busy ? null : _sendCode(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _sendCode,
            child: Text(tr('Kod gönder')),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo()),
                  const SizedBox(height: 24),
                  Text(
                    tr('Hesap silme'),
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  body,
                  const SizedBox(height: 32),
                  const _WhatIsDeleted(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Oturum açıldı: rolüne göre silme talebi ya da hemen silme.
class _Confirm extends StatelessWidget {
  const _Confirm({
    required this.profile,
    required this.busy,
    required this.onStudentRequest,
    required this.onDelete,
    required this.onCancel,
  });

  final Profile? profile;
  final bool busy;
  final VoidCallback onStudentRequest;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final p = profile;
    final isStudent = p?.role == UserRole.student;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p != null)
          Text(
            tr('Giriş yapılan hesap: {name} ({role})', {
              'name': p.fullName,
              'role': p.role.label,
            }),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: 8),
        Text(
          isStudent
              ? tr(
                  'Öğrenci hesabını koçun siler. Talebin koçuna iletilir; 29 gün içinde silinmezse hesabın ve tüm verilerin sistem tarafından otomatik olarak silinir.',
                )
              : tr('Hesabın ve tüm verilerin hemen ve kalıcı olarak silinir.'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: error),
          onPressed: busy ? null : (isStudent ? onStudentRequest : onDelete),
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(
            isStudent ? tr('Silme talebi gönder') : tr('Hesabımı sil'),
          ),
        ),
        TextButton(
          onPressed: busy ? null : onCancel,
          child: Text(tr('Vazgeç ve çıkış yap')),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(
        Icons.check_circle_outline,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
    ],
  );
}

/// Neler silinir, neler kalır (Google Play "veri silme" açıklaması).
class _WhatIsDeleted extends StatelessWidget {
  const _WhatIsDeleted();

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Neler silinir?'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            'Profilin, denemelerin, soru ve çalışma kayıtların, görevler, notlar, hata defteri fotoğrafları, bildirimler ve izin kayıtların silinir. Sistem yedeklerindeki kopyalar en geç 7 gün içinde kendiliğinden silinir.',
          ),
          style: small,
        ),
        if (kvkkContactEmail.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            tr('Sorun yaşarsan {email} adresine yazabilirsin.', {
              'email': kvkkContactEmail,
            }),
            style: small,
          ),
        ],
      ],
    );
  }
}
