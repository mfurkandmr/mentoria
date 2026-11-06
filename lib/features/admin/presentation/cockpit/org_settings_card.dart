import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/branding/branding_providers.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/widgets/common.dart';
import '../../../auth/data/profile.dart';
import '../../../credits/data/org_credits_repository.dart';
import '../../data/admin_repository.dart';
import 'cockpit_theme.dart';
import 'section_states.dart';
import 'success_ranking_tile.dart';

/// Lisans bitişine bu kadar gün kala uyarı bandı çıkar.
const licenseWarnDays = 14;

/// Kredi, kayıtlı öğrencinin bu oranının altına inince uyarı bandı çıkar.
const creditWarnRatio = 0.10;

/// Kurum ayarları: kredi, lisans, kurum kodu, ad, başarı sıralaması, görünüm. Bilgi tonunda;
/// uyarılar yalnızca eşik aşılınca [OrgAlertBanner]'da.
class OrgSettingsCard extends ConsumerWidget {
  const OrgSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider);
    return CockpitSection(
      key: const ValueKey('section-settings'),
      title: tr('Kurum ayarları'),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: CockpitAsync(
        value: org,
        onRetry: () => ref.invalidate(orgProvider),
        loading: const Padding(
          padding: EdgeInsets.all(16),
          child: SectionSkeleton(rows: 4, rowHeight: 32),
        ),
        builder: (o) => _Rows(org: o),
      ),
    );
  }
}

class _Rows extends ConsumerStatefulWidget {
  const _Rows({required this.org});

  final OrgInfo org;

  @override
  ConsumerState<_Rows> createState() => _RowsState();
}

class _RowsState extends ConsumerState<_Rows> {
  bool _busy = false;

