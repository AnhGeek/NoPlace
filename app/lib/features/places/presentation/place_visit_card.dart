import 'package:flutter/material.dart';

import '../../../core/formatting/unit_formatter.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/place_visit.dart';
import '../../../l10n/l10n.dart';
import '../../map/presentation/place_visuals.dart';

/// How often the player has been here, and when they last were.
///
/// One card for both kinds of place — the ones the player saved and the ones
/// the world came with — because "you have been here seven times, last on
/// Tuesday" is the same sentence either way, and the [PlaceVisit] it reads is
/// the same record. What differs is only whether there is an interval to
/// explain underneath.
class PlaceVisitCard extends StatelessWidget {
  const PlaceVisitCard({required this.visit, this.autoCheckInEvery, super.key});

  final PlaceVisit visit;

  /// How long a stay here has to run to count on its own, or null for a place
  /// that has no such setting — the world's own places, which count a visit
  /// when the player checks in and at no other time.
  ///
  /// The note it produces is not decoration: a count that goes up on its own is
  /// alarming unless you know why, and this is the only place the app can
  /// explain it at the moment it matters.
  final Duration? autoCheckInEvery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = UnitFormatter.of(l10n);
    final last = visit.lastCheckInAt;
    final every = autoCheckInEvery;

    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.how_to_reg_rounded,
                size: NpSize.iconLg,
                color: NpColors.accentDefault,
              ),
              const SizedBox(width: NpSpace.sm),
              Expanded(
                child: Text(
                  l10n.placeCheckInCount(visit.checkInCount),
                  style: NpTypography.bodyStrong,
                ),
              ),
            ],
          ),
          if (last != null) ...[
            const SizedBox(height: NpSpace.xxs),
            Text(
              l10n.placeLastCheckIn(
                format.weekday(last),
                format.timeOfDay(last),
              ),
              style: NpTypography.caption,
            ),
          ],
          if (every != null) ...[
            const SizedBox(height: NpSpace.xs),
            Text(
              autoCheckInSummary(every, l10n),
              style: NpTypography.caption.copyWith(
                color: NpColors.contentMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
