# NP-1 — Region packs on the device

**Type:** Feature · **Area:** app · **Depends on:** the format in
[region-pack-format.md](../region-pack-format.md) · **Blocks:** nothing
**Pairs with:** [NP-2](NP-2-region-pack-cooker.md), which produces the packs

## Why

The app should run on our own map data, not a third party's. For the beta the
data ships inside the APK; later it comes from our API. The app must not care
which — same format, same code path, the source is just where the file came
from.

It also has to pick the right city by itself. Somebody standing in Biên Hòa
should get Đồng Nai's map without being asked.

## Scope

### 1. Read a region pack

A pack is a SQLite file (MBTiles + our tables). We already link `sqflite`.

* `RegionPack` — opens a pack, validates `np:format_version` and `np:country`,
  exposes metadata, tiles, places and districts.
* `MbtilesTileProvider extends TileProvider` — returns tiles from the pack for
  `flutter_map`.
  **Flip the y axis**: `tile_row = (1 << z) - 1 - y`. Test at ≥2 zoom levels;
  this is the classic MBTiles bug and it looks like "the map is mirrored
  vertically", which is easy to miss on a symmetric city.
* Missing tile → transparent, not an exception. A pack with a hole in it must
  not crash the map.
* Places and districts load into the existing domain entities. `WorldRepository`
  gains a pack-backed implementation and `FakeWorldStore` is retired from the
  runtime (it stays as a test fixture).

### 2. Resolve the region from position

`RegionResolver`:

1. Country guard — outside `VN`, return `RegionUnsupported`. No pack loads.
2. Point-in-bbox against the catalogue. Ties (overlapping rectangles near a
   border) resolve to the nearest region centre.
3. No match → `RegionUnavailable(nearest: …)`, and the UI says which cities we
   do cover rather than showing an empty map.
4. Persist the resolved region so a cold start with no fix opens the last one
   instead of nothing.
5. When the resolved region *changes* mid-session, announce it — "You've
   reached Đồng Nai" — rather than swapping the map underneath the player. See
   decision 3 below.

Beta regions: `vn-hcmc`, `vn-dongnai`, `vn-hanoi`.

### 3. Source: server first, bundled fallback

```
RegionCatalogueSource            (interface)
├── BundledRegionCatalogue       ships in the APK               ← beta
└── HttpRegionCatalogue          our API                        ← placeholder

RegionPackStore
  1. a downloaded pack for this region, if its version ≥ bundled  → use it
  2. otherwise the bundled pack                                   → use it
  3. otherwise RegionUnavailable
```

`HttpRegionCatalogue` is written against a URL constant and **not wired up**.
The point of building it now is that the seam is real and provable — a fake
HTTP catalogue in tests must be able to drive the whole update path.

Update flow, once the API exists: fetch catalogue → compare `pack_version` →
download to a temp file → verify `sha256` → atomic rename into place → swap on
next region load, never mid-session.

### 4. Keep `flutter_map`

Recommendation: **yes, continue with it**, and this ticket is the reason it was
worth re-asking.

What we need is a camera, a projection (`latLngToScreenOffset`, which the fog
painter calls every frame), marker placement, and a pluggable tile source.
`flutter_map` gives all four, and `TileProvider` is a two-method interface — a
pack-backed provider is roughly 40 lines. Replacing it means writing a tile
pyramid, gesture handling and a projection ourselves: weeks, to end up where we
already are.

What changes: `AssetTileProvider` and network tiles both go; the only tile
source becomes the pack.

Revisit only if we move to vector packs, and even then `vector_map_tiles` slots
in as a layer.

## Out of scope

* The HTTP client itself, auth, retry policy — placeholder only.
* Downloading packs over the air, progress UI, storage management.
* District polygons (`boundary` is null in the beta; nearest-centre is fine).
* Any change to the fog, the trail, or the player's own points.

## Acceptance criteria

- [ ] A bundled pack renders as the basemap under the fog, correct side up, at
      every zoom in its range.
- [ ] Places from the pack appear as suggested points and drive the check-in
      prompt; nothing reads `FakeWorldStore` at runtime.
- [ ] `np:attribution` is displayed verbatim when non-empty, and nothing is
      displayed when empty.
- [ ] A GPS fix in each of the three regions resolves to that region; a fix in
      Bangkok resolves to `RegionUnsupported` and the map does not load a pack.
