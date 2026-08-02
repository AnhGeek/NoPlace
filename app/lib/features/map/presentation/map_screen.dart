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
import '../../../l10n/l10n.dart';
import '../../check_in/presentation/check_in_sheet.dart';
import 'basemap/basemap.dart';
import 'basemap/basemap_attribution.dart';
import 'map_controller.dart';
import 'picture_point_thumbnails.dart';
import 'place_visuals.dart';
import 'widgets/location_banner.dart';
import 'widgets/map_canvas.dart';
import 'widgets/nearby_card.dart';
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

  /// Re-reads the permission and location-service state when the app comes
  /// back to the foreground.
  ///
  /// Without this, a player who taps "Open settings", grants the permission and
  /// returns lands on the same banner telling them to do what they just did.
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

    // Keep the camera on the player, but only while they want it there.
    //
    // `MapOptions.initialCenter` is exactly that — initial. Without any follow
    // the marker walks off the edge of a stationary map; with an unconditional
    // one, dragging is impossible. `_following` is the difference, and
    // [RecentreButton] is how it comes back.
    ref.listen<AsyncValue<GeoPoint>>(playerPositionProvider, (previous, next) {
      if (!_following) return;
      final position = next.value;
      if (position == null) return;
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

        return Stack(
          children: [
            Positioned.fill(
              child: MapCanvas(
                mapController: _mapController,
                basemap: ref.watch(basemapProvider),
                center: playerPosition,
                zoom: scope.zoom,
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
                playerLabel: candidate == null
                    ? null
                    : YouAreHereChip(
                        placeName: placeDisplayName(candidate, l10n),
                      ),
              ),
            ),
            const _TopScrim(),
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

                  // A licence condition of the map data. Here because it is
                  // the one strip of the screen that is over the map and never
                  // covered by anything.
                  BasemapAttribution(basemap: ref.watch(basemapProvider)),

                  // Only present when there is something wrong the player can
                  // fix — no permission, or the location service switched off.
                  const LocationBanner(),
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
            Positioned(
              left: NpSpace.md,
              right: NpSpace.md,
              bottom: HomeShell.bottomInsetFor(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RecentreButton(
                    following: _following,
                    onPressed: _recentre,
                  ),
                  const SizedBox(height: NpSpace.sm),
                  switch (nearest) {
                    null => const NearbyCard.empty(),
                    (final place, final distance) => NearbyCard(
                      place: place,
                      distanceMeters: distance,
                      // Only the check-in candidate is claimable; the nearest
                      // place may be kilometres away.
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
    _moveTo(position, ref.read(mapScopeProvider).zoom);
  }

  void _moveTo(GeoPoint position, double zoom) {
    try {
      _mapController.move(position.toLatLng(), zoom);
    } on Object {
      // The controller is not attached until the map's first frame; a fix that
      // arrives before it is simply early, not an error.
    }
  }

  void _onScopeChanged(MapScope scope) {
    ref.read(mapScopeProvider.notifier).select(scope);
    _mapController.move(_mapController.camera.center, scope.zoom);
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
