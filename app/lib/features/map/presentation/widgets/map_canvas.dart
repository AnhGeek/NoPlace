import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../../../design_system/components/components.dart';
import '../../../../design_system/tokens/design_tokens.g.dart';
import '../../../../domain/entities/explored_area.dart';
import '../../../../domain/entities/fog_settings.dart';
import '../../../../domain/entities/geo_point.dart';
import '../../../../domain/entities/map_layer_visibility.dart';
import '../../../../domain/entities/map_point.dart';
import '../../../../domain/entities/place.dart';
import '../basemap/basemap.dart';
import '../picture_point_thumbnails.dart';
import '../place_visuals.dart';

/// The map: fog of war, the player's points and the player.
///
/// Everything above this widget in the stack is chrome; everything in it is the
/// world. Kept free of Riverpod so it can be dropped into a golden test with
/// plain data.
class MapCanvas extends StatelessWidget {
  const MapCanvas({
    required this.center,
    required this.zoom,
    required this.playerPosition,
    required this.places,
    required this.mapPoints,
    required this.exploredArea,
    required this.visibility,
    required this.fogSettings,
    required this.thumbnails,
    required this.onPlaceTap,
    required this.onMapPointTap,
    this.onLongPress,
    this.basemap,
    this.playerLabel,
    this.mapController,
    this.onUserMovedMap,
    this.onMapReady,
    super.key,
  });

  /// Called once the camera exists and will accept a move.
  ///
  /// [MapController] throws until flutter_map's first frame, so a position that
  /// arrives before it — which the last known fix usually does — has nowhere to
  /// go. This is the screen's cue to apply it.
  final VoidCallback? onMapReady;

  /// Called when the *player* moves the camera — a drag or a pinch — and never
  /// when we move it ourselves.
  ///
  /// This is what lets the screen above stop following the GPS the moment
  /// somebody starts looking around. Without it, every fix yanks the map back
  /// under their thumb.
  final VoidCallback? onUserMovedMap;

  /// The streets, if this region has a pack. Null draws no basemap at all,
  /// which is a supported state and not an error — see
  /// docs/adr/0008-openstreetmap-basemap.md.
  final Basemap? basemap;

  final GeoPoint center;
  final double zoom;
  final GeoPoint playerPosition;

  /// Suggested points, from the world data.
  final List<Place> places;

  /// The player's own points: dropped pins and photo points.
  final List<MapPoint> mapPoints;

  /// Everywhere already uncovered — read from the device at start-up, so the
  /// city looks exactly as the player left it.
  final ExploredArea exploredArea;

  /// Which of the three kinds of point to draw.
  final MapLayerVisibility visibility;

  /// How far one position uncovers, and how finely the trail is recorded.
  final FogSettings fogSettings;

  /// Decodes photo-point images at pin size, once each.
  final PicturePointThumbnails thumbnails;

  final ValueChanged<Place> onPlaceTap;
  final ValueChanged<MapPoint> onMapPointTap;

  /// Press and hold anywhere on the map. Saves a place at that coordinate
  /// rather than at the player — for the bar you walked past and did not stop
  /// at, and for the one you are looking at across the river.
  final ValueChanged<GeoPoint>? onLongPress;

  /// Floats above the player marker. Anchored to the coordinate, so panning the
  /// map moves the label with the street it describes.
  final Widget? playerLabel;

  final MapController? mapController;

  /// Height of the invisible box that lifts the "you are here" chip above the
  /// player marker and any pin sharing the same corner.
  static const double _playerLabelClearance = 96;

  /// Zoom floor when there is no pack to ask. Wide enough to see a province,
  /// tight enough that the world never repeats across the screen.
  static const double _fallbackMinZoom = 8;

  /// Zoom ceiling. Past the pack's own maximum the renderer scales its deepest
  /// tile, so this is about how close is *useful* on foot, not about data.
  static const double _maxZoom = 18;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center.toLatLng(),
        initialZoom: zoom,