- [ ] A pack with a future `np:format_version` is refused and the previous pack
      keeps working.
- [ ] A corrupt or truncated pack fails to a clear state, never a crash on
      launch.
- [ ] Tests: y-flip at two zooms; region resolution incl. an overlapping-bbox
      tie; catalogue precedence (downloaded > bundled); refusal paths.
- [ ] Verified on the S8 in all three regions with mock locations.

## Decisions

Settled 2026-08-02. Kept here rather than deleted, because the reasoning is
what stops them being re-argued.

1. **Đồng Nai is the province**, not Biên Hòa alone. `vn-dongnai` covers
   `[106.63, 10.50, 107.65, 11.58]`, already in
   [regions/vn-dongnai.json](../../tools/region_cooker/regions/vn-dongnai.json).

2. **Zoom stays z8–15 for now**, and the size question is deferred rather than
   answered. Measured, not estimated: HCMC cooks to **33.4 MB**, giving a
   **48.6 MB** APK with one city bundled. The rest are download-only.

   z15 is roughly a block; z16–17 would be a street corner at several times the
   size, since each level about quadruples the tile count. The call is to walk
   with z15 first and change it if it reads badly — the zoom range is one field
   in a region config and a recook, so this is deliberately cheap to revisit.

   **Revised 2026-08-05:** Đồng Nai is bundled too. It is the province this app
   is actually walked in, and an offline map that has to be downloaded first is
   not one. Hà Nội stays download-only — 700 km away, and weight in the APK of
   every player who never leaves the south.

3. **Crossing a region border is a moment, not a silent swap.** Show
   "You've reached Đồng Nai" when the resolved region changes mid-session.

   **Built 2026-08-05.** `regionArrivalProvider` records the crossing and
   `RegionArrivalSheet` says it — "You've reached Đồng Nai" — and offers the
   picker, because the claims are rectangles and the ground is not: somebody on
   the river is inside one box and looking at the other, and both packs hold
   the tiles either way. A pick goes through
   `RegionPackSourceNotifier.select` and survives the following fixes; only
   crossing into a *different* region than the ground last resolved to moves
   the map again.

   Position-based resolution landed the same day:
   `RegionCatalogue.forPosition` answers point-in-claim and
   `regionPackSourceProvider` holds the answer as state, so the pack and the
   fog follow the player across a border. What is still missing is the *moment*
   — reuse the pattern already carrying the district-discovered celebration, a
   result recorded in a provider and consumed once, so a rebuild cannot replay
   it. Today the swap is silent. **It still happens on a border crossing, never
   under a live map mid-frame.**

   The claims are rectangles trimmed not to overlap, which is a lie the ground
   does not tell: HCMC and Đồng Nai interlock along the river and no pair of
   boxes divides them exactly. 106.80°E is the split. It is wrong by a few
   streets either side and that costs nothing visible — both packs are cooked
   wide enough to hold the overlap, so the map draws either way. Province
   polygons are the real fix and are not worth their weight yet.

   **Revised 2026-08-06: the moment is per *device*, not per launch.** As
   built, the answer lived in memory, so every cold start resolved a region
   against nothing and the sheet opened on a player who had not moved a metre —
   a question asked every morning is one people learn to tap away, and then it
   is worth nothing on the morning it is right. The fix is one row in
   `preferences`: the fix a region was last resolved from, written as it is
   worked out and read back before the first frame. Opening in the same city is
   silent, opening in a new one still asks, and the map now opens on the city
   the phone was last in rather than on the fallback.

   The position is stored rather than the region id, so the catalogue stays the
   one authority on which ground belongs to which city even after a claim is
   redrawn. A second rule falls out of having a position to measure from:
   `RegionCatalogue.crossingDistanceMeters` (2 km) is how far the player has to
   be from that fix before a *different* claim is believed. Rectangle edges run
   through real streets and GPS drift alone can cross one, which used to read
   as a border crossing and back — an arrival sheet and a fog reload each way.

## Still open

- **The fog trail is one global set**, not partitioned by region. Listed in the
  backlog as harmless today, and it stops being harmless the moment a second
  region ships — a player's Hà Nội walking would clear fog in HCMC. It falls
  inside this ticket's blast radius; flagging rather than assuming, because
  fixing it after packs ship means a migration.
