import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/unit_formatter.dart';
import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/check_in.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../l10n/l10n.dart';
import '../../map/presentation/place_visuals.dart';
import '../../places/presentation/place_visit_card.dart';
import 'check_in_controller.dart';

/// Opens the check-in sheet for [place] and completes with the result, or
/// `null` if the player backed out.
Future<CheckInResult?> showCheckInSheet({
  required BuildContext context,
  required Place place,
}) {
  return showNpModalSheet<CheckInResult>(
    context: context,
    builder: (context) => CheckInSheet(place: place),
  );
}

/// The moment the whole app is built around.
///
/// Three jobs, in this order: confirm what the player is standing next to, show
/// what checking in is worth, and make correcting a wrong guess easy — because
/// a wrong auto-detected place is the fastest way to lose someone's trust.
class CheckInSheet extends ConsumerStatefulWidget {
  const CheckInSheet({required this.place, super.key});

  final Place place;

  @override
  ConsumerState<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<CheckInSheet> {
  late Place _place = widget.place;

  /// Why the last attempt was refused, shown on the sheet itself.
  ///
  /// Deliberately not a `SnackBar`. A modal sheet is pushed on the root
  /// navigator and the `ScaffoldMessenger` that shows snack bars lives in the
  /// screen *underneath* it, so the message was drawn behind the sheet and the
  /// scrim — the player tapped "Check in here", nothing appeared to happen, and
  /// the one explanation they were given was invisible. It belongs next to the
  /// button that produced it.
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = UnitFormatter.of(l10n);
    final isSubmitting = ref.watch(checkInControllerProvider).isLoading;
    // Watched rather than read: checking in writes the record, and the count on
    // screen should be the one the player just added to.
    final visit = ref.watch(placeVisitProvider(_place.id));
    final alternatives = ref
        .watch(checkInCandidatesProvider)
        .where((candidate) => candidate.id != _place.id)
        .take(3)
        .toList();

    return NpSheetSurface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              place: _place,
              format: format,
              distanceMeters: ref.watch(distanceToPlaceProvider(_place)),
              hasVisited: visit.hasVisited,
            ),
            const SizedBox(height: NpSpace.md),
            _RewardTiles(place: _place),
            // Only once there is something to say. A card reading "no check-ins
            // yet" above a button offering to make one is noise, and it would
            // sit on the sheet for every place the player has never been to —
            // which is most of them.
            if (visit.hasVisited) ...[
              const SizedBox(height: NpSpace.xs),
              PlaceVisitCard(visit: visit),
            ],
            const SizedBox(height: NpSpace.md),
            if (_error case final error?) ...[
              _Refusal(message: error),
              const SizedBox(height: NpSpace.sm),
            ],
            NpPrimaryButton(
              label: l10n.checkInAction,
              onPressed: isSubmitting ? null : _submit,
            ),
            if (alternatives.isNotEmpty) ...[
              const SizedBox(height: NpSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.checkInWrongPlaceTitle,
                      style: NpTypography.footnote.copyWith(
                        fontWeight: NpFontWeight.semibold,
                      ),
                    ),
                  ),
                  Text(
                    '${l10n.commonSearch} ›',
                    style: NpTypography.caption.copyWith(
                      color: NpColors.accentDefault,
                      fontWeight: NpFontWeight.semibold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NpSpace.xs),
              for (final alternative in alternatives) ...[
                _AlternativeRow(
                  place: alternative,
                  distanceMeters: ref.watch(
                    distanceToPlaceProvider(alternative),
                  ),
                  // A refusal is about the place it was refused for. Carrying
                  // "you're too far away" over to a different place would be
                  // the sheet telling the player something it does not know.
                  onTap: () => setState(() {
                    _place = alternative;
                    _error = null;
                  }),
                ),
                const SizedBox(height: NpSpace.xs),
              ],
            ],
            const SizedBox(height: NpSpace.xs),
            NpGhostButton(
              label: l10n.commonNotNow,
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final result = await ref
        .read(checkInControllerProvider.notifier)
        .checkIn(_place.id);
    if (!mounted) return;

    if (result != null) {
      Navigator.of(context).pop(result);
      return;
    }

    // The rules refused it — most often because the player drifted out of
    // range while the sheet was open. Say so on the sheet rather than closing
    // it on a silent failure.
    final error = ref.read(checkInControllerProvider).error;
    final l10n = context.l10n;

    setState(() {
      _error =
          error is CheckInFailure &&
              error.reason == CheckInFailureReason.outOfRange
          ? l10n.checkInTooFar
          : l10n.checkInFailed;
    });
  }
}

