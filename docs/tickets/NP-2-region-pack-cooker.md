# NP-2 — The region pack cooker

**Type:** Tooling · **Area:** `tools/region_cooker/` · **Produces:** the packs
[NP-1](NP-1-region-packs-on-device.md) consumes · **Contract:**
[region-pack-format.md](../region-pack-format.md)

## Why

The app must not care where map data came from. Today that is OpenStreetMap via
Protomaps; tomorrow it could be Overture, a Google or Apple export, a government
dataset, or something we survey ourselves. Every one of those becomes the same
`.mbtiles` pack.

That is the whole job: **many sources in, one format out, repeatably.**

## Shape

```
tools/region_cooker/
├── regions/            one config per region
│   ├── vn-hcmc.yaml
│   ├── vn-dongnai.yaml
│   └── vn-hanoi.yaml
├── sources/            one adapter per upstream
│   ├── protomaps.*     vector tiles → raster
│   ├── osm-overpass.*  POIs → places
│   ├── overture.*      (stub)
│   ├── google.*        (stub)
│   └── apple.*         (stub)
├── style/
│   └── noplace-dark.json    MapLibre style, generated from design tokens
├── dist/               output packs + catalogue.json
└── cook                the CLI
```

A region config is the only thing anyone edits to add a city:

```yaml
id: vn-hcmc
name: "TP. Hồ Chí Minh"
name_en: "Ho Chi Minh City"
country: VN
bbox: [106.36, 10.34, 107.03, 11.16]
zoom: { min: 14, max: 17 }
tiles:  { source: protomaps, build: v4-daily }
places: { source: osm-overpass, categories: [food, cafe, landmark, park, market] }
attribution: "© OpenStreetMap contributors"
districts: districts/vn-hcmc.geojson
```

## Pipeline

```
cook fetch  <region>   upstream data for the bbox, cached locally
cook render <region>   vector → raster PNG, NoPlace dark style, z14–17
cook places <region>   upstream POIs → normalised `places` rows
cook pack   <region>   metadata + tiles + places + districts → .mbtiles
cook verify <region>   refuse to publish a bad pack (see below)
cook publish           copy to dist/, bump pack_version, rewrite catalogue.json
cook all    <region>   the lot
```

Rendering is [`mapgl-tile-renderer`](https://hub.docker.com/r/communityfirst/mapgl-tile-renderer)
or `tileserver-gl` in Docker — both are Node/GL, so the cooker is Node with a
Dockerfile, not Dart. It never runs on a developer's machine by accident: the
CLI refuses to run outside its container.

### Source adapters

One interface, so a new upstream is a new file and a config line, never a change
to `pack`:

```
TileSource   → fetch(bbox, zoom) → local vector/raster tiles
PlaceSource  → fetch(bbox)       → [{ id, name, name_en, category, lat, lng,
                                      district_id, address, source, source_ref,
                                      attributes }]
```

Each adapter owns two things nobody else may know about: how to talk to its
upstream, and **how to map that upstream's taxonomy onto our closed category
vocabulary**. Google's `restaurant`, OSM's `amenity=restaurant` and Overture's
`eat_and_drink` all arrive as `food`.

Ship `protomaps` and `osm-overpass` working; ship `overture`, `google` and
`apple` as stubs that throw "not implemented" — the point is that the seam is
visible and the shape is fixed before anyone needs it.

### Determinism

Same inputs must produce the same pack, or nothing downstream can be trusted:

* pin the upstream build (`protomaps: v4-daily/2026-07-31`), never "latest";
* sort rows before writing so checksums are stable;
* `built_at` and `pack_version` are the only fields allowed to vary between two
  cooks of the same input;
* cache fetched upstream data by content hash — re-rendering must not re-download
  a country extract.

### The style comes from our tokens

`style/noplace-dark.json` is **generated** from `design/tokens/`, by the existing
token builder gaining a MapLibre emitter. A brand colour change must not mean
somebody hand-editing a map style, and the map must not drift from the app it
sits under.

## `cook verify` — what makes a pack publishable

Refuse on any of these, loudly:

- [ ] `np:format_version` matches the spec the cooker was built against
- [ ] every zoom in `[min, max]` has tiles, and the count is within 5% of the
      expected count for the bbox — catches a render that died half way
- [ ] no tile is 0 bytes; no tile is suspiciously identical across the whole
      pyramid (a solid-colour render is a silent failure)
- [ ] a sampled tile round-trips through the **XYZ→TMS flip** and lands where it
      should — the same test the app has, on the other side of the contract
- [ ] `places` is non-empty; every `category` is in the vocabulary; every
      lat/lng is inside `bbox`; no duplicate `id`
- [ ] every `district_id` referenced by a place exists in `districts`
- [ ] `np:attribution` is present and non-null (empty string is a deliberate
      choice, null is a mistake)
- [ ] pack size within the region's budget, so nobody discovers a 400 MB pack
      after it ships

## Acceptance criteria

- [ ] `cook all vn-hcmc` produces `dist/vn-hcmc.v1.mbtiles` and a valid
      `catalogue.json`, from nothing, in one command.
- [ ] The pack opens in QGIS and shows the map — proof it is honest MBTiles.
- [ ] The same pack loads in the app (NP-1) with places and districts present.
- [ ] All three regions cook.
- [ ] Adding a hypothetical fourth source touches one new file plus one config
      line, and nothing in `pack` or `verify`.
- [ ] Two consecutive cooks of pinned inputs produce byte-identical packs apart
      from `built_at`/`pack_version`.
- [ ] `cook verify` fails a deliberately corrupted pack in CI.
- [ ] README covers running it, adding a region, and adding a source.

## Out of scope

* Serving the packs. `dist/` and `catalogue.json` are files; the API is later.
* Incremental/differential updates — a pack is replaced whole in v1.
* Vector packs. Raster only; the format can gain a `format: pbf` later.
* Automatic scheduling. Someone runs it, on purpose.

## Open questions

1. **Licensing follows the source, and it is stated in the pack.** Cooking from
   Protomaps or OSM means `attribution: "© OpenStreetMap contributors"` — the
   obligation does not disappear by going offline. It disappears only with data
   we own or license. The format supports both; the config decides.
2. **Zoom range** — z14–17 (~25 MB/region) or z14–16 (~6 MB)? Ties directly to
   the APK-size question in NP-1.
3. **How often do packs get re-cooked**, and does a player's progress survive a
   place disappearing between versions? Suggest: `places.id` is stable, and the
   app keeps a check-in whose place has vanished rather than deleting history.
