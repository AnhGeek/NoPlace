# The region cooker

Turns OpenStreetMap data into a NoPlace region pack: one city, one `.mbtiles`
file, the format in [region-pack-format.md](../../docs/region-pack-format.md)
that the app reads directly.

Why it exists and why it looks like this:
[adr/0008](../../docs/adr/0008-openstreetmap-basemap.md).

## Once, before the first cook

Install the `pmtiles` CLI — a single Go binary from
<https://docs.protomaps.com/pmtiles/cli>. No Docker, no account, **no API key**.

> A Protomaps API key (`protomaps_api_key` in `.env`) is for their *hosted tile
> service*, which is the vendor path this whole design avoids. The cooker does
> not read it and does not need it: the daily planet build is a free download.

```bash
cd tools/region_cooker
dart pub get
```

## Cook a city

```bash
dart run bin/cook.dart vn-hcmc
```

Roughly twenty seconds and 33 MB for Ho Chi Minh City. What happens:

1. **extract** — `pmtiles extract` cuts the region's bounding box out of the
   Protomaps daily planet build using HTTP range requests. Only the tiles inside
   the bbox are transferred: HCMC is 44 requests against a planet-sized file.
2. **convert** — PMTiles → MBTiles. The CLI only converts the other way, so this
   half is ours: [`lib/pmtiles.dart`](lib/pmtiles.dart). It also does the
   **XYZ → TMS y-flip**, which the app undoes on read. Both sides are tested.
3. **stamp** — writes the MBTiles standard keys and our `np:` ones, including
   `np:attribution`, which the app renders verbatim.
4. **verify** — refuses to finish on an empty zoom level, a zero-byte tile, a
   missing attribution, or a pack over the region's size budget.

Then either bundle it:

```bash
cp dist/vn-hcmc.mbtiles ../../app/assets/maps/vn-hcmc.mbtiles
```

or upload it to any HTTPS object store — R2, S3, a CDN, a web server — and point
`RegionCatalogue.remoteBase` at it. A pack is a static file; the app fetches it
with a plain GET and no vendor SDK, which is what keeps that choice open.

## Add a city

One file: `regions/<id>.json`. Nothing else changes.

```json
{
  "id": "vn-danang",
  "name": "Đà Nẵng",
  "name_en": "Da Nang",
  "country": "VN",
  "bbox": [107.96, 15.92, 108.35, 16.15],
  "minzoom": 8,
  "maxzoom": 15,
  "build": "20260806",
  "attribution": "© OpenStreetMap contributors",
  "tile_source": "protomaps-v4",
  "max_size_mb": 120
}
```

`build` is pinned to a date on purpose, never "latest": two cooks of the same
input must produce the same pack, or nothing downstream can be trusted. Bump it
deliberately when you want newer map data.

It also has to be bumped whether you want newer data or not. Protomaps keeps
only about a week of daily builds, so a pin older than that is a 404 and the
cook dies on `Failed to create range reader`. That is a release-day failure —
the tag is already pushed by the time it happens, as v0.7.1 found out — so bump
the pin *before* tagging if the last one is more than a few days old. Check what
is still up with:

```bash
curl -sI -r 0-0 https://build.protomaps.com/20260806.pmtiles | head -1
```

The reproducibility this pin buys is therefore a week long, not forever. Keeping
a pack byte-identical beyond that means hosting the planet build ourselves,
which is a bigger decision than this tool should make on its own.

`maxzoom` is the size dial. z15 is a street corner and costs ~33 MB for HCMC;
z14 is roughly a quarter of that and stops being useful on foot.

## Licensing

The tiles are a Produced Work of OpenStreetMap under the Open Database Licence.
The obligation — display `© OpenStreetMap contributors` — travels with the data
and does **not** disappear by going offline.

That obligation is carried in the pack itself, as `np:attribution`, and the app
renders whatever it says without knowing anything about the source. Change the
source, change that string, and the credit follows.
