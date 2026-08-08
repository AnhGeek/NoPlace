import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// The orange call to action. There is at most one on screen at a time.
class NpPrimaryButton extends StatelessWidget {
  const NpPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Fills the available width. Turn off for inline actions such as the
  /// "Check in" button inside the nearby card.
  final bool expand;

  /// Shorter vertical padding, used inside cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? NpRadius.md : NpRadius.md);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? NpOpacity.locked : 1,
        child: Material(
          color: NpColors.accentDefault,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Container(
              width: expand ? double.infinity : null,
              constraints: BoxConstraints(
                minHeight: compact ? 40 : NpSize.touchTarget,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? NpSpace.lg : NpSpace.xl,
                vertical: compact ? NpSpace.sm : NpSpace.md,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: NpSize.iconMd,
                      color: NpColors.contentOnAccent,
                    ),
                    const SizedBox(width: NpSpace.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: NpTypography.label.copyWith(
                        color: NpColors.contentOnAccent,
                        fontWeight: NpFontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The quiet way out of a sheet — "Not now", "Skip", "Maybe later".
///
/// Quiet, but never grey-on-grey: a second button under the orange one is still
/// something the player is meant to be able to press, and the muted foreground
/// this used to wear made it read as disabled.
class NpGhostButton extends StatelessWidget {
  const NpGhostButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.emphasized = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Sits before the label. Used where the button does something rather than
  /// declines something.
  final IconData? icon;

  /// Lights the button up in the accent colour, for when it has work waiting
  /// for it — an edited form with unsaved changes, mainly. The change is
  /// animated, so it reads as an answer to what the player just did rather
  /// than as a button that was always that colour.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(NpRadius.md);
    final foreground = emphasized
        ? NpColors.accentHover
        : NpColors.contentSecondary;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? NpOpacity.locked : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: NpDuration.fast,
              curve: NpEasing.standard,
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: NpSize.touchTarget),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: emphasized
                    ? NpColors.accentSubtle
                    : NpColors.backgroundPanel,
                borderRadius: radius,
                border: Border.all(
                  color: emphasized
                      ? NpColors.accentDefault
                      : NpColors.borderStrong,
                  width: emphasized
                      ? NpBorderWidth.thin
                      : NpBorderWidth.hairline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: NpSize.iconMd, color: foreground),
                    const SizedBox(width: NpSpace.xs),
                  ],
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: NpDuration.fast,
                      curve: NpEasing.standard,
                      style: NpTypography.body.copyWith(
                        color: foreground,
                        fontWeight: NpFontWeight.semibold,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
