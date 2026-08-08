import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/auto_check_in.dart';
import '../domain/entities/check_in.dart';
import '../domain/entities/district.dart';
import '../domain/entities/explored_area.dart';
import '../domain/entities/explorer_profile.dart';
import '../domain/entities/fog_settings.dart';
import '../domain/entities/geo_point.dart';
import '../domain/entities/log_entry.dart';
import '../domain/entities/map_layer_visibility.dart';
import '../domain/entities/map_point.dart';
import '../domain/entities/place.dart';
import '../domain/entities/place_visit.dart';
import '../domain/entities/player.dart';
import '../domain/entities/quest.dart';
import '../domain/entities/walk_history.dart';
import '../domain/repositories/repositories.dart';
import '../domain/rules/charting_rules.dart';
import '../domain/rules/exploration_rules.dart';
import '../domain/rules/place_visit_rules.dart';
import '../domain/rules/progression_rules.dart';
import 'fake/fake_repositories.dart';
import 'fake/fake_world_store.dart';
import 'local/app_database.dart';
import 'local/avatar_store.dart';
import 'local/backup_service.dart';
import 'local/district_boundaries.dart';
import 'local/geolocator_location_repository.dart';
import 'local/region_catalogue.dart';
import 'local/region_pack.dart';
import 'local/region_pack_store.dart';
import 'local/sqlite_map_point_repository.dart';
import 'local/sqlite_place_visit_repository.dart';
import 'local/sqlite_preferences_repository.dart';
import 'local/sqlite_trail_repository.dart';
import 'local/visit_recording_check_in_repository.dart';

/// The composition root of the data layer.
///
/// This is the *only* file that names a concrete implementation. Swapping the
/// fakes for HTTP repositories is a change here and nowhere else; tests
/// override the same providers with their own doubles.

/// The in-memory world. Alive for the whole session.
final fakeWorldStoreProvider = Provider<FakeWorldStore>((ref) {
  return FakeWorldStore();
});

final worldRepositoryProvider = Provider<WorldRepository>((ref) {
  return FakeWorldRepository(ref.watch(fakeWorldStoreProvider));
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return FakePlayerRepository(ref.watch(fakeWorldStoreProvider));
});

final logRepositoryProvider = Provider<LogRepository>((ref) {
  return FakeLogRepository(ref.watch(fakeWorldStoreProvider));
});

final questRepositoryProvider = Provider<QuestRepository>((ref) {
  return FakeQuestRepository(ref.watch(fakeWorldStoreProvider));
});

/// The world's rules decide whether a check-in is allowed; the device keeps the
/// record of it. Two owners, so two objects — see
/// [VisitRecordingCheckInRepository].
final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return VisitRecordingCheckInRepository(
    FakeCheckInRepository(ref.watch(fakeWorldStoreProvider)),
    ref.watch(placeVisitRepositoryProvider),
  );
});

// ---------------------------------------------------------------------------
// On-device storage
//
// `bootstrap()` opens the database and overrides these with instances it has
// already loaded, so the first frame draws the real fog and the real points
// instead of blanking the city and filling it in a moment later.
// ---------------------------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final trailStoreProvider = Provider<SqliteTrailRepository>((ref) {
  final store = SqliteTrailRepository(
    ref.watch(appDatabaseProvider),
    // The fog belongs to a city. Read once here rather than watched: a region
    // change must go through `switchTo`, which flushes first — rebuilding the
    // store instead would drop whatever had not reached disk.
    regionId: ref.read(regionPackSourceProvider).regionId,
  );
  ref.onDispose(() => unawaited(store.dispose()));
  return store;
});

/// Keeps the fog on the same city as the map.
///
/// Alive for as long as the map is (the map watches it), so crossing a border
/// reloads the trail exactly once, after the pending points of the city just
/// left have been written.
final trailRegionSyncProvider = Provider<void>((ref) {
  ref.listen<RegionPackSource>(regionPackSourceProvider, (previous, next) {
    if (previous?.regionId == next.regionId) return;
    unawaited(ref.read(trailStoreProvider).switchTo(next.regionId));
  }, fireImmediately: true);
});

