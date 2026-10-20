import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_version.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/effects.dart';
import '../../account/data/account_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/profile.dart';
import '../data/consent_repository.dart';
import 'legal_text_screen.dart';

/// KVKK başvuruları için adres. Veri sorumlusu bilgileri gelince doldurulacak
/// (bkz. docs/kvkk/00_README.md); boşken ekranda gösterilmez.
const kvkkContactEmail = '';

/// "Gizlilik ve izinler" ekranını açar.
Future<void> openPrivacy(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()));

/// KVKK: metinler, rızalar (aç/kapat), veli onayı, verilerimi indir.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Gizlilik ve izinler'))),
      body: profile == null
          ? const Center(child: BizzLoader())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                if (profile.role == UserRole.student) ...[
                  const _StudentConsents(),
                  const SizedBox(height: 12),
                ],
                if (profile.role == UserRole.parent) ...[
                  const _ParentConsents(),
                  const SizedBox(height: 12),
                ],
                const _DocsCard(),
                const SizedBox(height: 12),
                const _ExportCard(),
                const SizedBox(height: 20),
                const CopyrightNote(),
              ],
            ),
    );
  }
}

class _DocsCard extends StatelessWidget {
  const _DocsCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: tr('Metinler'),
      subtitle: tr('Verilerinin nasıl işlendiğini buradan okuyabilirsin.'),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final d in LegalDoc.values)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(d.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openLegal(context, d),
            ),
          if (kvkkContactEmail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                tr(
                  'Haklarınla ilgili başvurular için: {email}. En geç 30 gün içinde ücretsiz cevap verilir.',
                  {'email': kvkkContactEmail},
                ),
                style: text.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Telif notu ve sürüm: "© 2026 Mentoria. Tüm hakları saklıdır."
/// Kurum kendi markasıyla kullansa da yazılımın sahibi Mentoria'dır.
class CopyrightNote extends StatelessWidget {
  const CopyrightNote({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      children: [
        Text(
          '© 2026 Mentoria. ${tr('Tüm hakları saklıdır.')}',
          style: style,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          tr('Sürüm {v}', {'v': '$appVersion ($appBuild)'}),
          style: style,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Öğrenci: doğum yılı, veli onayı durumu, sıralama ve veli izni.
class _StudentConsents extends ConsumerWidget {
  const _StudentConsents();

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    ConsentKind kind,
    bool granted,
  ) async {
    try {
      await ref
          .read(consentRepositoryProvider)
          .setConsent(kind, granted: granted);
      ref.invalidate(myConsentStatusProvider);
      if (kind == ConsentKind.parentView) ref.invalidate(parentCountProvider);
    } catch (_) {
      if (context.mounted) showMessage(context, tr('Kaydedilemedi.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return AsyncView(
      value: ref.watch(myConsentStatusProvider),
      onRetry: () => ref.invalidate(myConsentStatusProvider),
      builder: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: tr('Yaş ve veli onayı'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.birthYear == null) ...[
                  Text(
                    tr(
                      '18 yaşından küçük olup olmadığını bilmemiz gerekiyor. Doğum yılını bir kez girmen yeterli.',
                    ),
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => showBirthYearDialog(context, ref),
                    icon: const Icon(Icons.cake_outlined),
                    label: Text(tr('Doğum yılını gir')),
                  ),
                ] else
                  Text(
                    tr('Doğum yılı: {year}', {'year': s.birthYear}),
                    style: text.bodyMedium,
                  ),
                if (s.minor) ...[
                  const SizedBox(height: 12),
                  _GuardianLine(status: s),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: tr('İzinlerin'),
            subtitle: tr(
              'Hepsi isteğe bağlı. Kapatsan da Mentoria\'yı kullanmaya devam edersin.',
            ),
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Column(
              children: [
                SwitchListTile(
                  value: s.ranking,
                  onChanged: (v) => _set(context, ref, ConsentKind.ranking, v),
                  title: Text(tr('Başarı sıralamasında görün')),
                  subtitle: Text(
                    s.ranking && !s.rankingVisible
                        ? tr(
                            'Veli onayı gelince sıralamada görünürsün (adının kısaltması, avatarın ve netin).',
                          )
                        : tr(
                            'Kurumundaki diğer öğrenciler adının kısaltmasını (ör. "El***"), avatarını ve netini görür.',
                          ),
                  ),
                ),
                if (!s.minor)
                  SwitchListTile(
                    value: s.parentView,
                    onChanged: (v) async {
                      if (!v && s.hasParent) {
                        final ok = await confirm(
                          context,
                          title: tr('Velinin erişimi kaldırılsın mı?'),
                          message: tr(
                            'Velin artık çalışmalarını ve denemelerini göremez. İstersen sonra yeniden davet edebilirsin.',
                          ),
                          action: tr('Kaldır'),
                        );
                        if (!ok) return;
                      }
                      if (context.mounted) {
                        await _set(context, ref, ConsentKind.parentView, v);
                      }
                    },
                    title: Text(tr('Velim çalışmalarımı görebilsin')),
                    subtitle: Text(
                      tr(
                        'Davet ettiğin velin çalışma sürelerini, soru sayılarını ve deneme sonuçlarını görür.',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianLine extends StatelessWidget {
  const _GuardianLine({required this.status});

  final ConsentStatus status;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ok = status.guardianApproval;
    final color = ok ? context.brand.success : context.brand.danger;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.verified_user_rounded : Icons.hourglass_top_rounded,
          color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ok
                ? (status.guardianSource == 'institution'
                      ? tr('Veli onayın kurumun tarafından alındı.')
                      : tr('Velin onay verdi.'))
                : tr(
                    'Veli onayı bekleniyor. 18 yaşından küçük olduğun için velinin onayı gerekiyor. Profil sayfasındaki "Veli bağlantısı"ndan velini davet et; velin kayıt olurken onay verir.',
                  ),
            style: text.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Veli: her çocuk için kullanım onayı ve sıralama izni.
class _ParentConsents extends ConsumerWidget {
  const _ParentConsents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(childrenProvider),
      onRetry: () => ref.invalidate(childrenProvider),
      builder: (children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in children) ...[
            _ChildConsentCard(child: c),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ChildConsentCard extends ConsumerWidget {
  const _ChildConsentCard({required this.child});

  final ChildRef child;

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    ConsentKind kind,
    bool granted,
  ) async {
    try {
      await ref
          .read(consentRepositoryProvider)
          .setConsent(kind, granted: granted, studentId: child.id);
      ref.invalidate(studentConsentStatusProvider(child.id));
    } catch (_) {
      if (context.mounted) showMessage(context, tr('Kaydedilemedi.'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: child.fullName,
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: AsyncView(
        value: ref.watch(studentConsentStatusProvider(child.id)),
        onRetry: () => ref.invalidate(studentConsentStatusProvider(child.id)),
        builder: (s) => Column(
          children: [
            if (s.minor)
              SwitchListTile(
                value: s.guardianApproval,
                onChanged: (v) async {
                  if (!v) {
                    final ok = await confirm(
                      context,
                      title: tr('Onayını geri çekmek istiyor musun?'),
                      message: tr(
                        'Çocuğunun hesabı için silme talebi açılır; koçu ya da kurumu hesabı kapatır. Bu işlem geri alınamaz.',
                      ),
                      action: tr('Onayı geri çek'),
                    );
                    if (!ok) return;
                  }
                  if (context.mounted) {
                    await _set(context, ref, ConsentKind.guardianApproval, v);
                  }
                },
                title: Text(tr('Mentoria\'yı kullanmasına onay veriyorum')),
                subtitle: Text(
                  s.guardianSource == 'institution' && s.guardianApproval
                      ? tr('Onay kurum kaydında alındı.')
                      : tr('18 yaşından küçük öğrenciler için gerekli.'),
                ),
              ),
            SwitchListTile(
              value: s.ranking,
              onChanged: (v) => _set(context, ref, ConsentKind.ranking, v),
              title: Text(tr('Başarı sıralamasında görünsün')),
              subtitle: Text(
                tr(
                  'Kurumundaki diğer öğrenciler adının kısaltmasını, avatarını ve netini görür.',
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(LegalDoc.guardianConsent.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openLegal(context, LegalDoc.guardianConsent),
            ),
          ],
        ),
      ),
    );
  }
}

/// KVKK md. 11: verilerin tamamı tek dosyada.
class _ExportCard extends ConsumerStatefulWidget {
  const _ExportCard();

  @override
  ConsumerState<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends ConsumerState<_ExportCard> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await ref.read(consentRepositoryProvider).exportMyData();
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/json',
              name: 'mentoria-verilerim.json',
            ),
          ],
          text: tr('Mentoria verilerim'),
        ),
      );
    } catch (e) {
      debugPrint('Veriler dışa aktarılamadı: $e');
      if (mounted) showMessage(context, tr('Veriler hazırlanamadı.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: tr('Verilerimi indir'),
      subtitle: tr(
        'Mentoria\'daki bütün kayıtların tek bir dosyada (JSON). Kaydedebilir ya da paylaşabilirsin.',
      ),
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _export,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
        label: Text(tr('Verilerimi indir')),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    );
  }
}

/// Doğum yılı penceresi. [userId] verilirse koç/müdür olarak öğrencisi için.
/// Kaydedildiyse true.
Future<bool> showBirthYearDialog(
  BuildContext context,
  WidgetRef ref, {
  String? userId,
}) async {
  final now = DateTime.now().year;
  final years = [for (var y = now - 12; y >= now - 70; y--) y];
  int? picked = now - 17;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(tr('Doğum yılın')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              userId == null
                  ? tr(
                      'Bir kez girilir; sonra yalnızca koçun ya da kurumun değiştirebilir.',
                    )
                  : tr('Öğrencinin doğum yılı.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: picked,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Doğum yılı')),
              items: [
                for (final y in years)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (v) => setState(() => picked = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Vazgeç')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Kaydet')),
          ),
        ],
      ),
    ),
  );
  if (ok != true || picked == null) return false;
  try {
    await ref
        .read(consentRepositoryProvider)
        .setBirthYear(picked!, userId: userId);
    ref.invalidate(myConsentStatusProvider);
    if (userId != null) ref.invalidate(studentConsentStatusProvider(userId));
    return true;
  } catch (_) {
    if (context.mounted) showMessage(context, tr('Kaydedilemedi.'));
    return false;
  }
}

/// Öğrenci ana sayfasında: doğum yılı yoksa ya da veli onayı bekleniyorsa
/// kısa bir uyarı kartı (yoksa görünmez).
class KvkkHomeCard extends ConsumerWidget {
  const KvkkHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(myConsentStatusProvider).value;
    if (s == null || (s.birthYear != null && !s.awaitingGuardian)) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final needYear = s.birthYear == null;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: Icon(
          needYear ? Icons.cake_outlined : Icons.family_restroom,
          color: context.brand.primaryDeep,
        ),
        title: Text(
          needYear ? tr('Doğum yılını gir') : tr('Veli onayı bekleniyor'),
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          needYear
              ? tr('18 yaşından küçükler için veli onayı gerekiyor.')
              : tr('Velini davet et; kayıt olurken onay verir.'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            needYear ? showBirthYearDialog(context, ref) : openPrivacy(context),
      ),
    );
  }
}
