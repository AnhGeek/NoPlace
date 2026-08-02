import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/home_shell.dart';
import '../../../../core/formatting/unit_formatter.dart';
import '../../../../data/repository_providers.dart';
import '../../../../design_system/components/components.dart';
import '../../../../design_system/theme/np_typography.dart';
import '../../../../design_system/tokens/design_tokens.g.dart';
import '../../../../domain/entities/place.dart';
import '../../../../domain/rules/exploration_rules.dart';
import '../../../../l10n/l10n.dart';
import '../place_visuals.dart';

/// The NEARBY tab: everything within walking distance, closest first.
///
/// It answers a different question from the map. The map is "where am I"; this
/// is "what is around me, and what is worth the walk" — a question a map
/// zoomed to one street cannot answer, because the answer is mostly off screen.
///
/// Out-of-range rows are dimmed rather than dropped: the list is also how a
/// player picks the next thing to walk to, and a list that only shows what you
/// can already claim would be empty exactly when it is most useful.
class NearbyList extends ConsumerWidget {
  const NearbyList({required this.onCheckIn, super.key});

  final ValueChanged<Place> onCheckIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = ref.watch(nearbyPlacesByDistanceProvider);

    // The rules decide what is claimable, not a comparison written here: the
    // check-in sheet offers exactly this list, so a row can never enable a
    // button the sheet would then have nothing to fill.
    final claimable = ref
        .watch(checkInCandidatesProvider)
        .map((place) => place.id)
        .toSet();

    if (ranked.isEmpty) return const _NothingNearby();

    return ListView.separated(
      padding: EdgeInsets.only(
        top: NpSpace.md,
        bottom: HomeShell.bottomInsetFor(context),
      ),
      itemCount: ranked.length,
      separatorBuilder: (context, index) => const SizedBox(height: NpSpace.sm),
      itemBuilder: (context, index) {
        final (place, distance) = ranked[index];
        return _NearbyRow(
          place: place,
          distanceMeters: distance,
          inRange: claimable.contains(place.id),
          onCheckIn: () => onCheckIn(place),
        );
      },
    );
  }
}

/// One place in the list: what it is, how far, and the way in.
class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    required this.place,
    required this.distanceMeters,
    required this.inRange,
    required this.onCheckIn,
  });

  final Place place;
  final double distanceMeters;
  final bool inRange;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = UnitFormatter.of(l10n);

    final name = placeDisplayName(place, l10n);

    return NpListRow(
      mark: NpMapPin.small(
        icon: place.category.icon,
        color: place.category.color,
      ),
      // Whether the player has been here rides on the name, where the eye
      // already is. The meta line carries it too, but only for rows in range —
      // and "have I done this one?" is the question you scan the whole list
      // for.
      title: place.visited ? l10n.mapNearbyVisitedName(name) : name,
      subtitle: inRange
          ? l10n.mapNearbyMeta(
              format.distance(distanceMeters),
              place.visited ? 'before' : 'never',
              place.visited
                  ? place.xpReward
                  : place.xpReward * ExplorationRules.firstVisitMultiplier,
            )
          : l10n.mapNearestMeta(format.distance(distanceMeters)),
      // Disabled rather than hidden, so every row is the same shape and the
      // list does not reflow as the player walks in and out of range.
      trailing: NpPrimaryButton(
        label: l10n.mapCheckIn,
        onPressed: inRange ? onCheckIn : null,
        expand: false,
        compact: true,
      ),
      onTap: inRange ? onCheckIn : null,
      dimmed: !inRange,
    );
  }
}

/// Nothing within walking distance.
///
/// Says the same true thing the map's card says: the fog opens because you
/// walked, not because there was a place to claim.
class _NothingNearby extends StatelessWidget {
  const _NothingNearby();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NpSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NpMapPin(
              icon: Icons.explore_outlined,
              color: NpColors.categoryUnknown,
            ),
            const SizedBox(height: NpSpace.md),
            Text(
              l10n.mapNothingNearbyTitle,
              style: NpTypography.bodyStrong,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NpSpace.xs),
            Text(
              l10n.mapNothingNearbyBody,
              style: NpTypography.body.copyWith(color: NpColors.contentMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
