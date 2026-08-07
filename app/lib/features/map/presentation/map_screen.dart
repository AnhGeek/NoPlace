import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/shell/home_shell.dart';
import '../../../core/ui/np_async_view.dart';
import '../../../data/local/region_pack_store.dart';
import '../../../data/repository_providers.dart';
import '../../../design_system/components/components.dart';
import '../../../design_system/tokens/design_tokens.g.dart';
import '../../../domain/entities/explored_area.dart';
import '../../../domain/entities/fog_settings.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/map_layer_visibility.dart';
import '../../../domain/entities/map_point.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../l10n/l10n.dart';
import '../../check_in/presentation/check_in_sheet.dart';
import '../../places/presentation/place_sheet.dart';
import 'basemap/basemap.dart';
import 'basemap/basemap_attribution.dart';
import 'map_controller.dart';
import 'picture_point_thumbnails.dart';
import 'place_visuals.dart';
import 'widgets/add_place_button.dart';
import 'widgets/background_permission_sheet.dart';
import 'widgets/fog_toggle_button.dart';
import 'widgets/location_banner.dart';
import 'widgets/map_canvas.dart';
import 'widgets/nearby_card.dart';
import 'widgets/nearby_list.dart';
import 'widgets/recentre_button.dart';
import 'widgets/region_arrival_sheet.dart';

