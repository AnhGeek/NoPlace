import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/data/local/district_boundaries.dart';
import 'package:noplace/domain/entities/geo_point.dart';

void main() {
  /// A square kilometre-ish block, as the cooker writes one.
  String fileWith(List<Map<String, Object?>> districts) => jsonEncode({
    'format_version': 1,
    'region_id': 'vn-test',
    'districts': districts,
  });

  Map<String, Object?> square({
    required String id,
    required String name,
    required double lat,
    required double lng,
    double size = 0.01,
  }) => {
    'id': id,
    'name': name,
    'center': [lat + size / 2, lng + size / 2],
    'bbox': [lat, lng, lat + size, lng + size],
    'area_m2': 1230000,
    'ring': [
      lat, lng, //
      lat + size, lng,
      lat + size, lng + size,
      lat, lng + size,
      lat, lng,
    ],
  };

  group('reading a district file', () {
    test('a point inside a district finds it', () {
      final boundaries = DistrictBoundaries.parse(
        'vn-test',
        fileWith([
          square(id: 'a', name: 'Phường A', lat: 10.77, lng: 106.69),
          square(id: 'b', name: 'Phường B', lat: 10.79, lng: 106.69),
        ]),
      );

      expect(boundaries.districts, hasLength(2));
      expect(boundaries.at(const GeoPoint(10.775, 106.695))?.name, 'Phường A');
      expect(boundaries.at(const GeoPoint(10.795, 106.695))?.name, 'Phường B');
    });

    test('a point in none of them is null, not the nearest one', () {
      // The cooked file covers a bounding box, and a box drawn around a
      // province contains sea and the province next door. Guessing there would
      // credit somebody's walk to a ward they were nowhere near.
      final boundaries = DistrictBoundaries.parse(
        'vn-test',
        fileWith([square(id: 'a', name: 'Phường A', lat: 10.77, lng: 106.69)]),
      );

      expect(boundaries.at(const GeoPoint(10.90, 106.99)), isNull);
    });

    test('a file from a newer cooker is refused rather than guessed at', () {
      final boundaries = DistrictBoundaries.parse(
        'vn-test',
        jsonEncode({'format_version': 99, 'districts': <Object?>[]}),
      );

      expect(boundaries.isEmpty, isTrue);
    });

    test('a malformed district is dropped and the rest survive', () {
      final boundaries = DistrictBoundaries.parse(
        'vn-test',
        fileWith([
          {'id': 'broken', 'name': 'No shape at all'},
          square(id: 'a', name: 'Phường A', lat: 10.77, lng: 106.69),
        ]),
      );

      expect(boundaries.districts, hasLength(1));
      expect(boundaries.districts.single.name, 'Phường A');
    });
  });

  group('the cooked asset', () {
    // Reads the committed file directly rather than through the asset bundle,
    // which is not mounted in a plain test. The point is the *data*: a file
    // that parsed but put Chợ Bến Thành in the wrong ward would sail past every
    // test above.
    final file = File('assets/districts/vn-hcmc.json');

    test('puts Ho Chi Minh City landmarks in the right districts', () {
      if (!file.existsSync()) {
        markTestSkipped('vn-hcmc.json has not been cooked in this checkout');
        return;
      }

      final boundaries = DistrictBoundaries.parse(
        'vn-hcmc',
        file.readAsStringSync(),
      );

      expect(boundaries.districts.length, greaterThan(100));
      expect(
        boundaries.at(const GeoPoint(10.77286, 106.69800))?.name,
        contains('Bến Thành'),
      );
      expect(
        boundaries.at(const GeoPoint(10.83792, 106.67133))?.name,
        contains('Gò Vấp'),
      );
    });

    test('gives every district a name, a shape and an area', () {
      if (!file.existsSync()) {
        markTestSkipped('vn-hcmc.json has not been cooked in this checkout');
        return;
      }

      final boundaries = DistrictBoundaries.parse(
        'vn-hcmc',
        file.readAsStringSync(),
      );

      for (final district in boundaries.districts) {
        expect(district.name, isNotEmpty);
        expect(district.areaSquareMeters, greaterThan(0));
        // Closed, and a ring is at least a triangle.
        expect(district.ring.length, greaterThanOrEqualTo(8));
        expect(district.ring.first, district.ring[district.ring.length - 2]);
      }
    });
  });
}
