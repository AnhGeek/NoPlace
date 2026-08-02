import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// The four-destination navigation bar.
///
/// Drawn by hand rather than with `NavigationBar` for two reasons: the active
/// item needs a tinted pill behind the icon only (not the label), and the bar
/// has to fade into the map instead of sitting on an opaque surface.
class NpBottomNavBar extends StatelessWidget {
  const NpBottomNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.transparent = false,
    super.key,
  });

  final List<NpNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Over the map the bar fades out into the scene; on list screens it sits on
  /// the surface colour.
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: transparent ? null : NpColors.backgroundSurface,
        gradient: transparent
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x0008080A), Color(0xF708080A)],
                stops: [0, 0.28],
              )
            : null,
        border: transparent
            ? null
            : const Border(top: BorderSide(color: NpColors.borderSubtle)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: NpSpace.xs,
          bottom: bottomInset > 0 ? bottomInset : NpSpace.sm,
        ),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _NavItem(
                  destination: destinations[i],
                  isSelected: i == currentIndex,
                  onTap: () => onDestinationSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NpNavDestination {
  const NpNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final NpNavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? NpColors.accentDefault : NpColors.contentMuted;

    return Semantics(
      selected: isSelected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: NpSize.touchTarget,
        splashColor: NpColors.accentSubtle,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: NpSpace.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: NpDuration.fast,
                curve: NpEasing.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: NpSpace.lg,
                  vertical: NpSpace.xxs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? NpColors.accentSubtle
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(NpRadius.lg),
                ),
                child: Icon(
                  isSelected ? destination.selectedIcon : destination.icon,
                  size: NpSize.iconXl,
                  color: color,
                ),
              ),
              const SizedBox(height: NpSpace.xxs),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NpTypography.caption.copyWith(
                  color: color,
                  fontWeight: isSelected
                      ? NpFontWeight.bold
                      : NpFontWeight.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
