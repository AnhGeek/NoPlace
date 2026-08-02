import 'package:flutter/material.dart';

import '../../../../design_system/tokens/design_tokens.g.dart';
import '../../../../l10n/l10n.dart';

/// Puts the map back on the player, at the zoom the app opens with.
///
/// It exists because the map stops following as soon as you drag it — which it
/// has to, or a GPS fix every few metres would pull the map out from under your
/// thumb. That trade needs a way back, and this is it.
///
/// [following] is not decoration: it is the only way to tell whether the map is
/// tracking you or parked where you left it. Filled means it is following, so
/// the button is a status light as much as a control.
class RecentreButton extends StatelessWidget {
  const RecentreButton({
    required this.following,
    required this.onPressed,
    super.key,
  });

  final bool following;
  final VoidCallback onPressed;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.mapRecentre,
      child: Material(
        color: following
            ? NpColors.accentDefault
            : NpColors.backgroundPanelRaised,
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
              // Filled crosshair while following, hollow while parked — the
              // same distinction every map app makes, so nobody has to learn
              // it here.
              following ? Icons.my_location : Icons.location_searching,
              size: NpSize.iconXl,
              color: following
                  ? NpColors.contentOnAccent
                  : NpColors.contentSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
