import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// A selectable pill in a horizontally scrolling row — the city switcher.
class NpChip extends StatelessWidget {
  const NpChip({
    required this.label,
    this.icon,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;

  /// For a chip that names something real the player cannot have yet — a map
  /// that exists but is not on this phone. Shown rather than hidden, because
  /// "there is a map of Hà Nội" is worth knowing; dimmed and untappable,
  /// because selecting it would open an empty city.
  final bool dimmed;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? NpColors.accentDefault
        : NpColors.contentMuted;

    final chip = Semantics(
      selected: selected,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: NpDuration.fast,
          curve: NpEasing.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: NpSpace.md,
            vertical: NpSpace.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? NpColors.accentSubtle : NpColors.backgroundPanel,
            borderRadius: BorderRadius.circular(NpRadius.pill),
            border: Border.all(
              color: selected ? NpColors.accentDefault : NpColors.borderSubtle,
              width: NpBorderWidth.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: NpSize.iconSm, color: foreground),
                const SizedBox(width: NpSpace.xxs),
              ],
              Text(
                label,
                style: NpTypography.footnote.copyWith(
                  color: foreground,
                  fontWeight: NpFontWeight.semibold,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return dimmed ? Opacity(opacity: NpOpacity.locked, child: chip) : chip;
  }
}
