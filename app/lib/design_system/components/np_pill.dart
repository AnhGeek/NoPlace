import 'package:flutter/widgets.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';

/// A small filled badge: "+14%", "+100 XP", "current".
class NpPill extends StatelessWidget {
  const NpPill({
    required this.label,
    this.color = NpColors.statusSuccess,
    this.foreground = NpColors.contentOnStatus,
    this.large = false,
    super.key,
  });

  final String label;
  final Color color;
  final Color foreground;

  /// The celebration variant used on the discovery screen.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? NpSpace.lg : NpSpace.sm,
        vertical: large ? NpSpace.xxs : NpSpace.hair,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(NpRadius.pill),
      ),
      child: Text(
        label,
        style: (large ? NpTypography.body : NpTypography.caption).copyWith(
          color: foreground,
          fontWeight: NpFontWeight.semibold,
        ),
      ),
    );
  }
}

/// The orange "+50" that trails a reward-bearing row.
class NpXpLabel extends StatelessWidget {
  const NpXpLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: NpTypography.footnote.copyWith(
        color: NpColors.accentDefault,
        fontWeight: NpFontWeight.semibold,
      ),
    );
  }
}
