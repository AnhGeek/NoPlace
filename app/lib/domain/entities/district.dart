import 'package:equatable/equatable.dart';

import 'geo_point.dart';

/// An administrative area of a city. Districts are the unit of progression:
/// entering one for the first time is the big reward moment.
class District extends Equatable {
  const District({
    required this.id,
    required this.cityId,
    required this.name,
    required this.index,
    required this.center,
    this.chartedFraction = 0,
    this.firstEnteredAt,
  }) : assert(
         chartedFraction >= 0 && chartedFraction <= 1,
         'chartedFraction is a 0..1 fraction',
       );

  final String id;
  final String cityId;

  /// Empty while undiscovered — the UI renders "???" rather than the real name.
  final String name;

  /// 1-based position in the city, used for "District 3 of 12".
  final int index;

  final GeoPoint center;

  /// How much of the district the player has uncovered, 0..1.
  final double chartedFraction;

  /// `null` until the player physically enters it.
  final DateTime? firstEnteredAt;

  bool get isDiscovered => firstEnteredAt != null;

  District copyWith({double? chartedFraction, DateTime? firstEnteredAt}) =>
      District(
        id: id,
        cityId: cityId,
        name: name,
        index: index,
        center: center,
        chartedFraction: chartedFraction ?? this.chartedFraction,
        firstEnteredAt: firstEnteredAt ?? this.firstEnteredAt,
      );

  @override
  List<Object?> get props => [
    id,
    cityId,
    name,
    index,
    center,
    chartedFraction,
    firstEnteredAt,
  ];
}

/// A city the player is exploring. One is "current" at a time; the others stay
/// on the profile as chips they can switch back to.
class City extends Equatable {
  const City({
    required this.id,
    required this.name,
    required this.center,
    required this.districtCount,
  });

  final String id;
  final String name;
  final GeoPoint center;
  final int districtCount;

  @override
  List<Object?> get props => [id, name, center, districtCount];
}
