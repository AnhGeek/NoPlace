import 'package:equatable/equatable.dart';

import 'walk_history.dart';

/// One district and how much of it the player has uncovered.
///
/// Not [District]: that one is world data with an id, a city and a discovery
/// date, and is what the seeded world hands the logs and the discovery screen.
/// This is a *measurement* — a name from the boundary file and a number worked
/// out from the trail on this phone.
class DistrictProgress extends Equatable {
  const DistrictProgress({
    required this.id,
    required this.name,
    required this.chartedFraction,
    required this.chartedSquareMeters,
    required this.areaSquareMeters,
  });

  final String id;
  final String name;

  /// 0..1, and 1 means the fog is off all of it.
  final double chartedFraction;

  final double chartedSquareMeters;
  final double areaSquareMeters;

  @override
  List<Object?> get props => [
    id,
    name,
    chartedFraction,
    chartedSquareMeters,
    areaSquareMeters,
  ];
}

/// The profile screen's whole subject: who the player is and what the walking
/// has come to.
///
/// Assembled in `repository_providers.dart` out of the device's own record —
/// the trail, the points, the visits, the boundary file for the region being
/// walked. Nothing on it is seeded and nothing comes from a server, which is
/// also why [cityRank] does not exist here: there is no leaderboard to be on,
/// and the card says so rather than inventing a position.
class ExplorerProfile extends Equatable {
  const ExplorerProfile({
    required this.regionId,
    required this.regionName,
    this.displayName = '',
    this.avatarPath,
    this.level = 1,
    this.xp = 0,
    this.chartedSquareMeters = 0,
    this.walk = const WalkHistory.empty(),
    this.checkInPlaces = 0,
    this.districts = const [],
    this.districtsKnown = 0,
  });

  /// The map being walked, which is what all the district numbers are about.
  final String regionId;
  final String regionName;

  /// Empty until the player names themselves; the screen shows its own
  /// translated placeholder rather than storing one.
  final String displayName;

  final String? avatarPath;

  final int level;
  final int xp;

  /// Ground uncovered in this region, in square metres. The headline number —
  /// it is the fog that has actually come off the map.
  final double chartedSquareMeters;

  final WalkHistory walk;

  /// How many distinct places the player has checked into, their own points and
  /// the world's alike.
  final int checkInPlaces;

  /// Districts with any ground charted, most walked first.
  final List<DistrictProgress> districts;

  /// How many districts the region has at all. Zero when this region has no
  /// boundary file, which the card says plainly.
  final int districtsKnown;

  int get districtsCharted => districts.length;

  bool get hasDistrictData => districtsKnown > 0;

  double get chartedSquareKilometers => chartedSquareMeters / 1000000;

  @override
  List<Object?> get props => [
    regionId,
    regionName,
    displayName,
    avatarPath,
    level,
    xp,
    chartedSquareMeters,
    walk,
    checkInPlaces,
    districts,
    districtsKnown,
  ];
}