final explorationTrailRepositoryProvider = Provider<ExplorationTrailRepository>(
  (ref) => ref.watch(trailStoreProvider),
);

final mapPointStoreProvider = Provider<SqliteMapPointRepository>((ref) {
  return SqliteMapPointRepository(ref.watch(appDatabaseProvider));
});

final mapPointRepositoryProvider = Provider<MapPointRepository>(
  (ref) => ref.watch(mapPointStoreProvider),
);

/// The visit history of places the player did not author.
final placeVisitStoreProvider = Provider<SqlitePlaceVisitRepository>((ref) {
  return SqlitePlaceVisitRepository(ref.watch(appDatabaseProvider));
});

final placeVisitRepositoryProvider = Provider<PlaceVisitRepository>(
  (ref) => ref.watch(placeVisitStoreProvider),
);

final preferencesStoreProvider = Provider<SqlitePreferencesRepository>((ref) {
  return SqlitePreferencesRepository(ref.watch(appDatabaseProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => ref.watch(preferencesStoreProvider),
);

/// The player's own picture: picked, copied into app storage, remembered.
final avatarStoreProvider = Provider<AvatarStore>((ref) {
  return AvatarStore(ref.watch(preferencesRepositoryProvider));
});

/// Copies the walk off the device and back on.
///
/// Depends on the stores rather than the repository interfaces because a backup
/// is a fact about *storage*: it flushes the trail's write buffer before it
/// reads, and reloads all three afterwards so the map agrees with the file.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    database: ref.watch(appDatabaseProvider),
    trail: ref.watch(trailStoreProvider),
    mapPoints: ref.watch(mapPointStoreProvider),
    placeVisits: ref.watch(placeVisitStoreProvider),
    preferences: ref.watch(preferencesStoreProvider),
  );
});

// ---------------------------------------------------------------------------
// Where the player actually is
//
// The world is still seeded, but the position in it is the device's. See
// docs/adr/0009-real-location.md.
// ---------------------------------------------------------------------------

