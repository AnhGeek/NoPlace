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
class NpGhostButton extends StatelessWidget {
  const NpGhostButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(NpRadius.md);

    return Semantics(
      button: true,
      child: Material(
        color: NpColors.backgroundPanel,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: NpSize.touchTarget),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: NpColors.borderSubtle,
                width: NpBorderWidth.hairline,
              ),
            ),
            child: Text(
              label,
              style: NpTypography.body.copyWith(
                color: NpColors.contentMuted,
                fontWeight: NpFontWeight.semibold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
