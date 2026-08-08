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
  /// [AutoCheckIn.daily] does not mean a day of standing there — see
  /// [_arrived].
  static PlaceVisit? advance(
    PlaceVisit visit, {
    required double distanceMeters,
    required Duration every,
    required DateTime now,
  }) {
    if (!AutoCheckIn.isOn(every)) return null;
    if (distanceMeters > presenceRadiusMeters) return null;
    if (every == AutoCheckIn.daily) return _arrived(visit, now: now);

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

  /// [AutoCheckIn.daily], which counts arriving rather than staying.
  ///
  /// The player is inside the radius; that is the whole condition. Turning up is
  /// the visit, so the check-in lands on the first fix rather than a day later,
  /// and then nothing more is collected here until midnight.
  ///
  /// Calendar days, not a rolling twenty-four hours, because the promise the
  /// setting makes is "once a day" and a rolling window quietly breaks it: a
  /// commute that arrives a few minutes earlier each morning would skip a day
  /// roughly once a week, which reads as the feature failing rather than as a
  /// rule being kept.
  ///
  /// [PlaceVisit.lastCheckInAt] is what the day is measured against, and it is
  /// set by tapping the button too. That is deliberate — somebody who checked in
  /// by hand this morning has already got their line for today, and a second one
  /// an hour later would be the app counting the same arrival twice.
  ///
  /// Deliberately does not touch [PlaceVisit.claimedAt]: turning up unattended
  /// is not the deliberate first visit that spends the bonus. Same reason as
  /// [advance] — see [PlaceVisit.claimedAt].
  static PlaceVisit? _arrived(PlaceVisit visit, {required DateTime now}) {
    final lastCheckInAt = visit.lastCheckInAt;
    if (lastCheckInAt == null || !_isSameDay(lastCheckInAt, now)) {
      return visit.copyWith(
        checkInCount: visit.checkInCount + 1,
        lastCheckInAt: now,
        stayStartedAt: now,
        stayLastSeenAt: now,
      );
    }

    // Already counted today. The stay is still kept, by the same rules as
    // everywhere else, so that switching this place to an interval later in the
    // day finds a live stay rather than starting one from scratch — a stay that
    // [intervalChanged] then rewinds to the moment of the switch, because what
    // is worth keeping here is the sighting, not the hours behind it.
    final startedAt = visit.stayStartedAt;
    final seenAt = visit.stayLastSeenAt;
    if (startedAt == null ||
        seenAt == null ||
        now.isBefore(seenAt) ||
        now.difference(seenAt) > presenceGap) {
      return visit.copyWith(stayStartedAt: now, stayLastSeenAt: now);
    }
    if (now.difference(seenAt) >= heartbeat) {
      return visit.copyWith(stayLastSeenAt: now);
    }

    return null;
  }

  /// Whether two moments fall on the same day, in the phone's own timezone —
  /// which is the one the player is standing in, and the only one in which
  /// "until the end of the day" means anything to them.
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  /// The player changed how often this place pays out.
  ///
  /// Restarts the wait without touching the counts, so the first check-in on
  /// the new interval is a whole one, measured from the moment they picked it.
  ///
  /// Without this, the stay already in progress is re-read under the new rule
  /// and pays for time spent under the old one. [AutoCheckIn.daily] is where it
  /// bites: that mode keeps a stay running from the moment the player arrived —
  /// see [_arrived] — so a place they have been sitting in since eight, moved to
  /// hourly at twenty to eleven, would hand over two check-ins on the next fix
  /// and eleven if the place was their home and the stay began after midnight.
  /// An interval is a promise about waiting, and the wait has to start when the
  /// player says so.
  ///
  /// [PlaceVisit.stayLastSeenAt] is deliberately left where it is: whether the
  /// player is still standing here is the GPS's business, not the picker's, and
  /// moving it would vouch for a sighting nobody made.
  static PlaceVisit intervalChanged(
    PlaceVisit visit, {
    required DateTime now,
  }) => visit.copyWith(stayStartedAt: now);

  /// [intervalChanged], for a place the player saved.
  static MapPoint applyIntervalChange(MapPoint place, {required DateTime now}) =>
      place.withVisit(intervalChanged(place.visit, now: now));

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
