import '../entities/explored_area.dart';
import '../entities/geo_point.dart';

/// How much of somewhere the player has actually uncovered.
///
/// The trail is a record of *where the player stood*, one metre-quantised point
/// per position fix. What the map draws is something else: a disc of
/// `FogSettings.clearingRadiusMeters` around each of those points. "Charted" is
/// the second thing — the ground the player can see — because that is what they
/// are looking at when they wonder how much of the city is left.
///
/// The exact answer is the area of a union of a hundred thousand overlapping
/// discs, which is not a thing to compute on a phone while somebody waits. This
/// is the approximation: quantise every walked point onto a grid whose cells are
/// as wide as one clearing is across, and count the cells that got one. A cell
/// is then either uncovered or not, and the sum is within a few percent of the
/// union for a walked path — which is the shape all real trails have.
///
/// It is deliberately the *same* grid for the city total and for each district,
/// so the parts add up to the whole and nobody has to explain why they do not.
abstract final class ChartingRules {
  const ChartingRules._();

  /// A cell is as wide as a clearing: twice the radius.
  ///
  /// Tuned against the honest answer rather than chosen for tidiness. A single
  /// fix uncovers πr², and one cell is 4r² — 27% generous. A kilometre of
  /// walking uncovers about 2r·1000 + πr², and the cells it lands in come to
  /// about 15% less than that. Between a lone standing start and a real walk the
  /// error changes sign, so neither is systematically flattered.
  static double cellSizeMeters(double clearingRadiusMeters) =>
      clearingRadiusMeters * 2;

  /// The area one cell stands for.
  static double cellAreaSquareMeters(double clearingRadiusMeters) {
    final size = cellSizeMeters(clearingRadiusMeters);
    return size * size;
  }

  /// One metre of latitude, in degrees. Longitude uses the same step, which at
  /// Vietnamese latitudes makes a cell about 2% narrower than it is tall — far
  /// inside the error of the approximation itself.
  static const double _metersToDegrees = ExploredArea.cellSizeDegrees;

  /// The charting cell a point falls in, as a single int.
  ///
  /// Packed rather than a pair so the caller can put millions of them in a
  /// `Set<int>` — which is exactly what counting distinct cells is.
  static int cellOf(GeoPoint point, double clearingRadiusMeters) {
    final size = cellSizeMeters(clearingRadiusMeters) * _metersToDegrees;
    final latitude = (point.latitude / size).floor();
    final longitude = (point.longitude / size).floor();
    // Longitude is bounded by ±180/size, which for any usable radius is well
    // under [_longitudeBias]; latitude carries the rest of the int. The bias is
    // what keeps the packing reversible in the western hemisphere, where the
    // longitude cell is negative and would otherwise borrow from the latitude.
    return latitude * _stride + longitude + _longitudeBias;
  }

  /// The centre of [cell], which is where it gets attributed to a district.
  static GeoPoint centreOf(int cell, double clearingRadiusMeters) {
    final size = cellSizeMeters(clearingRadiusMeters) * _metersToDegrees;
    final latitude = (cell / _stride).floor();
    final longitude = cell - latitude * _stride - _longitudeBias;
    return GeoPoint((latitude + 0.5) * size, (longitude + 0.5) * size);
  }

  static const int _stride = 10000000;
  static const int _longitudeBias = _stride ~/ 2;

  /// The distinct charting cells [area] covers.
  static Set<int> cellsOf(ExploredArea area, double clearingRadiusMeters) => {
    for (final cell in area.cells)
      cellOf(cell.center, clearingRadiusMeters),
  };

  /// How much of a place of [areaSquareMeters] is uncovered by [cells] of its
  /// own, as a 0..1 fraction.
  ///
  /// Clamped, because the approximation can overshoot a small district: one
  /// clearing is 130 000 m² and the smallest ward in Ho Chi Minh City is under
  /// a square kilometre, so eight cells of edge overlap would otherwise report
  /// a district as 104% charted.
  static double fractionOf(int cells, double areaSquareMeters, double radius) {
    if (areaSquareMeters <= 0) return 0;
    return (cells * cellAreaSquareMeters(radius) / areaSquareMeters).clamp(
      0.0,
      1.0,
    );
  }
}
