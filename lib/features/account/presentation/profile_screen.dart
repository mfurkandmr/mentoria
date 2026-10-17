import 'package:flutter/material.dart';
import '../../avatar/presentation/student_avatar.dart';
import '../../avatar/data/avatar_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/branding_providers.dart';
import '../../../core/constants/exam_subjects.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/settings_controls.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';
import '../../auth/presentation/auth_error.dart';
import '../../auth/presentation/reset_password_screen.dart';
import '../../coaching/presentation/coaching_widgets.dart';
import '../../help/presentation/faq_screen.dart';
import '../data/account_repository.dart';
import '../../../shared/widgets/effects.dart';
import '../../../core/i18n/i18n.dart';
import '../../ranking/data/ranking_repository.dart';

/// Tüm rollerin profil / ayarlar ekranı.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final details = ref.watch(profileDetailsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Profil'))),
      body: profile == null
          ? const BizzLoader()
          : AsyncView(
              value: details,
              onRetry: () => ref.invalidate(profileDetailsProvider),
              builder: (d) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Center(
                    child: profile.role == UserRole.student
                        ? StudentAvatar(
                            config: AvatarConfig.fromJson(profile.avatar),
                            reward: ref.watch(myAvatarRewardProvider),
                            size: 108,
                            semanticLabel: tr('Avatarın'),
                          )
                        : CircleAvatar(
                            radius: 38,
                            backgroundColor: context.brand.primary,
                            child: Text(
                              _initials(d.fullName),
                              style: text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: context.brand.ink,
                              ),
                            ),
                          ),
                  ),
                  if (profile.role == UserRole.student)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => context.push('/student/avatar'),
                        icon: const Icon(Icons.brush_rounded, size: 18),
                        label: Text(tr('Avatarını düzenle')),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    d.fullName,
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    profile.role.label,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  _DetailsCard(details: d, role: profile.role),
                  if (profile.role == UserRole.student) ...[
                    const SizedBox(height: 12),
                    GoalsCard(studentId: profile.id, canEdit: true),
                    const SizedBox(height: 12),
                    const _ParentInviteCard(),
                  ],
                  const _PlatformCard(),
                  const SizedBox(height: 12),
                  FaqCard(role: profile.role),
                  const SizedBox(height: 12),
                  const AppearanceCard(),
                  const SizedBox(height: 12),
                  const _SecurityCard(),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        title: tr('Çıkış yapılsın mı?'),
                        message: tr(
                          'Tekrar girmek için e-posta ve şifren gerekecek.',
                        ),
                        action: tr('Çıkış yap'),
                      );
                      if (ok) await ref.read(authRepositoryProvider).signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(tr('Çıkış yap')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  static String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((p) => p.isEmpty ? '' : p[0])
      .join()
      .toUpperCase();
}

class _DetailsCard extends ConsumerStatefulWidget {
  const _DetailsCard({required this.details, required this.role});

  final ProfileDetails details;
  final UserRole role;

  @override
  ConsumerState<_DetailsCard> createState() => _DetailsCardState();
}

class _DetailsCardState extends ConsumerState<_DetailsCard> {
  late final _name = TextEditingController(text: widget.details.fullName);
  late int? _year = widget.details.examYear;
  late FieldType? _field = widget.details.field;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 3) {
      showMessage(context, tr('Adını ve soyadını gir.'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateDetails(
            ProfileDetails(fullName: name, examYear: _year, field: _field),
          );
      ref.invalidate(profileDetailsProvider);
      ref.invalidate(currentProfileProvider);
      if (mounted) showMessage(context, tr('Bilgilerin kaydedildi.'));
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.role == UserRole.student;
    final thisYear = DateTime.now().year;
    return SectionCard(
      title: tr('Bilgilerim'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: tr('Ad Soyad')),
          ),
          if (isStudent) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _year,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tr('Sınav yılı')),
                    items: [
                      for (var y = thisYear; y <= thisYear + 3; y++)
                        DropdownMenuItem(value: y, child: Text('$y YKS')),
                    ],
                    onChanged: (v) => setState(() => _year = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<FieldType?>(
                    initialValue: _field,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tr('Alan')),
                    items: [
                      for (final f in FieldType.values)
                        DropdownMenuItem(value: f, child: Text(f.label)),
                    ],
                    onChanged: (v) => setState(() => _field = v),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(tr('Kaydet')),
          ),
        ],
      ),
    );
  }
}

class _ParentInviteCard extends ConsumerStatefulWidget {
  const _ParentInviteCard();

  @override
  ConsumerState<_ParentInviteCard> createState() => _ParentInviteCardState();
}

