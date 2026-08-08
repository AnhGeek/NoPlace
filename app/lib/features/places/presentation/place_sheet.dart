import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/theme/np_typography.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/auto_check_in.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/map_point.dart';
import '../../../domain/rules/place_visit_rules.dart';
import '../../../l10n/l10n.dart';
import '../../map/presentation/place_visuals.dart';
import 'place_form_fields.dart';
import 'place_visit_card.dart';

/// What the sheet did, for the screen underneath to say out loud.
///
/// The sheet writes to the repository itself, but it cannot show the message:
/// by the time there is anything to say, its own context is on the way out.
enum PlaceSheetOutcome { saved, checkedIn, deleted }

class PlaceSheetResult {
  const PlaceSheetResult(this.outcome, this.place);

  final PlaceSheetOutcome outcome;

  /// The place as it stood when the sheet closed — the deleted one included,
  /// which is what makes undo possible.
  final MapPoint place;
}

/// Saves a new place at [location].
Future<PlaceSheetResult?> showAddPlaceSheet({
  required BuildContext context,
  required GeoPoint location,
}) {
  return showNpModalSheet<PlaceSheetResult>(
    context: context,
    builder: (context) => PlaceSheet(location: location),
  );
}

/// Opens a place the player already saved: rate it, rename it, check in, or
/// delete it.
Future<PlaceSheetResult?> showPlaceSheet({
  required BuildContext context,
  required MapPoint place,
}) {
  return showNpModalSheet<PlaceSheetResult>(
    context: context,
    builder: (context) => PlaceSheet(existing: place),
  );
}

/// One sheet for both halves of the same thing.
///
/// Adding a place and coming back to it are the same form with the same
/// controls; splitting them into two screens would mean two of every picker and
/// a guarantee they drift apart. What changes is the buttons underneath: a new
/// place can only be saved, an existing one can also be checked into and
/// deleted.
class PlaceSheet extends ConsumerStatefulWidget {
  const PlaceSheet({this.location, this.existing, super.key})
    : assert(
        location != null || existing != null,
        'a new place needs a location, an existing one brings its own',
      );

  /// Where a *new* place goes. Null when editing.
  final GeoPoint? location;

  /// The place being opened. Null when adding.
  final MapPoint? existing;

