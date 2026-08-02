# Region Pack format v1

The contract between the data pipeline ([NP-2](tickets/NP-2-region-pack-cooker.md))
and the app ([NP-1](tickets/NP-1-region-packs-on-device.md)). Neither side may
change this file alone.

A **region pack** is everything the app needs to work in one city: the map
tiles, and the places on it. One file, one region, one version.

## Why one SQLite file

A pack is a **valid MBTiles file with extra tables**. MBTiles is a published
spec and is itself SQLite, so this buys three things at once:

* the app already links SQLite — no new reader to write, no new plugin;
* any MBTiles tool (QGIS, `mbutil`, tileserver-gl) opens a pack and shows the
  map, which makes the pipeline inspectable at every step;
* the places travel with the tiles they belong to. A region is never half
  updated.

Readers that only know MBTiles ignore the extra tables. That is by design.

## Naming

```
<region-id>.v<pack-version>.mbtiles      e.g. vn-hcmc.v3.mbtiles
```

`region-id` is stable forever: `vn-hcmc`, `vn-dongnai`, `vn-hanoi`. Prefix is
ISO-3166-1 alpha-2, lower case. `pack-version` is an integer, incremented on
every publish of that region.

## Schema

### `metadata` — MBTiles standard, plus ours

Standard keys (required by the spec): `name`, `format` (`pbf` — vector tiles;
see [adr/0008](adr/0008-openstreetmap-basemap.md). Raster packs would say `png`
and the app reads whichever the metadata declares), `bounds`
(`minLon,minLat,maxLon,maxLat`), `center`, `minzoom`, `maxzoom`, `type`
(`baselayer`), `version`, `description`.

NoPlace keys:

| Key | Example | Meaning |
| --- | --- | --- |
| `np:format_version` | `1` | This document's version. The app refuses a pack it does not understand. |
| `np:region_id` | `vn-hcmc` | Stable region identity. |
| `np:region_name` | `TP. Hồ Chí Minh` | Display name, in Vietnamese. |
| `np:region_name_en` | `Ho Chi Minh City` | Display name, English. |
| `np:country` | `VN` | Country guard — the app only loads `VN` today. |
| `np:pack_version` | `3` | Increments per publish. |
| `np:built_at` | `2026-07-31T09:12:00Z` | UTC, from the pipeline. |
| `np:tile_source` | `protomaps-v4` | Which upstream the tiles came from. |
| `np:place_source` | `osm-overpass` | Which upstream the places came from. |
| `np:attribution` | `© OpenStreetMap contributors` | **Rendered verbatim by the app.** Empty string means show nothing. |
| `np:sha256` | `9f2c…` | Checksum of the pack, excluding this row. |

`np:attribution` is the mechanism that keeps the app honest without knowing
anything about its data sources: whatever the pipeline used, the pack states
what must be credited, and the app displays it. Swap the source, the credit
follows.

### `tiles` — MBTiles standard

```sql
CREATE TABLE tiles (
  zoom_level  INTEGER,
  tile_column INTEGER,
  tile_row    INTEGER,
  tile_data   BLOB,
  PRIMARY KEY (zoom_level, tile_column, tile_row)
);
```

⚠️ **MBTiles rows are TMS, not XYZ.** The y axis is flipped relative to the
slippy-map convention `flutter_map` uses:

```
tile_row = (1 << zoom) - 1 - y
```

This is the single most common bug in MBTiles readers. Both sides must have a
test for it, at more than one zoom.

### `places` — ours

Every point the app shows as a *suggested* point, plus the metadata it needs.

```sql
CREATE TABLE places (
  id          TEXT PRIMARY KEY,   -- '<source>:<source_ref>', stable across cooks
  name        TEXT NOT NULL,      -- local language
  name_en     TEXT,
  category    TEXT NOT NULL,      -- see the category vocabulary below
  latitude    REAL NOT NULL,
  longitude   REAL NOT NULL,
  district_id TEXT,               -- → districts.id, nullable
  address     TEXT,
  xp_reward   INTEGER NOT NULL DEFAULT 50,
  source      TEXT NOT NULL,      -- 'osm' | 'overture' | 'google' | 'apple' | 'manual'
  source_ref  TEXT,               -- upstream id, so a re-cook can diff
  attributes  TEXT                -- JSON, source-specific extras; app may ignore
);
CREATE INDEX idx_places_bounds ON places (latitude, longitude);
CREATE INDEX idx_places_district ON places (district_id);
```

`attributes` is the escape hatch that keeps the schema from churning every time
a source has one more field. The app never depends on anything inside it.

### `districts` — ours

Progression is measured in districts, so they ship with the region.

```sql
CREATE TABLE districts (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  name_en    TEXT,
  idx        INTEGER NOT NULL,    -- 1-based, display order
  center_lat REAL NOT NULL,
  center_lng REAL NOT NULL,
  boundary   TEXT                 -- GeoJSON Polygon/MultiPolygon, nullable in v1
);
```

`boundary` is nullable for the beta: with it null, "which district am I in?"
falls back to nearest centre. Filling it in is a data change, not a code change.

## Category vocabulary

Closed set. The pipeline maps every source's taxonomy onto exactly these; the
app renders an unknown value as `unknown` rather than failing.

```
food · cafe · landmark · park · market · unknown
```

Extending this list means changing the app's pin rendering, so it is a
deliberate, versioned change — not something a cook run can introduce.

## The catalogue

A single small JSON, served by the API and also bundled in the app, saying what
exists:

```jsonc
{
  "format_version": 1,
  "generated_at": "2026-07-31T09:12:00Z",
  "regions": [
    {
      "id": "vn-hcmc",
      "name": "TP. Hồ Chí Minh",
      "name_en": "Ho Chi Minh City",
      "country": "VN",
      "pack_version": 3,
      "bbox": [106.36, 10.34, 107.03, 11.16],   // minLon, minLat, maxLon, maxLat
      "size_bytes": 26214400,
      "sha256": "9f2c…",
      "url": "https://…/packs/vn-hcmc.v3.mbtiles",   // placeholder until the API exists
      "bundled": true
    }
  ]
}
```

`bbox` is what the app uses to pick a region from a GPS fix in the beta. It is
deliberately coarse — rectangles overlap around city borders, and the app
resolves ties by distance to the region centre. District polygons are the fix,
and they are a later data change.

## Compatibility rules

* The app checks `np:format_version` first and refuses anything it does not
  know, falling back to the previous pack it has.
* Adding a `metadata` key, a `places` column, or an `attributes` field is
  **backward compatible** — bump nothing.
* Removing or re-typing a column, or changing the category vocabulary, is
  **breaking** — bump `np:format_version` and this document.
