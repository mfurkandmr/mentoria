import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// Uygulamadaki bütün sayfa geçişleri buradan geçer.
///
/// iOS / macOS: sağdan kayma (kenardan kaydırınca geri dönüş korunur).
/// Öteki platformlar: belirirken [AppMotion.slidePage] kadar yukarı kayar.
/// Süre her yerde [AppMotion.slow]; hareketi azaltta geçiş çizilmez.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.slow;

  @override
  Duration get reverseTransitionDuration => AppMotion.base;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!Motion.of(context)) return child;
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return _cupertino.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return _FadeSlide(animation: animation, child: child);
  }
}

class _FadeSlide extends StatefulWidget {
  const _FadeSlide({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide> {
  late CurvedAnimation _curve = _build();

  CurvedAnimation _build() => CurvedAnimation(
    parent: widget.animation,
    curve: AppMotion.enter,
    reverseCurve: AppMotion.exit,
  );

  @override
  void didUpdateWidget(_FadeSlide old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _curve.dispose();
      _curve = _build();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, AppMotion.slidePage * (1 - _curve.value)),
        child: child,
      ),
    ),
  );
}

/// Bütün platformlarda aynı kurucu.
const appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: AppPageTransitionsBuilder(),
    TargetPlatform.iOS: AppPageTransitionsBuilder(),
    TargetPlatform.macOS: AppPageTransitionsBuilder(),
    TargetPlatform.windows: AppPageTransitionsBuilder(),
    TargetPlatform.linux: AppPageTransitionsBuilder(),
    TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
  },
);

/// Düğme basılıyken içeriği hafifçe küçültür (`ButtonStyle.foregroundBuilder`).
/// Dalga (ripple) temadan gelir; ikisi birlikte "basıldı" hissini verir.
Widget pressScaleLayer(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => AnimatedScale(
  scale: states.contains(WidgetState.pressed) && Motion.of(context)
      ? AppMotion.pressScale
      : 1,
  duration: AppMotion.fast,
  curve: AppMotion.enter,
  child: child,
);
