import '../entities/auto_check_in.dart';
import '../entities/geo_point.dart';
import '../entities/map_point.dart';
import '../entities/place_visit.dart';

/// When being somewhere counts as having been there.
///
/// A place has two ways of collecting a check-in: the player taps the button,
/// or they simply stay. An hour at the same coffee shop *is* a visit, and asking
/// somebody to confirm it turns a diary into a chore.
///
/// A class rather than three constants in `ExplorationRules` because the rule is
/// no longer "a constant and a comparison": it has to survive a phone that
/// sleeps, a GPS that drifts, and a stay that spans a restart. All of that lives
/// here, as pure functions over a [PlaceVisit], so it can be tested by moving a
/// clock instead of by walking around a city for three hours.
///
/// It works on [PlaceVisit] rather than on `MapPoint` so that one rule serves
/// both kinds of place — the ones the player saved and the ones the world came
/// with. [applyFix] is the `MapPoint` shaped door onto the same function.
abstract final class PlaceVisitRules {
  const PlaceVisitRules._();

  /// How close counts as "at" a place.
  ///
  /// Tighter than `ExplorationRules.checkInRadiusMeters`, which is generous
  /// because refusing a deliberate tap is worse than accepting an optimistic
  /// one. This radius is spent *unattended*, so the same generosity would hand
  /// out check-ins for the café across the street from the office.
  static const double presenceRadiusMeters = 150;

  /// How long a stay has to last to be worth a check-in, when nobody has chosen
  /// otherwise. The player picks per place — see [AutoCheckIn].
  static const Duration dwellCheckIn = AutoCheckIn.defaultInterval;

  /// How long without a sighting inside the radius before the stay is treated
  /// as over.
  ///
  /// This, and not "the player left the radius", is what ends a stay. A single
  /// drifting fix routinely lands 100 m away and would otherwise wipe out fifty
  /// minutes of sitting still; a genuine departure ends the stay just as surely,
  /// only twenty minutes later. Erring towards the player is the right way round
  /// — this is their own diary, and it costs nobody anything.
  ///
  /// It is also the guard against the worst failure this rule has: an app that
  /// was killed at the office on Friday must not pay out the weekend when it is
  /// opened there again on Monday. A stay is only ever as long as the sightings
  /// that vouch for it.
  static const Duration presenceGap = Duration(minutes: 20);

  /// How often a stay is confirmed and written back to the database.
  ///
  /// The caller ticks on this too, rather than relying on position fixes: a
  /// phone lying on a table stops producing them, and a stay measured only in
  /// fixes would go cold exactly when it was most real. Comfortably inside
  /// [presenceGap], so a live stay can miss a tick and survive.
  static const Duration heartbeat = Duration(minutes: 5);

  /// What a position fix does to [visit], or null when nothing worth storing
  /// changed — which is the overwhelmingly common case.
  ///
  /// Only fixes *inside* the radius are considered. Walking away writes
  /// nothing: [presenceGap] already decides when the stay ended, and a "you
  /// left" write would fire on every GPS wobble.
  ///
  /// [every] is how long a stay must run to be worth a check-in. At
  /// [AutoCheckIn.off] the whole thing is skipped: a place the player has told
  /// us not to watch should not be costing them database writes either.
  static PlaceVisit? advance(
    PlaceVisit visit, {
    required double distanceMeters,
    required Duration every,
    required DateTime now,
  }) {
    if (!AutoCheckIn.isOn(every)) return null;
    if (distanceMeters > presenceRadiusMeters) return null;

    final startedAt = visit.stayStartedAt;
    final seenAt = visit.stayLastSeenAt;

    // No stay in progress, one that has gone cold, or a clock that has moved
    // backwards (a timezone change, an NTP correction): this fix starts a new
    // one. Nothing is awarded yet — arriving is not a visit.
    if (startedAt == null ||
        seenAt == null ||
        now.isBefore(seenAt) ||
        now.difference(seenAt) > presenceGap) {
      return visit.copyWith(stayStartedAt: now, stayLastSeenAt: now);
    }

    final earned = now.difference(startedAt).inMinutes ~/ every.inMinutes;
    if (earned >= 1) {
      return visit.copyWith(
        checkInCount: visit.checkInCount + earned,
        lastCheckInAt: now,
        // Advanced by exactly what was paid out rather than reset to `now`, so
        // the minutes past the hour are not thrown away — four hours on the
        // spot is four check-ins whether the fixes were dense or sparse.
        stayStartedAt: startedAt.add(every * earned),
        stayLastSeenAt: now,
      );
    }

    if (now.difference(seenAt) >= heartbeat) {
      return visit.copyWith(stayLastSeenAt: now);
    }

    return null;
  }

  /// [advance], for a place the player saved. Null when nothing changed.
  static MapPoint? applyFix(
    MapPoint place, {
    required GeoPoint position,
    required DateTime now,
  }) {
    final advanced = advance(
      place.visit,
      distanceMeters: position.distanceTo(place.location),
      every: place.autoCheckInEvery,
      now: now,
    );
    return advanced == null ? null : place.withVisit(advanced);
  }

  /// The player said they are here.
  ///
  /// Restarts the stay: an hour that began before they tapped has been claimed,
  /// and paying it out again a minute later would look like double counting
  /// because it would be.
  ///
  /// This is the only path that sets [PlaceVisit.claimedAt] — see there for why
  /// an hour spent nearby deliberately does not.
  static PlaceVisit visited(PlaceVisit visit, {required DateTime now}) =>
      visit.copyWith(
        checkInCount: visit.checkInCount + 1,
        lastCheckInAt: now,
        claimedAt: visit.claimedAt ?? now,
        stayStartedAt: now,
        stayLastSeenAt: now,
      );

  /// [visited], for a place the player saved.
  static MapPoint checkIn(MapPoint place, {required DateTime now}) =>
      place.withVisit(visited(place.visit, now: now));
}
