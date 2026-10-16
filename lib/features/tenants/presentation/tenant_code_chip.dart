import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/branding.dart';
import '../../../core/branding/branding_providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../data/tenant_repository.dart';

/// Giriş ekranında dershane seçimi: kod (slug) girilince ekran o dershanenin
/// renkleri, logosu ve adıyla yeniden çizilir.
class TenantCodeChip extends ConsumerWidget {
  const TenantCodeChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slug = ref.watch(savedTenantSlugProvider);
    final branding = ref.watch(tenantBrandingProvider);
    final text = Theme.of(context).textTheme;

    if (slug == null) {
      return TextButton.icon(
        onPressed: () => showTenantCodeDialog(context, ref),
        icon: const Icon(Icons.school_outlined, size: 18),
        label: Text(tr('Dershane kodun var mı?')),
      );
    }

    final name = branding.value?.name;
    return Semantics(
      button: true,
      label: tr('Dershane: {name}. Değiştir', {'name': name ?? slug}),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => showTenantCodeDialog(context, ref, current: slug),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: context.brand.primary.withValues(alpha: 0.14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              branding.isLoading
                  ? const SizedBox.square(
                      dimension: 24,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : BrandInitial(size: 24, name: name ?? slug),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name ?? slug,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              Text(tr('Değiştir'), style: text.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dershane kodu sor, doğrula, kaydet. Kaldırılırsa Mentoria'ya dönülür.
Future<void> showTenantCodeDialog(
  BuildContext context,
  WidgetRef ref, {
  String? current,
}) async {
  final repo = ref.read(tenantRepositoryProvider);
  final saved = ref.read(savedTenantSlugProvider.notifier);
  await showDialog<void>(
    context: context,
    builder: (context) => _TenantCodeDialog(
      initial: current,
      lookup: repo.fetchBySlug,
      onSave: saved.set,
    ),
  );
}

class _TenantCodeDialog extends StatefulWidget {
  const _TenantCodeDialog({
    required this.initial,
    required this.lookup,
    required this.onSave,
  });

  final String? initial;
  final Future<Branding?> Function(String slug) lookup;
  final void Function(String? slug) onSave;

  @override
  State<_TenantCodeDialog> createState() => _TenantCodeDialogState();
}

class _TenantCodeDialogState extends State<_TenantCodeDialog> {
  late final _code = TextEditingController(text: widget.initial);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final slug = _code.text.trim().toLowerCase();
    if (!Branding.slugPattern.hasMatch(slug)) {
      setState(
        () => _error = tr('Dershane kodu küçük harf, rakam ve tire içerir.'),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await widget.lookup(slug);
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _busy = false;
          _error = tr('Bu kodla aktif bir dershane bulunamadı.');
        });
        return;
      }
      widget.onSave(slug);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = tr(
            'Dershane bilgisi alınamadı. İnternet bağlantını kontrol et.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Dershane kodu')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Dershanenin sana verdiği kodu gir (örn. bal-akademi).')),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: tr('Dershane kodu'),
              errorText: _error,
              prefixIcon: const Icon(Icons.school_outlined),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    widget.onSave(null);
                    Navigator.pop(context);
                  },
            child: Text(tr('Kodu kaldır')),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(tr('Vazgeç')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr('Kaydet')),
        ),
      ],
    );
  }
}
