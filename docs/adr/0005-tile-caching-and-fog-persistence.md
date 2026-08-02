# 0005 — Cache tiles with flutter_map; store the fog ourselves

**Status:** Accepted · 2026-07-31

## Context

Two kinds of data leave the process and need to survive it, and they are not
the same kind of data at all.

**Map tiles** are someone else's bytes, re-downloadable at any time. Without
caching, every pan re-fetches: a data-usage and battery problem for an app whose
entire premise is walking around outdoors, and a bill from whoever serves the
tiles.

**The walked trail** is the player's own history. It is the product. Losing it
means telling somebody the kilometres they walked did not count.

An earlier version of this document said flutter_map had no caching and pointed
at community packages (`flutter_map_cache`, FMTC). That was **wrong for
flutter_map 8**, which ships caching in the core. Corrected here rather than
quietly, because the wrong version was acted on.

## Decision

### Tiles — `BuiltInMapCachingProvider`

```dart
TileLayer(
  urlTemplate: ...,
  tileProvider: NetworkTileProvider(
    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: 200 * 1024 * 1024,
      overrideFreshAge: const Duration(days: 14),
    ),
  ),
)
```

- **200 MB, not the 1 GB default.** A city centre across our zoom range is a few
  tens of megabytes. Tiles are disposable; taking a gigabyte of somebody's phone
  for them is not a trade we get to make on their behalf.
- **A fortnight of freshness.** Basemaps change slowly. HTTP headers would
  otherwise have us re-fetch streets that have not moved in decades.
- **The OS cache directory** (the provider's default), which Android and iOS may
  clear under storage pressure. Correct: the worst case is re-downloading.
- No third-party package, so no GPL question — FMTC is GPL-3.0 with a paid
  commercial licence, which would have needed a decision of its own.

### The fog — our own store

`data/local/fog_trail_store.dart`, holding an `ExploredArea` — a set of ~40 m
grid cells rather than a list of GPS fixes.

- **Grid, not fixes.** A walk down one street collapses into a handful of cells
  instead of hundreds of samples; re-walking adds nothing; "have I been here?"
  is a set lookup. The file after a first launch is 163 bytes.
- **Application support directory, not the cache directory.** The OS must never
  bin this.
- **Debounced writes** (3 s after the last change) plus an immediate flush from
  an `AppLifecycleListener` on hide/pause/detach. Recording happens on every
  position fix; writing that often would burn flash and battery, and a
  swipe-away must still cost nothing.
- **Atomic writes** — write `.tmp`, then rename. A rename is atomic on both
  platforms, so a kill mid-write leaves the previous good file rather than a
  truncated one.
- **A version field.** An unrecognised version is discarded, not guessed at. The
  format will change — a bitmask or tile pyramid when trails get long.
- **Loaded in `bootstrap()` before `runApp`.** It is one small file, and reading
  it there is the difference between the city appearing as the player left it
  and the fog visibly snapping open a moment after launch.

### Clearings are sized in metres

The fog painter converts metres to pixels through the live camera each frame.
Previously the radii were pixel constants, which was invisible with a single
clearing around the player and would have been badly wrong the moment a stored
trail had to cover the same ground at every zoom level.

`ExplorationRules.fogClearingRadiusMeters = 180` — tuned on a device, not on
paper. At 70 m the clearing was a pinprick at city zoom and walking felt
unrewarding; past ~250 m the city falls open faster than it can be earned.

## Consequences

- Verified on a Galaxy S8: Wi-Fi off, no SIM, app force-stopped and cold
  launched — the basemap still renders and the fog is exactly as it was left.
- The app now works usably on a walk through a dead zone, which is a real
  condition for the product, not a hypothetical.
- Fog is drawn from a set that grows without bound, so the layer culls to the
  viewport before projecting. Beyond a few thousand cells this needs a spatial
  index.
- The trail is device-local. Reinstall and it is gone. Acceptable while there
  are no accounts; the moment there are, this file is what gets synced.

## What would change our mind

- **Offline-first maps.** If we promise a downloadable city rather than
  best-effort caching, FMTC's bulk region downloading is the tool, and its
  licence becomes a decision to make properly.
- **Trail size.** Tens of thousands of cells make the JSON slow to parse at
  start-up. The answer is a compact binary format or SQLite, not a bigger JSON.
