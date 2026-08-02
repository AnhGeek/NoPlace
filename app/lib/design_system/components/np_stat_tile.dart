import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';
import 'np_card.dart';

/// A square tile with an icon, a number and a caption. Three of them fit one
/// row on every phone we support, which is why the icon badge is fixed size and
/// the caption is allowed two lines.
class NpStatTile extends StatelessWidget {
  const NpStatTile({
    required this.icon,
    required this.value,
    required this.caption,
    required this.iconBackground,
    super.key,
  });

  final IconData icon;
  final String value;
  final String caption;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return NpCard(
      padding: const EdgeInsets.symmetric(
        horizontal: NpSpace.xs,
        vertical: NpSpace.md,
      ),
      semanticLabel: '$value $caption',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(NpSpace.xs),
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(NpRadius.md),
            ),
            child: Icon(
              icon,
              size: NpSize.iconLg,
              color: NpColors.contentOnStatus,
            ),
          ),
          const SizedBox(height: NpSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: NpTypography.headline),
          ),
          const SizedBox(height: NpSpace.hair),
          Text(
            caption,
            style: NpTypography.caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
