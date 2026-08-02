import '../../domain/entities/geo_point.dart';
import '../../domain/entities/map_point.dart';

/// A handful of the player's "own" points, written once into an empty database.
///
/// They exist so the three map layers and their settings can be seen and
/// reviewed before the flows that create them are built. Deliberately obvious
/// stand-ins — real points arrive the moment a player can drop a pin or take a
/// photo, and this seed never runs again once the table has anything in it.
abstract final class DemoMapPoints {
  const DemoMapPoints._();

  static List<MapPoint> seed() {
    final now = DateTime.now();

    return [
      MapPoint(
        id: 'demo-user-1',
        kind: MapPointKind.user,
        location: const GeoPoint(10.77190, 106.69720),
        createdAt: now,
        label: 'Bánh mì on the corner',
        iconId: 'food',
      ),
      MapPoint(
        id: 'demo-user-2',
        kind: MapPointKind.user,
        location: const GeoPoint(10.77380, 106.69930),
        createdAt: now,
        label: 'Good bench',
        iconId: 'star',
      ),
      MapPoint(
        id: 'demo-picture-1',
        kind: MapPointKind.picture,
        location: const GeoPoint(10.77130, 106.69890),
        createdAt: now,
        label: 'Rooftop view',
        iconId: 'view',
        // No file yet: the pin falls back to its camera glyph, which is exactly
        // what a photo point looks like while its image is missing.
      ),
    ];
  }
}
