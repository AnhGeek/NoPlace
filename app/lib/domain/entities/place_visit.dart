import 'package:equatable/equatable.dart';

/// The player's record of having been somewhere: how many times, when last, and
/// whether they are standing in it right now.
///
/// One row per place, keyed by the place's id — which is why it is a *record
/// about* a place rather than a field *on* one. A [Place] is world data that a
/// places API will one day hand us and replace wholesale on a refresh; the fact
/// that somebody stood in it on a Tuesday in August is theirs and must survive
/// that. `MapPoint` carries the same four numbers inline because a point the
/// player authored is never replaced by anybody.
///
/// Deliberately a count and a timestamp rather than a log of every visit. "You
/// have been here seven times, last on Tuesday" is the sentence people actually
/// want; a full history is a bigger feature and is not owed by this one.
class PlaceVisit extends Equatable {
  const PlaceVisit({
    required this.placeId,
    this.checkInCount = 0,
    this.lastCheckInAt,
    this.claimedAt,
    this.stayStartedAt,
    this.stayLastSeenAt,
  });

  /// A place nobody has been to yet. What every place starts as, and what the
  /// store hands back for an id it has never written a row for.
  const PlaceVisit.none(String placeId) : this(placeId: placeId);

  /// Matches the id of the [Place] or `MapPoint` this is about.
  final String placeId;

  /// How many times the player has been here, counting both the ones they
  /// tapped and the ones an hour on the spot earned. See `PlaceVisitRules`.
  final int checkInCount;

  /// The most recent visit of any kind — one the player tapped for, or one an
  /// hour on the spot earned.
  final DateTime? lastCheckInAt;

  /// When the player first *deliberately* checked in here, or null if they
  /// never have. Hours spent nearby do not set it.
  ///
  /// The reason this is not just `checkInCount > 0`: the first deliberate
  /// check-in pays double, and that bonus has to be claimable by somebody who
  /// happened to sit near the place first. Without the distinction, switching
  /// [Place.autoCheckIn] on would quietly spend a reward the player never
  /// collected — they would be worse off for having stood still, with nothing
  /// on screen to say so.
  ///
  /// Only meaningful for the world's own places, which are the ones with an XP
  /// reward attached. A `MapPoint` has no first-visit bonus to protect, so it
  /// has no column for this and drops it on the way through `withVisit`.
  final DateTime? claimedAt;

  /// When the current stay began, or null if the player is not on one. Every
  /// `AutoCheckIn` interval of it is a check-in.
  ///
  /// Persisted rather than held in memory: a stay outlives the process — the
  /// app is put to sleep in a pocket all the time — and an hour at a café must
  /// survive that or the feature only works with the screen on.
  final DateTime? stayStartedAt;

  /// The last fix seen inside the place's radius. What tells a stay in progress
  /// from a stale one nobody has been near since Tuesday.
  final DateTime? stayLastSeenAt;

  /// Whether the player has been here at all, however it was earned. What the
  /// history on the sheet counts.
  bool get hasVisited => checkInCount > 0;

  /// Whether the first-visit bonus has been spent. What the *reward* turns on.
  bool get isClaimed => claimedAt != null;

  /// The stay only, cleared. Used when a record crosses to another phone: the
  /// counts are the player's, the stay is a fact about the device that was
  /// standing there.
  PlaceVisit withoutStay() => PlaceVisit(
    placeId: placeId,
    checkInCount: checkInCount,
    lastCheckInAt: lastCheckInAt,
    claimedAt: claimedAt,
  );

  PlaceVisit copyWith({
    int? checkInCount,
    DateTime? lastCheckInAt,
    DateTime? claimedAt,
    DateTime? stayStartedAt,
    DateTime? stayLastSeenAt,
  }) => PlaceVisit(
    placeId: placeId,
    checkInCount: checkInCount ?? this.checkInCount,
    lastCheckInAt: lastCheckInAt ?? this.lastCheckInAt,
    claimedAt: claimedAt ?? this.claimedAt,
    stayStartedAt: stayStartedAt ?? this.stayStartedAt,
    stayLastSeenAt: stayLastSeenAt ?? this.stayLastSeenAt,
  );

  @override
  List<Object?> get props => [
    placeId,
    checkInCount,
    lastCheckInAt,
    claimedAt,
    stayStartedAt,
    stayLastSeenAt,
  ];
}
