import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/domain/entities/geo_point.dart';

void main() {
  group('GeoPoint.distanceTo', () {
    test('is zero for the same point', () {
      const point = GeoPoint(10.7725, 106.6980);
      expect(point.distanceTo(point), 0);
    });

    test('measures a short city hop within a metre', () {
      // ~40 m due north of the seed position — the distance the nearby card
      // reports for Chợ Bến Thành.
      const from = GeoPoint(10.7725, 106.6980);
      const to = GeoPoint(10.77286, 106.69800);

      expect(from.distanceTo(to), closeTo(40, 1));
    });

    test('is symmetric', () {
      const a = GeoPoint(10.7725, 106.6980);
      const b = GeoPoint(10.8039, 106.7077);

      expect(a.distanceTo(b), closeTo(b.distanceTo(a), 0.001));
    });

    test('measures a cross-city distance in kilometres', () {
      const benThanh = GeoPoint(10.7725, 106.6980);
      const binhThanh = GeoPoint(10.8039, 106.7077);

      expect(benThanh.distanceTo(binhThanh), closeTo(3630, 60));
    });
  });
}
