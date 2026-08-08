/// What counts as walking, and what counts as a day.
///
/// Separate from `ExplorationRules` because these decide the *history* — the
/// distance on the profile and the streak under it — rather than what the map
/// does with a fix. Both the live recorder and the one-off backfill of an
/// upgraded database read them, which is the point: a walk must be worth the
/// same number of metres whichever side of the upgrade it happened on.
abstract final class WalkRules {
  const WalkRules._();

  /// The furthest two consecutive fixes may be apart and still be believed as
  /// steps taken.
  ///
  /// The gap is normal: the OS puts the app to sleep in a pocket, a signal is
  /// lost between buildings, the player closes the app on the bus. Five hundred
  /// metres is about six minutes of walking — long enough that a genuine quiet
  /// patch is still credited, short enough that no drive is.
  static const double maxStepMeters = 500;

  /// And the longest it may take.
  ///
  /// Distance alone cannot tell four hundred metres of walking from four
  /// hundred metres of the same journey by car; the clock can. Together the two
  /// are the honest test: it was walking if it was near enough *and* slow
  /// enough.
  static const Duration maxStepGap = Duration(minutes: 10);

  /// Whether a move from one fix to the next was walked, and so counts.
  static bool countsAsWalking(double meters, Duration elapsed) =>
      meters <= maxStepMeters && elapsed <= maxStepGap && !elapsed.isNegative;

  /// The calendar day [at] falls in, as `YYYY-MM-DD`.
  ///
  /// Local, deliberately. A streak is about the days somebody went outside, and
  /// nobody's evening walk belongs to tomorrow because UTC says so.
  static String dayOf(DateTime at) {
    final local = at.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  /// The day before [day], which must be a [dayOf] string.
  static String dayBefore(String day) {
    final parts = day.split('-').map(int.parse).toList();
    return dayOf(
      DateTime(parts[0], parts[1], parts[2]).subtract(const Duration(days: 1)),
    );
  }

  /// How many days in a row up to today the player has walked.
  ///
  /// Today not being in [days] does not break the streak — the day is not over.
  /// Yesterday missing does: that is a day that ended with nobody going out.
  static int streakOf(Set<String> days, {required DateTime now}) {
    var cursor = dayOf(now);
    if (!days.contains(cursor)) {
      cursor = dayBefore(cursor);
      if (!days.contains(cursor)) return 0;
    }

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = dayBefore(cursor);
    }
    return streak;
  }
}