        // Zooming is clamped to what the pack actually contains.
        //
        // Without this the map has no floor: pinch out past the pack's minimum
        // zoom and every tile request misses, so the basemap and the city
        // border vanish and the screen goes black. Worse, once the whole world
        // is narrower than the screen, flutter_map repeats it horizontally and
        // the player marker is drawn once per copy — a row of identical dots
        // that reads as a bug because it is one.
        //
        // The ceiling is deliberately *above* the pack's maximum: the renderer
        // scales the deepest tile it has, so pinching in past 15 on a pack that
        // stops there still draws. Nothing is missing up there, only softer.
        minZoom: basemap?.info.minZoom.toDouble() ?? _fallbackMinZoom,
        maxZoom: _maxZoom,

        // With no basemap, this colour *is* the uncovered world: the fog is
        // opaque black, and erasing it reveals this. Explored ground has to be
        // visibly lighter or walking would change nothing on screen.
        backgroundColor: NpColors.backgroundExploredGround,
        interactionOptions: const InteractionOptions(
          // No rotation: a north-up map is easier to match to the street, and
          // the fog mask stays cheap to compute.
          flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
        ),

        // `hasGesture` is the whole point: it is true for a drag or a pinch and
        // false for our own `move()`, so following can be cancelled by the
        // player without the act of following cancelling itself.
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) onUserMovedMap?.call();
        },

        // A long press, not a tap: a tap on the map is how you miss a pin, and
        // turning every near-miss into a new place would fill the city with
        // accidents.
        onLongPress: onLongPress == null
            ? null
            : (_, point) =>
                  onLongPress!(GeoPoint(point.latitude, point.longitude)),

        onMapReady: onMapReady,
      ),
      children: [
        // The streets, drawn first and therefore underneath everything. The
        // fog above decides how much of them the player has earned.
        //
        // Vector tiles from our own region pack, styled at runtime from the
        // design tokens — so there is no vendor, no API key and no tile bill,
        // and the map cannot drift from the app it sits under.
        if (basemap != null)
          VectorTileLayer(
            // Keyed on the region, so crossing a border builds a new layer
            // instead of handing the old one a different pack. The renderer
            // keeps caches and in-flight tile futures of its own, and those
            // belong to the pack they were started against.
            key: ValueKey('basemap-${basemap!.info.regionId}'),
            theme: basemap!.theme,
            tileProviders: basemap!.tileProviders,
            // The tiles are already on the device. A second, redundant copy in
            // the library's own file cache would cost the player storage for
            // nothing.
            fileCacheTtl: Duration.zero,
            fileCacheMaximumSizeInBytes: 0,
          ),

        // Hidden, not emptied: the trail underneath is untouched and the walk
        // keeps recording, so turning the fog back on shows exactly the ground
        // that had been earned while it was off.
        if (visibility.showFog)
          _FogLayer(
            playerPosition: playerPosition,
            exploredArea: exploredArea,
            settings: fogSettings,
          ),

        // The city's edge, over the fog.
        //
        // The only piece of map allowed through: everything else is earned by
        // walking, but a player needs to see the shape of the thing they are
        // exploring, or unexplored ground is just black in every direction with
        // no sense of how much is left.
        if (basemap != null)
          VectorTileLayer(
            key: ValueKey('city-border-${basemap!.info.regionId}'),
            theme: basemap!.cityBorderTheme,
            tileProviders: basemap!.tileProviders,
            fileCacheTtl: Duration.zero,
            fileCacheMaximumSizeInBytes: 0,
          ),

        // Everything below is drawn *after* the fog, and therefore on top of
        // it. Points stay visible in unexplored ground on purpose: a suggestion
        // you cannot see is not a suggestion.
        MarkerLayer(
          markers: [
            if (visibility.showSuggested)
              for (final place in places)
                Marker(
                  point: place.location.toLatLng(),
                  width: NpSize.mapPin + NpSpace.xs,
                  height: NpSize.mapPin + NpSpace.xs,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => onPlaceTap(place),
                    child: NpMapPin(
                      icon: place.category.icon,
                      color: place.category.color,
                    ),
                  ),
                ),
            for (final point in mapPoints)
              if (visibility.isVisible(point.kind))
                Marker(
                  point: point.location.toLatLng(),
                  width: NpSize.mapPin + NpSpace.xs,
                  height: NpSize.mapPin + NpSpace.xs,
                  alignment: point.kind == MapPointKind.picture
                      ? Alignment.center
                      : Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => onMapPointTap(point),
                    child: point.kind == MapPointKind.picture
                        ? NpPicturePin(
                            image: thumbnails.thumbnailFor(point.imagePath),
                          )
                        : NpMapPin(
                            icon: userPointIcon(point.iconId),
                            color: NpColors.statusRare,
                          ),
                  ),
                ),
            Marker(
              point: playerPosition.toLatLng(),
              width: NpSize.playerHalo,
              height: NpSize.playerHalo,
              child: const NpPlayerMarker(),
            ),
            if (playerLabel != null)
              Marker(
                point: playerPosition.toLatLng(),
                width: 220,
                // Tall enough to clear both the player halo and the pin of a
                // place standing on the same corner — at city zoom, 40 m is
                // only a few pixels.
                height: _playerLabelClearance,
                alignment: Alignment.topCenter,
                child: playerLabel!,
              ),
          ],
        ),

        // The credit the map data requires is *not* drawn here. The bottom of
        // the map is covered by the nav bar and the check-in card, so it lives
        // in the screen's chrome instead — see `BasemapAttribution`, which
        // MapScreen renders directly under the search field.
      ],
    );
  }
}

