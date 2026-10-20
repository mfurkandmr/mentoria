import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/common.dart';
import '../data/org_credits_repository.dart';

/// Kredi azaldığında (50'nin altı) ya da kurum kapalıyken uyarı. Yalnızca
/// "yöneticinizle iletişime geçin" der: fiyat, satın alma ya da ödeme
/// bağlantısı yoktur (mağaza kuralları gereği de olmamalı).
class LowCreditBanner extends ConsumerWidget {
  const LowCreditBanner({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(orgCreditsProvider).value;
    if (c == null || (c.isActive && !c.low)) return const SizedBox.shrink();
    final empty = !c.canAddStudent;
    final color = empty ? context.brand.danger : const Color(0xFFE08A00);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                empty ? Icons.block_rounded : Icons.warning_amber_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !c.isActive
                          ? tr('Kurum hesabı kapalı')
                          : empty
                          ? tr('Öğrenci krediniz bitti')
                          : tr('Öğrenci krediniz azalıyor: {n} kaldı', {
                              'n': c.balance,
                            }),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      empty
                          ? tr(
                              'Yeni öğrenci eklenemez. Yöneticinizle iletişime geçin.',
                            )
                          : tr('Yöneticinizle iletişime geçin.'),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Müdür: kurum davet kodu. Öğrenciler bu kodla kayıt olur, en az öğrencisi
/// olan koça bağlanır; her kayıt 1 kredi harcar.
class OrgCodeCard extends ConsumerStatefulWidget {
  const OrgCodeCard({super.key});

  @override
  ConsumerState<OrgCodeCard> createState() => _OrgCodeCardState();
}

class _OrgCodeCardState extends ConsumerState<OrgCodeCard> {
  bool _busy = false;

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
    final code = ref.watch(orgCodeProvider);
    final credits = ref.watch(orgCreditsProvider).value;
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: tr('Kurum kodu'),
      subtitle: tr(
        'Öğrenciler kayıt olurken bu kodu yazar; en az öğrencisi olan koça bağlanır. Her yeni öğrenci 1 kredi kullanır.',
      ),
      child: AsyncView(
        value: code,
        onRetry: () => ref.invalidate(orgCodeProvider),
        builder: (c) => c == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          c,
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Kopyala'),
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copy(c),
                      ),
                      IconButton(
                        tooltip: tr('Kodu yenile'),
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _busy ? null : _regenerate,
                      ),
                    ],
                  ),
                  if (credits != null)
                    Text(
                      tr('Kalan öğrenci kredisi: {n}', {'n': credits.balance}),
                      style: text.bodySmall,
                    ),
                ],
              ),
      ),
    );
  }
}