/// The home screen: the city, the fog, and the one thing worth doing next.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  /// One cache for the life of the screen, so panning past the same photo point
  /// does not decode its image again.
  final PicturePointThumbnails _thumbnails = PicturePointThumbnails();

  /// Whether the camera is tracking the GPS.
  ///
  /// True until the player drags or pinches, then false until they ask for it
  /// back. Following unconditionally means a fix every few metres pulls the map
  /// out from under a thumb that is trying to look somewhere else — which reads
  /// as the map fighting you, because it is.
  bool _following = true;

  /// Whether the camera has already been put on a real fix.
  ///
  /// Until it has, the map is showing the seeded start point, and the first fix
  /// takes the camera whatever the player has done with it — that is the app
  /// correcting a guess, not the map fighting them for control. After it has,
  /// [_following] decides, as it should.
  bool _openedOnPlayer = false;

  /// A move that arrived before the camera existed.
  ///
  /// [MapController.move] throws until flutter_map's first frame, and the fix
  /// the app opens with is very often earlier than that — it comes from the
  /// OS's last known position, read during start-up. Dropping it would leave
  /// the map on the seed point until the player walked far enough to trigger a
  /// second fix, which with a 25 m filter can be a long wait for somebody
  /// sitting down.
  ({GeoPoint position, double zoom})? _pendingMove;

  /// Re-reads everything that can change while we are not looking, when the app
  /// comes back to the foreground.
  ///
  /// Without this, a player who taps "Open settings", grants the permission and
  /// returns lands on the same banner telling them to do what they just did.
  ///
  /// It is also where a walk repairs itself: a position stream that failed in a
  /// pocket cannot be restarted from the background — that would mean starting
  /// a foreground service from the background, which Android 12 forbids — so
  /// [GeolocatorLocationRepository.refresh] holds the restart until here.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_onResume()));
  }

  /// Answers "where am I *now*" every time the app comes back.
  ///
  /// Two steps: repair whatever broke while we were away, then ask the OS for a
  /// current fix rather than waiting for the stream to notice movement. A
  /// marker still sitting on the street you left an hour ago is the map
  /// answering the one question it exists to answer wrong.
  ///
  /// It deliberately stops there. **Taking hold of the camera is a cold-start
  /// move, not a resume one** — opening the app is the player asking where they
  /// are, but flicking back from a message is them returning to a map they had
  /// already put where they wanted it, and yanking it to the player at the
  /// opening zoom throws that away. The fresh fix still moves the camera when
  /// [_following] is on, which is ordinary follow behaviour and stays at the
  /// zoom they chose; [RecentreButton] is how somebody who wants the jump asks
  /// for it.
  Future<void> _onResume() async {
    final location = ref.read(locationRepositoryProvider);

    await location.refresh();
    if (!mounted) return;

    await location.refreshPosition();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _mapController.dispose();
    _thumbnails.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = ref.watch(mapScopeProvider);
    final places = ref.watch(placesProvider);
    final position = ref.watch(playerPositionProvider).value;
    final exploredArea =
        ref.watch(exploredAreaProvider).value ?? const ExploredArea.empty();
    final mapPoints = ref.watch(mapPointsProvider).value ?? const <MapPoint>[];
    final visibility =
        ref.watch(mapLayerVisibilityProvider).value ??
        const MapLayerVisibility();
    final fogSettings =
        ref.watch(fogSettingsProvider).value ?? const FogSettings();
    final candidate = ref.watch(checkInCandidateProvider);
    final nearest = ref.watch(nearestPlaceProvider);

    // Keep the trail recorder and the precision sync alive while the map is.
    ref
      ..watch(trailRecorderProvider)
      ..watch(trailPrecisionSyncProvider)
      ..watch(trailRegionSyncProvider)
      // An hour spent at a place the player saved is a check-in they never had
      // to tap for. Alive with the map, like the trail.
      ..watch(placePresenceProvider)
      // Puts the visits recorded on this device back onto the freshly seeded
      // world, so a place checked into last week is not offered as new.
      ..watch(placeVisitSyncProvider)
      // Starts the GPS and the foreground service, and feeds every fix into
      // the world. Alive for as long as the map is.
      ..watch(locationSyncProvider);

    // The one-time background question. Deliberately not on first launch: it
    // waits until location is actually working, so the player has already said
    // yes to the permission this one builds on and has the map in front of them
    // to make sense of the ask.
    ref
      ..listen<AsyncValue<bool>>(batteryOptimisedProvider, (previous, next) {
        _maybeAskAboutBackground();
      })
      ..listen<AsyncValue<LocationAvailability>>(
        locationAvailabilityProvider,
        (previous, next) => _maybeAskAboutBackground(),
      )
      // All three arrive asynchronously and in no fixed order, so every one of
      // them has to re-ask the question. Reading a provider nobody listens to
      // would answer "still loading" forever.
      ..listen<AsyncValue<bool>>(
        backgroundPromptSeenProvider,
        (previous, next) => _maybeAskAboutBackground(),
      )
      // Walking into a new region is a moment, not a silent swap: the streets
      // change and so does the fog. Say so, and let the player choose which
      // map they want while the answer is in front of them.
      ..listen<RegionPackSource?>(
        regionArrivalProvider,
        (previous, next) => _maybeAnnounceRegion(),
      );

    // Keep the camera on the player, but only while they want it there.
    //
    // `MapOptions.initialCenter` is exactly that — initial. Without any follow
    // the marker walks off the edge of a stationary map; with an unconditional
    // one, dragging is impossible. `_following` is the difference, and
    // [RecentreButton] is how it comes back.
    ref.listen<AsyncValue<GeoPoint>>(playerPositionProvider, (previous, next) {
      final position = next.value;
      if (position == null) return;

      // The first real fix is not a follow, it is the answer to "where am I" —
      // so it lands at the opening zoom and ignores the follow flag. Until the
      // GPS has said anything the position is a seeded placeholder, and moving
      // the camera onto it would only make the wrong city look deliberate.
      if (!_openedOnPlayer) {
        if (!hasRealPosition(ref)) return;
        _openedOnPlayer = true;
        _moveTo(position, mapDefaultZoom);
        return;
      }

      if (!_following) return;
      _moveTo(position, _mapController.camera.zoom);
    });

    return NpAsyncView<List<Place>>(
      value: places,
      data: (places) {
        // Until the first fix arrives there is nowhere to centre but the city.
        final playerPosition =
            position ??
            ref.watch(currentCityProvider).value?.center ??
            const GeoPoint(10.7725, 106.6980);

        // The two scopes are two screens sharing one header, not one screen
        // with two zooms: NEARBY is a list, so the map is not built at all
        // while it is showing. Building it offstage would keep the tile
        // renderer working for something nobody can see.
        final showMap = scope == MapScope.city;

        return Stack(
          children: [
            if (showMap) ...[
              Positioned.fill(
                child: MapCanvas(
                  mapController: _mapController,
                  basemap: ref.watch(basemapProvider),
                  center: playerPosition,
                  zoom: mapDefaultZoom,
                  playerPosition: playerPosition,
                  places: places,
                  mapPoints: mapPoints,
                  exploredArea: exploredArea,
                  visibility: visibility,
                  fogSettings: fogSettings,
                  thumbnails: _thumbnails,
                  onPlaceTap: _openCheckInSheet,
                  onMapPointTap: _openPlaceSheet,
                  onLongPress: _addPlaceAt,
                  onUserMovedMap: _stopFollowing,
                  onMapReady: _onMapReady,
                  playerLabel: candidate == null
                      ? null
                      : YouAreHereChip(
                          placeName: placeDisplayName(candidate, l10n),
                        ),
                ),
              ),
              const _TopScrim(),
            ],
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  NpTopTabs<MapScope>(
                    selected: scope,
                    onChanged: _onScopeChanged,
                    tabs: [
                      NpTopTab(value: MapScope.city, label: l10n.mapTabCity),
                      NpTopTab(
                        value: MapScope.nearby,
                        label: l10n.mapTabNearby,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NpSpace.lg,
                      NpSpace.md,
                      NpSpace.lg,
                      0,
                    ),
                    child: NpSearchField(
                      hintText: l10n.mapSearchHint,
                      readOnly: true,
                      onTap: _onSearchTap,
                    ),
                  ),

                  // A licence condition of the map data. Only where the data is
                  // actually drawn — the list shows no tiles to attribute.
                  if (showMap)
                    BasemapAttribution(basemap: ref.watch(basemapProvider)),

                  // Only present when there is something wrong the player can
                  // fix — no permission, or the location service switched off.
                  // On both scopes: the list needs a position as much as the
                  // map does.
                  const LocationBanner(),

                  // The second way a walk goes missing: everything is granted
                  // and the phone still puts the app to sleep in a pocket.
                  const BackgroundSleepBanner(),

                  if (!showMap)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NpSpace.lg,
                        ),
                        child: NearbyList(onCheckIn: _openCheckInSheet),
                      ),
                    ),
                ],
              ),
            ),
            // Always on screen, so the bottom of the map does not jump as you
            // walk in and out of range.
            //
            // `bottomInsetFor` rather than a hand-written offset: it adds the
            // system inset, which is 0 on a button-nav phone and ~34 dp with
            // gesture navigation. The old constant ignored it, which is why
            // the card sat under the nav bar on some phones.
            //
            // The recentre button rides in the same column rather than being
            // positioned on its own, so the two can never be measured apart
            // and end up on top of each other.
            if (showMap)
              Positioned(
                left: NpSpace.md,
                right: NpSpace.md,
                bottom: HomeShell.bottomInsetFor(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FogToggleButton(
                      fogVisible: visibility.showFog,
                      onPressed: () => _toggleFog(visible: !visibility.showFog),
                    ),
                    const SizedBox(height: NpSpace.sm),
                    RecentreButton(following: _following, onPressed: _recentre),
                    const SizedBox(height: NpSpace.sm),
                    // Closest to the thumb of the three, because it is the one
                    // that gets used while standing somewhere rather than while
                    // looking at the map.
                    AddPlaceButton(onPressed: () => _addPlaceAt(null)),
                    const SizedBox(height: NpSpace.sm),
                    switch (nearest) {
                      null => const NearbyCard.empty(),
                      (final place, final distance) => NearbyCard(
                        place: place,
                        distanceMeters: distance,
                        // Only the check-in candidate is claimable; the
                        // nearest place may be kilometres away.
                        inRange: candidate != null && candidate.id == place.id,
                        onCheckIn: candidate == null
                            ? null
                            : () => _openCheckInSheet(candidate),
                        onCorrect: candidate == null
                            ? null
                            : () => _openCheckInSheet(candidate),
                      ),
                    },
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Whether the background sheet is already up or has been this session.
  ///
  /// Three streams can land within a frame of each other and all three would
  /// otherwise open it; the persisted flag is only written once the player has
  /// answered, which is too late to stop the second sheet.
  bool _asking = false;

  /// Puts the background question when, and only when, all of it is true: the
  /// GPS is working, the phone can still freeze us, and we have not asked
  /// before.
  void _maybeAskAboutBackground() {
    if (_asking || !mounted) return;

    final ready =
        ref.read(locationAvailabilityProvider).value ==
        LocationAvailability.ready;
    final optimised = ref.read(batteryOptimisedProvider).value ?? false;
    final seen = ref.read(backgroundPromptSeenProvider).value ?? true;
    if (!ready || !optimised || seen) return;

    _asking = true;
    unawaited(showBackgroundPermissionSheet(context: context, ref: ref));
  }

  /// Whether an arrival sheet is on screen.
  ///
  /// A crossing can be recorded while the check-in or background sheet is up,
  /// and two modal sheets stacked on one screen is how a player ends up
  /// dismissing one they never saw the top of.
  bool _announcing = false;

  /// Announces the region the player has just walked into, once.
  ///
  /// [RegionArrival.take] clears the arrival as it reads it, so a rebuild — a
  /// fix every few metres, a tab change — cannot replay the sheet for a border
  /// that was crossed a kilometre ago.
  Future<void> _maybeAnnounceRegion() async {
    if (_announcing || !mounted) return;

    final arrived = ref.read(regionArrivalProvider.notifier).take();
    if (arrived == null) return;

    _announcing = true;
    try {
      await showRegionArrivalSheet(context: context, arrived: arrived);
    } finally {
      _announcing = false;
    }

    // A border crossed while the sheet was open was recorded and not shown —
    // the listener fired into the guard above. Somebody who walks out of one
    // region and into another without closing the sheet must still be told
    // where they ended up.
    if (mounted && ref.read(regionArrivalProvider) != null) {
      unawaited(_maybeAnnounceRegion());
    }
  }

  /// The player took hold of the map. Stop pulling it back.
  ///
  /// Called from `onPositionChanged` with `hasGesture: true`, so our own
  /// [_moveTo] cannot trigger it and turn following off by following.
  void _stopFollowing() {
    if (_following) setState(() => _following = false);
  }

  /// Back to the player, at the zoom the app opens with.
  ///
  /// Restores the zoom deliberately rather than keeping the current one: this
  /// is the way out of being lost, and somebody who has zoomed out to the whole
  /// province wants their street back, not the province re-centred.
  void _recentre() {
    final position = ref.read(playerPositionProvider).value;
    setState(() => _following = true);
    if (position == null) return;
    _moveTo(position, mapDefaultZoom);
  }

  /// Lifts the fog, or puts it back.
  ///
  /// Written straight to preferences rather than held in this State: the choice
  /// is remembered like the other layers, and the map reads it from the same
  /// stream the settings screen does — so there is one answer to "is the fog
  /// on", not two that can disagree.
  void _toggleFog({required bool visible}) {
    unawaited(
      ref.read(preferencesRepositoryProvider).setFogVisible(visible: visible),
    );
  }

  void _moveTo(GeoPoint position, double zoom) {
    try {
      _mapController.move(position.toLatLng(), zoom);
      _pendingMove = null;
    } on Object {
      // The controller is not attached until the map's first frame; a fix that
      // arrives before it is simply early, not an error. Held rather than
      // dropped — see [_pendingMove].
      _pendingMove = (position: position, zoom: zoom);
    }
  }

  /// The camera exists now. Anything that arrived before it can be applied.
  void _onMapReady() {
    // A fix that landed before this build is already in `initialCenter`, so the
    // map was born on the player and there is nothing to correct. Saying so
    // here is what stops the *next* fix yanking the camera back from somebody
    // who has since panned away.
    if (hasRealPosition(ref)) _openedOnPlayer = true;

    final pending = _pendingMove;
    if (pending == null) return;
    _pendingMove = null;

    // Next frame, not this one: `onMapReady` fires while flutter_map is still
    // building, and moving the camera from inside its own build is how you get
    // a "setState during build" out of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _moveTo(pending.position, pending.zoom);
    });
  }

  /// Switching scopes tears the map down and builds it again, so there is no
  /// camera to move here — only the follow flag to restore.
  ///
  /// The rebuilt map opens centred on the player at [mapDefaultZoom], which is
  /// what somebody coming back from the list wants: they left the map to look
  /// at what is around them, not to keep a viewport.
  void _onScopeChanged(MapScope scope) {
    ref.read(mapScopeProvider.notifier).select(scope);
    if (scope == MapScope.city && !_following) {
      setState(() => _following = true);
    }
  }

  /// Saves a place: at [location] for a long press, at the player for the
  /// button.
  ///
  /// The button falls back to the map's centre when there is no fix yet, so the
  /// control is never a dead end — somebody with location switched off can
  /// still keep a list of places, they just have to aim.
  Future<void> _addPlaceAt(GeoPoint? location) async {
    final at =
        location ?? ref.read(playerPositionProvider).value ?? _cameraCentre();
    if (at == null) return;

    final result = await showAddPlaceSheet(context: context, location: at);
    _announce(result);
  }

  /// Where the map is looking, or null before it has been built — the same
  /// "the camera does not exist yet" case [_moveTo] handles.
  GeoPoint? _cameraCentre() {
    try {
      final centre = _mapController.camera.center;
      return GeoPoint(centre.latitude, centre.longitude);
    } on Object {
      return null;
    }
  }

  /// Tapping one of the player's own points: rate it, rename it, check in, or
  /// delete it.
  Future<void> _openPlaceSheet(MapPoint point) async {
    final result = await showPlaceSheet(context: context, place: point);
    _announce(result);
  }

  /// Says what the sheet did, and — for a deletion — offers the way back.
  void _announce(PlaceSheetResult? result) {
    if (!mounted || result == null) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        placeOutcomeSnackBar(
          result: result,
          l10n: context.l10n,
          onUndo: () =>
              unawaited(ref.read(mapPointRepositoryProvider).add(result.place)),
        ),
      );
  }

  void _onSearchTap() {
    // Search lands with the places API; until then the field is a visible
    // promise rather than a dead end.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.l10n.mapSearchHint)));
  }

  Future<void> _openCheckInSheet(Place place) async {
    final result = await showCheckInSheet(context: context, place: place);
    if (!mounted || result == null) return;

    final district = result.districtDiscovered;
    if (district != null) {
      await context.pushNamed<void>(AppRoute.discoveryName, extra: district);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.checkInSuccess(
              placeDisplayName(result.place, context.l10n),
            ),
          ),
        ),
      );
  }
}

