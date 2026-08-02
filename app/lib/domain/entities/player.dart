import 'package:equatable/equatable.dart';

/// The person holding the phone, as far as the game is concerned.
class Player extends Equatable {
  const Player({
    required this.id,
    required this.displayName,
    required this.level,
    required this.xp,
    required this.currentCityId,
    this.chartedFraction = 0,
    this.distanceTodayMeters = 0,
    this.checkInPlaces = 0,
    this.streakDays = 0,
    this.cityRank = 0,
    this.cityExplorers = 0,
    this.rankTrendPercent = 0,
  });

  final String id;
  final String displayName;
  final int level;
  final int xp;
  final String currentCityId;

  /// Share of the current city uncovered, 0..1.
  final double chartedFraction;

  final double distanceTodayMeters;
  final int checkInPlaces;
  final int streakDays;

  /// Position on the city leaderboard, 1-based. Zero while unranked.
  final int cityRank;
  final int cityExplorers;

  /// How much the player climbed this week, in percent.
  final int rankTrendPercent;

  bool get isRanked => cityRank > 0 && cityExplorers > 0;

  Player copyWith({
    int? level,
    int? xp,
    double? chartedFraction,
    double? distanceTodayMeters,
    int? checkInPlaces,
    int? streakDays,
  }) => Player(
    id: id,
    displayName: displayName,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    currentCityId: currentCityId,
    chartedFraction: chartedFraction ?? this.chartedFraction,
    distanceTodayMeters: distanceTodayMeters ?? this.distanceTodayMeters,
    checkInPlaces: checkInPlaces ?? this.checkInPlaces,
    streakDays: streakDays ?? this.streakDays,
    cityRank: cityRank,
    cityExplorers: cityExplorers,
    rankTrendPercent: rankTrendPercent,
  );

  @override
  List<Object?> get props => [
    id,
    displayName,
    level,
    xp,
    currentCityId,
    chartedFraction,
    distanceTodayMeters,
    checkInPlaces,
    streakDays,
    cityRank,
    cityExplorers,
    rankTrendPercent,
  ];
}
