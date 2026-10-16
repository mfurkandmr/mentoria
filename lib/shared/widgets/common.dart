import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bizz.dart';
import 'effects.dart';
import '../../core/i18n/i18n.dart';

/// Küçük özet kutusu (değer + etiket, isteğe bağlı alt satır).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _AnimatedValue(
                value,
                text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                style: text.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// Eşit yükseklikte yan yana özet kutuları.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// Başlıklı kart.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: text.bodySmall),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Bızz'lı boş durum.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.bizzSize = 120,
  });

  final String title;
  final String message;
  final Widget? action;
  final double bizzSize;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Bizz(size: bizzSize),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: text.bodyMedium),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Yükleme / hata / veri durumları için ortak sarmalayıcı.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: true,
    loading: () => const BizzLoader(),
    error: (_, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Veriler yüklenemedi. İnternet bağlantını kontrol et.'),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: Text(tr('Tekrar dene'))),
            ],
          ],
        ),
      ),
    ),
    data: builder,
  );
}

/// Basit onay penceresi.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String? action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('Vazgeç')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action ?? tr('Sil')),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

/// "84,75", "%41", "305" gibi değerleri sayarak gösterir; başka rakam
/// içeren metinler ("6 sa 12 dk") olduğu gibi kalır.
class _AnimatedValue extends StatelessWidget {
  const _AnimatedValue(this.value, this.style);

  final String value;
  final TextStyle? style;

  static final _pattern = RegExp(r'^(\D*?)(\d+)(?:([.,])(\d+))?(\D*)$');

  @override
  Widget build(BuildContext context) {
    final m = _pattern.firstMatch(value);
    if (m == null) return Text(value, style: style);
    final prefix = m.group(1)!, suffix = m.group(5)!;
    final sep = m.group(3);
    final decimals = m.group(4)?.length ?? 0;
    final target = double.parse('${m.group(2)}.${m.group(4) ?? '0'}');
    return CountUp(
      value: target,
      style: style,
      format: (v) {
        final fixed = v.toStringAsFixed(decimals);
        return '$prefix${sep == null ? fixed : fixed.replaceAll('.', sep)}$suffix';
      },
    );
  }
}
