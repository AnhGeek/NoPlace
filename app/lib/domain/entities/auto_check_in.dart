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

  static const Duration halfHourly = Duration(minutes: 30);
  static const Duration hourly = Duration(hours: 1);
  static const Duration twoHourly = Duration(hours: 2);

  /// What a place gets when nobody has chosen.
  ///
  /// An hour: long enough that waiting for a bus does not count, short enough
  /// that a morning's work counts more than once. It is a guess made at a desk
  /// — see ADR 0011 — which is exactly why the player can now change it.
  static const Duration defaultInterval = hourly;

  /// The choices the place sheet offers, in the order it shows them.
  static const List<Duration> all = [off, halfHourly, hourly, twoHourly];

  static bool isOn(Duration every) => every > Duration.zero;

  /// Reads a stored value back.
  ///
  /// Anything unrecognised — a missing column, a hand-edited row, a value from
  /// a build that offered an interval this one does not — falls back to the
  /// default rather than silently switching the feature off. A place that
  /// quietly stops counting is the harder failure to notice.
  static Duration fromMinutes(Object? minutes) {
    if (minutes is! int || minutes < 0) return defaultInterval;
    if (minutes == 0) return off;
    return Duration(minutes: minutes);
  }

  static int toMinutes(Duration every) => every.inMinutes;
}