class _ParentInviteCardState extends ConsumerState<_ParentInviteCard> {
  String? _code;
  bool _loading = false;

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final code = await ref
          .read(accountRepositoryProvider)
          .createParentInvite();
      setState(() => _code = code);
    } catch (_) {
      if (mounted) showMessage(context, tr('Kod oluşturulamadı.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(parentCountProvider).value ?? 0;
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: tr('Veli bağlantısı'),
      subtitle: count == 0
          ? tr('Henüz bağlı velin yok')
          : tr('{count} veli bağlı · istatistiklerini görebiliyor', {
              'count': count,
            }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              'Velin, bu kodla uygulamaya kayıt olduğunda denemelerini, soru ve çalışma istatistiklerini görebilir; hiçbir şeyi değiştiremez. Kod 30 gün geçerli ve tek kullanımlık.',
            ),
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_code == null)
            OutlinedButton.icon(
              onPressed: _loading ? null : _create,
              icon: const Icon(Icons.family_restroom),
              label: Text(tr('Veli davet kodu oluştur')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.brand.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _code!,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Kopyala'),
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _code!));
                      if (context.mounted) {
                        showMessage(context, tr('Kod kopyalandı'));
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SecurityCard extends ConsumerWidget {
  const _SecurityCard();

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (value == null || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).updatePassword(value);
      if (context.mounted) showMessage(context, tr('Şifren değiştirildi.'));
    } catch (e) {
      if (context.mounted) showMessage(context, authErrorMessage(e));
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).deleteMyAccount();
    } catch (e) {
      final msg = e.toString();
      if (!context.mounted) return;
      showMessage(
        context,
        msg.contains('LAST_ADMIN')
            ? tr('Kurumun tek müdürüsün. Önce başka bir müdür eklenmeli.')
            : msg.contains('STUDENT_DELETE_BY_COACH')
            ? tr('Öğrenci hesabını yalnızca koçun silebilir.')
            : msg.contains('COACH_HAS_STUDENTS')
            ? tr(
                'Bağlı öğrencilerin var. Önce kurum müdürünün öğrencilerini başka bir koça devretmesi gerekiyor.',
              )
            : tr('Hesap silinemedi. Tekrar dene.'),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStudent =
        ref.watch(currentProfileProvider).value?.role == UserRole.student;
    return SectionCard(
      title: tr('Güvenlik'),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.password),
            title: Text(tr('Şifre değiştir')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changePassword(context, ref),
          ),
          // Öğrenci hesabını koçu siler; öğrenci silmeyi talep eder.
          if (isStudent)
            const _DeletionRequestTile()
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                tr('Hesabımı sil'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _deleteAccount(context, ref),
            ),
        ],
      ),
    );
  }
}

/// Öğrencinin hesap silme talebi: talep koçuna iletilir, hesabı koçu siler.
/// Bekleyen talep varsa tarihi ve "Geri al" görünür.
class _DeletionRequestTile extends ConsumerStatefulWidget {
  const _DeletionRequestTile();

  @override
  ConsumerState<_DeletionRequestTile> createState() =>
      _DeletionRequestTileState();
}

class _DeletionRequestTileState extends ConsumerState<_DeletionRequestTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(deletionRequestProvider);
      if (mounted) showMessage(context, done);
    } catch (_) {
      if (mounted) showMessage(context, tr('İşlem yapılamadı. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    final ok = await confirm(
      context,
      title: tr('Hesabının silinmesini istiyor musun?'),
      message: tr(
        'Talebin koçuna iletilir. Koçun hesabını sildiğinde tüm verilerin (denemeler, soru kayıtları, çalışma süreleri, görevler, notlar) kalıcı olarak silinir. Fikrini değiştirirsen talebi geri alabilirsin.',
      ),
      action: tr('Talep gönder'),
    );
    if (!ok || !mounted) return;
    final repo = ref.read(accountRepositoryProvider);
    await _run(repo.requestAccountDeletion, tr('Talebin koçuna iletildi.'));
  }

  Future<void> _cancel() {
    final repo = ref.read(accountRepositoryProvider);
    return _run(
      repo.cancelAccountDeletion,
      tr('Hesap silme talebin geri alındı.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(deletionRequestProvider);
    final requestedAt = request.value;
    final error = Theme.of(context).colorScheme.error;

    if (requestedAt != null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.hourglass_top_rounded, color: error),
        title: Text(tr('Hesap silme talebin iletildi')),
        subtitle: Text(
          tr('{date} tarihinde istedin. Hesabını koçun silecek.', {
            'date': formatLongDate(requestedAt),
          }),
        ),
        trailing: TextButton(
          onPressed: _busy ? null : _cancel,
          child: Text(tr('Geri al')),
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !_busy && !request.isLoading,
      leading: Icon(Icons.delete_forever_outlined, color: error),
      title: Text(
        tr('Hesabımın silinmesini iste'),
        style: TextStyle(color: error),
      ),
      subtitle: Text(
        tr('Talebin koçuna iletilir; hesabını ve tüm verilerini koçun siler.'),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _request,
    );
  }
}

/// Şifre değiştirme diyaloğu. Denetleyiciler diyaloğun kendisinde: kapanış
/// animasyonu bitince serbest bırakılır. Onaylanırsa yeni şifreyi döndürür.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _again = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Şifre değiştir')),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 360,
        child: PasswordFields(password: _password, again: _again),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Vazgeç')),
      ),
      TextButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _password.text);
          }
        },
        child: Text(tr('Kaydet')),
      ),
    ],
  );
}

/// Kendi hesabını silme onayı ("SİL" yazılmadan onaylanamaz). Metin
/// denetleyicisi diyaloğun kendisinde: kapanış animasyonu bitince serbest
/// bırakılır.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmed =>
      const {'SİL', 'SIL'}.contains(_controller.text.trim().toUpperCase());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Hesabın silinsin mi?')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(
            'Hesabın ve tüm verilerin (denemeler, soru kayıtları, çalışma süreleri, görevler, notlar) kalıcı olarak silinir. Bu işlem geri alınamaz.',
          ),
        ),
        const SizedBox(height: 12),
        Text(tr('Onaylamak için SİL yaz:')),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(tr('Vazgeç')),
      ),
      TextButton(
        onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        child: Text(tr('Hesabımı sil')),
      ),
    ],
  );
}

/// Süper admin için dershane (white label) yönetimine giriş.
class _PlatformCard extends ConsumerWidget {
  const _PlatformCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isSuperAdminProvider).value != true) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(Icons.apartment_rounded),
          title: Text(tr('Dershane yönetimi')),
          subtitle: Text(tr('Dershane ekle, logo ve renkleri düzenle')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/platform'),
        ),
      ),
    );
  }
}
