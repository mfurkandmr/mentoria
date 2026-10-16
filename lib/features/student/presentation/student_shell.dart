import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../shared/motion.dart';
import '../../../shared/widgets/exit_guard.dart';
import '../../../shared/widgets/honey_nav_bar.dart';
import '../../notifications/presentation/notification_widgets.dart';

/// Öğrenci alt menüsü: Ana Sayfa · Denemeler · Soru · Konular · Süre
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      onBack: () {
        if (shell.currentIndex == 0) return false;
        shell.goBranch(0);
        return true;
      },
      child: InAppNotifier(
        child: Scaffold(
          body: _BranchTransition(index: shell.currentIndex, child: shell),
          bottomNavigationBar: HoneyNavBar(
            selectedIndex: shell.currentIndex,
            onSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            items: [
              HoneyNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: tr('Ana Sayfa'),
              ),
              HoneyNavItem(
                icon: Icons.insights_outlined,
                selectedIcon: Icons.insights_rounded,
                label: tr('Denemeler'),
              ),
              HoneyNavItem(
                icon: Icons.edit_note_outlined,
                selectedIcon: Icons.edit_note_rounded,
                label: tr('Soru'),
              ),
              HoneyNavItem(
                icon: Icons.checklist_outlined,
                selectedIcon: Icons.checklist_rounded,
                label: tr('Konular'),
              ),
              HoneyNavItem(
                icon: Icons.timer_outlined,
                selectedIcon: Icons.timer_rounded,
                label: tr('Süre'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sekme değişince yeni sayfa hafifçe büyüyerek ve yukarı süzülerek belirir.
class _BranchTransition extends StatefulWidget {
  const _BranchTransition({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchTransition> createState() => _BranchTransitionState();
}

class _BranchTransitionState extends State<_BranchTransition>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(_BranchTransition old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && Motion.of(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    child: widget.child,
    builder: (context, child) {
      final v = _curve.value;
      return Opacity(
        opacity: 0.35 + 0.65 * v,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - v)),
          child: Transform.scale(scale: 0.985 + 0.015 * v, child: child),
        ),
      );
    },
  );
}
