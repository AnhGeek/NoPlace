import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/components.dart';
import '../../design_system/tokens/design_tokens.g.dart';
import '../../l10n/l10n.dart';

/// The frame around the four main destinations.
///
/// The body extends behind the navigation bar so the map can fill the screen;
/// list screens compensate with [HomeShell.bottomInsetFor].
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Bottom padding a screen needs so its last row clears the navigation bar.
  /// Screens use this instead of guessing a magic number.
  ///
  /// The system inset is read from the **view**, not from `MediaQuery.of`.
  /// That is not a stylistic choice: `Scaffold` hands its `body` a MediaQuery
  /// with the bottom padding already consumed, while the `bottomNavigationBar`
  /// it sits above gets the real one. Asking the body's MediaQuery therefore
  /// under-reports the inset and puts content *underneath* the nav bar — which
  /// is invisible on a phone with no gesture bar and obvious on one with it,
  /// and is what edge-to-edge on Android 15+ turned into a visible bug.
  ///
  /// `View.of` is the window, and nothing in the widget tree can shrink it.
  static double bottomInsetFor(BuildContext context) =>
      NpSize.navBarHeight +
      NpSpace.lg +
      MediaQueryData.fromView(View.of(context)).viewPadding.bottom;

  static const int _mapBranchIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isMap = navigationShell.currentIndex == _mapBranchIndex;

    return Scaffold(
      backgroundColor: NpColors.backgroundSurface,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: NpBottomNavBar(
        transparent: isMap,
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NpNavDestination(
            icon: Icons.explore_outlined,
            selectedIcon: Icons.explore,
            label: l10n.navMap,
          ),
          NpNavDestination(
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            label: l10n.navLogs,
          ),
          NpNavDestination(
            icon: Icons.shield_outlined,
            selectedIcon: Icons.shield_rounded,
            label: l10n.navQuests,
          ),
          NpNavDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }

  void _onDestinationSelected(int index) {
    // Tapping the active tab again pops that branch back to its root — the
    // behaviour every phone user already expects.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
