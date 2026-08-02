import 'package:equatable/equatable.dart';

import 'geo_point.dart';

/// One square metre of ground the player has stood on.
///
/// The trail is quantised to a metre: fine enough that the recorded path is the
/// path actually walked, coarse enough that standing still or GPS jitter does
/// not add a row per second.
///
/// Note what this is *not*: it is not the uncovered area. A metre-resolution
/// record of uncovered ground would be about a hundred thousand cells per
/// position fix. What is stored is where the player **was**; the fog opens a
/// disc around each of those points when it is drawn.
class TrailCell extends Equatable {
  const TrailCell(this.latIndex, this.lngIndex);

  factory TrailCell.of(GeoPoint point) => TrailCell(
    (point.latitude / ExploredArea.cellSizeDegrees).round(),
    (point.longitude / ExploredArea.cellSizeDegrees).round(),
  );

  final int latIndex;
  final int lngIndex;

  GeoPoint get center => GeoPoint(
    latIndex * ExploredArea.cellSizeDegrees,
    lngIndex * ExploredArea.cellSizeDegrees,
  );

  @override
  List<Object?> get props => [latIndex, lngIndex];

  @override
  String toString() => '$latIndex:$lngIndex';
}

/// Everywhere the player has been.
class ExploredArea extends Equatable {
  const ExploredArea(this.cells);

  const ExploredArea.empty() : cells = const {};

  /// The metre-resolution points that have been walked.
  final Set<TrailCell> cells;

  /// One metre, in degrees of latitude.
  ///
  /// Longitude uses the same step, so a cell is a metre tall and a little under
  /// a metre wide at Vietnamese latitudes. At this scale that is far below GPS
  /// accuracy and nobody will ever measure it.
  static const double cellSizeDegrees = 1 / 111320;

  static const double cellSizeMeters = 1;

  bool contains(GeoPoint point) => cells.contains(TrailCell.of(point));

  bool get isEmpty => cells.isEmpty;

  int get count => cells.length;

  /// Records a single position. One fix, one cell — the fog decides how much
  /// ground that uncovers when it draws.
  ExploredArea withPoint(GeoPoint point) =>
      ExploredArea({...cells, TrailCell.of(point)});

  ExploredArea withPoints(Iterable<GeoPoint> points) =>
      ExploredArea({...cells, ...points.map(TrailCell.of)});

  @override
  List<Object?> get props => [cells];
}
