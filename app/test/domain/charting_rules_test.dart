import 'package:flutter_test/flutter_test.dart';
import 'package:noplace/domain/entities/explored_area.dart';
import 'package:noplace/domain/entities/geo_point.dart';
import 'package:noplace/domain/rules/charting_rules.dart';
import 'package:noplace/domain/rules/exploration_rules.dart';

void main() {
  const radius = ExplorationRules.fogClearingRadiusMeters;
  const benThanh = GeoPoint(10.7725, 106.6980);

  group('charting cells', () {
    test('two fixes a few metres apart are one cell', () {
      const nextDoor = GeoPoint(10.77255, 106.69805);
      expect(
        ChartingRules.cellOf(benThanh, radius),
        ChartingRules.cellOf(nextDoor, radius),
      );
    });

    test('a kilometre apart is not', () {
      const acrossTown = GeoPoint(10.7815, 106.6980);
      expect(
        ChartingRules.cellOf(benThanh, radius),
        isNot(ChartingRules.cellOf(acrossTown, radius)),
      );
    });

    test('the packing survives a round trip', () {
      final cell = ChartingRules.cellOf(benThanh, radius);
      final centre = ChartingRules.centreOf(cell, radius);
      expect(ChartingRules.cellOf(centre, radius), cell);
      // And the centre it hands back is inside the clearing it stands for.
      expect(centre.distanceTo(benThanh), lessThan(radius * 2));
    });

    test('and in the western hemisphere, where longitude goes negative', () {
      // Nothing ships there yet. The packing is arithmetic, and arithmetic that
      // only works east of Greenwich is a bug waiting for the first city we add
      // that is not.
      const quito = GeoPoint(-0.1807, -78.4678);
      final cell = ChartingRules.cellOf(quito, radius);
      final centre = ChartingRules.centreOf(cell, radius);
      expect(centre.latitude, lessThan(0));
      expect(centre.longitude, lessThan(0));
      expect(ChartingRules.cellOf(centre, radius), cell);
    });
  });

  group('how much has been uncovered', () {
    test('standing still is one clearing, not a hundred thousand', () {
      // The trail records a point per metre; the fog opens one disc over all of
      // them. An area that grew with the number of fixes would make standing on
      // a corner the fastest way to chart a city.
      final area = ExploredArea({
        for (var step = 0; step < 50; step++)
          TrailCell.of(
            GeoPoint(benThanh.latitude + step * 0.000009, benThanh.longitude),
          ),
      });

      expect(ChartingRules.cellsOf(area, radius).length, 1);
    });

    test('a walk uncovers roughly what the fog draws', () {
      // A kilometre due north. What the map opens is a corridor: two radii wide
      // and a kilometre long, with a cap at each end.
      final points = <TrailCell>[];
      for (var metre = 0; metre < 1000; metre += 5) {
        points.add(
          TrailCell.of(
            GeoPoint(
              benThanh.latitude + metre * ExploredArea.cellSizeDegrees,
              benThanh.longitude,
            ),
          ),
        );
      }

      final cells = ChartingRules.cellsOf(ExploredArea(points.toSet()), radius);
      final charted = cells.length * ChartingRules.cellAreaSquareMeters(radius);
      const swept = 2 * radius * 1000 + 3.14159 * radius * radius;

      expect(charted, greaterThan(swept * 0.6));
      expect(charted, lessThan(swept * 1.4));
    });

    test('a fraction never runs past all of it', () {
      // One clearing is 130 000 m² and the smallest ward is under a square
      // kilometre, so the estimate can overshoot a small district.
      expect(ChartingRules.fractionOf(40, 500000, radius), 1.0);
    });

    test('and is zero for a place with no area', () {
      expect(ChartingRules.fractionOf(3, 0, radius), 0);
    });
  });
}
