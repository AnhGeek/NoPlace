/// The controls the place sheet is made of.
///
/// They live together because they are one form and they share one rule: a
/// second tap on the answer you already gave takes it back. Nothing here is
/// mandatory — a pin with no name, no feeling and no rating is a perfectly good
/// "come back to this", and a form that will not let you leave a field alone
/// turns a two-second note into an interrogation.
///
/// [PlaceAutoCheckInPicker] is the exception to the "tap again to undo" rule,
/// and has to be: it always has an answer, and one of them is "Off".
library;

import 'package:flutter/material.dart';

import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/auto_check_in.dart';
import '../../../domain/entities/map_point.dart';
import '../../../l10n/l10n.dart';
import '../../map/presentation/place_visuals.dart';

/// Picks the glyph the pin is drawn with.
class PlaceIconPicker extends StatelessWidget {
  const PlaceIconPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: NpSpace.xs,
      runSpacing: NpSpace.xs,
      children: [
        for (final iconId in MapPointIcon.all)
          _IconCell(
            iconId: iconId,
            selected: iconId == selected,
            onTap: () => onChanged(iconId),
          ),
      ],
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.iconId,
    required this.selected,
    required this.onTap,
  });

  final String iconId;
  final bool selected;
  final VoidCallback onTap;

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? NpColors.accentSubtle
            : NpColors.backgroundPanelSunken,
        borderRadius: BorderRadius.circular(NpRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NpRadius.md),
              border: Border.all(
                color: selected ? NpColors.accentDefault : Colors.transparent,
                width: NpBorderWidth.thick,
              ),
            ),
            child: Icon(
              userPointIcon(iconId),
              size: NpSize.iconXl,
              color: selected
                  ? NpColors.accentDefault
                  : NpColors.contentSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Records how the place felt, in one tap.
class PlaceMoodPicker extends StatelessWidget {
  const PlaceMoodPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final moodId in PlaceMood.all) ...[
          Expanded(
            child: _MoodCell(
              moodId: moodId,
              selected: moodId == selected,
              // Tapping the chosen one again clears it: the difference between
              // "meh" and "I have not said" is worth being able to get back to.
              onTap: () =>
                  onChanged(moodId == selected ? PlaceMood.none : moodId),
            ),
          ),
          if (moodId != PlaceMood.all.last) const SizedBox(width: NpSpace.xxs),
        ],
      ],
    );
  }
}

class _MoodCell extends StatelessWidget {
  const _MoodCell({
    required this.moodId,
    required this.selected,
    required this.onTap,
  });

  final String moodId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = placeMoodLabel(moodId, context.l10n);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? NpColors.accentSubtle
            : NpColors.backgroundPanelSunken,
        borderRadius: BorderRadius.circular(NpRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: NpSpace.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NpRadius.md),
              border: Border.all(
                color: selected ? NpColors.accentDefault : Colors.transparent,
                width: NpBorderWidth.thick,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Excluded from semantics because the cell already announces
                // the feeling by name; a screen reader saying "smiling face
                // with heart-shaped eyes, Love it" is worse than either alone.
                ExcludeSemantics(
                  child: Text(
                    placeMoodEmoji(moodId),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(height: NpSpace.hair),
                ExcludeSemantics(
                  child: Text(
                    label,
                    style: NpTypography.caption.copyWith(
                      color: selected
                          ? NpColors.contentPrimary
                          : NpColors.contentMuted,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How long the player has to stay before it counts as a visit on its own —
/// and a question mark that says what that means.
///
/// A segmented control rather than a switch and a duration field, because there
/// are four answers and all of them fit on one line. The help sits *inside* the
/// control's row rather than under it: this is the one setting on the sheet
/// that keeps acting after the phone is back in a pocket, and somebody meeting
/// it for the first time deserves the explanation within reach of the thing
/// they are about to change.
class PlaceAutoCheckInPicker extends StatelessWidget {
  const PlaceAutoCheckInPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final Duration selected;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return NpSegmentedControl<Duration>(
      // Anything not on offer — a value from a build with a different set —
      // lands on the default rather than leaving every segment unselected.
      selected: AutoCheckIn.all.contains(selected)
          ? selected
          : AutoCheckIn.defaultInterval,
      onChanged: onChanged,
      segments: [
        for (final every in AutoCheckIn.all)
          NpSegment(value: every, label: autoCheckInLabel(every, l10n)),
      ],
    );
  }
}

/// The question mark beside the auto check-in heading.
class PlaceAutoCheckInTip extends StatelessWidget {
  const PlaceAutoCheckInTip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return NpTipButton(
      title: l10n.placeAutoCheckInTipTitle,
      body: l10n.placeAutoCheckInTipBody,
      semanticLabel: l10n.placeAutoCheckInHelp,
      dismissLabel: l10n.commonGotIt,
    );
  }
}

/// Five stars, and a way back to none of them.
class PlaceStarRating extends StatelessWidget {
  const PlaceStarRating({
    required this.stars,
    required this.onChanged,
    super.key,
  });

  final int stars;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      label: l10n.placeStars(stars),
      container: true,
      child: Row(
        children: [
          for (var star = 1; star <= MapPoint.maxStars; star++)
            _Star(
              filled: star <= stars,
              // Tapping the star you are already on clears the rating, which is
              // the only way back to "not rated" once you have picked one.
              onTap: () => onChanged(star == stars ? 0 : star),
            ),
          const SizedBox(width: NpSpace.xs),
          Expanded(
            child: Text(
              l10n.placeStars(stars),
              style: NpTypography.caption.copyWith(
                color: NpColors.contentMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.filled, required this.onTap});

  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: InkResponse(
        onTap: onTap,
        radius: NpSpace.xxl,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NpSpace.xxs,
            vertical: NpSpace.xs,
          ),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: NpSize.iconHero,
            color: filled
                ? NpColors.categoryLandmark
                : NpColors.contentPlaceholder,
          ),
        ),
      ),
    );
  }
}