  Future<void> _rename() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => ControllerScope(
        initial: widget.org.name,
        builder: (context, controller) => AlertDialog(
          title: Text(tr('Kurum adı')),
          content: TextField(
            key: const ValueKey('org-name-field'),
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Vazgeç')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(tr('Kaydet')),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.length < 2 || name == widget.org.name) return;
    try {
      await ref.read(adminRepositoryProvider).renameOrg(name);
      ref.invalidate(orgProvider);
      // Kurum adı markaya da yansır (koç ve öğrenciler de yeni adı görür).
      ref.invalidate(tenantBrandingProvider);
    } catch (_) {
      if (mounted) showMessage(context, tr('Kaydedilemedi. Tekrar dene.'));
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) showMessage(context, tr('{code} kopyalandı', {'code': code}));
  }

  Future<void> _regenerate() async {
    final ok = await confirm(
      context,
      title: tr('Kurum kodu yenilensin mi?'),
      message: tr(
        'Eski kod hemen geçersiz olur. Kodu paylaştığın öğrencilere yenisini göndermen gerekir.',
      ),
      action: tr('Yenile'),
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(orgCreditsRepositoryProvider).regenerateOrgCode();
      ref.invalidate(orgCodeProvider);
    } catch (_) {
      if (mounted) showMessage(context, tr('Kod yenilenemedi. Tekrar dene.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.org;
    final credits = ref.watch(orgCreditsProvider).value;
    final code = ref.watch(orgCodeProvider);
    final members = ref.watch(orgMembersProvider).value;
    final expiry = o.licenseExpiresAt == null
        ? tr('Süresiz')
        : tr('{date} tarihine kadar', {
            'date': DateFormat(
              'd MMMM yyyy',
              localeTag,
            ).format(o.licenseExpiresAt!),
          });

    int count(UserRole r) => members?.where((m) => m.role == r).length ?? 0;

    return Column(
      children: [
        _row(
          key: const ValueKey('settings-name'),
          icon: Icons.apartment_outlined,
          label: tr('Kurum adı'),
          value: o.name,
          action: IconButton(
            tooltip: tr('Kurum adını değiştir'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: _rename,
          ),
        ),
        _row(
          key: const ValueKey('settings-credits'),
          icon: Icons.confirmation_number_outlined,
          label: tr('Öğrenci kredisi'),
          value: credits == null
              ? '–'
              : tr('{n} kaldı', {'n': credits.balance}),
          note: tr('Her yeni öğrenci 1 kredi kullanır.'),
        ),
        _row(
          key: const ValueKey('settings-license'),
          icon: Icons.event_available_outlined,
          label: tr('Lisans'),
          value: expiry,
        ),
        _row(
          key: const ValueKey('settings-code'),
          icon: Icons.vpn_key_outlined,
          label: tr('Kurum kodu'),
          value: code.value ?? (code.hasError ? tr('Yüklenemedi') : '…'),
          note: tr('Öğrenciler kayıt olurken bu kodu yazar.'),
          action: code.value == null
              ? (code.hasError
                    ? IconButton(
                        tooltip: tr('Tekrar dene'),
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => ref.invalidate(orgCodeProvider),
                      )
                    : null)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: tr('Kopyala'),
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copy(code.value!),
                    ),
                    IconButton(
                      tooltip: tr('Kodu yenile'),
                      icon: const Icon(Icons.autorenew_rounded),
                      onPressed: _busy ? null : _regenerate,
                    ),
                  ],
                ),
        ),
        if (members != null)
          _row(
            key: const ValueKey('settings-members'),
            icon: Icons.people_outline,
            label: tr('Kurumdaki hesaplar'),
            value: tr('{s} öğrenci · {c} koç · {p} veli', {
              's': count(UserRole.student),
              'c': count(UserRole.coach),
              'p': count(UserRole.parent),
            }),
          ),
        const SuccessRankingRow(),
        _row(
          key: const ValueKey('settings-branding'),
          icon: Icons.palette_outlined,
          label: tr('Görünüm'),
          value: tr('Logo, renk ve yazı tipi'),
          onTap: () => context.push('/admin/branding'),
          action: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.chevron_right, color: context.cockpit.muted),
          ),
        ),
      ],
    );
  }

  Widget _row({
    required Key key,
    required IconData icon,
    required String label,
    required String value,
    String? note,
    Widget? action,
    VoidCallback? onTap,
  }) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
        child: Row(
          children: [
            Icon(icon, color: context.cockpit.muted, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: cockpitLabel(context)),
                  Text(
                    value,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (note != null)
                    Text(
                      note,
                      style: text.bodySmall?.copyWith(
                        color: context.cockpit.muted,
                      ),
                    ),
                ],
              ),
            ),
            ?action,
            if (action == null) const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// Bant metni: (anlam, başlık, açıklama).
typedef OrgAlert = ({Tone tone, String title, String message});

/// Yalnızca gerçek eşik aşıldığında uyarılar: kurum kapalı, lisans bitti /
/// [licenseWarnDays] gün kaldı, kredi bitti / kayıtlı öğrencinin
/// %[creditWarnRatio]'unun altında. Müdüre "yöneticinizle" denmez.
List<OrgAlert> orgAlerts({
  required OrgInfo? org,
  required OrgCredits? credits,
  required int students,
  DateTime? now,
}) {
  now ??= DateTime.now();
  final out = <OrgAlert>[];
  if (credits != null && !credits.isActive) {
    out.add((
      tone: Tone.risk,
      title: tr('Kurum hesabı kapalı'),
      message: tr('Hesabı yeniden açmak için destek ekibiyle görüşün.'),
    ));
  }
  final exp = org?.licenseExpiresAt;
  if (exp != null) {
    final date = DateFormat('d MMMM yyyy', localeTag).format(exp);
    final days = DateTime(
      exp.year,
      exp.month,
      exp.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (exp.isBefore(now)) {
      out.add((
        tone: Tone.risk,
        title: tr('Lisans süresi doldu ({date})', {'date': date}),
        message: tr(
          'Öğrenci, koç ve veliler giriş yapamıyor. Lisansı uzatmak için destek ekibiyle görüşün.',
        ),
      ));
    } else if (days <= licenseWarnDays) {
      out.add((
        tone: Tone.warn,
        title: days == 0
            ? tr('Lisans bugün bitiyor')
            : tr('Lisans {n} gün sonra bitiyor', {'n': days}),
        message: tr(
          '{date} tarihinden sonra öğrenci, koç ve veliler giriş yapamaz. Lisansı uzatmak için destek ekibiyle görüşün.',
          {'date': date},
        ),
      ));
    }
  }
  if (credits != null && credits.isActive) {
    if (credits.balance <= 0) {
      out.add((
        tone: Tone.risk,
        title: tr('Öğrenci krediniz bitti'),
        message:
            '${tr('Yeni öğrenci eklenemez.')} ${tr('Kredi yüklemek için destek ekibiyle görüşün.')}',
      ));
    } else if (students > 0 && credits.balance < students * creditWarnRatio) {
      out.add((
        tone: Tone.warn,
        title: tr('Öğrenci krediniz azaldı: {n} kaldı', {'n': credits.balance}),
        message: tr('Kredi yüklemek için destek ekibiyle görüşün.'),
      ));
    }
  }
  return out;
}

/// Eşik bantları (ekranın en üstünde). Eşik aşılmadıysa hiç yer kaplamaz.
class OrgAlertBanner extends ConsumerWidget {
  const OrgAlertBanner({super.key, required this.students});

  final int students;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = orgAlerts(
      org: ref.watch(orgProvider).value,
      credits: ref.watch(orgCreditsProvider).value,
      students: students,
    );
    if (alerts.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final a in alerts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Container(
                key: ValueKey('org-alert-${a.tone.name}'),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: a.tone.tintOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: a.tone.of(context).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      a.tone == Tone.risk
                          ? Icons.error_outline
                          : Icons.warning_amber_rounded,
                      color: a.tone.of(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: a.tone.of(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(a.message, style: text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
