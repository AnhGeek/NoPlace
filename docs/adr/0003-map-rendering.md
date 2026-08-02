# 0003 — `flutter_map` with CARTO raster tiles

**Status:** Accepted · 2026-07-30

## Context

The map is the product, and it has two unusual requirements:

1. **Fog of war.** We draw a near-opaque layer over the whole viewport and punch
   soft holes in it at specific coordinates, every frame, while the camera
   moves.
2. **Dark, but readable.** Street names have to stay legible under the fog and
   under a dimming filter, while orange pins stay the loudest thing on screen.

Candidates: `google_maps_flutter` (platform SDK), `mapbox_maps_flutter` (vector,
themable), `flutter_map` (Dart, tile-based).

## Decision

**`flutter_map` 8** with CARTO's Voyager raster basemap, dimmed via a
`ColorFilter` in `tileBuilder`, and a custom `CustomPainter` fog layer that
projects world coordinates through `MapCamera.latLngToScreenOffset`.

## Consequences

- The fog is a plain Flutter widget in the same compositing tree as everything
  else. On a platform-view map it would have to sit *above* an opaque native
  surface, which is exactly the case where Android platform views cost the most.
- Map pins are ordinary widgets, so `NpMapPin` is one component shared by the
  map, the check-in sheet and the nearby card.
- No API key, no billing account, no per-load quota during development.
- **We render raster tiles**, so we cannot restyle the basemap the way a vector
  style could — dimming is a colour matrix over someone else's design.
- Attribution is our responsibility: `© OpenStreetMap · CARTO` is rendered in
  `MapCanvas`. It is a licence requirement, not decoration.
- CARTO's public basemap endpoint is fine for development and light usage. A
  launch needs a paid tile plan or a self-hosted server — that is a cost item,
  not an architecture change. Disk caching cuts the request volume
  substantially; see [0005](0005-tile-caching-and-fog-persistence.md).

## What would change our mind

- **Vector styling.** If design wants a bespoke basemap (custom road colours,
  hidden labels in unexplored areas), Mapbox's vector styles do things a colour
  matrix cannot.
- **Offline maps.** Best-effort tile caching is now in place
  ([0005](0005-tile-caching-and-fog-persistence.md)), but a promise of
  *downloadable cities* is a different feature, and vendor SDKs handle it
  better.
- **Rendering cost.** If the fog painter becomes the frame budget on mid-range
  Android, the answer is a shader, and that decision gets its own record.

The domain layer uses its own `GeoPoint`, and the single conversion to the map
package's `LatLng` lives in `map_canvas.dart` — so swapping the map library
touches one feature folder, not the model.
