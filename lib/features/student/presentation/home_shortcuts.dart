import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/widgets/effects.dart';
import '../../garden/data/garden.dart';
import '../../garden/presentation/garden_screen.dart';
import '../../mistakes/data/mistake_repository.dart';

/// Ana sayfada yan yana iki kısayol: Hata Defteri ve Odak Bahçesi.
class HomeShortcuts extends ConsumerWidget {
  const HomeShortcuts({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(mistakeCardsProvider(studentId)).value ?? const [];
    final due = cards.where((c) => c.isDue(DateTime.now())).length;
    final sessions =
        ref.watch(allSessionsProvider(studentId)).value ?? const [];
    final flowers = sessions
        .where((s) => FlowerSize.of(s) != FlowerSize.wilted)
        .length;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Shortcut(
              colors: const [Color(0xFFFF6F91), Color(0xFFC2185B)],
              icon: Icons.menu_book_rounded,
              title: tr('Hata Defteri'),
              subtitle: due > 0
                  ? tr('{n} soru tekrar bekliyor', {'n': due})
                  : cards.isEmpty
                  ? tr('Yanlışlarını unutma')
                  : tr('Bugünlük tekrar yok ✓'),
              badge: due > 0 ? '$due' : null,
              onTap: () => context.push('/student/mistakes'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Shortcut(
              colors: const [Color(0xFF7BD389), Color(0xFF2F8F3A)],
              icon: Icons.local_florist_rounded,
              title: tr('Odak Bahçem'),
              subtitle: flowers == 0
                  ? tr('İlk çiçeğini ek')
                  : tr('{n} çiçek açtı', {'n': flowers}),
              onTap: () => context.push('/student/garden'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final List<Color> colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title. $subtitle',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: PressScale(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 30),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          color: colors.last,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
