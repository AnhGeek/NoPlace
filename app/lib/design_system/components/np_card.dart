import 'package:flutter/material.dart';

import '../tokens/design_tokens.g.dart';

/// The panel every piece of content sits on: log rows, stat tiles, sheets.
///
/// One surface, one border, one radius — if a screen needs a different
/// container, it is either a new component or a design bug.
class NpCard extends StatelessWidget {
  const NpCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: NpSpace.lg,
      vertical: NpSpace.md,
    ),
    this.color = NpColors.backgroundPanel,
    this.borderColor = NpColors.borderSubtle,
    this.borderRadius = NpRadius.lg,
    this.gradient,
    this.onTap,
    this.dimmed = false,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double borderRadius;

  /// Used only by the weekly-challenge header, which is the one card allowed to
  /// carry a gradient.
  final Gradient? gradient;

  final VoidCallback? onTap;

  /// Locked content: 45% opacity, still readable, obviously unavailable.
  final bool dimmed;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: NpBorderWidth.hairline),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: NpColors.accentSubtle,
          highlightColor: NpColors.accentSubtle,
          child: content,
        ),
      );
    }

    if (dimmed) {
      content = Opacity(opacity: NpOpacity.locked, child: content);
    }

    return semanticLabel == null
        ? content
        : Semantics(label: semanticLabel, container: true, child: content);
  }
}