final locationRepositoryProvider = Provider<GeolocatorLocationRepository>((
  ref,
) {
  final repository = GeolocatorLocationRepository();
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

/// Whether fixes are flowing, and if not, why. Watched by the map so it can
/// say something the player can act on.
final locationAvailabilityProvider = StreamProvider<LocationAvailability>((
  ref,
) {
  return ref.watch(locationRepositoryProvider).watchAvailability();
});

/// Whether the OS is still allowed to freeze this process mid-walk.
///
/// A separate state from [locationAvailabilityProvider] because it is a
/// separate problem with a separate remedy: the permission can be perfect and
/// the service running, and the walk still comes back with a hole in it because
/// the phone put the app to sleep in a pocket.
final batteryOptimisedProvider = StreamProvider<bool>((ref) {
  return ref.watch(locationRepositoryProvider).watchBatteryOptimised();
});

/// Whether we have already put the background question to the player.
final backgroundPromptSeenProvider = StreamProvider<bool>((ref) {
  return ref.watch(preferencesRepositoryProvider).watchBackgroundPromptSeen();
});

/// Starts tracking and feeds every fix into the world.
///
/// Kept alive by the map. Everything downstream — the marker, the nearby list,
/// the check-in candidate, the distances — reads the world, so this one wire is
/// what makes all of them real rather than each of them knowing about GPS.
final locationSyncProvider = Provider<void>((ref) {
  final location = ref.watch(locationRepositoryProvider);
  final world = ref.watch(fakeWorldStoreProvider);

  final subscription = location.watchPosition().listen(world.moveTo);
  ref.onDispose(subscription.cancel);

  unawaited(location.start());
});

// ---------------------------------------------------------------------------
// The basemap
//
// Streets come from a region pack: one MBTiles file per city, cooked from
// OpenStreetMap. See docs/adr/0008-openstreetmap-basemap.md.
// ---------------------------------------------------------------------------

final regionPackStoreProvider = Provider<RegionPackStore>((ref) {
  final store = RegionPackStore();
  ref.onDispose(store.dispose);
  return store;
});

/// Which city's map to open, decided by where the player is standing.
///
/// Four rules, and each of them is a bug that was worth not having:
///
///  * only a **real** fix moves the region. The world opens on a seeded
///    coordinate in District 1, and resolving from that would open a city the
///    player may never have been to;
///  * a fix outside every region we have a map for **keeps the current one**
///    rather than snapping back to the fallback. Walking off the eastern edge
///    of Đồng Nai must not quietly move the player's fog to Ho Chi Minh City;
///  * the region is state, not a computation over the latest fix, so the pack
///    and the trail change once per border crossing instead of once per fix;
///  * the answer **survives the app being closed**. The city the player was in
///    yesterday is on disk, so a cold start in the same city is not an arrival
///    and does not open the sheet. Launching the app used to ask "which city is
///    this?" every single morning, which taught people to tap it away without
///    reading — and then it was worth nothing on the morning it was right.
class RegionPackSourceNotifier extends Notifier<RegionPackSource> {
  /// The region the *ground* last resolved to, which is not always the region
  /// being shown: [select] lets the player override the map without moving.
  ///
  /// Held separately so a crossing is detected against where the player was
  /// standing, not against what they chose to look at. Without it, picking Ho
  /// Chi Minh City while standing in Biên Hòa would be undone by the very next
  /// fix, which still resolves to Đồng Nai.
  String? _lastResolvedId;

  /// The fix [_lastResolvedId] was worked out from. Restored from the device on
  /// launch, so "have I moved cities since I last had this open" is answerable
  /// on the first frame rather than a question we re-ask every launch.
  GeoPoint? _lastResolvedAt;

  @override
  RegionPackSource build() {
    ref.listen<AsyncValue<GeoPoint>>(playerPositionProvider, (_, next) {
      final position = next.value;
      if (position == null) return;

      final resolved = _resolve(position);
      if (resolved == null || resolved.regionId == _lastResolvedId) return;

      // A different rectangle is not yet a different city. Two fixes either
      // side of a border can be metres apart, and believing that would swap
      // the streets and reload the fog over GPS noise.
      final from = _lastResolvedAt;
      if (from != null &&
          position.distanceTo(from) < RegionCatalogue.crossingDistanceMeters) {
        return;
      }

      _remember(resolved, position);

      if (resolved.regionId != state.regionId) state = resolved;

      // The crossing itself, for the map to announce. Recorded even when the
      // map was already on this region — the player has still just arrived
      // somewhere, and that is the moment the sheet is about.
      ref.read(regionArrivalProvider.notifier).record(resolved);
    });

    // The OS's last known position is pushed into the stream before the first
    // real fix, so by the time the map builds this is usually already answerable
    // — which is what stops the first frame drawing the wrong city.
    final world = ref.read(fakeWorldStoreProvider);
    final opening = _resolve(world.currentPosition);
    if (opening != null) {
      _remember(opening, world.currentPosition);
      return opening;
    }

    // Nothing from the GPS yet, so fall back to where this device was when it
    // last worked the question out. Restoring the *position* rather than the
    // region id means the catalogue stays the one authority on which ground
    // belongs to which city, even after its boundaries are redrawn.
    final remembered = ref.read(preferencesRepositoryProvider).lastFix;
    _lastResolvedAt = remembered;
    final rememberedRegion = remembered == null
        ? null
        : RegionCatalogue.forPosition(remembered);
    _lastResolvedId = rememberedRegion?.regionId;

    return rememberedRegion ?? RegionCatalogue.fallback;
  }

  /// The player's own choice of map, from the arrival sheet.
  ///
  /// Survives the following fixes: only *crossing into a different region* than
  /// the one the ground last resolved to moves the map again. Somebody standing
  /// on the border who wants the other side's streets gets to keep them.
  void select(RegionPackSource source) {
    if (source.regionId == state.regionId) return;
    state = source;
  }

  /// Records the answer, in memory for this session and on disk for the next
  /// one. Fire-and-forget: a write that fails costs one redundant question on
  /// some future launch, which is not worth holding a position fix for.
  void _remember(RegionPackSource region, GeoPoint position) {
    _lastResolvedId = region.regionId;
    _lastResolvedAt = position;
    unawaited(ref.read(preferencesRepositoryProvider).saveLastFix(position));
  }

  RegionPackSource? _resolve(GeoPoint position) {
    if (!ref.read(fakeWorldStoreProvider).hasRealPosition) return null;
    return RegionCatalogue.forPosition(position);
  }
}

/// The region the player has just walked into, until somebody says it.
///
/// Same shape as [LastCheckInResult] and for the same reason: the map consumes
/// it with [take], so a rebuild — a position fix, a tab change, the keyboard —
/// cannot replay the sheet. Null the rest of the time.
class RegionArrival extends Notifier<RegionPackSource?> {
  @override
  RegionPackSource? build() => null;

  // ignore: use_setters_to_change_properties
  void record(RegionPackSource region) => state = region;

  RegionPackSource? take() {
    final arrival = state;
    state = null;
    return arrival;
  }
}

final regionArrivalProvider =
    NotifierProvider<RegionArrival, RegionPackSource?>(RegionArrival.new);

final regionPackSourceProvider =
    NotifierProvider<RegionPackSourceNotifier, RegionPackSource>(
      RegionPackSourceNotifier.new,
    );

/// The open pack, or null when there is none to open.
///
/// Null is a supported state, not a failure: the map falls back to the fog and
/// the player's own points, which is exactly what it drew before there was a
/// basemap at all.
final regionPackProvider = FutureProvider<RegionPack?>((ref) async {
  final store = ref.watch(regionPackStoreProvider);
  final pack = await store.open(ref.watch(regionPackSourceProvider));
  ref.onDispose(() {
    if (pack != null) unawaited(pack.close());
  });
  return pack;
});

// ---------------------------------------------------------------------------
// Read models
//
// Screens watch these, never the repositories directly. Keeping the stream
// wiring in one place means a screen is a pure function of state, which is what
// makes the widget tests short.
// ---------------------------------------------------------------------------

final currentCityProvider = StreamProvider<City>((ref) {
  return ref.watch(worldRepositoryProvider).watchCurrentCity();
});

final districtsProvider = StreamProvider<List<District>>((ref) {
  return ref.watch(worldRepositoryProvider).watchDistricts();
});

final placesProvider = StreamProvider<List<Place>>((ref) {
  return ref.watch(worldRepositoryProvider).watchPlaces();
});

final playerProvider = StreamProvider<Player>((ref) {
  return ref.watch(playerRepositoryProvider).watchPlayer();
});

/// Where the player is. Fixed today; a GPS stream tomorrow.
final playerPositionProvider = StreamProvider<GeoPoint>((ref) {
  return ref.watch(worldRepositoryProvider).watchPlayerPosition();
});

/// Whether [playerPositionProvider] is the device's position yet, or still the
/// seeded starting point.
///
/// A getter on the store rather than a `StreamProvider` over
/// [FakeWorldStore.positionIsReal], deliberately: the answer is needed *inside*
/// the listener that handles a fix, in the same microtask that set it, and an
/// `AsyncValue` read there would still be carrying the previous frame's answer.
///
/// It reads the store rather than the repository because "have we heard from
/// the GPS" is a fact about this fake, which must always hand out *some*
/// coordinate. A real backend would make the position nullable and this would
/// go away.
bool hasRealPosition(WidgetRef ref) =>
    ref.read(fakeWorldStoreProvider).hasRealPosition;

/// Everywhere the player has already uncovered, loaded from the device.
final exploredAreaProvider = StreamProvider<ExploredArea>((ref) {
  return ref.watch(explorationTrailRepositoryProvider).watch();
});

/// The player's own points: dropped pins and photo points.
final mapPointsProvider = StreamProvider<List<MapPoint>>((ref) {
  return ref.watch(mapPointRepositoryProvider).watch();
});

/// How often the player has been to each of the world's places, keyed by id.
final placeVisitsProvider = StreamProvider<Map<String, PlaceVisit>>((ref) {
  return ref.watch(placeVisitRepositoryProvider).watch();
});

/// One place's history, for the sheet that is showing it.
///
/// A family over [placeVisitsProvider] rather than a lookup at each call site,
/// so a check-in recorded while the sheet is open repaints the count under the
/// player's thumb.
final placeVisitProvider = Provider.family<PlaceVisit, String>((ref, placeId) {
  final visits = ref.watch(placeVisitsProvider).value;
  return visits?[placeId] ?? PlaceVisit.none(placeId);
});

/// How the fog behaves. Watched by the map and by the settings screen, so a
/// slider drag is visible on the map behind it immediately.
final fogSettingsProvider = StreamProvider<FogSettings>((ref) {
  return ref.watch(preferencesRepositoryProvider).watchFogSettings();
});

/// Keeps the trail's recording throttle in step with the setting.
///
/// One place decides how finely we record; without this the slider would change
/// how the fog *looks* while the database quietly kept its old resolution.
final trailPrecisionSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<FogSettings>>(fogSettingsProvider, (previous, next) {
    final settings = next.value;
    if (settings != null) {
      ref.read(trailStoreProvider).recordingPrecisionMeters =
          settings.recordingPrecisionMeters;
    }
  }, fireImmediately: true);
});

