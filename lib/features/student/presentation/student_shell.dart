import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/brand_theme.dart';
import '../../../shared/widgets/exit_guard.dart';
import '../../../shared/widgets/honey_nav_bar.dart';
import '../../notifications/presentation/notification_widgets.dart';
import '../../../core/design/motion.dart';

/// Öğrenci alt menüsü: Ana Sayfa · Eğitim · Denemeler · Soru · Konular · Süre
class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  List<HoneyNavItem> get _items => [
    HoneyNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: tr('Ana Sayfa'),
    ),
    HoneyNavItem(
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
      label: tr('Eğitim'),
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
  ];

  /// Bu genişlikten itibaren (tablet yatay, bilgisayar) alt menü yerine
  /// solda yan menü; sayfalar ekranın kalanını doldurur.
  static const railBreakpoint = 900.0;

  void _select(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;
    final body = _BranchTransition(index: shell.currentIndex, child: shell);
    return ExitGuard(
      onBack: () {
        if (shell.currentIndex == 0) return false;
        shell.goBranch(0);
        return true;
      },
      child: InAppNotifier(
        child: Scaffold(
          body: wide
              ? Row(
                  children: [
                    _StudentRail(
                      items: _items,
                      selectedIndex: shell.currentIndex,
                      onSelected: _select,
                    ),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : HoneyNavBar(
                  selectedIndex: shell.currentIndex,
                  onSelected: _select,
                  items: _items,
                ),
        ),
      ),
    );
  }
}

/// Geniş ekranda öğrenci yan menüsü (alt menüyle aynı sekmeler).
class _StudentRail extends StatelessWidget {
  const _StudentRail({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<HoneyNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = context.brand;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: brand.primary.withValues(alpha: 0.22)),
        ),
      ),
      child: NavigationRail(
        key: const ValueKey('student-rail'),
        backgroundColor: Colors.transparent,
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        labelType: NavigationRailLabelType.all,
        groupAlignment: -0.9,
        indicatorColor: brand.primary,
        selectedIconTheme: IconThemeData(color: brand.onPrimary),
        selectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        destinations: [
          for (final item in items)
            NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon ?? item.icon),
              label: Text(item.label),
            ),
        ],
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
    duration: AppMotion.base,
    value: 1,
  );
  late final _curve = CurvedAnimation(parent: _c, curve: AppMotion.enter);

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