/// Punches holes in the fog wherever the player has already been.
///
/// Sits inside [FlutterMap] so it can project coordinates through the live
/// camera — pan the map and the clearings stay glued to the streets.
class _FogLayer extends StatelessWidget {
  const _FogLayer({
    required this.playerPosition,
    required this.exploredArea,
    required this.settings,
  });

  final GeoPoint playerPosition;
  final ExploredArea exploredArea;
  final FogSettings settings;

  /// Clearings are sized in **metres**, not pixels: a stored trail has to cover
  /// the same ground at every zoom level, or zooming out would appear to
  /// uncover half the province.
  static double _pixelsPerMeter(MapCamera camera, LatLng at) {
    const probeDegrees = 0.001;
    const probeMeters = probeDegrees * 111320;
    final origin = camera.latLngToScreenOffset(at);
    final probe = camera.latLngToScreenOffset(
      LatLng(at.latitude + probeDegrees, at.longitude),
    );
    return (probe - origin).distance / probeMeters;
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final playerLatLng = playerPosition.toLatLng();
    final scale = _pixelsPerMeter(camera, playerLatLng);

    final trailRadius = math.max(8.0, settings.clearingRadiusMeters * scale);
    final playerRadius = math.max(
      24.0,
      settings.playerVisibilityRadiusMeters * scale,
    );

    final viewport = Offset.zero & camera.size;
    final margin = trailRadius;

    // The trail is recorded at a metre, so a single street can be thousands of
    // points that all land within a few pixels of each other. Two passes of
    // thinning keep the draw count proportional to the *screen*, not to how far
    // the player has walked:
    //
    //  1. drop anything off screen (a trail grows without bound; the viewport
    //     does not);
    //  2. keep one point per bucket of a quarter of the clearing radius —
    //     discs that overlap that heavily contribute nothing to the union.
    final bucket = math.max(4.0, trailRadius / 4);
    final seen = <int>{};

    final holes = <NpFogHole>[
      NpFogHole(
        center: camera.latLngToScreenOffset(playerLatLng),
        radius: playerRadius,
      ),
    ];

    for (final cell in exploredArea.cells) {
      final center = camera.latLngToScreenOffset(cell.center.toLatLng());
      if (center.dx < viewport.left - margin ||
          center.dx > viewport.right + margin ||
          center.dy < viewport.top - margin ||
          center.dy > viewport.bottom + margin) {
        continue;
      }

      final key =
          (center.dx / bucket).floor() * 100003 + (center.dy / bucket).floor();
      if (!seen.add(key)) continue;

      holes.add(NpFogHole(center: center, radius: trailRadius));
    }

    return NpFogOverlay(holes: holes);
  }
}

extension GeoPointLatLng on GeoPoint {
  /// The one place the domain's [GeoPoint] meets the map package's `LatLng`.
  LatLng toLatLng() => LatLng(latitude, longitude);
}