/// Which kinds of point the map draws.
final mapLayerVisibilityProvider = StreamProvider<MapLayerVisibility>((ref) {
  return ref.watch(preferencesRepositoryProvider).watchMapLayerVisibility();
});

/// Feeds every position fix into the trail.
///
/// The rule — "being somewhere uncovers it" — belongs here rather than in a
/// widget: it must hold whether or not the map happens to be on screen. Keep it
/// alive by watching it from the map.
final trailRecorderProvider = Provider<void>((ref) {
  final trail = ref.watch(explorationTrailRepositoryProvider);
  ref.listen<AsyncValue<GeoPoint>>(playerPositionProvider, (previous, next) {
    // Only real fixes uncover ground. The world opens on a seeded coordinate in
    // District 1, and recording that would hand every new player a patch of
    // cleared fog in a city centre they have never stood in — and would write
    // it to disk, where it outlives the misunderstanding.
    final store = ref.read(fakeWorldStoreProvider);
    if (!store.hasRealPosition) return;

    final position = next.value;
    if (position != null) unawaited(trail.record(position));
  }, fireImmediately: true);
});

/// Puts the device's record of which world places have been visited back onto
/// the freshly seeded world.
///
/// The world is rebuilt from `_seedPlaces` on every launch and starts with
/// almost everything unvisited; the visits are on disk. Without this the
/// check-in sheet would call a place the player knows well "never visited", and
/// would offer the first-visit bonus for it a second time.
///
/// Kept alive by the map, like the trail recorder.
final placeVisitSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<Map<String, PlaceVisit>>>(placeVisitsProvider, (
    previous,
    next,
  ) {
    final visits = next.value;
    if (visits == null) return;

    // Keyed on the *claim*, not on having been here. An hour spent nearby
    // counts towards the history but must not spend the first-visit bonus —
    // see [PlaceVisit.claimedAt].
    ref.read(fakeWorldStoreProvider).restoreVisited({
      for (final entry in visits.entries)
        if (entry.value.isClaimed) entry.key,
    });
  }, fireImmediately: true);
});

