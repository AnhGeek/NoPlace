import 'package:flutter/material.dart';

import '../../../../design_system/tokens/design_tokens.g.dart';
import '../../../../l10n/l10n.dart';

/// Lifts the fog off the map for as long as the player wants it off.
///
/// The fog is the game, and it is also what stops you finding the street you
/// are standing on. An explorer who cannot orient themselves stops walking,
/// which costs the app more than the peek does — so this is a control, not a
/// cheat: nothing under the fog is erased, the walk keeps recording, and
/// turning it back on shows exactly the ground that was earned meanwhile.
///
/// The lit state is **fog hidden**, which is the opposite of [RecentreButton]'s
/// convention and deliberate. Fog on is the game as designed and needs no
/// marker on screen; fog off is the state worth noticing, because forgetting
/// about it means walking a city that has quietly stopped hiding anything.
class FogToggleButton extends StatelessWidget {
  const FogToggleButton({
    required this.fogVisible,
    required this.onPressed,
    super.key,
  });

  final bool fogVisible;
  final VoidCallback onPressed;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      button: true,
      // Names the action, not the state: a screen reader user needs to know
      // what the tap will do.
      label: fogVisible ? l10n.mapHideFog : l10n.mapShowFog,
      child: Tooltip(
        message: fogVisible ? l10n.mapHideFog : l10n.mapShowFog,
        child: Material(
          color: fogVisible
              ? NpColors.backgroundPanelRaised
              : NpColors.accentDefault,
          shape: const CircleBorder(
            side: BorderSide(color: NpColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: _size,
              height: _size,
              child: Icon(
                fogVisible ? Icons.filter_drama : Icons.cloud_off,
                size: NpSize.iconXl,
                color: fogVisible
                    ? NpColors.contentSecondary
                    : NpColors.contentOnAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
