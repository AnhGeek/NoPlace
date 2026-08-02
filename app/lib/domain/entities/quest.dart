import 'package:equatable/equatable.dart';

/// Something to do next. Quests are the only part of the game that tells the
/// player where to go, so each one names a concrete target.
sealed class Quest extends Equatable {
  const Quest({
    required this.id,
    required this.xpReward,
    this.isLocked = false,
  });

  final String id;
  final int xpReward;
  final bool isLocked;

  /// 0..1 completion, for the quests that have measurable progress.
  double get progress;

  bool get isComplete => progress >= 1;

  @override
  List<Object?> get props => [id, xpReward, isLocked];
}

/// "Reveal the unknown site" — walk into the radius of an unidentified place.
final class RevealSiteQuest extends Quest {
  const RevealSiteQuest({
    required super.id,
    required super.xpReward,
    required this.distanceMeters,
    required this.districtName,
  });

  final double distanceMeters;
  final String districtName;

  @override
  double get progress => 0;

  @override
  List<Object?> get props => [...super.props, distanceMeters, districtName];
}

/// "Walk 5 km today".
final class WalkDistanceQuest extends Quest {
  const WalkDistanceQuest({
    required super.id,
    required super.xpReward,
    required this.targetMeters,
    required this.doneMeters,
  });

  final double targetMeters;
  final double doneMeters;

  @override
  double get progress => (doneMeters / targetMeters).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [...super.props, targetMeters, doneMeters];
}

/// "Enter a new district" — the quest that grows the map the fastest.
final class EnterDistrictQuest extends Quest {
  const EnterDistrictQuest({
    required super.id,
    required super.xpReward,
    required this.nearestDistrictName,
    required this.distanceMeters,
  });

  final String nearestDistrictName;
  final double distanceMeters;

  @override
  double get progress => 0;

  @override
  List<Object?> get props => [
    ...super.props,
    nearestDistrictName,
    distanceMeters,
  ];
}

/// Which teaser a [LockedQuest] shows. An enum rather than a name string so the
/// title stays translatable — the server sends the kind, we own the words.
enum LockedQuestTeaser { nightWanderer }

/// A quest the player cannot start yet. Shown on purpose: knowing what is
/// coming is part of the pull.
final class LockedQuest extends Quest {
  const LockedQuest({
    required super.id,
    required this.teaser,
    required this.unlockLevel,
    super.xpReward = 0,
  }) : super(isLocked: true);

  final LockedQuestTeaser teaser;
  final int unlockLevel;

  @override
  double get progress => 0;

  @override
  List<Object?> get props => [...super.props, teaser, unlockLevel];
}

/// The highlighted goal at the top of the quest list. One per week, worth more
/// than everything else on the screen combined.
class WeeklyChallenge extends Equatable {
  const WeeklyChallenge({
    required this.target,
    required this.done,
    required this.xpReward,
  });

  final int target;
  final int done;
  final int xpReward;

  double get progress => target == 0 ? 0 : (done / target).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [target, done, xpReward];
}