/// What the map says after the place sheet has closed.
///
/// Built here rather than inline so the one thing that has already gone wrong
/// with it can be tested: a message that outstays its welcome is a bug the
/// widget test can catch, and only if it can get hold of the bar itself.
SnackBar placeOutcomeSnackBar({
  required PlaceSheetResult result,
  required AppL10n l10n,
  required VoidCallback onUndo,
}) {
  final name = mapPointDisplayName(result.place, l10n);
  final deleted = result.outcome == PlaceSheetOutcome.deleted;

  return SnackBar(
    // Said out loud because the default is the opposite: a `SnackBar` carrying
    // an action defaults to `persist: action != null`, so the undo below would
    // keep this bar on screen *for ever*. It never times out, and the only ways
    // out are tapping Undo — the one thing somebody who meant the deletion does
    // not want — or swiping a bar most people do not know is swipeable.
    // Deleting a place left a message sitting over the map until the app was
    // restarted.
    persist: false,
    // Longer than the 4s default when there is something to undo: that window
    // is not a confirmation, it is the whole chance to take the deletion back,
    // and four seconds is not enough to read a name and change your mind.
    duration: Duration(seconds: deleted ? 8 : 4),
    content: Text(switch (result.outcome) {
      PlaceSheetOutcome.saved => l10n.placeSaved(name),
      PlaceSheetOutcome.checkedIn => l10n.placeCheckedIn(name),
      PlaceSheetOutcome.deleted => l10n.placeDeleted(name),
    }),
    // The place goes back exactly as it was, id and check-in count included:
    // this is an undo, not a second attempt at making it.
    action: deleted
        ? SnackBarAction(label: l10n.placeUndo, onPressed: onUndo)
        : null,
  );
}

/// Keeps the tabs and the search field legible over bright map tiles.
class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF20D0D0F), Color(0x000D0D0F)],
              stops: [0.45, 1],
            ),
          ),
        ),
      ),
    );
  }
}
