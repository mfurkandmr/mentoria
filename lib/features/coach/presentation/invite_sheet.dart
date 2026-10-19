import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../privacy/presentation/guardian_statement_tile.dart';
import '../../../shared/widgets/common.dart';
import '../../../core/branding/app_links.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/format.dart';
import '../data/coach_repository.dart';
import '../../../core/i18n/i18n.dart';

/// Öğrenci davet kodu oluşturma ve aktif kodlar.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key});

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  int _maxUses = 1;
  bool _guardianStatement = false;
  String? _newCode;
  bool _loading = false;

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final code = await ref
          .read(coachRepositoryProvider)
          .createStudentInvite(
            maxUses: _maxUses,
            guardianStatement: _guardianStatement,
          );
      ref.invalidate(studentInvitesProvider);
      if (mounted) setState(() => _newCode = code);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Kod oluşturulamadı. Tekrar dene.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('{code} kopyalandı', {'code': code}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final invites = ref.watch(studentInvitesProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Öğrenci davet et'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Kodu öğrencine gönder. Uygulamada "Davet kodum var" diyerek kayıt olduğunda sana bağlanır. Kodlar 14 gün geçerli.',
              ),
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_newCode == null) ...[
              Text(tr('Kaç öğrenci kullanabilsin?'), style: text.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 1, label: Text(tr('1 kişi'))),
                  ButtonSegment(value: 5, label: Text(tr('5 kişi'))),
                  ButtonSegment(value: 30, label: Text(tr('Sınıf (30)'))),
                ],
                selected: {_maxUses},
                onSelectionChanged: (s) => setState(() => _maxUses = s.first),
              ),
              const SizedBox(height: 8),
              GuardianStatementTile(
                value: _guardianStatement,
                onChanged: (v) => setState(() => _guardianStatement = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _loading ? null : _create,
                child: _loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Text(tr('Kod oluştur')),
              ),
            ] else
              _NewCodeCard(
                code: _newCode!,
                maxUses: _maxUses,
                onCopy: () => _copy(_newCode!),
                onAnother: () => setState(() => _newCode = null),
              ),
            const SizedBox(height: 24),
            Text(
              tr('Aktif kodların'),
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            invites.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(tr('Kodlar yüklenemedi.')),
              data: (list) => list.isEmpty
                  ? Text(tr('Aktif davet kodun yok.'), style: text.bodySmall)
                  : Column(
                      children: [
                        for (final i in list)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              i.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                            subtitle: Text(
                              tr(
                                '{p0} kişilik hak kaldı · {p1} tarihine kadar',
                                {
                                  'p0': i.remaining,
                                  'p1': formatShortDate(i.expiresAt.toLocal()),
                                },
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: tr('Kopyala'),
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copy(i.code),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCodeCard extends StatelessWidget {
  const _NewCodeCard({
    required this.code,
    required this.maxUses,
    required this.onCopy,
    required this.onAnother,
  });

  final String code;
  final int maxUses;
  final VoidCallback onCopy;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.brand.primary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(tr('Davet kodun'), style: text.labelLarge),
          const SizedBox(height: 6),
          SelectableText(
            code,
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          Text(
            maxUses == 1
                ? tr('Tek öğrenci kullanabilir')
                : tr('{maxUses} öğrenci kullanabilir', {'maxUses': maxUses}),
            style: text.bodySmall,
          ),
          const SizedBox(height: 8),
          // Davet linki: açan kişi kayıt ekranına kod dolu ve dershanenin
          // markasıyla gelir.
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: AppLinks.invite(code)),
              );
              if (context.mounted) {
                showMessage(context, tr('Davet linki kopyalandı'));
              }
            },
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text(tr('Davet linkini kopyala')),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onAnother,
                  child: Text(tr('Yeni kod')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(tr('Kopyala')),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
