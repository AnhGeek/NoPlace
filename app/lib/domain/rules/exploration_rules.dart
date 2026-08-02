/// Game rules that both the data layer and the UI have to agree on.
///
/// They live in the domain so there is exactly one number: if the UI offered a
/// place the rules would then reject, the player would meet an error they did
/// nothing to deserve.
abstract final class ExplorationRules {
  const ExplorationRules._();

  /// How close the player must be to claim a place.
  ///
  /// Generous on purpose: urban GPS routinely drifts 30–50 m, and refusing a
  /// legitimate check-in is far more damaging than accepting a slightly
  /// optimistic one.
  static const double checkInRadiusMeters = 200;

  /// How far around the player we look for things worth showing.
  static const double nearbyRadiusMeters = 500;

  /// First visits pay double.
  static const int firstVisitMultiplier = 2;

  /// Flat award for stepping into a district for the first time.
  static const int districtDiscoveryXp = 100;

  /// How much ground a single position fix uncovers.
  ///
  /// Two or three blocks — roughly what you can actually take in from a street
  /// corner. Tuned on a device, not on paper: at 70 m the clearing was a
  /// pinprick at city zoom and walking felt unrewarding; past ~250 m the city
  /// falls open faster than you can earn it.
  static const double fogClearingRadiusMeters = 180;

  /// The live circle around the player, which reads as "what I can see right
  /// now" rather than "where I have been". Slightly wider than the trail so the
  /// player always sits in open ground.
  static const double playerVisibilityRadiusMeters =
      fogClearingRadiusMeters * 1.2;

  /// How finely positions are recorded, by default.
  ///
  /// A metre is the finest that means anything: consumer GPS is not accurate to
  /// better than a few metres, so a finer grid would only be recording noise.
  static const double defaultRecordingPrecisionMeters = 1;
}
