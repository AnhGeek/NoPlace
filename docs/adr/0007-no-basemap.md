# 0007 — No third-party basemap

**Status:** Superseded by [0008](0008-openstreetmap-basemap.md) · 2026-08-02 —
we wanted streets back, which is the reversal condition this record names at the
bottom. The route taken was option 1, self-hosted tiles.

**Originally:** Accepted · 2026-07-31 · supersedes the tile-caching half of
[0005](0005-tile-caching-and-fog-persistence.md), amends
[0003](0003-map-rendering.md)

## Context

NoPlace rendered CARTO's Voyager raster tiles, which are built from
OpenStreetMap data. Both require attribution while their tiles are displayed.

The decision was to stop using them.

One clarification that shaped the outcome, because it is a common
misunderstanding: **`flutter_map` is a renderer, not a map.** It draws tiles,
markers and layers, and handles the camera and projection — but it ships no map
data of its own. "Use flutter_map instead of CARTO" is not an option; the real
choice is which tile source, or none.

## Decision

**No tile layer.** The map is the player's own trail and their own points on a
dark ground.

`flutter_map` stays, doing the work that actually matters here: the camera, the
coordinate projection the fog painter needs every frame, and marker placement.
It simply has nothing to draw underneath.

Removed with it: the tile URL, the tile-dimming colour filter, the attribution
widget, and the `BuiltInMapCachingProvider` configuration from 0005 — there are
no tiles left to cache.

## Consequences

- **No streets, no labels, no landmarks.** The player's sense of place comes
  entirely from their own trail and their own points. This is a real product
  change, not a cosmetic one, and it is the main thing to evaluate on a walk.
- **A second colour became necessary.** With tiles, the fog worked by hiding
  something. With nothing underneath, clearing the fog revealed more black — the
  map looked identical whether you had walked somewhere or not. Explored ground
  now has its own token (`color.background.exploredGround`), and the fog is
  fully opaque above it. The fog no longer *hides* the world; it *is* the
  difference between known and unknown ground.
- No API key, no tile bill, no attribution obligation, no third-party terms.
- No offline concern: there is nothing to download.

## What would change our mind

Wanting streets back. If that happens, the options in order of effort:

1. **Self-hosted tiles** — full control, full attribution obligation to whatever
   data source is used (almost certainly still OpenStreetMap).
2. **A paid vendor** (Google, Mapbox) — see
   [0003](0003-map-rendering.md); note Mapbox's data is also partly OSM, and
   Google's Places terms may constrain the renderer choice.
3. **Our own minimal geometry** — draw only district outlines and major roads
   from a small dataset we own. Fits the aesthetic, and is the only route that
   is genuinely free of third-party map data.

Worth being clear about the constraint: essentially every free raster basemap is
OSM-derived. "Streets, but not from OpenStreetMap" means paying a vendor or
sourcing the geometry ourselves.