  @override
  ConsumerState<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<PlaceSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.label ?? '',
  );

  late String _iconId = widget.existing?.iconId ?? MapPointIcon.defaultId;
  late String _moodId = widget.existing?.moodId ?? PlaceMood.none;
  late int _stars = widget.existing?.stars ?? 0;
  late Duration _autoCheckInEvery =
      widget.existing?.autoCheckInEvery ?? AutoCheckIn.defaultInterval;

  bool _saving = false;

  /// Whether the form says anything the saved place does not. Drives the save
  /// button: a button that looks the same before and after an edit gives the
  /// player no reason to believe the app noticed.
  bool _edited = false;

  MapPoint? get _existing => widget.existing;

  bool get _isNew => _existing == null;

  @override
  void initState() {
    super.initState();
    // Typing changes the form as much as the pickers do, and the name is the
    // field people edit most.
    _name.addListener(_nameChanged);
  }

  @override
  void dispose() {
    _name
      ..removeListener(_nameChanged)
      ..dispose();
    super.dispose();
  }

  /// Runs a change from one of the pickers and re-reads the form against the
  /// place it was opened on.
  void _edit(VoidCallback change) {
    setState(() {
      change();
      _edited = _hasEdits;
    });
  }

  /// Only rebuilds when the answer actually flips — this runs on every
  /// keystroke, and the sheet is a screenful of pickers.
  void _nameChanged() {
    if (_hasEdits == _edited) return;
    setState(() => _edited = _hasEdits);
  }

  bool get _hasEdits {
    final existing = _existing;
    if (existing == null) return true;
    return _name.text.trim() != existing.label ||
        _iconId != existing.iconId ||
        _moodId != existing.moodId ||
        _stars != existing.stars ||
        _autoCheckInEvery != existing.autoCheckInEvery;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final existing = _existing;

    return NpSheetSurface(
      child: SingleChildScrollView(
        // The name field is the first thing on the sheet and the keyboard
        // covers the bottom half of it. Without this the buttons are under the
        // keyboard and the sheet looks broken the moment anybody types.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              iconId: _iconId,
              controller: _name,
              title: _isNew ? l10n.placeAddTitle : null,
            ),
            const SizedBox(height: NpSpace.lg),

            _SectionLabel(l10n.placeSectionIcon),
            const SizedBox(height: NpSpace.xs),
            PlaceIconPicker(
              selected: _iconId,
              onChanged: (id) => _edit(() => _iconId = id),
            ),
            const SizedBox(height: NpSpace.lg),

            _SectionLabel(l10n.placeSectionMood),
            const SizedBox(height: NpSpace.xs),
            PlaceMoodPicker(
              selected: _moodId,
              onChanged: (id) => _edit(() => _moodId = id),
            ),
            const SizedBox(height: NpSpace.lg),

            _SectionLabel(l10n.placeSectionRating),
            const SizedBox(height: NpSpace.xs),
            PlaceStarRating(
              stars: _stars,
              onChanged: (stars) => _edit(() => _stars = stars),
            ),
            const SizedBox(height: NpSpace.lg),

            _SectionLabel(
              l10n.placeSectionAutoCheckIn,
              trailing: const PlaceAutoCheckInTip(),
            ),
            const SizedBox(height: NpSpace.xs),
            PlaceAutoCheckInPicker(
              selected: _autoCheckInEvery,
              onChanged: (every) => _edit(() => _autoCheckInEvery = every),
            ),
            const SizedBox(height: NpSpace.lg),

            if (existing != null) ...[
              // The interval comes from the form rather than from the saved
              // point, so the note under the count describes what the player
              // has just picked instead of what they picked last time.
              PlaceVisitCard(
                visit: existing.visit,
                autoCheckInEvery: _autoCheckInEvery,
              ),
              const SizedBox(height: NpSpace.md),
            ],

            NpPrimaryButton(
              label: _isNew ? l10n.placeAddAction : l10n.placeCheckInAction,
              icon: _isNew
                  ? Icons.add_location_alt_rounded
                  : Icons.done_rounded,
              onPressed: _saving
                  ? null
                  : () => unawaited(_submit(checkIn: !_isNew)),
            ),

            if (existing != null) ...[
              const SizedBox(height: NpSpace.xs),
              NpGhostButton(
                label: l10n.placeSave,
                icon: Icons.save_rounded,
                // Lights up the moment anything on the form moves. Left
                // pressable when nothing has: a player who taps it after
                // changing their mind twice back to where they started should
                // get their place back, not a dead button.
                emphasized: _edited,
                onPressed: _saving
                    ? null
                    : () => unawaited(_submit(checkIn: false)),
              ),
              const SizedBox(height: NpSpace.xs),
              _DeleteButton(
                onPressed: _saving ? null : () => unawaited(_delete(existing)),
              ),
            ] else ...[
              const SizedBox(height: NpSpace.xs),
              NpGhostButton(
                label: l10n.commonNotNow,
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Writes the form, and optionally counts this as a visit.
  ///
  /// Checking in saves the edits too. Somebody who re-rates a café and then
  /// taps "I'm here now" meant both, and losing the rating to the more obvious
  /// button is exactly the kind of small betrayal that stops people editing
  /// anything.
  Future<void> _submit({required bool checkIn}) async {
    setState(() => _saving = true);

    final now = DateTime.now();
    final repository = ref.read(mapPointRepositoryProvider);
    final opened = _existing;

    // The row as it stands now, not as it stood when the sheet opened. The
    // presence ticker writes check-ins into these points while the player is
    // looking at one, and a form saved on top of the copy it opened with would
    // roll that back — the same edit, five minutes apart, quietly costing them
    // an hour they had actually spent here.
    final existing = opened == null ? null : repository.of(opened.id) ?? opened;

    var place = (existing ?? _blank()).copyWith(
      label: _name.text.trim(),
      iconId: _iconId,
      moodId: _moodId,
      stars: _stars,
      autoCheckInEvery: _autoCheckInEvery,
    );
    // Picking a different interval starts the wait again, so the first check-in
    // it earns is a whole one. See [PlaceVisitRules.intervalChanged] for what
    // this is protecting against.
    if (existing != null && _autoCheckInEvery != existing.autoCheckInEvery) {
      place = PlaceVisitRules.applyIntervalChange(place, now: now);
    }
    if (checkIn) {
      place = PlaceVisitRules.checkIn(place, now: now);
    }

    if (existing == null) {
      await repository.add(place);
    } else {
      await repository.update(place);
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      PlaceSheetResult(
        checkIn ? PlaceSheetOutcome.checkedIn : PlaceSheetOutcome.saved,
        place,
      ),
    );
  }

  Future<void> _delete(MapPoint place) async {
    setState(() => _saving = true);
    await ref.read(mapPointRepositoryProvider).remove(place.id);

    if (!mounted) return;
    // Deleted without asking, on purpose: the map offers to undo it, which is
    // one tap instead of two and keeps the point recoverable for longer than a
    // dialog would.
    Navigator.of(
      context,
    ).pop(PlaceSheetResult(PlaceSheetOutcome.deleted, place));
  }

  /// A brand new point. The id is the microsecond it was made in: unique on one
  /// device without a dependency, and readable in the database file — which is
  /// the whole point of storing it in a plain one.
  MapPoint _blank() => MapPoint(
    id: 'user-${DateTime.now().microsecondsSinceEpoch}',
    kind: MapPointKind.user,
    location: widget.location!,
    createdAt: DateTime.now(),
  );
}

/// The pin the player is building, next to what they are calling it.
///
/// The preview updates as the icon is picked, so the choice is made against the
/// thing that will actually be on the map rather than against a grid cell.
class _Header extends StatelessWidget {
  const _Header({required this.iconId, required this.controller, this.title});

  final String iconId;
  final TextEditingController controller;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NpMapPin(icon: userPointIcon(iconId), color: NpColors.statusRare),
        const SizedBox(width: NpSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(title!, style: NpTypography.caption),
                const SizedBox(height: NpSpace.hair),
              ],
              _NameField(controller: controller, hintText: l10n.placeNameHint),
            ],
          ),
        ),
      ],
    );
  }
}

/// The one text input in the app so far. Styled like [NpSearchField] minus the
/// magnifying glass, so a field is a field wherever it turns up.
class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: NpTypography.title,
      cursorColor: NpColors.accentDefault,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      // Long enough for a real name, short enough that it cannot become a
      // paragraph the map has to draw.
      maxLength: 60,
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hintText,
        hintStyle: NpTypography.title.copyWith(
          color: NpColors.contentPlaceholder,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;

  /// Sits at the end of the heading's row. Today only the auto check-in tip
  /// uses it — a heading that needs a control beside it is the exception, not
  /// the pattern.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: NpTypography.overline.copyWith(color: NpColors.contentMuted),
    );
    if (trailing == null) return label;

    return Row(
      children: [
        label,
        // Beside the words rather than pushed to the far edge: a question mark
        // stranded on the right of the sheet reads as belonging to the sheet
        // rather than to the heading it is answering for.
        trailing!,
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(NpRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: NpSize.touchTarget),
            alignment: Alignment.center,
            child: Text(
              context.l10n.placeDelete,
              style: NpTypography.body.copyWith(
                color: NpColors.statusWarning,
                fontWeight: NpFontWeight.semibold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
