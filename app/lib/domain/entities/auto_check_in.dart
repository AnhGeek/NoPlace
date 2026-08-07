/// How often standing at a place, unattended, turns into a check-in.
///
/// A `Duration` rather than an enum because the number is the whole meaning of
/// the setting, and the rule that spends it — `PlaceVisitRules` — wants to do
/// arithmetic with it, not translate a name back into one.
///
/// Lives in its own file so both `MapPoint` (which stores the choice) and
/// `PlaceVisitRules` (which acts on it) can reach it without importing each
/// other.
abstract final class AutoCheckIn {
  const AutoCheckIn._();

  /// Nothing accrues. Only tapping the button counts as a visit.
  ///
  /// Zero rather than `null` so that the field can stay non-nullable: a
  /// `copyWith` built on `??` cannot put a null back, and "Off" has to be as
  /// settable as any other choice or the picker is a one-way door.
  static const Duration off = Duration.zero;

  static const Duration hourly = Duration(hours: 1);
  static const Duration twoHourly = Duration(hours: 2);

  /// Once a day, on arrival — the one option that is not a waiting time.
  ///
  /// The others ask the player to stay put and pay out per interval spent. This
  /// one counts the moment they turn up and then goes quiet until midnight, so a
  /// place they pass through daily still gets a line a day without their having
  /// to linger for one. `PlaceVisitRules.advance` special-cases it; the duration
  /// is a name for "a calendar day", not an amount of time anyone has to spend.
  ///
  /// A day rather than a rolling 24 hours because "again tomorrow" is what the
  /// setting promises, and a player who arrives at nine on Monday should not be
  /// refused at eight on Tuesday for being an hour early.
  static const Duration daily = Duration(days: 1);

  /// What a place gets when nobody has chosen.
  ///
  /// An hour: long enough that waiting for a bus does not count, short enough
  /// that a morning's work counts more than once. It is a guess made at a desk
  /// — see ADR 0011 — which is exactly why the player can now change it.
  static const Duration defaultInterval = hourly;

  /// The choices the place sheet offers, in the order it shows them.
  ///
  /// Four, because that is what fits on one line of a segmented control — so
  /// adding [daily] meant dropping half-hourly, and that was the one to drop.
  /// Half an hour is barely longer than the twenty minutes it takes to decide a
  /// stay has ended, which made it the interval most likely to turn a long lunch
  /// into a handful of identical entries.
  static const List<Duration> all = [off, hourly, twoHourly, daily];

  static bool isOn(Duration every) => every > Duration.zero;

  /// Reads a stored value back.
  ///
  /// Anything unrecognised — a missing column, a hand-edited row, a value from
  /// a build that offered an interval this one does not — falls back to the
  /// default rather than silently switching the feature off. A place that
  /// quietly stops counting is the harder failure to notice.
  ///
  /// That last case is a live one rather than a hypothetical: every place set to
  /// half-hourly before [all] dropped it reads back as hourly here. Better than
  /// honouring a number the picker can no longer show, which would leave the
  /// player looking at "1 hour" while the place kept paying out twice as often.
  static Duration fromMinutes(Object? minutes) {
    if (minutes is! int || minutes < 0) return defaultInterval;
    if (minutes == 0) return off;
    final stored = Duration(minutes: minutes);
    return all.contains(stored) ? stored : defaultInterval;
  }

  static int toMinutes(Duration every) => every.inMinutes;
}
