# 0008 — Our own OpenStreetMap basemap, shipped as vector region packs

**Status:** Accepted · 2026-08-02 · supersedes
[0007](0007-no-basemap.md), replaces the tile source in
[0003](0003-map-rendering.md)

## Context

[0007](0007-no-basemap.md) removed the basemap entirely and predicted the
condition that would reverse it: *wanting streets back*. That happened. Walking
a city with no streets under the fog means the player's only sense of place is
the shape of their own trail, and one dark clearing looks much like another.

The requirement was narrow and worth stating exactly, because it rules out most
of the market: **free, offline-capable, and with no vendor terms that could be
withdrawn.** The app also has to remain publishable on both stores.

Options, and why they lost:

| Option | Why not |
| --- | --- |
| `openstreetmap.org` raster tiles | Breaks the OSMF tile usage policy for apps. Not a store problem — a "you are blocked" problem. |
| CARTO / Stadia / MapTiler free tiers | API keys, quotas and terms. This is exactly what 0003 backed away from. |
| Google or Mapbox SDKs | Costs money at launch, and Google's Places terms constrain the renderer. |
| Raster tiles we render ourselves | Needs a GL rendering pipeline in Docker, and freezes the styling at cook time. |

One thing worth writing down because it is a common misunderstanding, and
0007 got it right: **neither the store policies nor the licence care that the
data is OpenStreetMap.** Play and the App Store place no restriction on
OSM-derived maps. The real obligation is the Open Database Licence's: display
`© OpenStreetMap contributors` while the tiles are shown. Going offline does not
remove it.

## Decision

**Vector tiles from OpenStreetMap, via Protomaps, packaged as one MBTiles file
per city and styled at runtime from our design tokens.**

Four parts:

1. **The data.** [Protomaps](https://docs.protomaps.com/basemaps/downloads)
   publishes a free daily PMTiles build of the whole planet from OSM data.
   `pmtiles extract` cuts our bounding box out of it over HTTP range requests —
   Ho Chi Minh City at z8–15 is 44 requests and 33 MB, in about twenty seconds.
   No account, no API key, no rate limit.

2. **The container.** A pack is an MBTiles file, which is the format
   [region-pack-format.md](../region-pack-format.md) already specified, now with
   `format = pbf` instead of `png`. MBTiles is SQLite, and the app already links
   `sqflite`, so the reader is a table query and a y-flip rather than a new
   binary format.

3. **The look.** `NpBasemapStyle` builds a MapLibre style in Dart from the
   generated design tokens. Because the tiles are vector, the style is applied
   at *render* time — so the basemap cannot drift from the app it sits under,
   and a brand colour change is a token change.

4. **The renderer.** `vector_map_tiles` inside the existing `flutter_map`.
   `flutter_map` keeps doing what 0007 correctly identified as the work that
   matters: the camera, the projection the fog painter calls every frame, and
   marker placement.

The pack is found by precedence — a downloaded pack, then the one bundled in the
app, then nothing. The remote is a **plain HTTPS URL**: a pack is a static file,
so it can live on Cloudflare R2, S3, a CDN or a plain web server, and the app
cannot tell the difference. No vendor SDK is what keeps that true.

## Consequences

- **Streets are back**, and they are ours: no key, no bill, no quota, no
  third-party terms that can change under us.
- **The fog now hides something again.** 0007 had to invent
  `color.background.exploredGround` because clearing the fog revealed more
  black. It stays — it is the ground the map is drawn on — but the reward for
  walking is now a street you can name.
- **The APK is ~34 MB larger** with HCMC bundled. That buys a map that works on
  a plane, in a basement and through a dead zone, which is a real condition for
  this product rather than a hypothetical. Đồng Nai and Hà Nội are
  download-only for the same reason.
- **Attribution is a rendered widget, not a comment.** `BasemapAttribution`
  shows whatever the pack's `np:attribution` says, verbatim. It sits in the
  screen chrome rather than on the map because the bottom of the map is covered
  by the nav bar and the check-in card, and a credit behind a nav bar is not a
  credit.
- **We depend on a beta.** `vector_map_tiles` supports `flutter_map` 8 only on
  its `9.0.0-beta` line, and it is pinned exactly rather than with a caret so it
  cannot move on its own. This is the one soft spot in the decision.
- `pmtiles` and `vector_tile_renderer` disagree about `protobuf` and `latlong2`
  versions, so the PMTiles reader in the cooker is ours
  (`tools/region_cooker/lib/pmtiles.dart`, ~200 lines against a published spec).
  It is build-time code and never ships.
- Verified on a Galaxy S8+ (Android 9): the bundled pack renders the correct
  streets, the right way up, under the fog.

## What would change our mind

- **A pack per country instead of per city.** The precedence logic and the
  format already allow it; the reason not to is size.
- **Raster.** If vector rendering turns out to be the frame budget on
  mid-range Android, the same pipeline can emit raster tiles into the same
  container — `format` is a metadata key. We would lose runtime styling.
- **Places from the pack.** The tiles carry a `pois` layer we currently ignore,
  because the app's places come from the world repository. If those two ever
  need to be the same data, this is where it comes from.
