/// Contracts the presentation layer is allowed to depend on.
///
/// They are `Stream`-based on purpose: position, XP and quest progress all
/// change while a screen is open, and a stream is the honest shape for that.
/// The fake implementations in `lib/data/fake/` replay their latest value on
/// subscribe, so screens paint real data on their first frame.
///
/// Implementations live in `lib/data/`; nothing in `lib/features/` may import
/// them directly — they arrive through the providers in
/// `lib/data/repository_providers.dart`.
library;

import '../entities/check_in.dart';
import '../entities/district.dart';
import '../entities/explored_area.dart';
import '../entities/fog_settings.dart';
import '../entities/geo_point.dart';
import '../entities/log_entry.dart';
import '../entities/map_layer_visibility.dart';
import '../entities/map_point.dart';
import '../entities/place.dart';
import '../entities/player.dart';
import '../entities/quest.dart';

/// The map and everything on it.
abstract interface class WorldRepository {
  /// The city the player is currently exploring.
  Stream<City> watchCurrentCity();

  /// Districts of the current city, in map order, discovered or not.
  Stream<List<District>> watchDistricts();

  /// Places to draw as pins.
  Stream<List<Place>> watchPlaces();

  /// Live position of the player. Comes from the GPS in production, from a
  /// fixed seed point today.
  Stream<GeoPoint> watchPlayerPosition();

  /// Places within [radiusMeters] of the player, nearest first. Drives both the
  /// check-in prompt and the "wrong place?" list.
  Stream<List<Place>> watchNearbyPlaces({double radiusMeters});
}

/// Why the app is not currently receiving positions.
///
/// Modelled as states rather than an error, because each one has a different
/// answer and the player can act on all of them: turn the service on, grant the
/// permission, or open Settings because the permission is gone for good.
enum LocationAvailability {
  /// Never asked. The permission prompt has not been shown yet.
  unknown,

  /// Fixes are arriving.
  ready,

  /// The device's location service is switched off — nothing to do with us.
  serviceDisabled,

  /// Asked and refused. Asking again is allowed.
  denied,

  /// Refused permanently, or blocked by policy. Only Settings can undo it, so
  /// the UI must say that rather than pop a prompt that will never appear.
  deniedForever,
}

/// Where the player is.
///
/// Separate from [WorldRepository] because it answers to the device rather than
/// to the game: it has permissions, a hardware switch, and a state where it
/// legitimately has no answer.
abstract interface class LocationRepository {
  /// Positions, as they arrive. Never emits until tracking has started.
  Stream<GeoPoint> watchPosition();

  /// Whether fixes can flow, and if not, why.
  Stream<LocationAvailability> watchAvailability();

  /// Asks for permission if needed, then starts the stream.
  ///
  /// Safe to call more than once; calling it when already tracking is a no-op.
  /// Returns the resulting availability so a caller can react immediately
  /// rather than waiting for the stream.
  Future<LocationAvailability> start();

  /// Stops the stream and, on Android, tears down the foreground service and
  /// its notification.
  Future<void> stop();

  /// Opens the OS screen that can fix the current problem — app settings for a
  /// permanently denied permission, location settings for a disabled service.
  Future<void> openSettingsFor(LocationAvailability problem);
}

/// The fog of war — everywhere the player has already uncovered.
///
/// This is the one piece of state the player would be genuinely upset to lose:
/// it represents kilometres actually walked. It therefore lives on the device
/// from the first version, before there is any account to sync it to.
abstract interface class ExplorationTrailRepository {
  Stream<ExploredArea> watch();

  /// Uncovers the ground around [point]. Cheap to call on every position fix —
  /// points inside an already-explored cell are a no-op.
  Future<void> record(GeoPoint point);

  /// Forces anything buffered in memory to disk. Called when the app goes to
  /// the background, so a swipe-away never costs the player a walk.
  Future<void> flush();

  /// Wipes the trail. Only reachable from settings, and only with a
  /// confirmation — this is destructive and unrecoverable.
  Future<void> clear();
}

/// The points the player authored: dropped pins and photo points.
///
/// Suggested points are not in here — those come from the world data through
/// [WorldRepository]. The split is deliberate: one of these is the player's
/// content and must never be silently replaced by a data refresh.
abstract interface class MapPointRepository {
  Stream<List<MapPoint>> watch();

  Future<void> add(MapPoint point);

  Future<void> update(MapPoint point);

  Future<void> remove(String id);
}

/// Small persisted choices.
abstract interface class PreferencesRepository {
  Stream<MapLayerVisibility> watchMapLayerVisibility();

  Future<void> setMapLayerVisible(MapPointKind kind, {required bool visible});

  /// Shows or hides the fog. Remembered, like the other layers: a player who
  /// turned it off to find a street should not have to do it again every launch.
  Future<void> setFogVisible({required bool visible});

  /// How the fog behaves. Tunable because the right values have to be walked,
  /// not argued about.
  Stream<FogSettings> watchFogSettings();

  Future<void> setFogSettings(FogSettings settings);

  /// How far the NEARBY list reaches, in metres. One number rather than an
  /// entity because there is exactly one thing to choose — the values on offer
  /// are `ExplorationRules.nearbyRadiusSteps`.
  Stream<double> watchNearbyRadiusMeters();

  Future<void> setNearbyRadiusMeters(double meters);

  /// Whether the player has already been asked to let NoPlace keep running in
  /// the background.
  ///
  /// Persisted rather than session-scoped because the alternative is a dialog
  /// on every launch, and an app that asks the same question every morning
  /// teaches people to dismiss it without reading. Asked once; after that the
  /// map carries a card they can act on whenever they like.
  Stream<bool> watchBackgroundPromptSeen();

  Future<void> markBackgroundPromptSeen();
}

/// The player's own progression.
abstract interface class PlayerRepository {
  Stream<Player> watchPlayer();
}

/// The explorer's log — an append-only history of what the player uncovered.
abstract interface class LogRepository {
  Stream<List<LogEntry>> watchEntries();
}

/// Quests and the weekly challenge.
abstract interface class QuestRepository {
  Stream<List<Quest>> watchQuests();

  Stream<WeeklyChallenge> watchWeeklyChallenge();
}

/// The one write path in the app today.
abstract interface class CheckInRepository {
  /// Records a visit and returns the reward.
  ///
  /// Throws [CheckInFailure] when the place is out of range or already claimed
  /// today; the caller turns that into a message, never into a silent no-op.
  Future<CheckInResult> checkIn(String placeId);
}

/// Why a check-in was refused.
enum CheckInFailureReason { outOfRange, alreadyCheckedIn, unknownPlace }

class CheckInFailure implements Exception {
  const CheckInFailure(this.reason);

  final CheckInFailureReason reason;

  @override
  String toString() => 'CheckInFailure(${reason.name})';
}
