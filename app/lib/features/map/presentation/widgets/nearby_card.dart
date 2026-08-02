import 'package:flutter/material.dart';

import '../../../../core/formatting/unit_formatter.dart';
import '../../../../design_system/components/components.dart';
import '../../../../design_system/theme/np_typography.dart';
import '../../../../design_system/tokens/design_tokens.g.dart';
import '../../../../domain/entities/place.dart';
import '../../../../l10n/l10n.dart';
import '../place_visuals.dart';

/// The prompt that turns "I am walking past something" into a check-in.
///
/// It is the busiest 90 dp in the product, so it carries exactly three things:
/// what we think you are near, what it is worth, and a way to say we got it
/// wrong.
///
/// **Always on screen.** It has three states rather than existing or not:
///
/// * a place close enough to claim — the check-in prompt;
/// * a place too far to claim — its name and how far, so the card is a compass
///   rather than a blank;
/// * nothing known nearby at all — an empty state that still says walking
///   works, because it does: the fog opens with or without a place in it.
///
/// A card that appears and disappears makes the bottom of the screen jump and
/// leaves the player wondering whether they broke something.
class NearbyCard extends StatelessWidget {
  const NearbyCard({
    required this.place,
    required this.distanceMeters,
    required this.onCheckIn,
    required this.onCorrect,
    this.inRange = true,
    super.key,
  });

  /// The card with no place to point at.
  const NearbyCard.empty({super.key})
    : place = null,
      distanceMeters = 0,
      inRange = false,
      onCheckIn = null,
      onCorrect = null;

  /// Null when nothing is known nearby.
  final Place? place;
  final double distanceMeters;

  /// Whether [place] is close enough to claim. Out of range the button is
  /// disabled rather than hidden, so the card does not change shape as you
  /// walk towards something.
  final bool inRange;

  final VoidCallback? onCheckIn;
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = UnitFormatter.of(l10n);

    final place = this.place;
    if (place == null) return const _NothingNearbyCard();

    return NpCard(
      color: NpColors.backgroundPanelRaised,
      padding: const EdgeInsets.symmetric(
        horizontal: NpSpace.md,
        vertical: NpSpace.md,
      ),
      borderRadius: NpRadius.xl,
      child: Row(
        children: [
          NpMapPin.small(
            icon: place.category.icon,
            color: place.category.color,
          ),
          const SizedBox(width: NpSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  inRange
                      ? l10n.mapNearbyTitle(placeDisplayName(place, l10n))
                      : l10n.mapNearestTitle(placeDisplayName(place, l10n)),
                  style: NpTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  inRange
                      ? l10n.mapNearbyMeta(
                          format.distance(distanceMeters),
                          place.visited ? 'before' : 'never',
                          place.visited ? place.xpReward : place.xpReward * 2,
                        )
                      : l10n.mapNearestMeta(format.distance(distanceMeters)),
                  style: NpTypography.caption,
                  // Two lines: Vietnamese runs ~30% longer than English, and
                  // clipping the reward is clipping the reason to tap.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Only offered when there is something to correct *to*. Out of
                // range there are no candidates, so the link would open an
                // empty list.
                if (inRange) ...[
                  const SizedBox(height: NpSpace.hair),
                  GestureDetector(
                    onTap: onCorrect,
                    child: Text(
                      l10n.mapNearbyWrongPlace,
                      style: NpTypography.caption.copyWith(
                        color: NpColors.accentDefault,
                        fontWeight: NpFontWeight.semibold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: NpSpace.sm),
          NpPrimaryButton(
            label: l10n.mapCheckIn,
            // Disabled, not hidden: the button keeps its place so the card
            // does not resize the moment you step inside the radius.
            onPressed: inRange ? onCheckIn : null,
            expand: false,
            compact: true,
          ),
        ],
      ),
    );
  }
}

/// The card when there is no known place anywhere near.
///
/// It still says something true and useful: the fog opens because you walked,
/// not because you checked in somewhere.
class _NothingNearbyCard extends StatelessWidget {
  const _NothingNearbyCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return NpCard(
      color: NpColors.backgroundPanelRaised,
      padding: const EdgeInsets.symmetric(
        horizontal: NpSpace.md,
        vertical: NpSpace.md,
      ),
      borderRadius: NpRadius.xl,
      child: Row(
        children: [
          const NpMapPin.small(
            icon: Icons.explore_outlined,
            color: NpColors.categoryUnknown,
          ),
          const SizedBox(width: NpSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.mapNothingNearbyTitle,
                  style: NpTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.mapNothingNearbyBody,
                  style: NpTypography.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "You are here · Bến Thành" — pinned to the player, not to the screen, so it
/// stays truthful when the map is panned.
class YouAreHereChip extends StatelessWidget {
  const YouAreHereChip({required this.placeName, super.key});

  final String placeName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NpColors.accentDefault,
          borderRadius: BorderRadius.circular(NpRadius.md),
          boxShadow: const [NpShadows.marker],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NpSpace.sm,
            vertical: NpSpace.xxs,
          ),
          child: Text(
            context.l10n.mapYouAreHere(placeName),
            style: NpTypography.caption.copyWith(
              color: NpColors.contentOnAccent,
              fontWeight: NpFontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
