import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/geo_point.dart';

/// The districts of one region, with their shapes.
///
/// Cooked from the OpenStreetMap administrative boundaries by
/// `tools/region_cooker/bin/districts.dart` and bundled as an asset — see that
/// file for why they do not come out of the map pack, which is where the pack
/// format says they will eventually live.
///
/// A district is `admin_level = 6`, the smallest named unit Vietnam has. Since
/// the 2025 reform that is the ward (phường) or commune (xã); before it, the
/// quận above them. Either way it is the unit a Vietnamese address names, and
/// small enough that walking one is an evening.
class DistrictBoundaries {
  const DistrictBoundaries._(this.regionId, this.districts, this._index);

  const DistrictBoundaries.empty(this.regionId)
    : districts = const [],
      _index = const {};

  final String regionId;

  final List<DistrictBoundary> districts;

  /// Grid cell → the districts whose bounding box touches it.
  ///
  /// A region is a couple of hundred polygons and the profile asks this
  /// question once per cleared cell of the map, which is thousands of times in
  /// a row. Without the index that is a quarter of a million bounding-box tests
  /// per open; with it, a handful each.
  final Map<int, List<int>> _index;

  /// The size of one index cell, in degrees. About five kilometres — a few
  /// districts across, so a bucket stays short without there being many.
  static const double _indexCellDegrees = 0.05;

  /// The format this build understands, matching the cooker's.
  static const int supportedFormatVersion = 1;

  bool get isEmpty => districts.isEmpty;

  /// Reads `assets/districts/<regionId>.json`.
  ///
  /// A region with no district file is a supported state, not a failure: the
  /// profile says so and the rest of the app does not care. That is what makes
  /// adding a city a data change.
  static Future<DistrictBoundaries> load(
    String regionId, {
    AssetBundle? bundle,
  }) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(
        'assets/districts/$regionId.json',
      );
      return parse(regionId, raw);
    } on FlutterError {
      // No asset for this region. Expected for a region we have not cooked.
      return DistrictBoundaries.empty(regionId);
    } on Object catch (error) {
      debugPrint('Districts: $regionId could not be read ($error)');
      return DistrictBoundaries.empty(regionId);
    }
  }

  @visibleForTesting
  static DistrictBoundaries parse(String regionId, String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final version = decoded['format_version'] as int? ?? 0;
    if (version > supportedFormatVersion) {
      debugPrint(
        'Districts: $regionId is format v$version, newer than this build '
        'understands (v$supportedFormatVersion)',
      );
      return DistrictBoundaries.empty(regionId);
    }

    final districts = <DistrictBoundary>[];
    for (final entry in (decoded['districts'] as List? ?? const [])) {
      final district = _boundaryOf(entry as Map<String, dynamic>);
      if (district != null) districts.add(district);
    }

    final index = <int, List<int>>{};
    for (var position = 0; position < districts.length; position++) {
      final district = districts[position];
      final minLat = (district.minLatitude / _indexCellDegrees).floor();
      final maxLat = (district.maxLatitude / _indexCellDegrees).floor();
      final minLng = (district.minLongitude / _indexCellDegrees).floor();
      final maxLng = (district.maxLongitude / _indexCellDegrees).floor();

      for (var lat = minLat; lat <= maxLat; lat++) {
        for (var lng = minLng; lng <= maxLng; lng++) {
          (index[_cellKey(lat, lng)] ??= []).add(position);
        }
      }
    }

    return DistrictBoundaries._(regionId, districts, index);
  }

  static DistrictBoundary? _boundaryOf(Map<String, dynamic> entry) {
    final ring = (entry['ring'] as List?)?.cast<num>();
    final bbox = (entry['bbox'] as List?)?.cast<num>();
    final centre = (entry['center'] as List?)?.cast<num>();
    if (ring == null || ring.length < 8 || bbox == null || centre == null) {
      return null;
    }

    return DistrictBoundary(
      id: entry['id'] as String,
      name: entry['name'] as String,
      center: GeoPoint(centre[0].toDouble(), centre[1].toDouble()),
      areaSquareMeters: (entry['area_m2'] as num).toDouble(),
      ring: Float64List.fromList([
        for (final value in ring) value.toDouble(),
      ]),
      minLatitude: bbox[0].toDouble(),
      minLongitude: bbox[1].toDouble(),
      maxLatitude: bbox[2].toDouble(),
      maxLongitude: bbox[3].toDouble(),
    );
  }

  /// The district [point] is standing in, or null where none of them is.
  ///
  /// Null is ordinary: the cooked file covers the region's bounding box, and a
  /// bounding box drawn around a province contains sea, the next province, and
  /// in one case another country.
  DistrictBoundary? at(GeoPoint point) {
    final candidates =
        _index[_cellKey(
          (point.latitude / _indexCellDegrees).floor(),
          (point.longitude / _indexCellDegrees).floor(),
        )];
    if (candidates == null) return null;

    for (final position in candidates) {
      final district = districts[position];
      if (district.contains(point)) return district;
    }
    return null;
  }

  /// Two grid coordinates in one int, so the index is a plain hash map rather
  /// than a map of maps. Latitude fits in ±3600 cells and longitude in ±7200,
  /// which leaves this comfortably inside a 64-bit int.
  static int _cellKey(int latitude, int longitude) =>
      latitude * 100000 + longitude;
}

/// One district: what it is called, how big it is, and where its edge runs.
class DistrictBoundary {
  const DistrictBoundary({
    required this.id,
    required this.name,
    required this.center,
    required this.areaSquareMeters,
    required this.ring,
    required this.minLatitude,
    required this.minLongitude,
    required this.maxLatitude,
    required this.maxLongitude,
  });

  final String id;
  final String name;
  final GeoPoint center;

  /// Precomputed by the cooker from the unsimplified shape, so the phone is not
  /// doing polygon arithmetic to answer "what fraction of this have I walked".
  final double areaSquareMeters;

  /// The outer edge, flat: `lat, lng, lat, lng…`, closed. Simplified to about
  /// eighty metres, which is the width of the block either side of the border.
  final Float64List ring;

  final double minLatitude;
  final double minLongitude;
  final double maxLatitude;
  final double maxLongitude;

  /// Ray casting, after a bounding-box rejection that answers the great
  /// majority of calls.
  bool contains(GeoPoint point) {
    final latitude = point.latitude;
    final longitude = point.longitude;

    if (latitude < minLatitude ||
        latitude > maxLatitude ||
        longitude < minLongitude ||
        longitude > maxLongitude) {
      return false;
    }

    var inside = false;
    final count = ring.length ~/ 2;
    var previous = count - 1;

    for (var current = 0; current < count; current++) {
      final currentLat = ring[current * 2];
      final currentLng = ring[current * 2 + 1];
      final previousLat = ring[previous * 2];
      final previousLng = ring[previous * 2 + 1];

      if ((currentLat > latitude) != (previousLat > latitude)) {
        final crossing =
            (previousLng - currentLng) *
                (latitude - currentLat) /
                (previousLat - currentLat) +
            currentLng;
        if (longitude < crossing) inside = !inside;
      }

      previous = current;
    }

    return inside;
  }

  /// How far [point] is from the district's centre. Used only to pick the
  /// nearest district to talk about when the player is standing outside all of
  /// them.
  double distanceFrom(GeoPoint point) => math.sqrt(
    math.pow(point.latitude - center.latitude, 2) +
        math.pow(point.longitude - center.longitude, 2),
  );
}