/// Turns time spent standing near a saved place into check-ins.
///
/// Sits next to [trailRecorderProvider] and for the same reason: "being
/// somewhere counts" is a rule about the player, not about whichever screen
/// happens to be open. Kept alive by the map.
///
/// The decision itself is [PlaceVisitRules.applyFix] — pure, and tested by
/// moving a clock. All this does is feed it a position and write back the
/// points that changed, which on the overwhelming majority of calls is none of
/// them. How long a stay has to run is the place's own
/// [MapPoint.autoCheckInEvery], so a place switched to "Off" costs nothing here
/// beyond the comparison that skips it.
///
/// Both kinds of place accrue, from opposite ends of the same rule. A point the
/// player saved carries the interval they chose. One the world came with is
/// fixed at [AutoCheckIn.hourly] and carries only [Place.autoCheckIn] — a flag
/// the places data sets rather than the player, so somewhere an unattended hour
/// would be meaningless can opt out.
///
/// Collecting an hour never spends the first-visit bonus: only a deliberate
/// check-in claims it. See [PlaceVisit.claimedAt].
final placePresenceProvider = Provider<void>((ref) {
  void evaluate(GeoPoint? position) {
    // Same guard as the trail: the world opens on a seeded coordinate, and
    // awarding visits from it would credit somebody an hour in a district they
    // have never stood in.
    if (position == null) return;
    final world = ref.read(fakeWorldStoreProvider);
    if (!world.hasRealPosition) return;

    final now = DateTime.now();

    final store = ref.read(mapPointStoreProvider);
    for (final place in store.current) {
      final updated = PlaceVisitRules.applyFix(
        place,
        position: position,
        now: now,
      );
      if (updated != null) unawaited(store.update(updated));
    }

    final visits = ref.read(placeVisitRepositoryProvider);
    for (final place in world.currentPlaces) {
      if (!place.autoCheckIn) continue;
      final updated = PlaceVisitRules.advance(
        visits.of(place.id),
        distanceMeters: position.distanceTo(place.location),
        every: AutoCheckIn.hourly,
        now: now,
      );
      if (updated != null) unawaited(visits.save(updated));
    }
  }

  ref.listen<AsyncValue<GeoPoint>>(
    playerPositionProvider,
    (previous, next) => evaluate(next.value),
  );

  // And on a clock of its own, because the feature is about *not* moving.
  //
  // Fixes are what the trail runs on, and they arrive as the player walks. A
  // phone lying on a café table can go quiet for a long time — the position has
  // genuinely not changed — and a stay measured only in fixes would then look
  // abandoned exactly when it was most real. The ticker keeps the stay alive
  // from the same position the GPS last reported.
  final ticker = Timer.periodic(
    PlaceVisitRules.heartbeat,
    (_) => evaluate(ref.read(fakeWorldStoreProvider).currentPosition),
  );
  ref.onDispose(ticker.cancel);
});

