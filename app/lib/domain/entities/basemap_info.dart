import 'package:equatable/equatable.dart';

import 'geo_point.dart';

/// What the app knows about the basemap it is drawing.
///
/// Deliberately in the domain: [attribution] is a licence obligation, not a
/// rendering detail. The pack states what must be credited and the app displays
/// it verbatim, which is what lets the data source change — OpenStreetMap
/// today, something else later — without the app learning anything about it.
///
/// See docs/region-pack-format.md and docs/adr/0008-openstreetmap-basemap.md.
class BasemapInfo extends Equatable {
  const BasemapInfo({
    required this.regionId,
    required this.regionName,
    required this.attribution,
    required this.minZoom,
    required this.maxZoom,
    required this.southWest,
    required this.northEast,
  });

  /// Stable region identity, e.g. `vn-hcmc`.
  final String regionId;

  final String regionName;

  /// Rendered on the map exactly as written. An empty string means the source
  /// requires no credit — a deliberate choice by whoever cooked the pack, not
  /// an omission.
  final String attribution;

  final int minZoom;
  final int maxZoom;

  final GeoPoint southWest;
  final GeoPoint northEast;

  GeoPoint get center => GeoPoint(
    (southWest.latitude + northEast.latitude) / 2,
    (southWest.longitude + northEast.longitude) / 2,
  );

  bool contains(GeoPoint point) =>
      point.latitude >= southWest.latitude &&
      point.latitude <= northEast.latitude &&
      point.longitude >= southWest.longitude &&
      point.longitude <= northEast.longitude;

  @override
  List<Object?> get props => [
    regionId,
    regionName,
    attribution,
    minZoom,
    maxZoom,
    southWest,
    northEast,
  ];
}
