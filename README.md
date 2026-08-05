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
for region in vn-hcmc vn-dongnai; do            # needs the `pmtiles` CLI
  dart run bin/cook.dart "$region"
  cp "dist/$region.mbtiles" ../../app/assets/maps/
done
```

Those two are the packs the release bundles, and the app opens whichever of them
the player is standing in — see `RegionCatalogue`. Cooking only one is fine for
development: a region with no pack draws no streets and nothing else breaks.

See [tools/region_cooker/README.md](tools/region_cooker/README.md).

## Releasing

Every push and pull request runs
[`.github/workflows/ci.yml`](.github/workflows/ci.yml): token sync, format,
`flutter analyze --fatal-infos`, tests, and a debug Android build.

Shipping an APK is a tag push:

```bash
git tag v0.1.0
git push origin v0.1.0
```

[`.github/workflows/release.yml`](.github/workflows/release.yml) then builds a
signed **arm64-v8a** APK and attaches it, with a `SHA256SUMS.txt` and a download
section in the notes, to a GitHub Release named after the tag.

arm64 is the only target on purpose — it covers the Samsung Galaxy A06 this
ships to, and every other 64-bit ARM phone. It will not install on a 32-bit
device or an x86 emulator; add a target back to the build step when one is
needed. The marketing version
comes from the tag (`v0.1.0` → `0.1.0`) and the build number from the workflow
run number, so neither is edited in `pubspec.yaml` by hand. A tag containing a
hyphen (`v0.2.0-rc1`) is published as a pre-release.

The release job **cooks the Ho Chi Minh City pack itself** and bundles it, so a
downloaded APK draws streets on first launch with no network. Region packs stay
gitignored — the job installs the pinned `pmtiles` CLI and runs the same cooker
you run locally, which is why the pack's `build` date is pinned rather than
`latest`: the release has to be reproducible. It adds roughly 33 MB to the APK
and about a minute to the job.

CI does not cook. Its Android job is a debug build that proves the project still
assembles, and paying the download on every pull request buys nothing.

### One-time signing setup

The release job refuses to run without an upload key, because the Gradle
fallback is the debug key and the runner generates a fresh one on every build —
users could not upgrade in place. Generate the keystore once:

```bash
keytool -genkeypair -v -keystore upload-keystore.jks \
        -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 \
        -alias upload
base64 -w0 upload-keystore.jks     # macOS: base64 -i upload-keystore.jks
```

Keep that file out of the repo and backed up — without it you can never ship an
update to this app again. Then add four repository secrets under
**Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the base64 output above |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_PASSWORD` | the key password |
| `ANDROID_KEY_ALIAS` | `upload` |

Local release builds read the same key from `android/key.properties` instead;
see [app/android/key.properties.example](app/android/key.properties.example).

## Status

The UI is complete and runs against an in-memory world that applies the real
game rules — check-ins, XP, streaks, district discovery. The basemap is real;
location, the places API and persistence are not wired up yet. See
[docs/backlog.md](docs/backlog.md) for the full list and where each seam is.

Verified on a Galaxy S8+ (Android 9), including the bundled HCMC basemap. iOS is
configured but has not had a device pass.
