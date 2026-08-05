import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/shell/home_shell.dart';
import '../../../core/ui/np_async_view.dart';
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
import 'basemap/basemap.dart';
import 'basemap/basemap_attribution.dart';
import 'map_controller.dart';
import 'picture_point_thumbnails.dart';
import 'place_visuals.dart';
import 'widgets/background_permission_sheet.dart';
import 'widgets/fog_toggle_button.dart';
import 'widgets/location_banner.dart';
import 'widgets/map_canvas.dart';
import 'widgets/nearby_card.dart';
import 'widgets/nearby_list.dart';
import 'widgets/recentre_button.dart';

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
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(ref.read(locationRepositoryProvider).refresh()),
    );
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
                  onMapPointTap: _showMapPoint,
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

  /// Tapping the player's own point. A proper detail sheet — rename, change
  /// icon, view the photo full size, delete — lands with the authoring flows;
  /// until then, say what it is rather than doing nothing.
  void _showMapPoint(MapPoint point) {
    final label = point.label.isNotEmpty
        ? point.label
        : switch (point.kind) {
            MapPointKind.picture => context.l10n.settingsHidePicturePoints,
            _ => context.l10n.settingsHideUserPoints,
          };

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(label)));
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
