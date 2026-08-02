import 'package:equatable/equatable.dart';

import 'geo_point.dart';

/// What kind of place this is. Drives the pin colour and icon, and nothing
/// else — rewards are a property of the place, not of its category.
enum PlaceCategory { food, cafe, landmark, park, market, unknown }

/// A spot on the map the player can check in to.
class Place extends Equatable {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.districtId,
    this.xpReward = 50,
    this.visited = false,
    this.explorersHere = 0,
  });

  final String id;

  /// Empty for an unidentified site: the UI shows "Unknown site" instead, and
  /// the name arrives when the player gets close enough to reveal it.
  final String name;

  final PlaceCategory category;
  final GeoPoint location;
  final String districtId;
  final int xpReward;
  final bool visited;

  /// How many other explorers are checked in right now. Social proof on the
  /// check-in sheet; zero means we simply hide the tile.
  final int explorersHere;

  bool get isIdentified => category != PlaceCategory.unknown;

  Place copyWith({bool? visited, int? explorersHere}) => Place(
    id: id,
    name: name,
    category: category,
    location: location,
    districtId: districtId,
    xpReward: xpReward,
    visited: visited ?? this.visited,
    explorersHere: explorersHere ?? this.explorersHere,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    location,
    districtId,
    xpReward,
    visited,
    explorersHere,
  ];
}
