import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/motion.dart';
import 'cockpit_theme.dart';

/// Kokpitin hareket dili (iOS'a yakın: sade ama akıcı).
///
/// Anlar (motion-and-haptics):
/// | An | Tetik | Değişen | Süre | Titreşim | Hareketi azalt |
/// |----|-------|---------|------|----------|----------------|
/// | Basma | parmak iner | kart %97'ye küçülür | kısa | yok | anında, küçülme yok |
/// | Seçim | segment değişir | kayan seçici, liste çapraz geçiş | orta | selectionClick | anında |
/// | Açılış | bölüm ilk kez görünür | aşağıdan süzülerek belirir, sırayla | orta | yok | anında görünür |
/// | Sayı | veri gelir | sayarak gelir | uzun | yok | son değer |
/// | Onay | bildirim/telefon/plan kaydedildi | mesaj | — | lightImpact | aynı |
///
/// Süreler rol olarak burada; yeni hareketler bunları kullanır.
abstract final class CockpitMotion {
  static const short = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 320);
  static const long = Duration(milliseconds: 700);

  /// iOS'taki "ease-out" eğrisine yakın: hızlı başlar, yumuşak durur.
  static const curve = Cubic(0.22, 1, 0.36, 1);

  /// Hareketi azalt açıksa (ya da testlerde) sıfır.
  static Duration of(BuildContext context, Duration d) =>
      Motion.of(context) ? d : Duration.zero;
}

/// Titreşim haritası: olay → en çok bir fiil. Tek merkezden kapatılır.
abstract final class CockpitHaptics {
  /// Uygulama genelindeki tek anahtar (testlerde kapatılabilir).
  static bool enabled = true;

  /// Segment / sekme seçimi.
  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Bir işlem kaydedildi (bildirim gönderildi, telefon, deneme planı).
  static void commit() {
    if (enabled) HapticFeedback.lightImpact();
  }
}

/// Bölümün ilk görünüşü: aşağıdan 16 px süzülerek ve hafifçe büyüyerek
/// belirir. [index] sıralı gecikme verir. Hareketi azaltta ve sayfa
/// kaydırılmışken anında görünür.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: CockpitMotion.long,
  );
  late final _a = CurvedAnimation(parent: _c, curve: CockpitMotion.curve);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Tembel listede bölüm, kaydırılınca (ilk kez ya da geri dönüşte) yeniden
    // kurulur. O anda animasyon ve gecikme boşluk gibi görünür: anında göster.
    final position = Scrollable.maybeOf(context)?.position;
    final scrolled =
        position != null && position.hasPixels && position.pixels > 0;
    if (!Motion.of(context) || scrolled) {
      _c.value = 1;
      return;
    }
    Future.delayed(Duration(milliseconds: 40 + widget.index * 70), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    child: widget.child,
    builder: (context, child) {
      final t = _a.value;
      return Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: Transform.scale(
            scale: 0.98 + 0.02 * t,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      );
    },
  );
}

/// Basınca hafifçe küçülen yüzey (iOS dokunma hissi). Dokunmayı kendisi
/// almaz; içindeki InkWell / düğme alır.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset _start = Offset.zero;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      _start = e.position;
      _set(true);
    },
    // Parmak kayıyorsa bu dokunma değil kaydırmadır: kart hemen eski boyuna
    // döner (Listener, kaydırma başlayınca iptal almaz).
    onPointerMove: (e) {
      if (_down && (e.position - _start).distance > kTouchSlop) _set(false);
    },
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down && Motion.of(context) ? widget.scale : 1,
      duration: CockpitMotion.short,
      curve: CockpitMotion.curve,
      child: widget.child,
    ),
  );
}

/// Tam sayının sayarak gelmesi (yalnızca ilk yüklemede ve değer değişince).
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
  Widget build(BuildContext context) {
    if (!Motion.of(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: CockpitMotion.long,
      curve: CockpitMotion.curve,
      builder: (_, v, _) => Text(format(v.round()), style: style),
    );
  }
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
          CockpitHaptics.select();
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
    const d = CockpitMotion.medium;
    return AnimatedSize(
      duration: d,
      curve: CockpitMotion.curve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: d,
        switchInCurve: CockpitMotion.curve,
        switchOutCurve: Curves.easeIn,
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
