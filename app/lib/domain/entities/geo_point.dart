import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A WGS-84 coordinate.
///
/// The domain layer deliberately does not use the map package's `LatLng`: the
/// map is a rendering choice (see docs/adr/0003-map-rendering.md) and swapping
/// it must not ripple through the model.
class GeoPoint extends Equatable {
  const GeoPoint(this.latitude, this.longitude)
    : assert(latitude >= -90 && latitude <= 90, 'latitude out of range'),
      assert(longitude >= -180 && longitude <= 180, 'longitude out of range');

  final double latitude;
  final double longitude;

  static const double _earthRadiusMeters = 6371000;

  /// Great-circle distance in metres.
  ///
  /// Haversine is accurate to a few metres at city scale, which is well inside
  /// the GPS error we have to tolerate anyway.
  double distanceTo(GeoPoint other) {
    final dLat = _toRadians(other.latitude - latitude);
    final dLon = _toRadians(other.longitude - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(latitude)) *
            math.cos(_toRadians(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(a)));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  @override
  List<Object?> get props => [latitude, longitude];

  @override
  String toString() =>
      'GeoPoint(${latitude.toStringAsFixed(5)}, '
      '${longitude.toStringAsFixed(5)})';
}
