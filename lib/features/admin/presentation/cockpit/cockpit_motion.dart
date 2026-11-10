import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/haptics.dart';
import '../../../../core/design/motion.dart';
import '../../../../shared/widgets/effects.dart';
import 'cockpit_theme.dart';

/// Kokpitin hareket parçaları. Süre, eğri ve titreşimler uygulamanın ortak
/// dilinden gelir (`AppMotion`, `AppHaptics`).
///
/// | An | Tetik | Değişen | Süre | Titreşim | Hareketi azalt |
/// |----|-------|---------|------|----------|----------------|
/// | Basma | parmak iner | kart %97'ye küçülür | fast | yok | anında, küçülme yok |
/// | Seçim | segment değişir | kayan seçici, liste çapraz geçiş | base | select | anında |
/// | Açılış | bölüm ilk kez görünür | aşağıdan süzülerek belirir, sırayla | base | yok | anında görünür |
/// | Sayı | veri gelir | sayarak gelir | slow | yok | son değer |
/// | Onay | bildirim/telefon/plan kaydedildi | mesaj | — | confirm | aynı |

/// Bölümün ilk görünüşü: aşağıdan süzülerek belirir. [index] sıralı gecikme
/// verir (ilk 8 bölüm). Hareketi azaltta ve sayfa kaydırılmışken anında.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) =>
      FadeSlideIn(delay: AppMotion.stagger(index), child: child);
}

/// Basınca hafifçe küçülen yüzey. Dokunmayı kendisi almaz; içindeki
/// InkWell / düğme alır.
typedef Pressable = PressScale;

/// Tam sayının sayarak gelmesi (ilk yüklemede ve değer değişince).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final int value;
  final String Function(int) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => CountUp(
    value: value.toDouble(),
    format: (v) => format(v.round()),
    style: style,
  );
}

/// iOS'un kayan seçim kontrolü: seçici bir segmentten ötekine kayar.
/// Her segment iki satır olabilir (ad + sayı); etiket kesilmez.
class SlidingSegments<T extends Object> extends StatelessWidget {
  const SlidingSegments({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  /// değer → (anahtar, ad, isteğe bağlı sayı)
  final Map<T, ({Key key, String label, String? count})> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: context.cockpit.faint,
        // Koyuda top raydan bir ton açık (iOS gibi).
        thumbColor: context.cockpit.isDark
            ? const Color(0xFF3A404A)
            : context.cockpit.surface,
        padding: const EdgeInsets.all(3),
        onValueChanged: (v) {
          if (v == null || v == value) return;
          AppHaptics.select();
          onChanged(v);
        },
        children: {
          for (final e in segments.entries)
            e.key: Padding(
              key: e.value.key,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tek satır: kontrol segment boyunu tek satıra göre
                  // ölçer, bölünen yazı taşar.
                  Text(
                    e.value.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: text.labelMedium?.copyWith(
                      fontWeight: e.key == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: e.key == value
                          ? context.cockpit.ink
                          : context.cockpit.muted,
                    ),
                  ),
                  if (e.value.count != null)
                    Text(
                      e.value.count!,
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: e.key == value
                            ? context.cockpit.ink
                            : context.cockpit.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
        },
      ),
    );
  }
}

/// İçerik değişince (segment, genişlet) yumuşak çapraz geçiş + boy değişimi.
class SmoothSwitch extends StatelessWidget {
  const SmoothSwitch({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Hareketi azaltta doğrudan son hal (sıfır süreli AnimatedSize düzen
    // sırasında kendini yeniden kirletir).
    if (!Motion.of(context)) return child;
    const d = AppMotion.base;
    return AnimatedSize(
      duration: d,
      curve: AppMotion.move,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: d,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(a),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}
