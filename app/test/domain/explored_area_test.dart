import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/domain/entities/explored_area.dart';
import 'package:noplace/domain/entities/geo_point.dart';

void main() {
  const benThanh = GeoPoint(10.7725, 106.6980);

  group('TrailCell', () {
    test('quantises sub-metre jitter onto the same cell', () {
      // Two fixes about 10 cm apart — the GPS wobbling while standing still.
      const a = GeoPoint(10.7725, 106.6980);
      const b = GeoPoint(10.77250090, 106.69800090);

      expect(TrailCell.of(a), TrailCell.of(b));
    });

    test('separates points a few metres apart', () {
      const a = GeoPoint(10.7725, 106.6980);
      // ~3 m north: a different square metre, and a different cell.
      const b = GeoPoint(10.77252695, 106.6980);

      expect(TrailCell.of(a), isNot(TrailCell.of(b)));
    });

    test('cell centres round-trip back to the same cell', () {
      final cell = TrailCell.of(benThanh);
      expect(TrailCell.of(cell.center), cell);
    });
  });

  group('ExploredArea', () {
    test('starts empty', () {
      expect(const ExploredArea.empty().isEmpty, isTrue);
      expect(const ExploredArea.empty().contains(benThanh), isFalse);
    });

    test('recording a point records exactly where the player was', () {
      final area = const ExploredArea.empty().withPoint(benThanh);

      expect(area.contains(benThanh), isTrue);
    });

    test('re-walking the same ground adds nothing', () {
      final once = const ExploredArea.empty().withPoint(benThanh);
      final twice = once.withPoint(benThanh);

      expect(twice.count, once.count);
    });

    test('a step onto new ground is not already explored', () {
      final area = const ExploredArea.empty().withPoint(benThanh);

      // ~11 m north. The fog will still *look* open there — the clearing is
      // 180 m wide — but the trail records where the player actually was, and
      // that is what gets stored and exported.
      expect(area.contains(const GeoPoint(10.77260, 106.69800)), isFalse);
    });

    test('walking somewhere new grows the trail', () {
      final area = const ExploredArea.empty()
          .withPoint(benThanh)
          .withPoint(const GeoPoint(10.8039, 106.7077));

      expect(area.contains(const GeoPoint(10.8039, 106.7077)), isTrue);
      expect(area.contains(benThanh), isTrue);
    });

    test('one fix is one cell — the fog decides how much that uncovers', () {
      final area = const ExploredArea.empty().withPoint(benThanh);

      expect(
        area.count,
        1,
        reason: 'storing the uncovered disc would be ~100k cells per fix',
      );
    });

    test('withPoints is the same as recording each point', () {
      const points = [benThanh, GeoPoint(10.7745, 106.6995)];
      final batch = const ExploredArea.empty().withPoints(points);
      final oneByOne = const ExploredArea.empty()
          .withPoint(points[0])
          .withPoint(points[1]);

      expect(batch.cells, oneByOne.cells);
    });
  });
}
