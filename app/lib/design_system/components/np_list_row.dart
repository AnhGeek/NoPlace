import 'package:flutter/material.dart';

import '../theme/np_typography.dart';
import '../tokens/design_tokens.g.dart';
import 'np_card.dart';

/// The circular marker on the left of a log or quest row.
///
/// Its colour carries the state — done, in progress, locked — so the row never
/// has to spell it out in words.
class NpRowMark extends StatelessWidget {
  const NpRowMark({
    required this.background,
    this.icon,
    this.label,
    this.foreground = NpColors.contentOnStatus,
    super.key,
  }) : assert(
         icon != null || label != null,
         'a mark needs either an icon or a label',
       );

  const NpRowMark.done({super.key})
    : background = NpColors.statusSuccessMuted,
      foreground = NpColors.contentOnStatus,
      icon = Icons.check_rounded,
      label = null;

  const NpRowMark.question({super.key})
    : background = NpColors.statusInfo,
      foreground = NpColors.contentOnStatus,
      icon = Icons.question_mark_rounded,
      label = null;

  const NpRowMark.locked({super.key})
    : background = NpColors.statusLocked,
      foreground = NpColors.contentMuted,
      icon = Icons.lock_outline_rounded,
      label = null;

  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NpSize.logMark,
      height: NpSize.logMark,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: NpSize.iconLg, color: foreground)
          : Text(
              label!,
              style: NpTypography.bodyStrong.copyWith(color: foreground),
            ),
    );
  }
}

/// One row of the logs and quests lists: mark, title, subtitle, reward.
class NpListRow extends StatelessWidget {
  const NpListRow({
    required this.mark,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dimmed = false,
    super.key,
  });

  final Widget mark;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return NpCard(
      onTap: onTap,
      dimmed: dimmed,
      padding: const EdgeInsets.symmetric(
        horizontal: NpSpace.md,
        vertical: NpSpace.md,
      ),
      semanticLabel: subtitle == null ? title : '$title. $subtitle',
      child: Row(
        children: [
          mark,
          const SizedBox(width: NpSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: NpTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: NpSpace.hair),
                  Text(
                    subtitle!,
                    style: NpTypography.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: NpSpace.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