/// How far the player walked today, and the run of days behind it.
final walkHistoryProvider = StreamProvider<WalkHistory>((ref) {
  return ref.watch(explorationTrailRepositoryProvider).watchHistory();
});

/// What the player calls themselves, and the picture they chose.
final displayNameProvider = StreamProvider<String>((ref) {
  return ref.watch(preferencesRepositoryProvider).watchDisplayName();
});

final avatarPathProvider = StreamProvider<String?>((ref) {
  return ref.watch(preferencesRepositoryProvider).watchAvatarPath();
});

/// The districts of the region being walked, with their shapes.
///
/// Keyed on the region rather than loaded once: crossing a border changes which
/// file is the right one, and a hundred kilobytes of polygons is not worth
/// holding on to for a city the player has left.
final districtBoundariesProvider = FutureProvider<DistrictBoundaries>((ref) {
  return DistrictBoundaries.load(ref.watch(regionPackSourceProvider).regionId);
});

/// Everything the profile screen is about, worked out from this device.
///
/// A plain [Provider] and not an async one: every input has an honest value
/// before its stream has said anything — no trail, no points, no name — so the
/// screen paints a real (empty) profile on the first frame instead of a
/// spinner over the player's own data.
final explorerProfileProvider = Provider<ExplorerProfile>((ref) {
  final region = ref.watch(regionPackSourceProvider);
  final trail = ref.watch(exploredAreaProvider).value ?? const ExploredArea.empty();
  final radius =
      ref.watch(fogSettingsProvider).value?.clearingRadiusMeters ??
      ExplorationRules.fogClearingRadiusMeters;
  final boundaries =
      ref.watch(districtBoundariesProvider).value ??
      DistrictBoundaries.empty(region.regionId);
  final walk = ref.watch(walkHistoryProvider).value ?? const WalkHistory.empty();

  final points = ref.watch(mapPointsProvider).value ?? const <MapPoint>[];
  final visits =
      ref.watch(placeVisitsProvider).value ?? const <String, PlaceVisit>{};

  // The charting grid, once. Both the headline and every district row are
  // counted off the same cells, so the parts add up to the whole.
  final cells = ChartingRules.cellsOf(trail, radius);
  final cellArea = ChartingRules.cellAreaSquareMeters(radius);

  final cellsPerDistrict = <String, int>{};
  for (final cell in cells) {
    final district = boundaries.at(ChartingRules.centreOf(cell, radius));
    if (district == null) continue;
    cellsPerDistrict[district.id] = (cellsPerDistrict[district.id] ?? 0) + 1;
  }

  final districts = <DistrictProgress>[];
  for (final district in boundaries.districts) {
    final charted = cellsPerDistrict[district.id];
    if (charted == null) continue;
    districts.add(
      DistrictProgress(
        id: district.id,
        name: district.name,
        chartedFraction: ChartingRules.fractionOf(
          charted,
          district.areaSquareMeters,
          radius,
        ),
        chartedSquareMeters: charted * cellArea,
        areaSquareMeters: district.areaSquareMeters,
      ),
    );
  }

  // Most walked first: the district somebody has covered the most ground in is
  // the one they want to see at the top, whatever its size.
  districts.sort(
    (a, b) => b.chartedSquareMeters.compareTo(a.chartedSquareMeters),
  );

  final checkInPlaces =
      points.where((point) => point.checkInCount > 0).length +
      visits.values.where((visit) => visit.hasVisited).length;

  final xp = ProgressionRules.xpFor(
    places: checkInPlaces,
    districts: districts.length,
    meters: walk.distanceTotalMeters,
  );

  return ExplorerProfile(
    regionId: region.regionId,
    regionName: region.name,
    displayName: ref.watch(displayNameProvider).value ?? '',
    avatarPath: ref.watch(avatarPathProvider).value,
    level: ProgressionRules.levelFor(xp),
    xp: xp,
    chartedSquareMeters: cells.length * cellArea,
    walk: walk,
    checkInPlaces: checkInPlaces,
    districts: districts,
    districtsKnown: boundaries.districts.length,
  );
});

