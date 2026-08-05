import 'package:flutter/material.dart';

import '../../../../design_system/tokens/design_tokens.g.dart';
import '../../../../l10n/l10n.dart';

/// Saves the spot the player is standing on.
///
/// The one authoring control on the map, and it deliberately takes no aim: it
/// drops the place *where you are*, because that is the moment the thought
/// happens — you are sitting in the café, not looking at it from three streets
/// away. Long-pressing the map covers the other case.
///
/// Accented like the primary button rather than panelled like [FogToggleButton]
/// and [RecentreButton]: those two change how the map is drawn, this one adds
/// something to it.
class AddPlaceButton extends StatelessWidget {
  const AddPlaceButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.placeAddAction;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: NpColors.accentDefault,
          shape: const CircleBorder(
            side: BorderSide(color: NpColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: InkWell(
            onTap: onPressed,
            child: const SizedBox(
              width: _size,
              height: _size,
              child: Icon(
                Icons.add_location_alt_rounded,
                size: NpSize.iconHero,
                color: NpColors.contentOnAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
