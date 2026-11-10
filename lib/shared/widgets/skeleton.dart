import 'package:flutter/material.dart';

import '../../core/design/motion.dart';
import '../../core/i18n/i18n.dart';

/// İskelet parçası: içeriğin yerini tutan soluk kutu (hareketsiz).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: circle ? height : width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(circle ? height : radius),
    ),
  );
}

/// Liste biçiminde iskelet: yuvarlak + iki satır. Yer darsa satır sayısı
/// sığacak kadar azalır (taşma olmaz); hiç sığmıyorsa tek ince çubuk.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 4,
    this.padding = const EdgeInsets.all(16),
  });

  final int rows;
  final EdgeInsets padding;

  static const _rowHeight = 44.0;
  static const _gap = 14.0;

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr('Yükleniyor'),
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, c) {
          var n = rows;
          if (c.hasBoundedHeight) {
            final room = c.maxHeight - padding.vertical + _gap;
            n = (room / (_rowHeight + _gap)).floor().clamp(0, rows);
            if (n == 0) {
              return Center(
                child: SkeletonBox(
                  width: 120,
                  height: c.maxHeight.clamp(0, 12).toDouble(),
                ),
              );
            }
          }
          return Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) const SizedBox(height: _gap),
                  Row(
                    children: [
                      const SkeletonBox(height: _rowHeight, circle: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(
                              widthFactor: i.isEven ? 0.6 : 0.45,
                              child: const SkeletonBox(),
                            ),
                            const SizedBox(height: 8),
                            FractionallySizedBox(
                              widthFactor: i.isEven ? 0.35 : 0.5,
                              child: const SkeletonBox(height: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// Yükleniyor → içerik / hata / boş geçişi: çapraz geçiş ([AppMotion.base]).
///
/// [loading] true iken [skeleton] gösterilir ve en az [AppMotion.minSkeleton]
/// kadar ekranda kalır (bir kare yanıp sönmesin). İçerik ilk kurulduğunda
/// hazırsa iskelet hiç görünmez. Hareketi azaltta geçiş anındadır.
class LoadSwitcher extends StatefulWidget {
  const LoadSwitcher({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.builder,
    this.stateKey,
  });

  final bool loading;
  final Widget skeleton;

  /// İçerik (ya da hata / boş durum). Yalnızca [loading] false iken çağrılır.
  final WidgetBuilder builder;

  /// İçerik türü değişince (veri ↔ hata) çapraz geçiş için anahtar.
  final Object? stateKey;

  @override
  State<LoadSwitcher> createState() => _LoadSwitcherState();
}

class _LoadSwitcherState extends State<LoadSwitcher>
    with SingleTickerProviderStateMixin {
  late bool _showSkeleton = widget.loading;

  /// İskeletin en az görünme süresini sayar (kare zamanıyla; testlerde
  /// `pumpAndSettle` bunu bekler).
  late final _hold =
      AnimationController(vsync: this, duration: AppMotion.minSkeleton)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed &&
              !widget.loading &&
              _showSkeleton) {
            setState(() => _showSkeleton = false);
          }
        });

  @override
  void initState() {
    super.initState();
    // Denetleyici burada kurulur (dispose sırasında tembel kurulmasın).
    _hold.value = 0;
    if (_showSkeleton) _hold.forward();
  }

  @override
  void didUpdateWidget(LoadSwitcher old) {
    super.didUpdateWidget(old);
    if (widget.loading == old.loading) return;
    if (widget.loading) {
      _showSkeleton = true;
      _hold.forward(from: 0);
    } else if (_hold.isCompleted || !Motion.of(context)) {
      _showSkeleton = false;
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skeleton = _showSkeleton || widget.loading;
    final child = skeleton
        ? KeyedSubtree(key: const ValueKey('skeleton'), child: widget.skeleton)
        : KeyedSubtree(
            key: ValueKey(widget.stateKey ?? 'content'),
            child: widget.builder(context),
          );
    if (!Motion.of(context)) return child;
    return AnimatedSwitcher(
      duration: AppMotion.base,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      // Üstten hizalı: iskelet ve içerik aynı yerden başlar (düzen kaymaz).
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}
