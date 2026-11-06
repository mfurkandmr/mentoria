import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/i18n.dart';
import 'cockpit_theme.dart';

/// Kokpitin bir bölümü: başlık, isteğe bağlı açıklama ve sağda eylem.
class CockpitSection extends StatelessWidget {
  const CockpitSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 16),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              16,
              14,
              trailing == null ? 16 : 4,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: cockpitLabel(context)),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Yükleniyor: içeriğin yerini tutan gri kutular (hareketsiz; azaltılmış
/// hareket tercihine de uygun).
class SectionSkeleton extends StatelessWidget {
  const SectionSkeleton({super.key, this.rows = 3, this.rowHeight = 44});

  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr('Yükleniyor'),
    child: ExcludeSemantics(
      child: Column(
        children: [
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                _box(context, rowHeight, rowHeight, circle: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: i.isEven ? 0.6 : 0.45,
                        child: _box(context, 12, double.infinity),
                      ),
                      const SizedBox(height: 8),
                      FractionallySizedBox(
                        widthFactor: i.isEven ? 0.35 : 0.5,
                        child: _box(context, 10, double.infinity),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _box(BuildContext context, double h, double w, {bool circle = false}) =>
    Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: context.cockpit.faint,
        borderRadius: BorderRadius.circular(circle ? h : 6),
      ),
    );

/// Özet kartı biçiminde yükleniyor kutusu.
class MetricSkeleton extends StatelessWidget {
  const MetricSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FractionallySizedBox(
              widthFactor: 0.6,
              child: _box(context, 10, double.infinity),
            ),
            const SizedBox(height: 12),
            FractionallySizedBox(
              widthFactor: 0.4,
              child: _box(context, 22, double.infinity),
            ),
            const SizedBox(height: 10),
            FractionallySizedBox(
              widthFactor: 0.7,
              child: _box(context, 10, double.infinity),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Hata: kısa açıklama ve "Tekrar dene".
class SectionError extends StatelessWidget {
  const SectionError({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.cloud_off_outlined, color: context.cockpit.muted),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          message ?? tr('Bu bölüm yüklenemedi. Bağlantını kontrol et.'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.cockpit.muted),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton(onPressed: onRetry, child: Text(tr('Tekrar dene'))),
    ],
  );
}

/// Boş hal: sade bir satır ve mutlaka bir eylem.
class SectionEmpty extends StatelessWidget {
  const SectionEmpty({
    super.key,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: context.cockpit.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.cockpit.muted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: onAction,
        icon: Icon(actionIcon ?? Icons.arrow_forward, size: 18),
        label: Text(actionLabel),
      ),
    ],
  );
}

/// Bölüm verisi: yükleniyorsa [loading], hatada [SectionError], sonra
/// [builder]. Yenilemede eski veri ekranda kalır.
class CockpitAsync<T> extends StatelessWidget {
  const CockpitAsync({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.loading = const SectionSkeleton(),
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final Widget loading;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: true,
    skipLoadingOnReload: true,
    loading: () => loading,
    error: (_, _) => SectionError(onRetry: onRetry),
    data: builder,
  );
}

/// Diyalogdaki metin alanının denetleyicisini sahiplenir: diyalog kapanış
/// animasyonu bitip ağaçtan çıkınca siler (önce silinirse hata verir).
class ControllerScope extends StatefulWidget {
  const ControllerScope({super.key, required this.builder, this.initial = ''});

  final String initial;
  final Widget Function(BuildContext context, TextEditingController c) builder;

  @override
  State<ControllerScope> createState() => _ControllerScopeState();
}

class _ControllerScopeState extends State<ControllerScope> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _c);
}
