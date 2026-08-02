# NoPlace

Explore your city, one district at a time. The map starts dark; walking is what
uncovers it.

This repository holds three things:

| Path | What it is |
| --- | --- |
| [`app/`](app/) | The Flutter application — Android and iOS |
| [`design/`](design/) | Design tokens: the source of truth for colour, type, spacing and motion |
| [`landing_page/`](landing_page/) | The marketing site, deployed as a Cloudflare Worker |
| [`docs/`](docs/) | Architecture, design system, flows, and the decisions behind them |
| [`tools/`](tools/) | The token compiler and the region-pack cooker |

## Run the app

Requires Flutter 3.44 or newer.

```bash
cd app
flutter pub get
flutter run
```

Useful commands:

```bash
flutter analyze                                          # must be clean
flutter test                                             # unit + widget tests
flutter gen-l10n                                         # regenerate translations
dart run ../tools/token_builder/bin/build_tokens.dart    # regenerate tokens
```

## Where to start reading

- **[docs/01-product.md](docs/01-product.md)** — what the app is and what "done"
  means for a feature.
- **[docs/02-architecture.md](docs/02-architecture.md)** — the four layers and
  where new code goes.
- **[docs/06-user-flows.md](docs/06-user-flows.md)** — every screen and how the
  player moves between them.
- **[docs/adr/](docs/adr/)** — the decisions we do not want to relitigate.

## The map

Streets come from OpenStreetMap, packaged as a region pack — one `.mbtiles` file
per city, cooked from the free Protomaps daily build and rendered as vector
tiles styled from `design/tokens/`. No API key, no tile bill, no vendor terms;
the only obligation is displaying `© OpenStreetMap contributors`, which the app
does. See [docs/adr/0008](docs/adr/0008-openstreetmap-basemap.md).

A fresh clone has **no pack** — they are tens of megabytes and are reproducible,
so they are not committed. The app runs without one and simply draws no streets.
To get the map:

```bash
cd tools/region_cooker
dart pub get
dart run bin/cook.dart vn-hcmc                  # needs the `pmtiles` CLI
cp dist/vn-hcmc.mbtiles ../../app/assets/maps/
```

See [tools/region_cooker/README.md](tools/region_cooker/README.md).

## Status

The UI is complete and runs against an in-memory world that applies the real
game rules — check-ins, XP, streaks, district discovery. The basemap is real;
location, the places API and persistence are not wired up yet. See
[docs/backlog.md](docs/backlog.md) for the full list and where each seam is.

Verified on a Galaxy S8+ (Android 9), including the bundled HCMC basemap. iOS is
configured but has not had a device pass.