final logEntriesProvider = StreamProvider<List<LogEntry>>((ref) {
  return ref.watch(logRepositoryProvider).watchEntries();
});

final questsProvider = StreamProvider<List<Quest>>((ref) {
  return ref.watch(questRepositoryProvider).watchQuests();
});

final weeklyChallengeProvider = StreamProvider<WeeklyChallenge>((ref) {
  return ref.watch(questRepositoryProvider).watchWeeklyChallenge();
});

/// How far the NEARBY list reaches. A setting, so a player in a quiet suburb
/// can widen it and one in the centre can cut it down.
final nearbyRadiusProvider = StreamProvider<double>((ref) {
  return ref.watch(preferencesRepositoryProvider).watchNearbyRadiusMeters();
});

/// Places close enough to matter, nearest first.
final nearbyPlacesProvider = StreamProvider<List<Place>>((ref) {
  final radiusMeters =
      ref.watch(nearbyRadiusProvider).value ??
      ExplorationRules.defaultNearbyRadiusMeters;

  return ref
      .watch(worldRepositoryProvider)
      .watchNearbyPlaces(radiusMeters: radiusMeters);
});

/// The same places with how far each one is, closest first — what the NEARBY
/// tab lists.
///
/// The distances are measured here rather than taken from the repository: the
/// contract promises a set of places, not an order or a distance, and the
/// number on screen has to count down as the player walks. Sorting on top of a
/// list a remote implementation might return unsorted costs nothing at this
/// size and removes a way for the list to look wrong.
final nearbyPlacesByDistanceProvider = Provider<List<(Place, double)>>((ref) {
  final nearby = ref.watch(nearbyPlacesProvider).value ?? const <Place>[];
  final position = ref.watch(playerPositionProvider).value;
  if (position == null) return const [];

  return nearby
      .map((place) => (place, position.distanceTo(place.location)))
      .toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));
});