/// Why the check-in did not happen, on the sheet that offered it.
///
/// Sits directly above the button rather than at the top of the sheet: the
/// player's eyes are already there, and a message at the other end of a
/// scrolling column is one they have to go looking for.
class _Refusal extends StatelessWidget {
  const _Refusal({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return NpCard(
      padding: const EdgeInsets.symmetric(
        horizontal: NpSpace.md,
        vertical: NpSpace.sm,
      ),
      borderColor: NpColors.statusWarning,
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: NpSize.iconMd,
            color: NpColors.statusWarning,
          ),
          const SizedBox(width: NpSpace.sm),
          Expanded(
            child: Text(
              message,
              style: NpTypography.footnote.copyWith(
                color: NpColors.statusWarning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.place,
    required this.format,
    required this.distanceMeters,
    required this.hasVisited,
  });

  final Place place;
  final UnitFormatter format;
  final double distanceMeters;

  /// Whether the player has been here at all, from their own visit record.
  ///
  /// Not `place.visited`, which since schema v5 means "the first-visit bonus
  /// has been spent". An hour spent nearby counts as having been somewhere but
  /// does not claim, so the two genuinely differ — and "never visited" above a
  /// card reading "checked in once" is the sheet contradicting itself.
  final bool hasVisited;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        NpMapPin.small(icon: place.category.icon, color: place.category.color),
        const SizedBox(width: NpSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                placeDisplayName(place, l10n),
                style: NpTypography.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                l10n.checkInSheetMeta(
                  _categoryLabel(place, l10n),
                  format.distance(distanceMeters),
                  hasVisited ? 'before' : 'never',
                ),
                style: NpTypography.footnote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: NpSpace.xs),
        Text(
          l10n.commonXp(place.visited ? place.xpReward : place.xpReward * 2),
          style: NpTypography.label.copyWith(color: NpColors.accentDefault),
        ),
      ],
    );
  }

  /// Categories are product vocabulary, not user-facing copy yet: the words
  /// come from the places API once it exists, so we show the raw kind rather
  /// than inventing a translation that will be replaced.
  String _categoryLabel(Place place, AppL10n l10n) => switch (place.category) {
    PlaceCategory.food => 'Food',
    PlaceCategory.cafe => 'Café',
    PlaceCategory.landmark => 'Landmark',
    PlaceCategory.park => 'Park',
    PlaceCategory.market => 'Market',
    PlaceCategory.unknown => l10n.logsUnknownSite,
  };
}

class _RewardTiles extends StatelessWidget {
  const _RewardTiles({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _RewardTile(
            value: '${place.explorersHere}',
            caption: l10n.checkInExplorersHere,
          ),
        ),
        const SizedBox(width: NpSpace.xs),
        Expanded(
          child: _RewardTile(
            value: l10n.checkInFirstVisit,
            caption: l10n.checkInFirstVisitBonus,
          ),
        ),
        const SizedBox(width: NpSpace.xs),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final streak = ref.watch(
                playerProvider.select((p) => p.value?.streakDays ?? 0),
              );
              return _RewardTile(
                value: l10n.commonDays(streak),
                caption: l10n.checkInStreakKept,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return NpCard(
      padding: const EdgeInsets.symmetric(vertical: NpSpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: NpTypography.title),
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

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({
    required this.place,
    required this.distanceMeters,
    required this.onTap,
  });

  final Place place;
  final double distanceMeters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = UnitFormatter.of(l10n);

    return NpCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: NpSpace.sm,
        vertical: NpSpace.xs,
      ),
      borderRadius: NpRadius.md,
      child: Row(
        children: [
          NpMapPin.small(
            icon: place.category.icon,
            color: place.category.color,
          ),
          const SizedBox(width: NpSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  placeDisplayName(place, l10n),
                  style: NpTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  format.distance(distanceMeters),
                  style: NpTypography.caption,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: NpSize.iconMd,
            color: NpColors.contentMuted,
          ),
        ],
      ),
    );
  }
}
