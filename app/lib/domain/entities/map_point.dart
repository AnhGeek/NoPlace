import 'package:equatable/equatable.dart';

import 'geo_point.dart';

/// The three kinds of thing that can sit on the map.
///
/// They are separate because they answer different questions and the player
/// wants to be able to silence each one independently:
///
/// * [suggested] — came from the places data. "What is around me?"
/// * [user] — the player dropped it themselves. "What do *I* care about?"
/// * [picture] — a photo taken at that spot. "What did I see here?"
enum MapPointKind { suggested, user, picture }

/// A point the player owns: one they placed, or one created by taking a photo.
///
/// Suggested points are [Place]s and come from the world data; these two kinds
/// are authored on the device and live in the local database.
class MapPoint extends Equatable {
  const MapPoint({
    required this.id,
    required this.kind,
    required this.location,
    required this.createdAt,
    this.label = '',
    this.iconId = MapPointIcon.defaultId,
    this.imagePath,
  }) : assert(
         kind != MapPointKind.suggested,
         'suggested points come from the world data, not the local database',
       );

  final String id;
  final MapPointKind kind;
  final GeoPoint location;
  final DateTime createdAt;

  /// What the player called it. May be empty — a dropped pin does not have to
  /// be named to be useful.
  final String label;

  /// Which icon the player chose. See [MapPointIcon].
  final String iconId;

  /// Absolute path to the photo for a [MapPointKind.picture] point.
  ///
  /// The image is turned into a pin-sized thumbnail when the map loads; the
  /// capture flow that writes this file is not built yet, so today this is only
  /// ever set by seeded data. See `PicturePointThumbnails`.
  final String? imagePath;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  MapPoint copyWith({String? label, String? iconId, String? imagePath}) =>
      MapPoint(
        id: id,
        kind: kind,
        location: location,
        createdAt: createdAt,
        label: label ?? this.label,
        iconId: iconId ?? this.iconId,
        imagePath: imagePath ?? this.imagePath,
      );

  @override
  List<Object?> get props => [
    id,
    kind,
    location,
    createdAt,
    label,
    iconId,
    imagePath,
  ];
}

/// The icons a player may choose for their own points.
///
/// Stored as stable string ids, never as an `IconData` index: Flutter's icon
/// code points are not a stable storage format, and a saved point must survive
/// an icon-set change.
abstract final class MapPointIcon {
  const MapPointIcon._();

  static const String defaultId = 'pin';

  /// Every selectable id, in the order the picker shows them.
  static const List<String> all = [
    'pin',
    'star',
    'heart',
    'home',
    'coffee',
    'food',
    'view',
    'flag',
  ];

  static bool isKnown(String id) => all.contains(id);
}
