import 'dart:ui';

import '../../../../design_system/tokens/design_tokens.g.dart';

/// The NoPlace basemap style, as MapLibre style JSON.
///
/// Built in Dart from the generated tokens rather than kept as a hand-edited
/// `.json` asset, for one reason: it cannot drift. A brand colour change is a
/// token change, and the map moves with the app it sits under — there is no
/// second copy of the palette for somebody to forget.
///
/// The style targets the **Protomaps v4 layer schema**, which is what our packs
/// are cooked from. Layer names (`earth`, `water`, `roads`, `places`…) and the
/// `kind` attribute come from that schema; see
/// https://docs.protomaps.com/basemaps/layers.
///
/// It is deliberately quiet. The basemap exists so a player can tell one street
/// from another, and nothing more — every value sits within a few steps of the
/// explored-ground colour so the orange pins stay the loudest thing on screen.
abstract final class NpBasemapStyle {
  /// The source name the style refers to. Must match the key the tile provider
  /// is registered under.
  static const String sourceName = 'protomaps';

  static Map<String, dynamic> build() => {
    'version': 8,
    'id': 'noplace-dark',
    'name': 'NoPlace',
    'layers': [
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': _c(NpColors.mapEarth)},
      },
      _fill('earth', 'earth', NpColors.mapEarth),

      // Green first, then everything else, so a park inside an urban area
      // reads as a park.
      _fill(
        'landcover',
        'landcover',
        NpColors.mapPark,
        filter: _kindIn(['forest', 'grassland', 'scrub', 'farmland']),
      ),
      _fill(
        'landuse-urban',
        'landuse',
        NpColors.mapLanduse,
        filter: _kindIn([
          'aerodrome',
          'hospital',
          'industrial',
          'military',
          'railway',
          'university',
          'school',
        ]),
      ),
      _fill(
        'landuse-green',
        'landuse',
        NpColors.mapPark,
        filter: _kindIn([
          'park',
          'garden',
          'forest',
          'nature_reserve',
          'pitch',
          'recreation_ground',
          'cemetery',
          'golf_course',
        ]),
      ),

      _fill('water', 'water', NpColors.mapWater),

      // Buildings only once the player is close enough for them to mean
      // something. At city zoom they would be noise.
      _fill('buildings', 'buildings', NpColors.mapBuilding, minZoom: 15),

      // Roads, narrowest first: a motorway drawn over a footpath is right, the
      // other way round is not.
      _line('roads-path', 'roads', NpColors.mapPath, _widths(0.4, 2.0),
          filter: _kindIn(['path'])),
      _line('roads-rail', 'roads', NpColors.mapRail, _widths(0.4, 1.6),
          filter: _kindIn(['rail'])),
      _line('roads-minor', 'roads', NpColors.mapRoadMinor, _widths(0.5, 4.0),
          filter: _kindIn(['minor_road'])),
      _line('roads-major', 'roads', NpColors.mapRoadMajor, _widths(0.9, 7.0),
          filter: _kindIn(['major_road'])),
      _line('roads-highway', 'roads', NpColors.mapRoadHighway,
          _widths(1.4, 10.0), filter: _kindIn(['highway'])),

      // District edges only. The city's own border is not drawn here — it is
      // drawn above the fog instead, by [buildCityBorder].
      {
        'id': 'boundaries-district',
        'type': 'line',
        'source': sourceName,
        'source-layer': 'boundaries',
        'filter': _kindIn(['county', 'locality']),
        'paint': {
          'line-color': _c(NpColors.mapBoundary),
          'line-width': _widths(0.6, 1.6),
          'line-dasharray': [3, 2],
        },
      },

      // Labels last, so nothing is drawn over a name. Haloed, because a street
      // name has to survive sitting on top of a road of nearly its own colour.
      _label(
        'labels-roads',
        'roads',
        NpColors.mapLabel,
        size: 11,
        minZoom: 15,
      ),
      _label(
        'labels-places',
        'places',
        NpColors.mapLabelStrong,
        size: 13,
        filter: _kindIn(['neighbourhood', 'macrohood', 'locality']),
      ),
    ],
  };

  /// The edge of the city, and nothing else.
  ///
  /// Rendered as a second layer *above* the fog. Everything else on the map is
  /// a reward for walking; this one line is the opposite — it shows the shape
  /// of what has not been walked yet, so the city reads as a territory with an
  /// end to it rather than black in every direction.
  ///
  /// `kind = region` is admin level 4 in OpenStreetMap, which for Vietnam is
  /// the province — and Ho Chi Minh City is a province-level unit. District
  /// edges (`county`) stay on the ground layer, under the fog, where they are
  /// ordinary map detail.
  ///
  /// No background layer: this style must draw the line and leave every other
  /// pixel untouched, or it would paint over the fog it sits on.
  static Map<String, dynamic> buildCityBorder() => {
    'version': 8,
    'id': 'noplace-city-border',
    'name': 'NoPlace city border',
    'layers': [
      {
        'id': 'city-border',
        'type': 'line',
        'source': sourceName,
        'source-layer': 'boundaries',
        'filter': _kindIn(['region']),
        'paint': {
          'line-color': _c(NpColors.mapCityBorder),
          // Heavier than anything on the ground layer: it is being seen
          // through nothing, against near-black, often at city zoom.
          'line-width': _widths(1.5, 4.0),
        },
      },
    ],
  };

  // --------------------------------------------------------------------------
  // Layer builders. Small on purpose: the style above should read as a list of
  // decisions, not as JSON.
  // --------------------------------------------------------------------------

  static Map<String, dynamic> _fill(
    String id,
    String sourceLayer,
    Color color, {
    List<dynamic>? filter,
    int? minZoom,
  }) => {
    'id': id,
    'type': 'fill',
    'source': sourceName,
    'source-layer': sourceLayer,
    'filter': ?filter,
    'minzoom': ?minZoom,
    'paint': {'fill-color': _c(color)},
  };

  static Map<String, dynamic> _line(
    String id,
    String sourceLayer,
    Color color,
    Map<String, dynamic> width, {
    List<dynamic>? filter,
  }) => {
    'id': id,
    'type': 'line',
    'source': sourceName,
    'source-layer': sourceLayer,
    'filter': ?filter,
    'paint': {'line-color': _c(color), 'line-width': width},
  };

  static Map<String, dynamic> _label(
    String id,
    String sourceLayer,
    Color color, {
    required double size,
    List<dynamic>? filter,
    int? minZoom,
  }) => {
    'id': id,
    'type': 'symbol',
    'source': sourceName,
    'source-layer': sourceLayer,
    'filter': ?filter,
    'minzoom': ?minZoom,
    'layout': {'text-field': '{name}', 'text-size': size},
    'paint': {
      'text-color': _c(color),
      'text-halo-color': _c(NpColors.mapLabelHalo),
      'text-halo-width': 1.2,
    },
  };

  /// Road widths in the only unit that behaves: they grow with zoom, so a
  /// street is a hairline across the city and a walkable corridor up close.
  static Map<String, dynamic> _widths(double atZoom12, double atZoom18) => {
    'stops': [
      [12, atZoom12],
      [18, atZoom18],
    ],
  };

  static List<dynamic> _kindIn(List<String> kinds) => ['in', 'kind', ...kinds];

  /// Tokens carry alpha, and MapLibre's `#rrggbb` cannot. `rgba()` can.
  static String _c(Color color) {
    int channel(double v) => (v * 255).round();
    return 'rgba(${channel(color.r)},${channel(color.g)},'
        '${channel(color.b)},${color.a})';
  }
}
