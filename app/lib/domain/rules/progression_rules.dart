import 'dart:math' as math;

import 'exploration_rules.dart';

/// What the player has earned, worked out from what they actually did.
///
/// There is no server keeping score and no session log to replay, so XP is not
/// a balance that is added to — it is a **function of the record on the
/// device**: the places checked into, the districts walked, the ground
/// uncovered. That has a property worth having: it cannot drift. Restore a
/// backup on a new phone and the number is the same, because it was never
/// stored in the first place.
///
/// The rates are the ones the rest of the game already pays, so a check-in is
/// worth the same on the profile as it was in the sheet that awarded it.
abstract final class ProgressionRules {
  const ProgressionRules._();

  /// What one visited place is worth. The same 50 the world's places carry, and
  /// what the check-in sheet says as it awards it.
  static const int xpPerPlace = 50;

  /// And one district walked into — [ExplorationRules.districtDiscoveryXp],
  /// which is the biggest single award in the game and should stay that way.
  static const int xpPerDistrict = ExplorationRules.districtDiscoveryXp;

  /// Ten a kilometre, so a long walk with nothing on it still counts for
  /// something. A five-kilometre morning is worth about a place.
  static const int xpPerKilometer = 10;

  /// XP for a player who has been to [places], walked into [districts] and
  /// covered [meters] in total.
  static int xpFor({
    required int places,
    required int districts,
    required double meters,
  }) =>
      places * xpPerPlace +
      districts * xpPerDistrict +
      (meters / 1000).floor() * xpPerKilometer;

  /// The first level costs [levelStepXp]; each one after costs a little more.
  ///
  /// Linear growth rather than exponential: this is a walking game, and the
  /// levels have to stay reachable by walking. At this rate level 10 is about
  /// forty-five thousand XP — a season of real mornings, not a grind.
  static const int levelStepXp = 1000;

  /// The level [xp] buys. One-based: nobody is level zero.
  static int levelFor(int xp) {
    if (xp < levelStepXp) return 1;
    // n levels cost levelStep · n(n+1)/2, inverted and floored.
    final solved = (math.sqrt(1 + 8 * xp / levelStepXp) - 1) / 2;
    return solved.floor() + 1;
  }

  /// Total XP needed to reach [level].
  static int xpForLevel(int level) =>
      levelStepXp * (level - 1) * level ~/ 2;

  /// How far into the current level [xp] sits, 0..1. What a progress bar under
  /// the level line would draw.
  static double levelProgress(int xp) {
    final level = levelFor(xp);
    final start = xpForLevel(level);
    final next = xpForLevel(level + 1);
    if (next <= start) return 0;
    return ((xp - start) / (next - start)).clamp(0.0, 1.0);
  }
}
