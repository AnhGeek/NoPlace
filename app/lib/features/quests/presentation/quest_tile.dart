import 'package:flutter/material.dart';

import '../../../core/formatting/unit_formatter.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/quest.dart';
import '../../../l10n/l10n.dart';

/// One quest row.
///
/// Shared by the quests screen and the quest half of the logs, so a quest looks
/// identical wherever the player meets it. The `switch` over the sealed [Quest]
/// is exhaustive: adding a quest type is a compile error until it has a row.
class QuestTile extends StatelessWidget {
  const QuestTile({required this.quest, this.onTap, super.key});

  final Quest quest;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = UnitFormatter.of(l10n);

    return switch (quest) {
      RevealSiteQuest(:final distanceMeters, :final districtName) => NpListRow(
        mark: const NpRowMark.question(),
        title: l10n.questsRevealSiteTitle,
        subtitle: l10n.questsRevealSiteSubtitle(
          format.distance(distanceMeters),
          districtName,
        ),
        trailing: NpXpLabel(l10n.commonXp(quest.xpReward)),
        onTap: onTap,
      ),
      WalkDistanceQuest(:final targetMeters, :final doneMeters) => NpListRow(
        mark: const NpRowMark(
          background: NpColors.statusWarning,
          icon: Icons.directions_walk_rounded,
        ),
        title: l10n.questsWalkTitle(format.kilometersCompact(targetMeters)),
        subtitle: l10n.questsWalkSubtitle(
          format.kilometers(doneMeters),
          format.kilometers(targetMeters),
        ),
        trailing: NpXpLabel(l10n.commonXp(quest.xpReward)),
        onTap: onTap,
      ),
      EnterDistrictQuest(:final nearestDistrictName, :final distanceMeters) =>
        NpListRow(
          mark: const NpRowMark(
            background: NpColors.statusRare,
            icon: Icons.grid_view_rounded,
          ),
          title: l10n.questsNewDistrictTitle,
          subtitle: l10n.questsNewDistrictSubtitle(
            nearestDistrictName,
            format.distance(distanceMeters),
          ),
          trailing: NpXpLabel(l10n.commonXp(quest.xpReward)),
          onTap: onTap,
        ),
      LockedQuest(:final teaser, :final unlockLevel) => NpListRow(
        mark: const NpRowMark.locked(),
        title: switch (teaser) {
          LockedQuestTeaser.nightWanderer => l10n.questsNightWandererTitle,
        },
        subtitle: l10n.questsUnlocksAtLevel(unlockLevel),
        dimmed: true,
      ),
    };
  }
}
