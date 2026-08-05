import 'package:equatable/equatable.dart';

import 'auto_check_in.dart';
import 'geo_point.dart';
import 'place_visit.dart';

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
    this.stars = 0,
    this.moodId = PlaceMood.none,
    this.checkInCount = 0,
    this.lastCheckInAt,
    this.stayStartedAt,
    this.stayLastSeenAt,
    this.autoCheckInEvery = AutoCheckIn.defaultInterval,
  }) : assert(
         kind != MapPointKind.suggested,
         'suggested points come from the world data, not the local database',
       ),
       assert(stars >= 0 && stars <= maxStars, 'stars out of range');

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

  /// The player's rating, 0–[maxStars]. Zero means unrated, which is a real
  /// state and not a bad score: a place you have not made your mind up about
  /// must not read as one star.
  final int stars;

  /// How the place felt. A [PlaceMood] id, or [PlaceMood.none].
  ///
  /// Kept apart from [stars] because they answer different questions: a
  /// five-star bún chả you queued an hour for can still have felt exhausting.
  final String moodId;

  /// How many times the player has been here, counting both the ones they
  /// tapped and the ones an hour on the spot earned. See `PlaceVisitRules`.
  final int checkInCount;

  final DateTime? lastCheckInAt;

  /// When the current stay near this place began, or null if the player is not
  /// on one. Every [PlaceVisitRules.dwellCheckIn] of it is a check-in.
  ///
  /// Persisted rather than held in memory: a stay outlives the process — the
  /// app is put to sleep in a pocket all the time — and an hour at a café must
  /// survive that or the feature only works with the screen on.
  final DateTime? stayStartedAt;

  /// The last fix seen inside the place's radius. What tells a stay in progress
  /// from a stale one nobody has been near since Tuesday.
  final DateTime? stayLastSeenAt;

  /// How long the player has to stay before it counts on its own, or
  /// [AutoCheckIn.off] if only tapping the button should.
  ///
  /// Per place rather than one setting for all of them, because the answer
  /// genuinely differs: an hour at your own desk is not news, an hour anywhere
  /// else usually is. Defaults to [AutoCheckIn.defaultInterval] so a pin
  /// dropped without a thought behaves the way every pin did before the choice
  /// existed.
  final Duration autoCheckInEvery;

  static const int maxStars = 5;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  bool get isRated => stars > 0;

  bool get hasMood => moodId != PlaceMood.none;

  bool get autoChecksIn => AutoCheckIn.isOn(autoCheckInEvery);

  /// The visit half of this point, in the shape the rules and the UI share with
  /// world places. See [PlaceVisit] for why the two are stored differently.
  PlaceVisit get visit => PlaceVisit(
    placeId: id,
    checkInCount: checkInCount,
    lastCheckInAt: lastCheckInAt,
    stayStartedAt: stayStartedAt,
    stayLastSeenAt: stayLastSeenAt,
  );

  /// This point with [visit]'s four numbers written back into it.
  MapPoint withVisit(PlaceVisit visit) => MapPoint(
    id: id,
    kind: kind,
    location: location,
    createdAt: createdAt,
    label: label,
    iconId: iconId,
    imagePath: imagePath,
    stars: stars,
    moodId: moodId,
    autoCheckInEvery: autoCheckInEvery,
    checkInCount: visit.checkInCount,
    lastCheckInAt: visit.lastCheckInAt,
    stayStartedAt: visit.stayStartedAt,
    stayLastSeenAt: visit.stayLastSeenAt,
  );

  MapPoint copyWith({
    String? label,
    String? iconId,
    String? imagePath,
    int? stars,
    String? moodId,
    int? checkInCount,
    DateTime? lastCheckInAt,
    DateTime? stayStartedAt,
    DateTime? stayLastSeenAt,
    Duration? autoCheckInEvery,
  }) => MapPoint(
    id: id,
    kind: kind,
    location: location,
    createdAt: createdAt,
    label: label ?? this.label,
    iconId: iconId ?? this.iconId,
    imagePath: imagePath ?? this.imagePath,
    stars: stars ?? this.stars,
    moodId: moodId ?? this.moodId,
    checkInCount: checkInCount ?? this.checkInCount,
    lastCheckInAt: lastCheckInAt ?? this.lastCheckInAt,
    stayStartedAt: stayStartedAt ?? this.stayStartedAt,
    stayLastSeenAt: stayLastSeenAt ?? this.stayLastSeenAt,
    // Works for "Off" because that is [AutoCheckIn.off] — a real value — and
    // not a null the `??` would read as "leave it alone".
    autoCheckInEvery: autoCheckInEvery ?? this.autoCheckInEvery,
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
    stars,
    moodId,
    checkInCount,
    lastCheckInAt,
    stayStartedAt,
    stayLastSeenAt,
    autoCheckInEvery,
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
  ///
  /// Ordered by how often somebody reaches for it, not alphabetically: the
  /// first row is the one most people never scroll past.
  static const List<String> all = [
    'pin',
    'heart',
    'star',
    'home',
    'coffee',
    'food',
    'boba',
    'ramen',
    'cake',
    'icecream',
    'pet',
    'flower',
    'shop',
    'music',
    'sparkle',
    'beach',
    'moon',
    'work',
    'view',
    'flag',
  ];

  static bool isKnown(String id) => all.contains(id);
}

/// How a place felt, as stable string ids for the same reason as
/// [MapPointIcon]: what the player recorded has to outlive the emoji we happen
/// to draw it with today.
///
/// Five is deliberate. Three cannot tell "fine" from "lovely", and seven turns
/// a one-tap reaction into a decision.
abstract final class PlaceMood {
  const PlaceMood._();

  /// No feeling recorded. Not the middle of the scale — the absence of one.
  static const String none = '';

  static const String love = 'love';
  static const String happy = 'happy';
  static const String calm = 'calm';
  static const String meh = 'meh';
  static const String bad = 'bad';

  /// Best to worst, which is the order the picker shows them in.
  static const List<String> all = [love, happy, calm, meh, bad];

  static bool isKnown(String id) => all.contains(id);
}