/// Places the player is actually allowed to claim right now. The check-in
/// sheet only ever offers these, so it cannot suggest something the rules would
/// then refuse.
final checkInCandidatesProvider = Provider<List<Place>>((ref) {
  final nearby = ref.watch(nearbyPlacesProvider).value ?? const <Place>[];
  // Measured against the *watched* position, so walking towards a place makes
  // it claimable and walking away stops it. Reading the store directly would
  // never recompute, because the store instance never changes.
  final position = ref.watch(playerPositionProvider).value;
  if (position == null) return const [];

  return nearby
      .where(
        (place) =>
            position.distanceTo(place.location) <=
            ExplorationRules.checkInRadiusMeters,
      )
      .toList();
});

/// The single place the check-in prompt is about: the closest one.
final checkInCandidateProvider = Provider<Place?>((ref) {
  final candidates = ref.watch(checkInCandidatesProvider);
  return candidates.isEmpty ? null : candidates.first;
});

/// The closest known place at any distance, and how far it is.
///
/// Unlike [checkInCandidateProvider] this is not limited by a radius: the
/// nearby card is always on screen, and when there is nothing to claim it still
/// points at the nearest thing rather than going blank. Null only when the
/// world knows of no places at all.
final nearestPlaceProvider = Provider<(Place, double)?>((ref) {
  final position = ref.watch(playerPositionProvider).value;
  final places = ref.watch(placesProvider).value ?? const <Place>[];
  if (position == null || places.isEmpty) return null;

  return places
      .map((place) => (place, position.distanceTo(place.location)))
      .reduce((a, b) => a.$2 <= b.$2 ? a : b);
});

/// Distance from the player to a place, in metres.
///
/// Watches the position rather than asking the store, so the "40 m away" on the
/// nearby card counts down as you walk instead of being the distance from
/// wherever the app happened to start.
final distanceToPlaceProvider = Provider.family<double, Place>((ref, place) {
  final position = ref.watch(playerPositionProvider).value;
  return position?.distanceTo(place.location) ?? double.infinity;
});

/// Result of the last check-in.
///
/// The check-in sheet writes it, the map reads it to decide whether to show the
/// district-discovered celebration once the sheet has closed. Cleared as soon
/// as it has been consumed so a rebuild cannot replay the celebration.
class LastCheckInResult extends Notifier<CheckInResult?> {
  @override
  CheckInResult? build() => null;

  /// A named verb reads better at the call site than assigning to a
  /// controller's state from the outside.
  // ignore: use_setters_to_change_properties
  void record(CheckInResult result) => state = result;

  CheckInResult? take() {
    final result = state;
    state = null;
    return result;
  }
}

final lastCheckInResultProvider =
    NotifierProvider<LastCheckInResult, CheckInResult?>(LastCheckInResult.new);
