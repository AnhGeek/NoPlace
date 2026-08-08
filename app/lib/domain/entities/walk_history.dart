import 'package:equatable/equatable.dart';

/// What the walking adds up to: today, and the run of days behind it.
///
/// Deliberately three numbers and not a log. "4.2 km today, six days in a row"
/// is the sentence the profile is trying to say; a walk-by-walk history is a
/// different feature and is not owed by this one.
class WalkHistory extends Equatable {
  const WalkHistory({
    this.distanceTodayMeters = 0,
    this.distanceTotalMeters = 0,
    this.streakDays = 0,
    this.daysWalked = 0,
  });

  const WalkHistory.empty() : this();

  /// Metres covered since midnight, local time.
  final double distanceTodayMeters;

  /// Metres covered since the app was installed — or since the trail was
  /// restored from a backup, which is the same walk on another phone.
  final double distanceTotalMeters;

  /// Days in a row, counting back from today. Today missing does not break it;
  /// the day is not over. See `WalkRules.streakOf`.
  final int streakDays;

  /// How many days the player went out at all, ever.
  final int daysWalked;

  @override
  List<Object?> get props => [
    distanceTodayMeters,
    distanceTotalMeters,
    streakDays,
    daysWalked,
  ];
}
