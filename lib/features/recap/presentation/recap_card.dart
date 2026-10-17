import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/bizz.dart';
import '../../../shared/widgets/effects.dart';
import '../data/week_recap.dart';
import 'recap_story_screen.dart';

/// Ana sayfadaki "Haftanın Bal Raporu" kartı: parıldayan gradyan, üzerinde
/// süzülen Bızz; dokununca tam ekran hikaye açılır.
class RecapCard extends StatelessWidget {
  const RecapCard({super.key, required this.recap, required this.firstName});

  final WeekRecap recap;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final subtitle = recap.isEmpty
        ? tr('Bu hafta kovan sessiz. Raporu doldurmaya başla!')
        : tr('{n} soru · {d} aktif gün · {emoji} {persona}', {
            'n': recap.questions,
            'd': recap.activeDays,
            'emoji': recap.persona.emoji,
            'persona': recap.persona.title,
          });
    return Semantics(
      button: true,
      label: tr('Haftanın Bal Raporu'),
      child: GestureDetector(
        onTap: () =>
            openRecapStory(context, recap: recap, firstName: firstName),
        child: PressScale(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LoopBuilder(
              period: const Duration(seconds: 6),
              builder: (_, t, child) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + math.sin(t * 2 * math.pi) * 0.4, -1),
                    end: Alignment(1, 1 + math.cos(t * 2 * math.pi) * 0.4),
                    colors: const [
                      Color(0xFF3B2A8F),
                      Color(0xFF7B4FD0),
                      Color(0xFFFF8A00),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: HoneycombPainter(
                          color: Colors.white,
                          opacity: 0.14,
                          radius: 18,
                        ),
                      ),
                    ),
                    // Kayan parıltı
                    Positioned.fill(
                      child: FractionalTranslation(
                        translation: Offset(t * 3 - 1.5, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.18),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    child!,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC233),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tr('YENİ · HAFTALIK'),
                              style: const TextStyle(
                                color: Color(0xFF2B2350),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('Haftanın Bal Raporu'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tr('İzle'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Bizz(
                      size: 92,
                      mood: BizzMood.happy,
                      interactive: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
